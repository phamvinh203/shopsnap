import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_constants.dart';
import '../models/app_update_model.dart';

class UpdateService {
  final http.Client _client;
  final String _repo;
  final String _currentVersion;

  static DateTime? _lastCheckedAt;
  static AppUpdateInfo? _cachedInfo;

  UpdateService({
    http.Client? client,
    String? repo,
    String? currentVersion,
  })  : _client = client ?? http.Client(),
        _repo = repo ?? AppConstants.githubRepo,
        _currentVersion = currentVersion ?? AppConstants.appVersion;

  /// Kiểm tra xem có phiên bản mới hơn không.
  /// [forceRefresh]: nếu true sẽ bỏ qua cache 30 phút.
  Future<AppUpdateInfo> checkForUpdate({bool forceRefresh = false}) async {
    final now = DateTime.now();

    // Dùng cache nếu vừa kiểm tra trong 30 phút và không yêu cầu forceRefresh
    if (!forceRefresh &&
        _cachedInfo != null &&
        _lastCheckedAt != null &&
        now.difference(_lastCheckedAt!).inMinutes < 30) {
      return _cachedInfo!;
    }

    try {
      final url = Uri.parse('https://api.github.com/repos/$_repo/releases/latest');
      final response = await _client.get(
        url,
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'ShopSnap-Mobile/$_currentVersion',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final info = AppUpdateInfo.fromGitHubJson(
          json: json,
          currentVersion: _currentVersion,
        );

        _cachedInfo = info;
        _lastCheckedAt = now;
        return info;
      } else {
        debugPrint('[UpdateService] GitHub releases API status: ${response.statusCode}');
        return forceRefresh ? AppUpdateInfo.noUpdate(_currentVersion) : (_cachedInfo ?? AppUpdateInfo.noUpdate(_currentVersion));
      }
    } catch (e) {
      debugPrint('[UpdateService] Error checking for updates: $e');
      return forceRefresh ? AppUpdateInfo.noUpdate(_currentVersion) : (_cachedInfo ?? AppUpdateInfo.noUpdate(_currentVersion));
    }
  }

  @visibleForTesting
  static void resetCache() {
    _lastCheckedAt = null;
    _cachedInfo = null;
  }

  /// Mở liên kết tải APK hoặc trang release bằng trình duyệt ngoài
  Future<bool> launchDownload(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      debugPrint('[UpdateService] Failed to launch download URL: $e');
      return false;
    }
  }
}
