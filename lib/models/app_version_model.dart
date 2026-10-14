class AppVersionModel {
  final String versionName;
  final int versionCode;
  final String minSupportedVersion;
  final int minSupportedVersionCode;
  final List<String> releaseNotes;
  final String apkUrl;
  final int? fileSizeBytes;
  final double? fileSizeMb;
  final bool forceUpdate;
  final DateTime? releasedAt;

  const AppVersionModel({
    required this.versionName,
    required this.versionCode,
    this.minSupportedVersion = '1.0.0',
    this.minSupportedVersionCode = 1,
    this.releaseNotes = const [],
    required this.apkUrl,
    this.fileSizeBytes,
    this.fileSizeMb,
    this.forceUpdate = false,
    this.releasedAt,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    List<String> parseNotes(dynamic notes) {
      if (notes == null) return [];
      if (notes is List) {
        return notes.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      if (notes is String) {
        return notes
            .split('\n')
            .map((e) => e.replaceFirst(RegExp(r'^[-*•\d.]\s*'), '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    }

    final bytes = json['file_size_bytes'] is num
        ? (json['file_size_bytes'] as num).toInt()
        : null;

    final mb = json['file_size_mb'] is num
        ? (json['file_size_mb'] as num).toDouble()
        : (bytes != null ? double.parse((bytes / (1024 * 1024)).toStringAsFixed(2)) : null);

    return AppVersionModel(
      versionName: (json['version_name'] ?? json['latest_version'] ?? '1.0.0').toString(),
      versionCode: (json['version_code'] as num?)?.toInt() ?? 1,
      minSupportedVersion: (json['min_supported_version'] ?? json['min_version'] ?? '1.0.0').toString(),
      minSupportedVersionCode: (json['min_supported_version_code'] as num?)?.toInt() ?? 1,
      releaseNotes: parseNotes(json['release_notes']),
      apkUrl: (json['apk_url'] ?? json['download_url'] ?? '').toString(),
      fileSizeBytes: bytes,
      fileSizeMb: mb,
      forceUpdate: json['force_update'] == true,
      releasedAt: json['released_at'] != null ? DateTime.tryParse(json['released_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'version_name': versionName,
    'version_code': versionCode,
    'min_supported_version': minSupportedVersion,
    'min_supported_version_code': minSupportedVersionCode,
    'release_notes': releaseNotes,
    'apk_url': apkUrl,
    'file_size_bytes': fileSizeBytes,
    'file_size_mb': fileSizeMb,
    'force_update': forceUpdate,
    'released_at': releasedAt?.toIso8601String(),
  };

  /// Compares current installed version against this remote version
  bool isNewerThan(String currentVersionName, int currentVersionCode) {
    if (versionCode > 0 && currentVersionCode > 0) {
      return versionCode > currentVersionCode;
    }
    return _compareSemanticVersions(versionName, currentVersionName) > 0;
  }

  /// Checks if current installed version is older than minimum supported version
  bool isBelowMinimum(String currentVersionName, int currentVersionCode) {
    if (forceUpdate) return true;
    if (minSupportedVersionCode > 0 && currentVersionCode > 0) {
      return currentVersionCode < minSupportedVersionCode;
    }
    return _compareSemanticVersions(currentVersionName, minSupportedVersion) < 0;
  }

  /// Helper to compare semantic version strings (e.g. "1.0.2" vs "1.0.1")
  static int _compareSemanticVersions(String v1, String v2) {
    final cleanV1 = v1.split('+').first.trim();
    final cleanV2 = v2.split('+').first.trim();

    final parts1 = cleanV1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = cleanV2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    while (parts1.length < maxLen) {
      parts1.add(0);
    }
    while (parts2.length < maxLen) {
      parts2.add(0);
    }

    for (int i = 0; i < maxLen; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }
    return 0;
  }
}
