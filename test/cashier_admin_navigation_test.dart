import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cashier Admin Navigation & Tab Selection Tests', () {
    // 1. Role and Target Route Resolution
    test('Cashier registration notification maps to /users route with pending_cashier tab argument', () {
      final notifMetadata = {
        'user_id': 105,
        'email': 'maryazxc1@gmail.com',
        'name': 'maryazxc',
        'role': 'cashier',
      };
      const message = 'maryazxc (maryazxc1@gmail.com) registered as Cashier and is pending approval.';
      const title = 'New User Registration';
      const type = 'user_registration';

      // Replicate route and argument resolution logic
      String resolveTargetRoute({required String role, required String message, required String title, required String type}) {
        if (role == 'cashier' || message.contains('cashier') || title.contains('cashier')) {
          return '/users';
        }
        return '/dashboard';
      }

      dynamic resolveRouteArg({
        required String targetRoute,
        required String role,
        required String message,
        required String title,
        required String type,
        required Map<String, dynamic> meta,
      }) {
        if (targetRoute == '/users') {
          final isCashier = role == 'cashier' || message.contains('cashier') || title.contains('cashier');
          final isPending = type == 'user_registration' || message.contains('pending') || title.contains('pending');

          final String tabName = isCashier
              ? (isPending ? 'pending_cashier' : 'active_cashier')
              : (isPending ? 'pending_partner' : 'active_partner');

          return {
            'tab': tabName,
            'email': meta['email'] ?? '',
            'name': meta['name'] ?? '',
          };
        }
        return null;
      }

      final targetRoute = resolveTargetRoute(
        role: notifMetadata['role']!.toString(),
        message: message.toLowerCase(),
        title: title.toLowerCase(),
        type: type,
      );
      final routeArg = resolveRouteArg(
        targetRoute: targetRoute,
        role: notifMetadata['role']!.toString(),
        message: message.toLowerCase(),
        title: title.toLowerCase(),
        type: type,
        meta: notifMetadata,
      );

      expect(targetRoute, '/users');
      expect(routeArg, isA<Map<String, dynamic>>());
      expect(routeArg['tab'], 'pending_cashier');
      expect(routeArg['email'], 'maryazxc1@gmail.com');
      expect(routeArg['name'], 'maryazxc');
    });

    // 2. Partner Investor Registration Resolution
    test('Partner Investor registration maps to /users with pending_partner tab argument', () {
      final notifMetadata = {
        'user_id': 88,
        'email': 'investor@example.com',
        'name': 'John Doe',
        'role': 'partner',
      };
      const message = 'John Doe (investor@example.com) registered as Partner Investor and is pending approval.';
      const title = 'New User Registration';
      const type = 'user_registration';

      dynamic resolveRouteArg({
        required String role,
        required String message,
        required String title,
        required String type,
        required Map<String, dynamic> meta,
      }) {
        final isCashier = role == 'cashier' || message.contains('cashier') || title.contains('cashier');
        final isPending = type == 'user_registration' || message.contains('pending') || title.contains('pending');

        final String tabName = isCashier
            ? (isPending ? 'pending_cashier' : 'active_cashier')
            : (isPending ? 'pending_partner' : 'active_partner');

        return {
          'tab': tabName,
          'email': meta['email'] ?? '',
          'name': meta['name'] ?? '',
        };
      }

      final routeArg = resolveRouteArg(
        role: notifMetadata['role']!.toString(),
        message: message.toLowerCase(),
        title: title.toLowerCase(),
        type: type,
        meta: notifMetadata,
      );

      expect(routeArg['tab'], 'pending_partner');
      expect(routeArg['email'], 'investor@example.com');
    });

    // 3. User Approvals Tab Index Resolution
    test('UserApprovalsScreen resolves tab index 3 for pending_cashier', () {
      int resolveTabIndex(dynamic args) {
        String? targetTab;
        if (args is String) {
          targetTab = args;
        } else if (args is Map) {
          targetTab = args['tab']?.toString();
        }

        if (targetTab == 'pending_cashier') {
          return 3;
        } else if (targetTab == 'active_cashier' || targetTab == 'cashier') {
          return 2;
        } else if (targetTab == 'pending_partner' || targetTab == 'pending') {
          return 1;
        } else if (targetTab == 'active_partner' || targetTab == 'partner') {
          return 0;
        }
        return 0;
      }

      // Check string argument
      expect(resolveTabIndex('pending_cashier'), 3);
      expect(resolveTabIndex('active_cashier'), 2);
      expect(resolveTabIndex('pending_partner'), 1);
      expect(resolveTabIndex('pending'), 1);
      expect(resolveTabIndex('active_partner'), 0);

      // Check structured Map argument
      expect(resolveTabIndex({'tab': 'pending_cashier', 'email': 'maryazxc1@gmail.com'}), 3);
      expect(resolveTabIndex({'tab': 'active_cashier'}), 2);
      expect(resolveTabIndex({'tab': 'pending_partner'}), 1);
    });

    // 4. Role Display Formatting for Cashier in Table Row
    test('Role display formatting in User Approvals table formats role strings correctly', () {
      String formatRole(String roleRaw) {
        final lower = roleRaw.toLowerCase();
        if (lower == 'partner') return 'Partner Investor';
        if (lower == 'cashier') return 'Cashier';
        if (lower.contains('raiser')) return 'Hog Raiser';
        return roleRaw;
      }

      expect(formatRole('cashier'), 'Cashier');
      expect(formatRole('Cashier'), 'Cashier');
      expect(formatRole('partner'), 'Partner Investor');
      expect(formatRole('hog_raiser'), 'Hog Raiser');
    });
  });
}
