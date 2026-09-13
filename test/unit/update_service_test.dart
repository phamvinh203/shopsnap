import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopsnap/models/app_update_model.dart';
import 'package:shopsnap/services/update_service.dart';

void main() {
  group('AppUpdateInfo.isNewerVersion Tests', () {
    test('Patch version update: 1.0.3 > 1.0.2', () {
      expect(AppUpdateInfo.isNewerVersion('1.0.3', '1.0.2'), isTrue);
    });

    test('Same version: 1.0.2 == 1.0.2', () {
      expect(AppUpdateInfo.isNewerVersion('1.0.2', '1.0.2'), isFalse);
    });

    test('Older version: 1.0.1 < 1.0.2', () {
      expect(AppUpdateInfo.isNewerVersion('1.0.1', '1.0.2'), isFalse);
    });

    test('Minor version update: 1.1.0 > 1.0.9', () {
      expect(AppUpdateInfo.isNewerVersion('1.1.0', '1.0.9'), isTrue);
    });

    test('Major version update: 2.0.0 > 1.9.9', () {
      expect(AppUpdateInfo.isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('Build numbers ignored in clean semver: 1.0.2+2 vs 1.0.2+1', () {
      expect(AppUpdateInfo.isNewerVersion('1.0.2+2', '1.0.2+1'), isFalse);
    });

    test('Handles invalid or empty strings safely', () {
      expect(AppUpdateInfo.isNewerVersion('', '1.0.2'), isFalse);
      expect(AppUpdateInfo.isNewerVersion('1.0.3', ''), isFalse);
    });
  });

  group('AppUpdateInfo.fromGitHubJson Tests', () {
    test('Parses GitHub release JSON and finds APK download URL', () {
      final mockJson = {
        'tag_name': 'v1.0.3',
        'name': 'ShopSnap v1.0.3 (New Features)',
        'body': 'Bản cập nhật v1.0.3 gồm nhiều cải tiến thú vị.',
        'html_url': 'https://github.com/phamvinh203/shopsnap/releases/tag/v1.0.3',
        'published_at': '2026-09-13T12:00:00Z',
        'assets': [
          {
            'name': 'source_code.zip',
            'browser_download_url': 'https://github.com/.../source_code.zip',
          },
          {
            'name': 'ShopSnap-v1.0.3.apk',
            'browser_download_url': 'https://github.com/phamvinh203/shopsnap/releases/download/v1.0.3/ShopSnap-v1.0.3.apk',
          },
        ],
      };

      final info = AppUpdateInfo.fromGitHubJson(
        json: mockJson,
        currentVersion: '1.0.2',
      );

      expect(info.currentVersion, '1.0.2');
      expect(info.latestVersion, '1.0.3');
      expect(info.hasUpdate, isTrue);
      expect(info.releaseTitle, 'ShopSnap v1.0.3 (New Features)');
      expect(info.releaseNotes, contains('Bản cập nhật v1.0.3'));
      expect(info.downloadUrl, 'https://github.com/phamvinh203/shopsnap/releases/download/v1.0.3/ShopSnap-v1.0.3.apk');
    });

    test('Detects no update when latest version equals current version', () {
      final mockJson = {
        'tag_name': 'v1.0.2',
        'name': 'ShopSnap v1.0.2',
        'body': 'Release notes',
        'assets': [],
      };

      final info = AppUpdateInfo.fromGitHubJson(
        json: mockJson,
        currentVersion: '1.0.2',
      );

      expect(info.hasUpdate, isFalse);
      expect(info.latestVersion, '1.0.2');
    });
  });

  group('UpdateService Tests', () {
    setUp(() {
      UpdateService.resetCache();
    });
    test('checkForUpdate returns valid update info on HTTP 200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/releases/latest')) {
          final payload = {
            'tag_name': 'v1.0.3',
            'name': 'ShopSnap v1.0.3',
            'body': 'Notes v1.0.3',
            'assets': [
              {
                'name': 'ShopSnap-v1.0.3.apk',
                'browser_download_url': 'https://download.apk',
              }
            ],
          };
          return http.Response(jsonEncode(payload), 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = UpdateService(
        client: mockClient,
        repo: 'phamvinh203/shopsnap',
        currentVersion: '1.0.2',
      );

      final info = await service.checkForUpdate(forceRefresh: true);
      expect(info.hasUpdate, isTrue);
      expect(info.latestVersion, '1.0.3');
      expect(info.downloadUrl, 'https://download.apk');
    });

    test('checkForUpdate handles HTTP error gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Error', 500);
      });

      final service = UpdateService(
        client: mockClient,
        repo: 'phamvinh203/shopsnap',
        currentVersion: '1.0.2',
      );

      final info = await service.checkForUpdate(forceRefresh: true);
      expect(info.hasUpdate, isFalse);
      expect(info.currentVersion, '1.0.2');
    });
  });
}
