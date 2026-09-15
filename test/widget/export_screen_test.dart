import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopsnap/core/network/api_exception.dart';
import 'package:shopsnap/models/user_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/export_provider.dart';
import 'package:shopsnap/screens/profile/export_screen.dart';
import 'package:shopsnap/services/export_api_service.dart';
import 'package:shopsnap/services/export_service.dart';
import 'package:shopsnap/widgets/ui/ui.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(id: 'u1', email: 'minh@shopsnap.dev', name: 'Minh'),
      );
}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.unauthenticated);
}

/// Fake ExportService — không chạm BE/path_provider/share_plus thật.
/// [error] != null → exportAndSave ném lỗi đó.
class _FakeExportService implements ExportService {
  int exportCalls = 0;
  int shareCalls = 0;
  ExportOutcome? outcome;
  Object? error;

  /// Chặn export giữa chừng để verify loading state (AC 11.2).
  Completer<void>? gate;

  @override
  Future<ExportOutcome> exportAndSave({
    required ExportFormat format,
    required String dateFrom,
    required String dateTo,
  }) async {
    exportCalls++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return outcome!;
  }

  @override
  Future<void> share(String path) async {
    shareCalls++;
  }
}

/// Outcome với File ẢO — KHÔNG đụng đĩa thật: dart:io completion không được
/// FakeAsync của testWidgets xử lý (await file IO trong widget test = treo).
/// UI chỉ đọc `filename` và đưa `file.path` vào fake sharer nên path ảo là đủ.
ExportOutcome _fakeOutcome(ExportFormat format) => ExportOutcome(
      format: format,
      file: File(
          'C:/shopsnap_test_fake/${ExportService.filenameFor(format, DateTime(2026, 9, 15))}'),
    );

GoRouter _router() => GoRouter(
      initialLocation: '/export',
      routes: [
        GoRoute(path: '/export', builder: (_, __) => const ExportScreen()),
        GoRoute(
          path: '/login',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('LOGIN_STUB'))),
        ),
      ],
    );

Future<void> _pumpExport(
  WidgetTester tester, {
  required bool authenticated,
  required _FakeExportService service,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(authenticated
            ? _AuthenticatedAuthNotifier.new
            : _UnauthenticatedAuthNotifier.new),
        exportServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp.router(
        theme: ThemeData.light(),
        routerConfig: _router(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ExportScreen — F-#11', () {
    testWidgets('AC 11.1: mặc định CSV + "Tháng này", đổi sang JSON được',
        (tester) async {
      final service = _FakeExportService()
        ..outcome = _fakeOutcome(ExportFormat.csv);
      await _pumpExport(tester, authenticated: true, service: service);

      expect(
        tester
            .widget<SegmentedButton<ExportFormat>>(
                find.byKey(const Key('exportScreen_formatSection')))
            .selected,
        {ExportFormat.csv},
        reason: 'AC 11.1 — format mặc định CSV',
      );
      // Range là enum private của screen → assert qua helper text của lựa chọn.
      expect(find.text('Từ đầu tháng đến hôm nay.'), findsOneWidget,
          reason: 'AC 11.1 — khoảng mặc định tháng hiện tại');

      // Đổi sang JSON vẫn chọn được.
      await tester.tap(find.byKey(const Key('exportScreen_formatJson')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedButton<ExportFormat>>(
                find.byKey(const Key('exportScreen_formatSection')))
            .selected,
        {ExportFormat.json},
      );

      // Đổi sang "Tất cả" → helper text đổi theo (366 ngày — BR-18).
      await tester.tap(find.byKey(const Key('exportScreen_rangeAll')));
      await tester.pumpAndSettle();
      expect(find.text('366 ngày gần nhất (giới hạn của máy chủ).'),
          findsOneWidget);
    });

    testWidgets('chưa đăng nhập → hint + nút Export DISABLE, không gọi BE',
        (tester) async {
      final service = _FakeExportService();
      await _pumpExport(tester, authenticated: false, service: service);

      expect(find.byKey(const Key('exportScreen_loginHint')), findsOneWidget);

      final button = tester.widget<PrimaryButton>(
        find.byKey(const Key('exportScreen_exportButton')),
      );
      expect(button.onPressed, isNull, reason: 'chưa login → nút disabled');

      await tester.tap(find.byKey(const Key('exportScreen_exportButton')));
      await tester.pumpAndSettle();
      expect(service.exportCalls, 0);
    });

    testWidgets('AC 11.2: bấm Export → loading → lưu file → tự mở share → '
        'snackbar xác nhận tên file', (tester) async {
      final service = _FakeExportService()
        ..outcome = _fakeOutcome(ExportFormat.csv)
        ..gate = Completer<void>();
      await _pumpExport(tester, authenticated: true, service: service);

      await tester.tap(find.byKey(const Key('exportScreen_exportButton')));
      await tester.pump();
      // Loading: nút chuyển sang spinner (đúng tokens của PrimaryButton).
      expect(find.byKey(const Key('primaryButton_loading')), findsOneWidget);

      // Cho phép export chạy xong → share → snackbar.
      service.gate!.complete();
      await tester.pumpAndSettle();

      expect(service.exportCalls, 1);
      expect(service.shareCalls, 1,
          reason: 'AC 11.2 — sau khi tạo file mở share sheet');
      expect(find.byKey(const Key('appSnackBar')), findsOneWidget);
      expect(find.textContaining('shopsnap_export_'), findsWidgets);
      // AC 11.3: xuất xong hiện nút chia sẻ lại.
      expect(find.byKey(const Key('exportScreen_shareAgainButton')),
          findsOneWidget);
    });

    testWidgets('AC 11.3: "Chia sẻ lại" mở share KHÔNG export lại',
        (tester) async {
      final service = _FakeExportService()
        ..outcome = _fakeOutcome(ExportFormat.json);
      await _pumpExport(tester, authenticated: true, service: service);

      await tester.tap(find.byKey(const Key('exportScreen_exportButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('exportScreen_shareAgainButton')));
      await tester.pumpAndSettle();

      expect(service.exportCalls, 1, reason: 'share lại không gọi BE');
      expect(service.shareCalls, 2);
    });

    testWidgets('AC 11.4: API lỗi → snackbar danger + thử lại được',
        (tester) async {
      final service = _FakeExportService()
        ..error = ApiException.network('Không thể kết nối tới máy chủ.');
      await _pumpExport(tester, authenticated: true, service: service);

      await tester.tap(find.byKey(const Key('exportScreen_exportButton')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appSnackBar')), findsOneWidget);
      expect(find.textContaining('Không xuất được dữ liệu'), findsOneWidget);
      expect(find.byKey(const Key('primaryButton_loading')), findsNothing,
          reason: 'loading không treo vô hạn');

      // Sửa fake thành công → bấm lại (retry) → thành công.
      service.error = null;
      service.outcome = _fakeOutcome(ExportFormat.csv);
      await tester.tap(find.byKey(const Key('exportScreen_exportButton')));
      await tester.pumpAndSettle();

      expect(service.exportCalls, 2);
      expect(service.shareCalls, 1);
      expect(find.byKey(const Key('appSnackBar')), findsOneWidget);
    });
  });
}
