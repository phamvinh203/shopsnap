class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String releaseTitle;
  final String releaseNotes;
  final String? downloadUrl;
  final String? releasePageUrl;
  final DateTime? publishedAt;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.releaseTitle,
    required this.releaseNotes,
    this.downloadUrl,
    this.releasePageUrl,
    this.publishedAt,
  });

  factory AppUpdateInfo.noUpdate(String currentVersion) {
    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: currentVersion,
      hasUpdate: false,
      releaseTitle: '',
      releaseNotes: '',
    );
  }

  factory AppUpdateInfo.fromGitHubJson({
    required Map<String, dynamic> json,
    required String currentVersion,
  }) {
    final rawTag = (json['tag_name'] as String? ?? '').trim();
    // Bỏ tiền tố 'v' nếu có (vd: 'v1.0.3' -> '1.0.3')
    final latestVersion = rawTag.startsWith('v') || rawTag.startsWith('V')
        ? rawTag.substring(1)
        : rawTag;

    final releaseTitle = (json['name'] as String? ?? '').trim();
    final releaseNotes = (json['body'] as String? ?? '').trim();
    final releasePageUrl = json['html_url'] as String?;
    final publishedAtStr = json['published_at'] as String?;
    final publishedAt = publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

    // Tìm asset có đuôi .apk
    String? downloadUrl;
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    final hasUpdate = isNewerVersion(latestVersion, currentVersion);

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      hasUpdate: hasUpdate,
      releaseTitle: releaseTitle.isNotEmpty ? releaseTitle : 'Phiên bản $rawTag',
      releaseNotes: releaseNotes,
      downloadUrl: downloadUrl ?? releasePageUrl,
      releasePageUrl: releasePageUrl,
      publishedAt: publishedAt,
    );
  }

  /// So sánh hai chuỗi version theo semantic versioning: (v1 > v2 => true).
  /// Ví dụ:
  /// isNewerVersion('1.0.3', '1.0.2') -> true
  /// isNewerVersion('1.0.2', '1.0.2') -> false
  /// isNewerVersion('1.1.0', '1.0.9') -> true
  /// isNewerVersion('2.0.0', '1.9.9') -> true
  static bool isNewerVersion(String latest, String current) {
    if (latest.isEmpty || current.isEmpty) return false;

    // Chuẩn hoá: bỏ các ký tự không phải số và dấu chấm (vd: 1.0.2+1 -> 1.0.2)
    final cleanLatest = latest.split('+').first.split('-').first;
    final cleanCurrent = current.split('+').first.split('-').first;

    final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Độ dài tối đa (thường là 3: major, minor, patch)
    final maxLen = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;

    for (var i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;

      if (l > c) return true;
      if (l < c) return false;
    }

    return false;
  }
}
