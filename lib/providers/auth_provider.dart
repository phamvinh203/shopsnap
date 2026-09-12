import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/token_storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Trạng thái đăng nhập toàn cục — app_router dựa vào đây để redirect.
enum AuthStatus {
  /// Đang khôi phục session lúc khởi động (đọc storage, thử refresh token).
  restoring,

  authenticated,

  unauthenticated,
}

class AuthState {
  final AuthStatus status;
  final UserModel? user;

  const AuthState({required this.status, this.user});

  const AuthState.restoring() : status = AuthStatus.restoring, user = null;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

// ── Providers hạ tầng ───────────────────────────────────────────────────────

/// ApiClient dùng chung toàn app (các wave sau: categories/items/budgets/... tái sử dụng).
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  // 401 mà refresh cũng hỏng (từ request bất kỳ) → đồng bộ đăng xuất toàn cục
  client.onSessionExpired = () => ref.read(authStateProvider.notifier).onSessionExpired();
  ref.onDispose(() => client.onSessionExpired = null);
  return client;
});

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(apiClientProvider)),
);

// ── AuthNotifier ────────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<AuthState> {
  AuthService get _auth   => ref.read(authServiceProvider);
  ApiClient   get _client => ref.read(apiClientProvider);

  /// Khôi phục session khi khởi động:
  /// - Không có refresh token → unauthenticated (vào thẳng /login qua redirect)
  /// - Có → thử refresh; thành công → GET /auth/me lấy user mới nhất rồi merge
  ///   với user đã lưu trong storage (me chỉ trả userId + email)
  @override
  Future<AuthState> build() async {
    try {
      final tokens = await _client.storage.readTokens();
      if (tokens == null) {
        return const AuthState(status: AuthStatus.unauthenticated);
      }

      final refreshed = await _client.refreshTokens();
      if (!refreshed) {
        await _client.storage.clear();
        return const AuthState(status: AuthStatus.unauthenticated);
      }

      final user = await _loadFreshUser();
      await _client.storage.saveUser(user);
      return AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      // Storage/refresh gặp lỗi bất ngờ (vd. plugin chưa sẵn sàng) → yêu cầu đăng nhập lại
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Đăng nhập. Ném lỗi lên UI (screen tự bắt để hiện snackbar);
  /// state chỉ đổi khi thành công → router tự redirect về trang chủ.
  Future<void> login({required String email, required String password}) async {
    final result = await _auth.login(email: email, password: password);
    await _persistSession(result.user, result.tokens);
    state = AsyncData(AuthState(status: AuthStatus.authenticated, user: result.user));
  }

  /// Đăng ký — contract giống login.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _auth.register(name: name, email: email, password: password);
    await _persistSession(result.user, result.tokens);
    state = AsyncData(AuthState(status: AuthStatus.authenticated, user: result.user));
  }

  /// Đăng xuất chủ động: gọi API (best-effort) + xoá session cục bộ.
  /// Router nghe authStateProvider → tự redirect về /login.
  Future<void> logout() async {
    await _auth.logout();
    await _client.storage.clear();
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }

  /// Session chết từ một request bất kỳ (401 + refresh hỏng) — storage đã được
  /// ApiClient xoá, ở đây chỉ cần đồng bộ state để router điều hướng.
  void onSessionExpired() {
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Future<void> _persistSession(UserModel user, AuthTokens tokens) async {
    await _client.storage.saveTokens(tokens);
    await _client.storage.saveUser(user);
  }

  /// User hợp lệ sau khi refresh: ưu tiên /auth/me (email mới nhất) merge với
  /// user đã lưu (name, createdAt); không có gì → user rỗng tối thiểu.
  Future<UserModel> _loadFreshUser() async {
    final stored = await _client.storage.readUser();
    try {
      final me = await _auth.me();
      return (stored ?? me).copyWith(id: me.id, email: me.email);
    } catch (_) {
      // /auth/me lỗi (mạng chập chờn) nhưng refresh đã OK → cứ cho vào app
      return stored ?? const UserModel(id: '', email: '');
    }
  }
}

/// Provider trạng thái auth — app_router lắng nghe provider này để redirect.
final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
