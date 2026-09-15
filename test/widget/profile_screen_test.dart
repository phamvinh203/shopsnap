import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/user_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/profile_provider.dart';
import 'package:shopsnap/providers/sync_provider.dart';
import 'package:shopsnap/providers/theme_provider.dart';
import 'package:shopsnap/screens/profile/profile_screen.dart';
import 'package:shopsnap/services/sync_engine.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _AuthenticatedAuthNotifier extends AuthNotifier {
  int logoutCalls = 0;

  @override
  Future<AuthState> build() async => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(id: 'u1', email: 'minh@shopsnap.dev', name: 'Minh'),
      );

  @override
  Future<void> logout() async {
    logoutCalls++;
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.unauthenticated);
}

/// SyncNotifier với state đóng gói sẵn — KHÔNG chạm SQLite thật (không gọi
/// `_init` qua override được vì nó private, nhưng trong widget test DB luôn
/// fail silent nên state set ở constructor giữ nguyên).
class _FakeSyncNotifier extends SyncNotifier {
  _FakeSyncNotifier(super.ref, SyncUIState fixed) {
    state = fixed;
  }
}

// ── Harness ───────────────────────────────────────────────────────────────────

GoRouter _router() => GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(
          path: '/login',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('LOGIN_STUB'))),
        ),
        GoRoute(
          path: '/export',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('EXPORT_STUB'))),
        ),
      ],
    );

Future<void> _pumpProfile(
  WidgetTester tester, {
  required bool authenticated,
  _AuthenticatedAuthNotifier? authNotifier,
  SyncUIState sync = const SyncUIState(),
  bool statsError = false,
}) async {
  // Màn có 6 section — surface mặc định 800x600 không đủ chứa hết để test
  // thứ tự AC 10.2 → nới surface rồi tự reset sau test.
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (authenticated)
          authStateProvider.overrideWith(
              () => authNotifier ?? _AuthenticatedAuthNotifier())
        else
          authStateProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        syncProvider
            .overrideWith((ref) => _FakeSyncNotifier(ref, sync)),
        if (statsError)
          localDataStatsProvider.overrideWith(
            (ref) async => throw StateError('DB down'),
          )
        else
          localDataStatsProvider.overrideWith(
            (ref) async => const LocalDataStats(
                items: 12, products: 5, priceHistories: 30),
          ),
      ],
      // Wire theme đúng như app.dart: themeMode theo themeModeProvider —
      // AC 10.5 assert theme đổi NGAY khi chọn segment.
      child: Consumer(builder: (context, ref, _) {
        return MaterialApp.router(
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode:
              ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system,
          routerConfig: _router(),
        );
      }),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // DateHelper.formatDateShort (Last synced) dùng locale 'vi_VN'.
    await initializeDateFormatting('vi_VN', null);
  });

  setUp(() {
    // ThemeModeSection (AC 10.5) đọc themeModeProvider → SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileScreen — F-#10', () {
    testWidgets('AC 10.2: đủ 6 section đúng thứ tự khi đã đăng nhập',
        (tester) async {
      await _pumpProfile(
        tester,
        authenticated: true,
        sync: SyncUIState(
          status: SyncStatus.success,
          lastSyncedAt: DateTime(2026, 9, 15, 9, 30),
          pendingCount: 2,
        ),
      );

      // Mỗi section hiển thị đúng 1 lần.
      expect(find.byKey(const Key('profile_accountCard')), findsOneWidget);
      expect(find.byKey(const Key('profile_syncSection')), findsOneWidget);
      expect(find.byKey(const Key('profile_localSection')), findsOneWidget);
      expect(find.byKey(const Key('profile_themeSection')), findsOneWidget);
      expect(find.byKey(const Key('profile_exportEntry')), findsOneWidget);
      expect(find.byKey(const Key('profile_logoutEntry')), findsOneWidget);

      // Thứ tự đứng dọc trên màn (section trên có toạ độ y nhỏ hơn).
      double dyOf(Key key) => tester.getTopLeft(find.byKey(key)).dy;
      final account = dyOf(const Key('profile_accountCard'));
      final syncSec = dyOf(const Key('profile_syncSection'));
      final local = dyOf(const Key('profile_localSection'));
      final theme = dyOf(const Key('profile_themeSection'));
      final export = dyOf(const Key('profile_exportEntry'));
      final logout = dyOf(const Key('profile_logoutEntry'));
      expect(account < syncSec, isTrue, reason: '1. Account → 2. Sync');
      expect(syncSec < local, isTrue, reason: '2. Sync → 3. Local');
      expect(local < theme, isTrue, reason: '3. Local → 4. Appearance');
      expect(theme < export, isTrue, reason: '4. Appearance → 5. Export');
      expect(export < logout, isTrue, reason: '5. Export → 6. Logout');

      // Account info hiện tên + email từ auth provider.
      expect(find.text('Minh'), findsOneWidget);
      expect(find.text('minh@shopsnap.dev'), findsOneWidget);

      // AC 10.9: Delete account KHÔNG render (kể cả dạng disabled).
      expect(find.text('Delete account'), findsNothing);
      expect(find.text('Xoá tài khoản'), findsNothing);
    });

    testWidgets('AC 10.3: sync status hiển thị last synced + pending count '
        '+ nhãn "Chưa có đồng bộ nền"', (tester) async {
      await _pumpProfile(
        tester,
        authenticated: true,
        sync: SyncUIState(
          status: SyncStatus.success,
          lastSyncedAt: DateTime(2026, 9, 15, 9, 30),
          pendingCount: 2,
        ),
      );

      expect(
          find.byKey(const Key('profile_syncLastSynced')), findsOneWidget);
      expect(find.textContaining('15/09/2026'), findsOneWidget);
      expect(find.byKey(const Key('profile_syncPending')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // G2 chưa mở → nhãn bắt buộc để user không hiểu nhầm đã backup.
      expect(find.text('Chưa có đồng bộ nền'), findsOneWidget);
    });

    testWidgets('AC 10.3: chưa từng sync → "Chưa từng đồng bộ", pending 0',
        (tester) async {
      await _pumpProfile(tester, authenticated: true);

      expect(find.text('Chưa từng đồng bộ'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Chưa có đồng bộ nền'), findsOneWidget);
    });

    testWidgets('AC 10.4: dữ liệu local hiện 3 count items/products/'
        'price histories', (tester) async {
      await _pumpProfile(tester, authenticated: true);

      expect(find.byKey(const Key('profile_localStats')), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // items
      expect(find.text('5'), findsOneWidget); // products (barcode_cache)
      expect(find.text('30'), findsOneWidget); // price histories
    });

    testWidgets('AC 10.4: DB lỗi → ErrorState + Thử lại (không crash, '
        'không leak raw exception)', (tester) async {
      await _pumpProfile(tester, authenticated: true, statsError: true);

      expect(find.byKey(const Key('errorState')), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
    });

    testWidgets('AC 10.5: chọn Tối → theme đổi NGAY; chọn Sáng → quay lại; '
        'persist vào prefs', (tester) async {
      await _pumpProfile(tester, authenticated: true);

      Brightness atTheme() => Theme.of(tester.element(
            find.byKey(const Key('profile_themeSection')),
          )).brightness;
      expect(atTheme(), Brightness.light);

      await tester.tap(find.byKey(const Key('profile_themeOption_dark')));
      await tester.pumpAndSettle();
      expect(atTheme(), Brightness.dark);

      await tester.tap(find.byKey(const Key('profile_themeOption_light')));
      await tester.pumpAndSettle();
      expect(atTheme(), Brightness.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeModeController.prefKey), 'light');
    });

    testWidgets('entry Export (section 5) → mở màn /export (F-#11)',
        (tester) async {
      await _pumpProfile(tester, authenticated: true);

      await tester.tap(find.byKey(const Key('profile_exportEntry')));
      await tester.pumpAndSettle();

      expect(find.text('EXPORT_STUB'), findsOneWidget);
    });

    testWidgets('chưa đăng nhập: account + sync hiện "Chưa đăng nhập", '
        'logout ẩn, tap account → /login', (tester) async {
      await _pumpProfile(tester, authenticated: false);

      expect(
          find.byKey(const Key('profile_accountLoggedOut')), findsOneWidget);
      expect(find.byKey(const Key('profile_syncLoggedOut')), findsOneWidget);
      expect(find.byKey(const Key('profile_logoutEntry')), findsNothing);
      // Vẫn đủ Appearance + Export (không phụ thuộc đăng nhập để XEM).
      expect(find.byKey(const Key('profile_themeSection')), findsOneWidget);
      expect(find.byKey(const Key('profile_exportEntry')), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_accountLoggedOut')));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN_STUB'), findsOneWidget);
    });

    testWidgets('AC 10.7: Logout → confirm dialog → xác nhận → gọi logout',
        (tester) async {
      final notifier = _AuthenticatedAuthNotifier();
      await _pumpProfile(
        tester,
        authenticated: true,
        authNotifier: notifier,
      );

      await tester.tap(find.byKey(const Key('profile_logoutEntry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirmDialog_confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmDialog_confirm')));
      await tester.pumpAndSettle();

      expect(notifier.logoutCalls, 1);
    });

    testWidgets('AC 10.7: bấm Huỷ trong dialog → KHÔNG logout',
        (tester) async {
      final notifier = _AuthenticatedAuthNotifier();
      await _pumpProfile(
        tester,
        authenticated: true,
        authNotifier: notifier,
      );

      await tester.tap(find.byKey(const Key('profile_logoutEntry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDialog_cancel')));
      await tester.pumpAndSettle();

      expect(notifier.logoutCalls, 0);
    });

    testWidgets('AC 10.8: pending > 0 → dialog cảnh báo lần 2; xác nhận '
        'lần 2 → logout', (tester) async {
      final notifier = _AuthenticatedAuthNotifier();
      await _pumpProfile(
        tester,
        authenticated: true,
        authNotifier: notifier,
        sync: const SyncUIState(status: SyncStatus.success, pendingCount: 3),
      );

      await tester.tap(find.byKey(const Key('profile_logoutEntry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmDialog_confirm')));
      await tester.pumpAndSettle();

      // Dialog lần 2 với cảnh báo dữ liệu chưa đồng bộ.
      expect(find.textContaining('3 thay đổi chưa được đẩy lên máy chủ'),
          findsOneWidget);
      expect(notifier.logoutCalls, 0,
          reason: 'chưa xác nhận lần 2 thì chưa logout');

      await tester.tap(find.byKey(const Key('confirmDialog_confirm')));
      await tester.pumpAndSettle();
      expect(notifier.logoutCalls, 1);
    });
  });
}
