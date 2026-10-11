import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _secureStorage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  /// Centralized role check for the admin portal.
  static bool isAdminRole(Object? role) {
    final normalized = role?.toString().trim().toLowerCase() ?? '';
    return normalized == 'admin' || normalized == 'administrator' || normalized == 'system administrator' || normalized.contains('admin');
  }

  /// Login with email or username and password using Supabase auth.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    String resolvedEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    // Check if user/email exists in app_users
    bool userExistsInDb = false;
    String? matchedEmail;
    try {
      final query = Supabase.instance.client.from('app_users').select('email, name, role, status');
      final record = await (resolvedEmail.contains('@')
          ? query.ilike('email', resolvedEmail).maybeSingle()
          : query.ilike('name', resolvedEmail).maybeSingle());

      if (record != null) {
        userExistsInDb = true;
        if (!isAdminRole(record['role'])) {
          return {
            'success': false,
            'errorField': 'email',
            'message': 'This account does not have Administrator access to the Admin Portal.',
          };
        }
        if (record['email'] != null) {
          matchedEmail = record['email'].toString().trim().toLowerCase();
        }
      }
    } catch (_) {
      // Query failed, fall back
    }

    if (matchedEmail != null && matchedEmail.isNotEmpty) {
      resolvedEmail = matchedEmail;
    }

    // Default system accounts are always known valid accounts
    final isKnownSystemAccount = resolvedEmail == 'admin' ||
        resolvedEmail == 'admin@piggytrunk.com' ||
        resolvedEmail == 'admin@gmail.com' ||
        resolvedEmail == 'piggytrunk@gmail.com';

    // If username was entered and neither DB nor known accounts match
    if (!resolvedEmail.contains('@') && !userExistsInDb && !isKnownSystemAccount) {
      return {
        'success': false,
        'errorField': 'email',
        'message': 'Username "$email" was not found.',
      };
    }

    try {
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: resolvedEmail,
        password: cleanPassword,
      );

      final session = authResponse.session;
      final user = authResponse.user;

      if (session == null || user == null) {
        return {
          'success': false,
          'errorField': 'password',
          'message': 'Unable to sign in to Supabase. Please verify your credentials.',
        };
      }

      await _secureStorage.write(key: _tokenKey, value: session.accessToken);
      await _secureStorage.write(
        key: _userKey,
        value: jsonEncode({
          'id': user.id,
          'email': user.email,
          'role': 'admin',
        }),
      );

      // Handle Remember Me state persistence
      if (rememberMe) {
        await _secureStorage.write(key: 'remembered_email', value: email);
        await _secureStorage.write(key: 'remembered_password', value: password);
        await _secureStorage.write(key: 'remember_me', value: 'true');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('remembered_email', email);
          await prefs.setString('remembered_password', password);
          await prefs.setBool('remember_me', true);
        } catch (_) {}
      } else {
        await _secureStorage.delete(key: 'remembered_email');
        await _secureStorage.delete(key: 'remembered_password');
        await _secureStorage.write(key: 'remember_me', value: 'false');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('remembered_email');
          await prefs.remove('remembered_password');
          await prefs.setBool('remember_me', false);
        } catch (_) {}
      }

      return {
        'success': true,
        'message': 'Login successful! Welcome back, ${user.email}',
        'token': session.accessToken,
        'user': {
          'id': user.id,
          'email': user.email,
          'role': 'admin',
        },
      };
    } catch (e) {
      String errorMessage = 'An unexpected error occurred. Please try again.';
      String? errorField;

      final isKnownEmail = userExistsInDb || isKnownSystemAccount;

      if (e is AuthException) {
        final msg = e.message.toLowerCase();
        if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
          if (isKnownEmail) {
            errorField = 'password';
            errorMessage = 'Incorrect password. Please try again.';
          } else {
            errorField = 'email';
            errorMessage = 'No account found with this email or username.';
          }
        } else if (msg.contains('email not confirmed')) {
          errorField = 'email';
          errorMessage = 'Email address has not been confirmed.';
        } else {
          errorMessage = e.message;
        }
      } else {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('invalid login credentials') || errStr.contains('invalid_credentials')) {
          if (isKnownEmail) {
            errorField = 'password';
            errorMessage = 'Incorrect password. Please try again.';
          } else {
            errorField = 'email';
            errorMessage = 'No account found with this email or username.';
          }
        }
      }

      return {
        'success': false,
        'errorField': errorField ?? (isKnownEmail ? 'password' : 'email'),
        'message': errorMessage,
      };
    }
  }

  /// Register a new account with typed email/gmail and password with role & metadata
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPassword = password.trim();
      final cleanName = name.trim();

      final res = await Supabase.instance.client.auth.signUp(
        email: cleanEmail,
        password: cleanPassword,
        data: {
          'name': cleanName,
          'full_name': cleanName,
          'role': role,
        },
      );

      final user = res.user;
      if (user != null) {
        return {
          'success': true,
          'message': 'Registration successful! Account is pending admin approval.',
          'user': user,
        };
      } else {
        return {
          'success': false,
          'message': 'Unable to complete registration. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e is AuthException ? e.message : e.toString(),
      };
    }
  }

  /// Update password for the currently authenticated account
  Future<bool> updatePassword(String newPassword) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clear remembered password (e.g. when unchecking Remember Me)
  Future<void> clearRememberedPassword() async {
    try {
      await _secureStorage.delete(key: 'remembered_password');
      await _secureStorage.write(key: 'remember_me', value: 'false');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remembered_password');
      await prefs.setBool('remember_me', false);
    } catch (_) {}
  }

  /// Get remembered email, password, and remember me status
  Future<Map<String, dynamic>> getRememberedCredentials() async {
    try {
      String? email = await _secureStorage.read(key: 'remembered_email');
      String? password = await _secureStorage.read(key: 'remembered_password');
      String? rememberMeStr = await _secureStorage.read(key: 'remember_me');

      // Web Fallback with SharedPreferences
      if (email == null || email.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          email ??= prefs.getString('remembered_email');
          password ??= prefs.getString('remembered_password');
          if (rememberMeStr == null) {
            final prefRemember = prefs.getBool('remember_me');
            if (prefRemember != null) {
              rememberMeStr = prefRemember ? 'true' : 'false';
            }
          }
        } catch (_) {}
      }

      final rememberMe = rememberMeStr == 'true';
      return {
        'email': email ?? '',
        'password': password ?? '',
        'rememberMe': rememberMe && (email != null && email.isNotEmpty),
      };
    } catch (e) {
      return {'email': '', 'password': '', 'rememberMe': false};
    }
  }

  /// Get stored authentication token
  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Logout and clear stored data
  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _userKey);
    } catch (e) {
      // Silently fail
    }
  }

  /// Get stored user data
  Future<Map<String, dynamic>?> getUser() async {
    try {
      final userData = await _secureStorage.read(key: _userKey);
      if (userData != null) {
        return jsonDecode(userData) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Verifies that the current session belongs to an administrator.
  Future<bool> isAdminSession() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    // Fast-path for default known system admin emails
    final userEmail = user.email?.trim().toLowerCase() ?? '';
    if (userEmail == 'admin@piggytrunk.com' ||
        userEmail == 'admin@gmail.com' ||
        userEmail == 'piggytrunk@gmail.com') {
      return true;
    }

    try {
      Map<String, dynamic>? record;

      // 1. Query by UUID column (supabase_user_id)
      try {
        final byUuid = await Supabase.instance.client
            .from('app_users')
            .select('role')
            .eq('supabase_user_id', user.id)
            .maybeSingle();
        if (byUuid != null) {
          record = Map<String, dynamic>.from(byUuid);
        }
      } catch (uuidErr) {
        debugPrint('Notice checking supabase_user_id: $uuidErr');
      }

      // 2. Query by Email fallback
      if (record == null && userEmail.isNotEmpty) {
        try {
          final byEmail = await Supabase.instance.client
              .from('app_users')
              .select('role')
              .ilike('email', userEmail)
              .maybeSingle();
          if (byEmail != null) {
            record = Map<String, dynamic>.from(byEmail);
          }
        } catch (emailErr) {
          debugPrint('Notice checking email: $emailErr');
        }
      }

      return record != null && isAdminRole(record['role']);
    } catch (_) {
      return false;
    }
  }

  /// Check auth and return basic session info.
  /// The dashboard screen fetches its own live data directly from Supabase.
  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No authenticated session found. Please sign in again.',
        };
      }

      final user = Supabase.instance.client.auth.currentUser;
      return {
        'success': true,
        'data': {
          'user': {
            'id': user?.id ?? '',
            'email': user?.email ?? '',
            'role': 'admin',
          },
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unexpected error: ${e.toString()}',
      };
    }
  }

  /// Refresh authentication token
  Future<bool> refreshToken() async {
    try {
      final token = await getToken();
      return token != null;
    } catch (e) {
      return false;
    }
  }
}
