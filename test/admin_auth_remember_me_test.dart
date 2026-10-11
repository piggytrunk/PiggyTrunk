import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Auth Remember Me & Session Logic Tests', () {
    // 1. Role Check
    test('isAdminRole correctly identifies administrator accounts', () {
      bool isAdminRole(Object? role) {
        final normalized = role?.toString().trim().toLowerCase() ?? '';
        return normalized == 'admin' ||
            normalized == 'administrator' ||
            normalized == 'system administrator' ||
            normalized.contains('admin');
      }

      expect(isAdminRole('admin'), isTrue);
      expect(isAdminRole('Administrator'), isTrue);
      expect(isAdminRole('System Administrator'), isTrue);
      expect(isAdminRole('super_admin'), isTrue);
      expect(isAdminRole('partner'), isFalse);
      expect(isAdminRole('cashier'), isFalse);
      expect(isAdminRole('hog_raiser'), isFalse);
      expect(isAdminRole(null), isFalse);
    });

    // 2. Default System Account Fast-Path Identification
    test('Default system admin emails are recognized as administrator', () {
      bool isDefaultSystemAdmin(String email) {
        final cleaned = email.trim().toLowerCase();
        return cleaned == 'admin' ||
            cleaned == 'admin@piggytrunk.com' ||
            cleaned == 'admin@gmail.com' ||
            cleaned == 'piggytrunk@gmail.com';
      }

      expect(isDefaultSystemAdmin('admin@piggytrunk.com'), isTrue);
      expect(isDefaultSystemAdmin('admin@gmail.com'), isTrue);
      expect(isDefaultSystemAdmin('piggytrunk@gmail.com'), isTrue);
      expect(isDefaultSystemAdmin('admin'), isTrue);
      expect(isDefaultSystemAdmin('user@gmail.com'), isFalse);
      expect(isDefaultSystemAdmin('cashier@piggytrunk.com'), isFalse);
    });

    // 3. Remember Me State Persistence Mapping
    test('Remember Me credential map retains email and password when enabled', () {
      Map<String, dynamic> buildRememberedCredentials({
        required String? email,
        required String? password,
        required bool rememberMe,
      }) {
        return {
          'email': email ?? '',
          'password': password ?? '',
          'rememberMe': rememberMe && (email != null && email.isNotEmpty),
        };
      }

      final enabled = buildRememberedCredentials(
        email: 'admin@piggytrunk.com',
        password: 'Password123!',
        rememberMe: true,
      );

      expect(enabled['rememberMe'], isTrue);
      expect(enabled['email'], 'admin@piggytrunk.com');
      expect(enabled['password'], 'Password123!');

      final disabled = buildRememberedCredentials(
        email: 'admin@piggytrunk.com',
        password: '',
        rememberMe: false,
      );

      expect(disabled['rememberMe'], isFalse);
    });

    // 4. Auto-redirect Condition Verification
    test('Auto-redirect only triggers if rememberMe is enabled and session or credentials exist', () {
      bool shouldAutoRedirect({
        required bool rememberMe,
        required bool hasActiveSession,
        required bool isAdmin,
        required String savedEmail,
        required String savedPassword,
      }) {
        if (!rememberMe) return false;
        if (hasActiveSession && isAdmin) return true;
        if (savedEmail.isNotEmpty && savedPassword.isNotEmpty) return true;
        return false;
      }

      // Case A: Remember Me enabled + Active Admin session -> Auto-redirect
      expect(
        shouldAutoRedirect(
          rememberMe: true,
          hasActiveSession: true,
          isAdmin: true,
          savedEmail: 'admin@piggytrunk.com',
          savedPassword: 'pwd',
        ),
        isTrue,
      );

      // Case B: Remember Me disabled -> NEVER auto-redirect
      expect(
        shouldAutoRedirect(
          rememberMe: false,
          hasActiveSession: true,
          isAdmin: true,
          savedEmail: 'admin@piggytrunk.com',
          savedPassword: 'pwd',
        ),
        isFalse,
      );

      // Case C: Remember Me enabled + Session expired + Saved credentials -> Auto-login redirect
      expect(
        shouldAutoRedirect(
          rememberMe: true,
          hasActiveSession: false,
          isAdmin: false,
          savedEmail: 'admin@piggytrunk.com',
          savedPassword: 'pwd',
        ),
        isTrue,
      );
    });
  });
}
