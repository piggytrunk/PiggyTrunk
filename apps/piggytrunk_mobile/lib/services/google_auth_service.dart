import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:piggytrunk/services/email_service.dart';

class GoogleAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String webClientId = '1011881228900-5h8q2u45cv9p8vurqu70e032fb8hjon7.apps.googleusercontent.com';
  static const String androidClientId = '1011881228900-de0pk92lqv378o0t06kc6227arog3kh0.apps.googleusercontent.com';

  /// Sign in with Google Auth natively or fallback smoothly
  Future<Map<String, dynamic>> signInWithGoogle({
    String? targetRole,
    bool isSignUpMode = false,
  }) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? webClientId : androidClientId,
        serverClientId: webClientId,
        scopes: ['email', 'profile'],
      );

      // Force account chooser by signing out previous local google session
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      GoogleSignInAccount? googleUser;
      String? googleErr;
      try {
        googleUser = await googleSignIn.signIn();
      } catch (e) {
        googleErr = e.toString();
        debugPrint('GoogleSignIn exception: $e');
      }

      if (googleUser == null) {
        // Try Supabase OAuth fallback if native GoogleSignIn fails or is unconfigured
        try {
          final bool oAuthStarted = await _supabase.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: kIsWeb ? null : 'io.supabase.piggytrunk://login-callback',
          );
          if (oAuthStarted) {
            final user = _supabase.auth.currentUser;
            if (user != null && user.email != null) {
              final String email = user.email!;
              final String fullName = user.userMetadata?['full_name'] ??
                  user.userMetadata?['name'] ??
                  email.split('@').first;
              return await _processGoogleUser(
                email: email,
                targetRole: targetRole,
                fullName: fullName,
                isSignUpMode: isSignUpMode,
              );
            }
          }
        } catch (oauthEx) {
          debugPrint('Supabase signInWithOAuth exception: $oauthEx');
        }

        return {
          'success': false,
          'message': googleErr != null
              ? 'Google Sign-In was canceled.'
              : 'Unable to connect to Google Sign-In. Please check your internet connection or try signing in with email and password.',
        };
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken != null) {
        try {
          await _supabase.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
        } catch (tokenErr) {
          debugPrint('Supabase signInWithIdToken notice: $tokenErr');
        }
      }

      final String email = googleUser.email;
      final String fullName = googleUser.displayName ?? email.split('@').first;

      return await _processGoogleUser(
        email: email,
        targetRole: targetRole,
        fullName: fullName,
        isSignUpMode: isSignUpMode,
      );
    } catch (e) {
      return {
        'success': false,
        'message': 'Google Sign-In error: ${e.toString()}',
      };
    }
  }

  String _toUuid(String str) {
    final String? authId = _supabase.auth.currentUser?.id;
    if (authId != null && authId.contains('-')) {
      return authId;
    }
    final rawHex = str.codeUnits.map((b) => b.toRadixString(16).padLeft(2, '0')).join().padRight(32, '0');
    final s = rawHex.substring(0, 32);
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-4${s.substring(13, 16)}-a${s.substring(17, 20)}-${s.substring(20, 32)}';
  }

  /// Process Google User: Auto-detect existing role or flag for new user role selection
  Future<Map<String, dynamic>> _processGoogleUser({
    required String email,
    String? targetRole,
    String? fullName,
    bool isSignUpMode = false,
  }) async {
    try {
      final nameToUse = (fullName != null && fullName.isNotEmpty)
          ? fullName
          : email.split('@').first;

      final String? authId = _supabase.auth.currentUser?.id;
      final String validGoogleUuid = (authId != null && authId.contains('-'))
          ? authId
          : _toUuid(email);

      Map<String, dynamic>? existingUser;
      try {
        existingUser = await _supabase
            .from('app_users')
            .select('user_id, status, role, name')
            .or('email.eq.$email,supabase_user_id.eq.$validGoogleUuid')
            .maybeSingle();
      } catch (_) {}

      // If user does not exist in database yet
      if (existingUser == null) {
        if (targetRole != null && targetRole.isNotEmpty) {
          // Pre-selected role (from Sign Up screen)
          return await completeGoogleRegistration(
            email: email,
            selectedRole: targetRole,
            fullName: nameToUse,
          );
        }

        // Universal Login: user is new, trigger role selection modal
        return {
          'success': true,
          'is_new_user': true,
          'email': email,
          'name': nameToUse,
        };
      }

      // User exists: auto-detect and return registered role & status
      final String currentRole = (existingUser['role'] ?? 'hog_raiser').toString();
      final String currentStatus = (existingUser['status'] ?? 'Pending').toString();
      final existingUserId = existingUser['user_id'];

      // Link supabase_user_id if not linked yet
      try {
        await _supabase
            .from('app_users')
            .update({'supabase_user_id': validGoogleUuid})
            .eq('user_id', existingUserId);
      } catch (_) {}

      // Always ensure Google Display Name is synced
      if (nameToUse.isNotEmpty && nameToUse != email.split('@').first) {
        try {
          await _supabase
              .from('app_users')
              .update({'name': nameToUse})
              .eq('user_id', existingUserId);
        } catch (_) {}
      }

      return {
        'success': true,
        'is_new_user': false,
        'email': email,
        'name': existingUser['name'] ?? nameToUse,
        'role': currentRole,
        'status': currentStatus,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing Google account: ${e.toString()}',
      };
    }
  }

  /// Complete Google Registration with selected role
  Future<Map<String, dynamic>> completeGoogleRegistration({
    required String email,
    required String selectedRole,
    String? fullName,
  }) async {
    try {
      final nameToUse = (fullName != null && fullName.isNotEmpty)
          ? fullName
          : email.split('@').first;

      final String? authId = _supabase.auth.currentUser?.id;
      final String validGoogleUuid = (authId != null && authId.contains('-'))
          ? authId
          : _toUuid(email);

      dynamic newUserId;
      try {
        final insertedUser = await _supabase.from('app_users').upsert({
          'supabase_user_id': validGoogleUuid,
          'email': email,
          'name': nameToUse,
          'role': selectedRole,
          'status': 'Pending',
        }, onConflict: 'email').select('user_id').single();

        newUserId = insertedUser['user_id'];
      } catch (insertErr) {
        debugPrint('app_users upsert notice: $insertErr');
        try {
          final fetchedUser = await _supabase
              .from('app_users')
              .select('user_id')
              .eq('email', email)
              .maybeSingle();
          if (fetchedUser != null) {
            newUserId = fetchedUser['user_id'];
          }
        } catch (_) {}
      }

      if (newUserId != null) {
        if (selectedRole == 'hog_raiser' || selectedRole == 'raiser') {
          try {
            await _supabase.from('hog_raisers').insert({
              'user_id': newUserId,
              'name': nameToUse,
              'phone': 'N/A',
              'address': 'N/A',
              'status': 'Inactive',
              'account_status': 'Pending',
              'pig_type': 'N/A',
              'lifecycle_stage': 'N/A',
            });
          } catch (raiserErr) {
            debugPrint('Hog raiser auto-create notice: $raiserErr');
          }
        } else if (selectedRole == 'partner' || selectedRole == 'investor') {
          try {
            await _supabase.from('partner_investors').insert({
              'user_id': newUserId,
            });
          } catch (partnerErr) {
            debugPrint('Partner investor auto-create notice: $partnerErr');
          }
        } else if (selectedRole == 'cashier') {
          try {
            await _supabase.from('cashiers').insert({
              'user_id': newUserId,
              'status': 'Pending',
            });
          } catch (cashierErr) {
            debugPrint('Cashier auto-create notice: $cashierErr');
          }
        }

        // Send Notification to Admin Web
        try {
          final String roleDisplay = selectedRole == 'hog_raiser' || selectedRole == 'raiser'
              ? 'Hog Raiser'
              : (selectedRole == 'partner' || selectedRole == 'investor' ? 'Partner Investor' : 'Cashier');
          await _supabase.from('admin_notifications').insert({
            'title': 'New User Registration',
            'message': '$nameToUse ($email) registered as $roleDisplay and is pending approval.',
            'type': 'user_registration',
            'is_read': false,
            'metadata': {
              'user_id': newUserId,
              'email': email,
              'name': nameToUse,
              'role': selectedRole,
            },
          });
        } catch (notifErr) {
          debugPrint('Admin notification insert notice: $notifErr');
        }

        // Trigger Registration Email via Gmail SMTP
        try {
          EmailService().sendRegistrationEmail(
            recipientEmail: email,
            recipientName: nameToUse,
            role: selectedRole,
          );
        } catch (emailErr) {
          debugPrint('Email send notice: $emailErr');
        }
      }

      return {
        'success': true,
        'is_new_user': true,
        'email': email,
        'name': nameToUse,
        'role': selectedRole,
        'status': 'Pending',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to complete registration: ${e.toString()}',
      };
    }
  }
}
