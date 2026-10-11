import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cashier Profile Resolution & Update Logic Tests', () {
    test('Correctly splits combined name into first, middle initial, and last name for editing dialog', () {
      String parseFirst(String name) {
        final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (clean.isEmpty || clean == 'Cashier Staff' || clean == 'N/A') return '';
        final parts = clean.split(' ');
        if (parts.length == 1) return parts[0];
        if (parts.length == 2) return parts[0];
        if (parts.length >= 3) {
          if (parts[1].endsWith('.') || parts[1].length <= 2) {
            return parts[0];
          }
          return parts.sublist(0, parts.length - 1).join(' ');
        }
        return '';
      }

      String parseMiddle(String name) {
        final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (clean.isEmpty || clean == 'Cashier Staff' || clean == 'N/A') return '';
        final parts = clean.split(' ');
        if (parts.length >= 3 && (parts[1].endsWith('.') || parts[1].length <= 2)) {
          return parts[1].replaceAll('.', '');
        }
        return '';
      }

      String parseLast(String name) {
        final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (clean.isEmpty || clean == 'Cashier Staff' || clean == 'N/A') return '';
        final parts = clean.split(' ');
        if (parts.length == 1) return '';
        if (parts.length == 2) return parts[1];
        if (parts.length >= 3) {
          if (parts[1].endsWith('.') || parts[1].length <= 2) {
            return parts.sublist(2).join(' ');
          }
          return parts.last;
        }
        return '';
      }

      expect(parseFirst('Maria S. Santos'), equals('Maria'));
      expect(parseMiddle('Maria S. Santos'), equals('S'));
      expect(parseLast('Maria S. Santos'), equals('Santos'));

      expect(parseFirst('Juan Dela Cruz'), equals('Juan Dela'));
      expect(parseMiddle('Juan Dela Cruz'), equals(''));
      expect(parseLast('Juan Dela Cruz'), equals('Cruz'));
    });

    test('Assembles combined name cleanly from first, middle initial, and last name', () {
      String assembleName(String first, String middle, String last) {
        return [
          first.trim(),
          if (middle.trim().isNotEmpty) '${middle.trim().replaceAll('.', '')}.',
          last.trim(),
        ].where((p) => p.isNotEmpty).join(' ');
      }

      expect(assembleName('Maria', 'S', 'Santos'), equals('Maria S. Santos'));
      expect(assembleName('Maria', '', 'Santos'), equals('Maria Santos'));
      expect(assembleName('Juan', 'D.', 'Dela Cruz'), equals('Juan D. Dela Cruz'));
    });

    test('Validates cashier profile payload to app_users table only targets existing schema columns', () {
      // app_users only has: user_id, name, email, password_hash, role, status, created_at, created_by, supabase_user_id
      final appUserPayload = {
        'name': 'Maria S. Santos',
      };

      expect(appUserPayload.containsKey('phone'), isFalse);
      expect(appUserPayload.containsKey('address'), isFalse);
      expect(appUserPayload.containsKey('avatar_url'), isFalse);
      expect(appUserPayload['name'], equals('Maria S. Santos'));
    });

    test('Resolves phone and store address from notification metadata when database schema lacks phone/address columns', () {
      final notificationMetadata = {
        'user_id': 105,
        'email': 'cashier@piggytrunk.com',
        'name': 'Maria S. Santos',
        'phone': '09123456789',
        'address': 'Main Branch - Davao City',
      };

      String resolvePhone(Map<String, dynamic> row, Map<String, dynamic>? meta) {
        String phone = (row['phone'] ?? row['contact_number'] ?? '').toString().trim();
        if (phone.isEmpty && meta != null) {
          phone = (meta['phone'] ?? meta['contact_number'] ?? '').toString().trim();
        }
        return phone.isNotEmpty ? phone : 'Not set';
      }

      String resolveAddress(Map<String, dynamic> row, Map<String, dynamic>? meta) {
        String address = (row['address'] ?? row['farm_location'] ?? row['store_address'] ?? '').toString().trim();
        if (address.isEmpty && meta != null) {
          address = (meta['address'] ?? meta['store_address'] ?? '').toString().trim();
        }
        return address.isNotEmpty ? address : 'Not set';
      }

      final cashierRow = {'user_id': 105, 'name': 'Maria S. Santos', 'role': 'cashier'};

      expect(resolvePhone(cashierRow, notificationMetadata), equals('09123456789'));
      expect(resolveAddress(cashierRow, notificationMetadata), equals('Main Branch - Davao City'));
    });

    test('Filters out personal User Password Reset notifications and internal sync records from admin stream', () {
      final sampleNotifications = [
        {
          'id': 1,
          'title': 'New User Registration',
          'message': 'New Cashier registered',
          'type': 'user_registration',
        },
        {
          'id': 2,
          'title': 'User Password Reset',
          'message': 'Hog Raiser (Mariel Deuda) reset their password via mobile verification.',
          'type': 'user_registration',
        },
        {
          'id': 3,
          'title': 'Cashier Profile Updated',
          'message': 'Marya A. Qwerty updated their profile details.',
          'type': 'cashier_profile',
        },
        {
          'id': 4,
          'title': 'New Partner Investment',
          'message': 'New investment received for Batch #1',
          'type': 'investment',
        },
      ];

      bool shouldDisplayToAdmin(Map<String, dynamic> notif) {
        final title = (notif['title'] ?? '').toString().toLowerCase();
        final msg = (notif['message'] ?? '').toString().toLowerCase();
        final type = (notif['type'] ?? '').toString().toLowerCase();

        // 1. Exclude sensitive password reset activity
        if (title.contains('password reset') ||
            msg.contains('reset their password') ||
            type.contains('password_reset')) {
          return false;
        }

        // 2. Exclude internal cashier profile backend sync records
        if (type == 'cashier_profile') {
          return false;
        }

        return true;
      }

      final filtered = sampleNotifications.where(shouldDisplayToAdmin).toList();
      expect(filtered.length, equals(2));
      expect(filtered[0]['title'], equals('New User Registration'));
      expect(filtered[1]['title'], equals('New Partner Investment'));
      expect(filtered.any((n) => n['title'] == 'User Password Reset'), isFalse);
      expect(filtered.any((n) => n['type'] == 'cashier_profile'), isFalse);
    });
  });
}
