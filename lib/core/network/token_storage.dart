import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';

/// Cặp token trả về từ /auth/register, /auth/login, /auth/refresh.
class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({required this.accessToken, required this.refreshToken});
}

/// Interface lưu session (token + user) — tách lớp để sau này swap sang
/// flutter_secure_storage (mã hoá) mà không phải sửa ApiClient/AuthNotifier.
abstract class TokenStorage {
  Future<AuthTokens?> readTokens();
  Future<void> saveTokens(AuthTokens tokens);
  Future<UserModel?> readUser();
  Future<void> saveUser(UserModel user);
  Future<void> clear();
}

/// Impl mặc định bằng SharedPreferences (plaintext — đủ dùng cho dev).
class SharedPreferencesTokenStorage implements TokenStorage {
  static const _kAccessToken  = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';
  static const _kUserJson     = 'auth_user_json';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<AuthTokens?> readTokens() async {
    final p       = await _prefs;
    final access  = p.getString(_kAccessToken);
    final refresh = p.getString(_kRefreshToken);
    if (access == null || refresh == null) return null;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> saveTokens(AuthTokens tokens) async {
    final p = await _prefs;
    await p.setString(_kAccessToken, tokens.accessToken);
    await p.setString(_kRefreshToken, tokens.refreshToken);
  }

  @override
  Future<UserModel?> readUser() async {
    final p   = await _prefs;
    final raw = p.getString(_kUserJson);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // JSON hỏng → coi như chưa có user đã lưu
    }
  }

  @override
  Future<void> saveUser(UserModel user) async {
    final p = await _prefs;
    await p.setString(_kUserJson, jsonEncode(user.toJson()));
  }

  @override
  Future<void> clear() async {
    final p = await _prefs;
    await p.remove(_kAccessToken);
    await p.remove(_kRefreshToken);
    await p.remove(_kUserJson);
  }
}
