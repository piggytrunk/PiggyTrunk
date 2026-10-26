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
import '../mobile_app/services/connectivity_service.dart';
import '../mobile_app/utils/app_strings.dart';

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

  static const String defaultApkUrl = 'https://piggytrunk.site/download/apk';
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

  /// Quick helper to get current semantic version without build number
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version.trim();
      return version.isNotEmpty ? version.split('+').first.trim() : '1.0.0';
    } catch (_) {
      return '1.0.0';
    }
  }

  /// Checks if an update is available on Android / Localhost. Returns UpdateCheckResult.
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      String currentVersion = '1.0.0';
      int currentCode = 1;

      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final rawVersion = packageInfo.version.trim();
        if (rawVersion.isNotEmpty) {
          currentVersion = rawVersion.split('+').first.trim();
        }
        final rawBuild = packageInfo.buildNumber.trim();
        final parsedCode = int.tryParse(rawBuild);
        if (parsedCode != null && parsedCode > 0) {
          currentCode = parsedCode;
        }
      } catch (pkgErr) {
        debugPrint('[AppUpdateService] PackageInfo lookup warning: $pkgErr');
      }

      // Check internet connectivity first
      final bool hasNet = await ConnectivityService.hasInternet();
      if (!hasNet) {
        return UpdateCheckResult(
          isAvailable: false,
          currentVersion: currentVersion,
          currentCode: currentCode,
          errorMessage: 'NO_INTERNET',
        );
      }

      AppVersionModel? remoteModel;
      bool hadNetworkError = false;

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
        hadNetworkError = true;
        debugPrint('[AppUpdateService] Supabase table lookup: $dbErr');
      }

      // Layer 2: Fallback to static version.json on web/localhost deployment
      if (remoteModel == null) {
        try {
          final lookupUrl = kIsWeb ? 'version.json' : staticVersionUrl;
          final res = await http
              .get(Uri.parse(lookupUrl))
              .timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
            remoteModel = AppVersionModel.fromJson(jsonMap);
            hadNetworkError = false;
          }
        } catch (netErr) {
          hadNetworkError = true;
          debugPrint(
            '[AppUpdateService] Static version fallback lookup: $netErr',
          );
          // If relative web lookup failed, try static external url
          if (kIsWeb) {
            try {
              final res2 = await http
                  .get(Uri.parse(staticVersionUrl))
                  .timeout(const Duration(seconds: 4));
              if (res2.statusCode == 200) {
                final jsonMap = jsonDecode(res2.body) as Map<String, dynamic>;
                remoteModel = AppVersionModel.fromJson(jsonMap);
                hadNetworkError = false;
              }
            } catch (_) {
              hadNetworkError = true;
            }
          }
        }
      }

      if (remoteModel == null) {
        return UpdateCheckResult(
          isAvailable: false,
          currentVersion: currentVersion,
          currentCode: currentCode,
          errorMessage: hadNetworkError ? 'NO_INTERNET' : null,
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
      return UpdateCheckResult(isAvailable: false, errorMessage: 'NO_INTERNET');
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
        builder: (ctx) =>
            AppUpdateDialog(result: result, onDismiss: () => markDismissed()),
      );
    } else if (isManualCheck) {
      final strings = AppStrings.of(context);
      if (result.errorMessage == 'NO_INTERNET') {
        AppToast.warning(
          context,
          strings.noInternetForUpdates,
        );
      } else if (result.errorMessage != null && result.errorMessage!.isNotEmpty) {
        AppToast.warning(
          context,
          strings.noInternetForUpdates,
        );
      } else {
        AppToast.success(
          context,
          "You're using the latest version of Piggy Trunk (${result.currentVersion})",
        );
      }
    }
  }

  /// Initiates update (Play Store link or direct APK download) and guides user
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
          final isPlayStore =
              finalUrl.contains('play.google.com') ||
              finalUrl.startsWith('market://');
          AppToast.info(
            context,
            isPlayStore
                ? 'Opening Google Play Store...'
                : 'Downloading Piggy Trunk update... Open the file when finished to install.',
          );
        } else {
          AppToast.error(context, 'Could not open update link automatically.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, 'Failed to launch update link: $e');
      }
    }
  }
}
