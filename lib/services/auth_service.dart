import '../core/network/api_client.dart';
import '../core/network/token_storage.dart';
import '../models/user_model.dart';

/// Kết quả register/login — khớp shape `data` của backend: { user, tokens }.
class AuthResult {
  final UserModel user;
  final AuthTokens tokens;

  const AuthResult({required this.user, required this.tokens});
}

/// Gọi các endpoint /auth/* qua [ApiClient]. DTO backend dùng camelCase.
class AuthService {
  final ApiClient _client;

  const AuthService(this._client);

  /// POST /auth/register → 201 { user, tokens }
  Future<AuthResult> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final data = await _client.post('/auth/register', body: {
      'email':    email,
      'password': password,
      'name':     name,
    });
    return AuthResult(
      user:   UserModel.fromJson(data['user'] as Map<String, dynamic>),
      tokens: _tokensFrom(data['tokens']),
    );
  }

  /// POST /auth/login → 200 { user, tokens }
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post('/auth/login', body: {
      'email':    email,
      'password': password,
    });
    return AuthResult(
      user:   UserModel.fromJson(data['user'] as Map<String, dynamic>),
      tokens: _tokensFrom(data['tokens']),
    );
  }

  /// POST /auth/refresh → 200 { accessToken, refreshToken, expiresIn }
  Future<AuthTokens> refresh(String refreshToken) async {
    final data = await _client.post('/auth/refresh', body: {'refreshToken': refreshToken});
    return _tokensFrom(data);
  }

  /// GET /auth/me → 200 { userId, email } — user tối thiểu, dùng khi khôi phục session.
  Future<UserModel> me() async {
    final data = await _client.get('/auth/me', auth: true);
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  /// POST /auth/logout (Bearer) — best-effort: lỗi mạng/token cũng không chặn đăng xuất,
  /// vì phía client xoá token là đủ để kết thúc session cục bộ.
  Future<void> logout() async {
    try {
      await _client.post('/auth/logout', auth: true);
    } catch (_) {
      // bỏ qua — xem ghi chú trên
    }
  }

  AuthTokens _tokensFrom(dynamic data) {
    data = data as Map;
    return AuthTokens(
      accessToken:  data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }
}
