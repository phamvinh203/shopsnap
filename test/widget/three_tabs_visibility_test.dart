// Bug regression (v1.0.5): user báo 3 tab chính (Trang chủ / Tổng kết /
// Lịch sử) hiển thị TRẮNG trên máy thật, trong khi toàn bộ 291 test xanh.
//
// ROOT CAUSE: DateHelper gọi DateFormat('...', 'vi_VN') — nhưng
// `initializeDateFormatting` CHỈ được gọi trong setUpAll của các file test,
// không hề có trong lib/. intl không init thì mọi locale != en_US đều ném
// LocaleDataException NGAY LÚC BUILD:
// - Home: formatDate trong build() của _HomeScreenState → NỔ TOÀN MÀN;
// - Lịch sử: formatMonthYear trong build() → NỔ TOÀN MÀN;
// - Tổng kết: formatDate trong _DateNavBar chỉ chạy khi xem kỳ ≠ hôm nay
//   (isToday == true dùng literal 'Hôm nay') → vỡ vùng date-nav khi bấm
//   prev/next. (formatTime dùng pattern không locale → rơi về en_US fallback
//   nên an toàn.)
// Màn lỗi = ErrorWidget (release = hộp xám trên nền giấy/bảng đen →
// "trang trắng").
//
// Vì vậy test này CỐ Ý KHÔNG gọi initializeDateFormatting (không có setUpAll
// masking như các file test cũ) — mô phỏng đúng điều kiện máy thật, để nếu
// ai regression (xóa guard trong DateHelper/main) thì test đỏ lại ngay.
//
// Ngoài ra assert 2 tầng chống cả loại bug "render nhưng tàng hình":
// 1. Presence — text tĩnh (header, appbar, nav) phải tồn tại trong cây widget;
// 2. Visibility — màu chữ phải TƯƠNG PHẢN với màu nền đục gần nhất phía sau
//    (contrast ratio > 1.2). Chữ cùng màu nền → ratio = 1.0 → fail.
// Cả 2 mode LIGHT và DARK đều chạy để chống lệch token dark mode.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/models/app_update_model.dart';
import 'package:shopsnap/models/budget_model.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/models/item_model.dart';
import 'package:shopsnap/models/summary_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/budget_provider.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/database_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/providers/summary_provider.dart';
import 'package:shopsnap/providers/update_provider.dart';
import 'package:shopsnap/screens/history/history_screen.dart';
import 'package:shopsnap/screens/home/home_screen.dart';
import 'package:shopsnap/screens/summary/summary_screen.dart';
import 'package:shopsnap/screens/shell/main_shell.dart';
import 'package:shopsnap/services/update_service.dart';
import 'package:sqflite/sqflite.dart';

class _FakeDatabase extends Mock implements Database {}

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.unauthenticated);
}

class _FakeItemsNotifier extends ItemsNotifier {
  final List<ItemModel> items;
  _FakeItemsNotifier(this.items);

  @override
  Future<List<ItemModel>> build() async => items;
}

class _FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<CategoryModel>> build() async => const [
        CategoryModel(
          id: 'cat_food',
          name: 'Ăn uống',
          icon: '🍔',
          color: '#FF6B6B',
          isDefault: true,
          sortOrder: 0,
          createdAt: 0,
        ),
      ];
}

class _FixedBudgetStatusNotifier extends BudgetStatusNotifier {
  final BudgetStatus? status;
  _FixedBudgetStatusNotifier(this.status);

  @override
  Future<BudgetStatus?> build() async => status;
}

/// Chặn call GitHub thật từ initState của HomeScreen.
class _FakeUpdateService extends UpdateService {
  @override
  Future<AppUpdateInfo> checkForUpdate({bool forceRefresh = false}) async =>
      AppUpdateInfo.noUpdate('1.0.5');
}

/// DB giả cho HistoryScreen (rawQuery theo tháng) — không chạm sqflite thật.
Database _fakeDb() {
  final db = _FakeDatabase();
  when(() => db.rawQuery(any(), any())).thenAnswer((inv) async {
    final sql = inv.positionalArguments[0] as String;
    if (sql.contains('day_of_month')) {
      return <Map<String, Object?>>[
        {'day_of_month': 14, 'total': 150000},
      ];
    }
    return <Map<String, Object?>>[];
  });
  return db;
}

SummaryModel _summary() => SummaryModel(
      date: DateTime(2026, 9, 14),
      totalSpent: 150000,
      itemCount: 3,
      categories: const [],
      items: const [
        ItemModel(
          id: 'i1',
          name: 'Cà phê',
          price: 50000,
          categoryId: 'cat_food',
          categoryName: 'Ăn uống',
          categoryIcon: '🍔',
          categoryColor: '#FF6B6B',
          createdAt: 1705302600000,
          updatedAt: 1705302600000,
        ),
      ],
    );

GoRouter _router(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (_, __, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            GoRoute(path: '/summary', builder: (_, __) => const SummaryScreen()),
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
          ],
        ),
        GoRoute(
            path: '/add',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('ADD_STUB')))),
        GoRoute(
            path: '/login',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('LOGIN_STUB')))),
      ],
    );

// ── Visibility helpers ────────────────────────────────────────────────────────

/// Màu chữ đang style của RenderParagraph (token của dự án luôn set màu tường
/// minh qua AppTypography nên color không null).
Color _textColor(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final span = paragraph.text;
  final style = span.style;
  assert(style?.color != null,
      'TextSpan cần có màu tường minh để test visibility: $span');
  return style!.color!;
}

/// Màu nền đục GẦN NHẤT phía sau render object (đi ngược tổ tiên: DecoratedBox
/// đục hoặc PhysicalModel/Material của Scaffold).
Color _backdrop(RenderObject ro) {
  RenderObject? current = ro.parent;
  while (current != null) {
    if (current is RenderDecoratedBox) {
      final deco = current.decoration;
      if (deco is BoxDecoration) {
        final c = deco.color;
        if (c != null && c.opacity == 1.0) return c;
      }
    }
    if (current is RenderPhysicalModel && current.color.opacity == 1.0) {
      return current.color;
    }
    if (current is RenderPhysicalShape && current.color.opacity == 1.0) {
      return current.color;
    }
    current = current.parent;
  }
  return const Color(0xFFFFFFFF);
}

/// Contrast ratio WCAG giữa 2 màu — 1.0 = giống hệt nhau (tàng hình).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Assert text hiển thị VISIBLE: màu chữ (blend với alpha) phải tương phản
/// với nền đục gần nhất. Ratio == 1.0 → chữ cùng màu nền → bug "trang trắng".
void _expectVisible(WidgetTester tester, Finder finder, String label) {
  final matches = finder.evaluate();
  expect(matches, isNotEmpty, reason: '$label: không tìm thấy trong cây widget');
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final textColor = _textColor(tester, finder);
  final backdrop = _backdrop(paragraph);
  final blended = Color.alphaBlend(textColor, backdrop);
  final ratio = _contrast(blended, backdrop);
  expect(
    ratio,
    greaterThan(1.2),
    reason: '$label: chữ tàng hình — màu ${blended.value.toRadixString(16)} '
        'nearly trùng nền ${backdrop.value.toRadixString(16)} (ratio=$ratio)',
  );
}

// ── Harness ───────────────────────────────────────────────────────────────────

Future<void> _pumpTab(
  WidgetTester tester, {
  required Brightness brightness,
  required String initialLocation,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
        itemsProvider.overrideWith(() => _FakeItemsNotifier(const [
              ItemModel(
                id: 'i1',
                name: 'Cà phê',
                price: 40000,
                categoryId: 'cat_food',
                categoryName: 'Ăn uống',
                categoryIcon: '🍔',
                categoryColor: '#FF6B6B',
                createdAt: 1705302600000,
                updatedAt: 1705302600000,
              ),
            ])),
        categoriesProvider.overrideWith(_FakeCategoriesNotifier.new),
        budgetStatusProvider.overrideWith(
          () => _FixedBudgetStatusNotifier(
            const BudgetStatus(
              budget: BudgetModel(
                id: 'b1',
                amount: 100000,
                period: BudgetPeriod.day,
                startDate: '2026-09-14',
                endDate: '2026-09-14',
                isActive: true,
                createdAt: 0,
              ),
              spent: 40000,
            ),
          ),
        ),
        updateServiceProvider.overrideWithValue(_FakeUpdateService()),
        summaryProvider.overrideWith((ref, params) async => _summary()),
        databaseProvider.overrideWith((ref) async => _fakeDb()),
      ],
      child: MaterialApp.router(
        theme: buildAppTheme(brightness),
        routerConfig: _router(initialLocation),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // themeModeProvider (MainShell thật) đọc SharedPreferences.
    // CỐ Ý KHÔNG gọi initializeDateFormatting ở đây — xem comment đầu file.
    SharedPreferences.setMockInitialValues({});
  });

  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.dark ? 'DARK' : 'LIGHT';

    group('3 tab chính hiển thị nội dung ($mode)', () {
      testWidgets('Trang chủ: header tĩnh + hero ngân sách + item list visible',
          (tester) async {
        await _pumpTab(tester,
            brightness: brightness, initialLocation: '/');

        // Text tĩnh KHÔNG phụ thuộc data — tàng hình ⇒ lỗi theme, không phải data.
        _expectVisible(tester, find.text('Xin chào! 👋'), 'Home header');
        _expectVisible(
            tester, find.text('NGÂN SÁCH HÔM NAY'), 'Hero overline');
        _expectVisible(tester,
            find.byKey(const Key('budgetProgressCard_remaining'))
                .first, // RenderParagraph của số "Còn lại"
            'Hero số còn lại');
        _expectVisible(tester, find.text('Cà phê'), 'Item card title');
      });

      testWidgets('Tổng kết: appbar + hero tổng chi tiêu visible',
          (tester) async {
        await _pumpTab(tester,
            brightness: brightness, initialLocation: '/summary');

        _expectVisible(tester, find.text('Tổng kết chi tiêu'), 'Appbar title');
        _expectVisible(tester, find.text('TỔNG CHI TIÊU'), 'Hero overline');
        _expectVisible(tester, find.text('Cà phê'), 'Item list title');
      });

      testWidgets('Tổng kết: bấm "hôm trước" — date bar vẫn render, không vỡ',
          (tester) async {
        await _pumpTab(tester,
            brightness: brightness, initialLocation: '/summary');

        // isToday == true → nhánh an toàn. Bấm prev → isToday == false →
        // nhánh gọi DateHelper.formatDate (locale vi_VN) trong _DateNavBar.
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Chuyển kỳ phát sinh exception — DateFormat chưa init?');
        // Overline ngày HOA theo vi_VN luôn chứa "THÁNG <n>" (kể cả case
        // cuối tháng); chữ thứ 2 dưới nó không HOA nên finder khớp đúng 1.
        _expectVisible(
            tester, find.textContaining('THÁNG'), 'Date bar overline');
      });

      testWidgets('Lịch sử: appbar + hero tổng tháng visible',
          (tester) async {
        await _pumpTab(tester,
            brightness: brightness, initialLocation: '/history');

        _expectVisible(tester, find.text('Lịch sử chi tiêu'), 'Appbar title');
        _expectVisible(tester, find.text('Tổng tháng'), 'Hero label');
        _expectVisible(
          tester,
          find.byKey(const Key('historyScreen_monthTotal')),
          'Hero tổng tháng',
        );
      });
    });
  }
}
