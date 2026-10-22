import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'google_auth_service.dart';

class AuthSessionService {
  static final AuthSessionService _instance = AuthSessionService._internal();
  factory AuthSessionService() => _instance;
  AuthSessionService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _keyUserEmail = 'pt_saved_user_email';
  static const String _keyUserRole = 'pt_saved_user_role';
  static const String _keyLoginMethod = 'pt_saved_login_method'; // 'google' or 'password'
  static const String _keyUserId = 'pt_saved_user_id';

  /// Save session details locally on successful login
  Future<void> saveSession({
    required String email,
    required String role,
    required String loginMethod,
    String? userId,
  }) async {
    try {
      await _storage.write(key: _keyUserEmail, value: email.trim().toLowerCase());
      await _storage.write(key: _keyUserRole, value: role.trim().toLowerCase());
      await _storage.write(key: _keyLoginMethod, value: loginMethod);
      if (userId != null && userId.isNotEmpty) {
        await _storage.write(key: _keyUserId, value: userId);
      }
    } catch (e) {
      debugPrint('AuthSessionService saveSession notice: $e');
    }
  }

  /// Get the currently saved user email
  Future<String?> getSavedEmail() async {
    try {
      return await _storage.read(key: _keyUserEmail);
    } catch (_) {
      return null;
    }
  }

  /// Check if there is a valid existing session and attempt auto-login
  /// Returns a map with { 'canAutoLogin': bool, 'targetRoute': String?, 'email': String?, 'role': String? }
  Future<Map<String, dynamic>> checkAndAttemptAutoLogin() async {
    try {
      // 1. Check if Supabase already has an active session in local storage
      final currentSession = _supabase.auth.currentSession;
      if (currentSession != null) {
        final user = currentSession.user;
        final email = user.email;
        if (email != null && email.isNotEmpty) {
          final accountResult = await _verifyAndResolveUser(email: email, userId: user.id);
          if (accountResult['isActive'] == true) {
            final role = accountResult['role'] ?? 'hog_raiser';
            await saveSession(
              email: email,
              role: role,
              loginMethod: 'supabase_session',
              userId: user.id,
            );
            return {
              'canAutoLogin': true,
              'targetRoute': _getRouteForRole(role),
              'email': email,
              'role': role,
            };
          } else if (accountResult['isPending'] == true) {
            return {
              'canAutoLogin': false,
              'targetRoute': '/onboarding',
              'isPending': true,
            };
          }
        }
      }

      // 2. Try Silent Google Sign-In if previous login was Google or no active Supabase session
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: kIsWeb ? GoogleAuthService.webClientId : GoogleAuthService.androidClientId,
          serverClientId: GoogleAuthService.webClientId,
          scopes: ['email', 'profile'],
        );

        final GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();
        if (googleUser != null) {
          final email = googleUser.email;
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final idToken = googleAuth.idToken;

          if (idToken != null) {
            try {
              await _supabase.auth.signInWithIdToken(
                provider: OAuthProvider.google,
                idToken: idToken,
                accessToken: googleAuth.accessToken,
              );
            } catch (tokenErr) {
              debugPrint('Silent Google signInWithIdToken notice: $tokenErr');
            }
          }

          final accountResult = await _verifyAndResolveUser(email: email);
          if (accountResult['isActive'] == true) {
            final role = accountResult['role'] ?? 'hog_raiser';
            await saveSession(
              email: email,
              role: role,
              loginMethod: 'google',
            );
            return {
              'canAutoLogin': true,
              'targetRoute': _getRouteForRole(role),
              'email': email,
              'role': role,
            };
          } else if (accountResult['isPending'] == true) {
            return {
              'canAutoLogin': false,
              'targetRoute': '/onboarding',
              'isPending': true,
            };
          }
        }
      } catch (googleErr) {
        debugPrint('Silent Google Sign-In notice: $googleErr');
      }

      // 3. Check persistent secure storage as fallback
      final savedEmail = await _storage.read(key: _keyUserEmail);
      final savedRole = await _storage.read(key: _keyUserRole);

      if (savedEmail != null && savedEmail.isNotEmpty) {
        final accountResult = await _verifyAndResolveUser(email: savedEmail);
        if (accountResult['isActive'] == true) {
          final role = accountResult['role'] ?? savedRole ?? 'hog_raiser';
          return {
            'canAutoLogin': true,
            'targetRoute': _getRouteForRole(role),
            'email': savedEmail,
            'role': role,
          };
        } else if (accountResult['isPending'] == true) {
          return {
            'canAutoLogin': false,
            'targetRoute': '/onboarding',
            'isPending': true,
          };
        }
      }
    } catch (e) {
      debugPrint('Error during checkAndAttemptAutoLogin: $e');
    }

    return {
      'canAutoLogin': false,
      'targetRoute': '/onboarding',
    };
  }

  /// Helper to verify user status in app_users / hog_raisers
  Future<Map<String, dynamic>> _verifyAndResolveUser({
    required String email,
    String? userId,
  }) async {
    try {
      Map<String, dynamic>? userData;

      try {
        if (userId != null && userId.isNotEmpty) {
          userData = await _supabase
              .from('app_users')
              .select('status, role, user_id')
              .or('supabase_user_id.eq.$userId,email.eq.$email')
              .maybeSingle();
        } else {
          userData = await _supabase
              .from('app_users')
              .select('status, role, user_id')
              .eq('email', email)
              .maybeSingle();
        }
      } catch (e) {
        debugPrint('Notice query app_users: $e');
      }

      if (userData == null) {
        // Check hog_raisers table fallback
        try {
          final raiser = await _supabase
              .from('hog_raisers')
              .select('account_status, status')
              .eq('email', email)
              .maybeSingle();
          if (raiser != null) {
            userData = {
              'role': 'hog_raiser',
              'status': raiser['account_status'] ?? raiser['status'] ?? 'Active',
            };
          }
        } catch (_) {}
      }

      if (userData != null) {
        final String rawStatus = (userData['status'] ?? 'Active').toString().toLowerCase();
        final String role = (userData['role'] ?? 'hog_raiser').toString().toLowerCase();

        final bool isActive = rawStatus == 'active' || rawStatus == 'approved';
        final bool isPending = rawStatus == 'pending';

        return {
          'exists': true,
          'isActive': isActive,
          'isPending': isPending,
          'role': role,
        };
      }
    } catch (e) {
      debugPrint('Error verifying user: $e');
    }

    return {
      'exists': false,
      'isActive': false,
      'isPending': false,
      'role': 'hog_raiser',
    };
  }

  String _getRouteForRole(String role) {
    final r = role.toLowerCase();
    if (r.contains('admin')) {
      return '/admin_dashboard';
    } else if (r.contains('partner') || r.contains('investor')) {
      return '/partner_dashboard';
    } else if (r.contains('cashier')) {
      return '/cashier_dashboard';
    } else {
      return '/raiser_dashboard';
    }
  }

  /// Clean up all saved session states on user Logout
  Future<void> clearSession() async {
    try {
      await _storage.deleteAll();
      await _supabase.auth.signOut();
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? GoogleAuthService.webClientId : GoogleAuthService.androidClientId,
        serverClientId: GoogleAuthService.webClientId,
      );
      await googleSignIn.signOut();
    } catch (e) {
      debugPrint('AuthSessionService clearSession notice: $e');
    }
  }
}
