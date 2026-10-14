import 'package:flutter_test/flutter_test.dart';
import 'package:piggytrunk/models/app_version_model.dart';

void main() {
  group('AppVersionModel & Version Comparison Tests', () {
    test('Correctly detects newer patch version (1.0.2 is newer than 1.0.1)', () {
      final remote = AppVersionModel(
        versionName: '1.0.2',
        versionCode: 3,
        apkUrl: 'https://example.com/PiggyTrunkMobile.apk',
      );

      expect(remote.isNewerThan('1.0.1', 2), isTrue);
      expect(remote.isNewerThan('1.0.2', 3), isFalse);
      expect(remote.isNewerThan('1.0.3', 4), isFalse);
    });

    test('Correctly detects newer minor version (1.1.0 is newer than 1.0.9)', () {
      final remote = AppVersionModel(
        versionName: '1.1.0',
        versionCode: 10,
        apkUrl: 'https://example.com/PiggyTrunkMobile.apk',
      );

      expect(remote.isNewerThan('1.0.9', 9), isTrue);
    });

    test('Correctly parses json with notes, size, and flags', () {
      final json = {
        'version_name': '1.0.2',
        'version_code': 3,
        'min_supported_version': '1.0.0',
        'release_notes': [
          'Fix cashier POS',
          'Add in-app updates'
        ],
        'apk_url': 'https://example.com/apk.apk',
        'file_size_bytes': 26822477,
        'force_update': false,
      };

      final model = AppVersionModel.fromJson(json);
      expect(model.versionName, equals('1.0.2'));
      expect(model.versionCode, equals(3));
      expect(model.releaseNotes.length, equals(2));
      expect(model.fileSizeMb, equals(25.58));
      expect(model.forceUpdate, isFalse);
    });

    test('Detects when app is below minimum required version', () {
      final remote = AppVersionModel(
        versionName: '2.0.0',
        versionCode: 20,
        minSupportedVersion: '1.5.0',
        minSupportedVersionCode: 15,
        apkUrl: 'https://example.com/apk.apk',
      );

      // Current 1.0.1 (code 2) is below min 1.5.0 (code 15)
      expect(remote.isBelowMinimum('1.0.1', 2), isTrue);

      // Current 1.6.0 (code 16) is above min
      expect(remote.isBelowMinimum('1.6.0', 16), isFalse);
    });
  });
}
