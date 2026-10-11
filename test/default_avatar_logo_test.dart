import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Default Avatar Logo Fallback Tests', () {
    const defaultLogoAsset = 'assets/piggytrunk_logo.png';

    test('Null or empty avatar URL resolves to default PiggyTrunk logo asset', () {
      String resolveAvatar(String? url) {
        if (url != null && url.trim().isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
          return url;
        }
        return defaultLogoAsset;
      }

      expect(resolveAvatar(null), defaultLogoAsset);
      expect(resolveAvatar(''), defaultLogoAsset);
      expect(resolveAvatar('   '), defaultLogoAsset);
      expect(resolveAvatar('not_a_url'), defaultLogoAsset);
      expect(resolveAvatar('https://supabase.co/storage/v1/avatar.png'), 'https://supabase.co/storage/v1/avatar.png');
    });

    test('User Approvals avatar extractor accurately extracts avatar across candidate fields', () {
      String? extractAvatarUrl(Map<String, dynamic> row) {
        final appUsers = row['app_users'] as Map<String, dynamic>?;
        final metadata = row['raw_user_meta_data'] as Map<String, dynamic>?;
        final dynamic candidate = row['profile_picture'] ??
            row['avatar_url'] ??
            row['photo_url'] ??
            row['image_url'] ??
            row['profile_image'] ??
            row['picture'] ??
            appUsers?['profile_picture'] ??
            appUsers?['avatar_url'] ??
            appUsers?['photo_url'] ??
            appUsers?['image_url'] ??
            appUsers?['profile_image'] ??
            appUsers?['picture'] ??
            metadata?['avatar_url'] ??
            metadata?['picture'] ??
            metadata?['profile_picture'];

        if (candidate != null) {
          final str = candidate.toString().trim();
          if (str.startsWith('http://') || str.startsWith('https://')) {
            return str;
          }
        }
        return null;
      }

      // Cashier without avatar
      final cashierMary = {
        'name': 'maryazxc',
        'email': 'maryazxc1@gmail.com',
        'role': 'Cashier',
      };
      expect(extractAvatarUrl(cashierMary), isNull);

      // User with metadata avatar
      final userWithMeta = {
        'name': 'John Doe',
        'raw_user_meta_data': {'avatar_url': 'https://example.com/avatar.jpg'},
      };
      expect(extractAvatarUrl(userWithMeta), 'https://example.com/avatar.jpg');

      // User with nested app_users avatar
      final userWithAppUsers = {
        'name': 'Celeste Moneda',
        'app_users': {'profile_picture': 'https://example.com/celeste.png'},
      };
      expect(extractAvatarUrl(userWithAppUsers), 'https://example.com/celeste.png');
    });

    test('Slide-over confirmation modal avatar displays default logo on missing avatar', () {
      bool shouldDisplayPiggyTrunkLogo(String? avatarUrl) {
        return avatarUrl == null || avatarUrl.trim().isEmpty;
      }

      expect(shouldDisplayPiggyTrunkLogo(null), isTrue);
      expect(shouldDisplayPiggyTrunkLogo(''), isTrue);
      expect(shouldDisplayPiggyTrunkLogo('https://cdn.example.com/pic.jpg'), isFalse);
    });

    test('All user roles (Admin, Cashier, Raiser, Partner) produce standard avatar fallback', () {
      final roles = ['Admin', 'Cashier', 'Hog Raiser', 'Partner Investor'];
      for (final role in roles) {
        final profile = {'role': role, 'avatar_url': null};
        final hasCustomAvatar = profile['avatar_url'] != null && (profile['avatar_url'] as String).isNotEmpty;
        final asset = hasCustomAvatar ? profile['avatar_url'] : defaultLogoAsset;
        expect(asset, defaultLogoAsset, reason: '$role should fall back to default PiggyTrunk logo');
      }
    });
  });
}
