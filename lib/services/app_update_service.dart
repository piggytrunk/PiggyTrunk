import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_version_model.dart';
import '../widgets/update/app_update_dialog.dart';
import '../utils/app_toast.dart';

class UpdateCheckResult {
  final bool isAvailable;
  final bool isForce;
  final String currentVersion;
  final int currentCode;
  final AppVersionModel? remoteVersion;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.isAvailable,
    this.isForce = false,
    this.currentVersion = '1.0.0',
    this.currentCode = 1,
    this.remoteVersion,
    this.errorMessage,
  });
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String defaultApkUrl =
      'https://github.com/rewithjie/Piggy-Trunk/releases/latest/download/PiggyTrunkMobile.apk';
  static const String staticVersionUrl =
      'https://piggy-trunk.vercel.app/version.json';

  bool _hasDismissedThisSession = false;

  /// Resets session dismissal (useful on manual check)
  void resetDismissal() {
    _hasDismissedThisSession = false;
  }

  /// Mark dismissed for current app run
  void markDismissed() {
    _hasDismissedThisSession = true;
  }

  /// Checks if an update is available on Android. Returns UpdateCheckResult.
  Future<UpdateCheckResult> checkForUpdate() async {
    // Only check for updates on native Android mobile app
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const UpdateCheckResult(isAvailable: false);
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();
      final currentCode = int.tryParse(packageInfo.buildNumber.trim()) ?? 1;

      AppVersionModel? remoteModel;

      // Layer 1: Query Supabase app_versions table
      try {
        final client = Supabase.instance.client;
        final data = await client
            .from('app_versions')
            .select()
            .eq('platform', 'android')
            .eq('is_active', true)
            .order('version_code', ascending: false)
            .limit(1)
            .maybeSingle();

        if (data != null) {
          remoteModel = AppVersionModel.fromJson(data);
        }
      } catch (dbErr) {
        debugPrint('[AppUpdateService] Supabase table lookup: $dbErr');
      }

      // Layer 2: Fallback to static version.json on web deployment
      if (remoteModel == null) {
        try {
          final res = await http
              .get(Uri.parse(staticVersionUrl))
              .timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
            remoteModel = AppVersionModel.fromJson(jsonMap);
          }
        } catch (netErr) {
          debugPrint('[AppUpdateService] Static version fallback lookup: $netErr');
        }
      }

      if (remoteModel == null) {
        return UpdateCheckResult(
          isAvailable: false,
          currentVersion: currentVersion,
          currentCode: currentCode,
        );
      }

      final isNewer = remoteModel.isNewerThan(currentVersion, currentCode);
      final isForce = remoteModel.isBelowMinimum(currentVersion, currentCode);

      return UpdateCheckResult(
        isAvailable: isNewer,
        isForce: isForce,
        currentVersion: currentVersion,
        currentCode: currentCode,
        remoteVersion: remoteModel,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] General error checking update: $e');
      return UpdateCheckResult(
        isAvailable: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Prompts the user with a dialog if a new version is available
  Future<void> promptUpdateIfAvailable(
    BuildContext context, {
    bool isManualCheck = false,
  }) async {
    if (!isManualCheck && _hasDismissedThisSession) {
      return;
    }

    final result = await checkForUpdate();
    if (!context.mounted) return;

    if (result.isAvailable && result.remoteVersion != null) {
      await showDialog(
        context: context,
        barrierDismissible: !result.isForce,
        builder: (ctx) => AppUpdateDialog(
          result: result,
          onDismiss: () => markDismissed(),
        ),
      );
    } else if (isManualCheck) {
      AppToast.success(
        context,
        "You're using the latest version of Piggy Trunk (${result.currentVersion})",
      );
    }
  }

  /// Initiates APK download and guides user to install
  Future<void> launchApkDownload(BuildContext context, String apkUrl) async {
    final finalUrl = apkUrl.isNotEmpty ? apkUrl : defaultApkUrl;
    final uri = Uri.parse(finalUrl);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (context.mounted) {
        if (launched) {
          AppToast.info(
            context,
            'Downloading Piggy Trunk update... Open the file when finished to install.',
          );
        } else {
          AppToast.error(
            context,
            'Could not open download link automatically.',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Failed to launch download: $e');
      }
    }
  }
}
