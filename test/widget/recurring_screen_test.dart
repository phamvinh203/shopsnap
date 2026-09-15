import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shopsnap/core/theme/app_theme.dart';
import 'package:shopsnap/core/utils/recurring_suggest.dart';
import 'package:shopsnap/database/daos/recurring_expense_dao.dart';
import 'package:shopsnap/models/recurring_expense_model.dart';
import 'package:shopsnap/providers/auth_provider.dart';
import 'package:shopsnap/providers/notification_provider.dart';
import 'package:shopsnap/providers/profile_provider.dart';
import 'package:shopsnap/providers/recurring_expense_provider.dart';
import 'package:shopsnap/providers/sync_provider.dart';
import 'package:shopsnap/screens/profile/profile_screen.dart';
import 'package:shopsnap/screens/recurring/recurring_screen.dart';

// ── Fakes (không chạm SQLite/API/plugin) ─────────────────────────────────────

RecurringExpense _entry(
  String id,
  String name, {
  int amount = 200000,
  int dueDay = 5,
  bool isActive = true,
  int remindDaysBefore = 1,
}) =>
    RecurringExpense(
      id: id,
      name: name,
      matchKey: name.toLowerCase(),
      amount: amount,
      dueDay: dueDay,
      isActive: isActive,
      remindDaysBefore: remindDaysBefore,
      createdAt: 0,
      updatedAt: 0,
    );

RecurringSuggestion _suggestion(String name, int amount, int occurrences) =>
    RecurringSuggestion(
      name: name,
      matchKey: name.toLowerCase(),
      amount: amount,
      occurrences: occurrences,
      lastPurchasedAt: DateTime(2026, 9, 2),
    );

/// Fake notifier giữ list trong bộ nhớ + ghi nhận mọi thao tác.
class _FakeRecurringNotifier extends RecurringExpensesNotifier {
  final List<RecurringExpense> entries;
  final List<String> calls = [];

  _FakeRecurringNotifier(this.entries);

  @override
  Future<List<RecurringExpense>> build() async => entries;

  @override
  Future<RecurringExpense?> add(CreateRecurringExpenseDto dto) async {
    calls.add(
        'add:${dto.name}:${dto.amount}:${dto.dueDay}:${dto.remindDaysBefore}');
    final created = _entry('new_${entries.length + 1}', dto.name.trim(),
        amount: dto.amount, dueDay: dto.dueDay);
    entries.add(created);
    // Mô phỏng provider thật: sau khi lưu, nhóm trùng match_key rời card gợi ý.
    ref.invalidate(recurringSuggestionsProvider);
    ref.invalidateSelf();
    return created;
  }

  @override
  Future<RecurringExpense?> updateEntry(
    String id, {
    String? name,
    int? amount,
    int? dueDay,
    int? remindDaysBefore,
  }) async {
    calls.add('update:$id:$name:$amount:$dueDay:$remindDaysBefore');
    final i = entries.indexWhere((e) => e.id == id);
    if (i >= 0) {
      entries[i] = entries[i].copyWith(
        name: name,
        amount: amount,
        dueDay: dueDay,
        updatedAt: 9999,
      );
    }
    ref.invalidateSelf();
    return i >= 0 ? entries[i] : null;
  }

  @override
  Future<void> setActive(String id, bool active) async {
    calls.add('setActive:$id:$active');
    final i = entries.indexWhere((e) => e.id == id);
    entries[i] = entries[i].copyWith(isActive: active);
    ref.invalidateSelf();
  }

  @override
  Future<void> rearmReminders() async {
    calls.add('rearm');
  }
}

// ── Harness ───────────────────────────────────────────────────────────────────

Future<void> _pumpScreen(
  WidgetTester tester, {
  required _FakeRecurringNotifier notifier,
  List<RecurringSuggestion> suggestions = const [],
  bool permissionDenied = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recurringExpensesProvider.overrideWith(() => notifier),
        // Mô phỏng provider thật: nhóm trùng match_key với entry ĐANG BẬT
        // (AC 4.9) không được gợi ý. Đọc state notifier TRỰC TIẾP (không
        // ref.watch) để tránh vòng lặp invalidate khi notifier tự invalidate
        // provider gợi ý sau khi add — như provider thật làm với DAO.
        recurringSuggestionsProvider.overrideWith((ref) async {
          final activeKeys = notifier.entries
              .where((e) => e.isActive)
              .map((e) => e.matchKey)
              .toSet();
          return suggestions
              .where((s) => !activeKeys.contains(s.matchKey))
              .toList();
        }),
        notificationPermissionDeniedProvider
            .overrideWith((ref) => permissionDenied),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const RecurringScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('RecurringScreen (M-2)', () {
    testWidgets('AC 4.2 — rỗng: empty state + nút "Thêm khoản định kỳ"; card gợi ý ẩn',
        (tester) async {
      final notifier = _FakeRecurringNotifier([]);
      await _pumpScreen(tester, notifier: notifier);

      expect(find.byKey(const Key('emptyState')), findsOneWidget);
      expect(find.text('Chưa có khoản định kỳ'), findsOneWidget);
      expect(find.byKey(const Key('emptyState_action')), findsOneWidget);
      // AC 4.10: không gợi ý → card ẩn hoàn toàn (không card rỗng).
      expect(find.byKey(const Key('recurringSuggestionCard')), findsNothing);
    });

    testWidgets('AC 4.11b/4.12 — mở màn → re-arm nhắc được gọi', (tester) async {
      final notifier = _FakeRecurringNotifier([]);
      await _pumpScreen(tester, notifier: notifier);

      expect(notifier.calls, contains('rearm'));
    });

    testWidgets('AC 4.2 — mỗi dòng: tên, tiền VND nguyên, "Hằng tháng, ngày X", toggle',
        (tester) async {
      final notifier = _FakeRecurringNotifier([
        _entry('e1', 'Netflix', amount: 200000, dueDay: 5),
      ]);
      await _pumpScreen(tester, notifier: notifier);

      expect(find.byKey(const Key('recurringTile_e1')), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('200.000đ'), findsOneWidget);
      expect(find.text('Hằng tháng, ngày 5'), findsOneWidget);

      final toggle =
          tester.widget<Switch>(find.byKey(const Key('recurring_toggle_e1')));
      expect(toggle.value, isTrue);
    });

    testWidgets('AC 4.5/4.6 — toggle tắt → setActive(false); mục "Đã tắt" style mờ',
        (tester) async {
      final notifier = _FakeRecurringNotifier([
        _entry('e1', 'Netflix'),
        _entry('e2', 'Tiền mạng', isActive: false),
      ]);
      await _pumpScreen(tester, notifier: notifier);

      await tester.tap(find.byKey(const Key('recurring_toggle_e1')));
      await tester.pumpAndSettle();
      expect(notifier.calls, contains('setActive:e1:false'));

      // Entry tắt nằm mục "ĐÃ TẮT" + opacity mờ (0.55).
      expect(find.byKey(const Key('recurring_inactiveHeader')), findsOneWidget);
      final dimmed = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const Key('recurringTile_e2')),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(dimmed.opacity, lessThan(1.0));
    });

    testWidgets('AC 4.3 — nút thêm trên app bar → sheet trống; điền hợp lệ → lưu ngay',
        (tester) async {
      final notifier = _FakeRecurringNotifier([]);
      await _pumpScreen(tester, notifier: notifier);

      await tester.tap(find.byKey(const Key('recurring_addButton')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recurringExpenseSheet')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('recurringSheet_nameField')), 'Tiền nhà');
      await tester.enterText(
          find.byKey(const Key('recurringSheet_amountField')), '3000000');
      await tester.enterText(
          find.byKey(const Key('recurringSheet_dueDayField')), '5');
      await tester.tap(find.byKey(const Key('recurringSheet_saveButton')));
      await tester.pumpAndSettle();

      expect(notifier.calls,
          contains('add:Tiền nhà:3000000:5:1')); // remind mặc định 1
      expect(find.byKey(const Key('recurringExpenseSheet')), findsNothing);
      expect(find.byKey(const Key('recurringTile_new_1')), findsOneWidget);
    });

    testWidgets('AC 4.3 — validation: tên rỗng / tiền 0 / ngày 29 → lỗi inline, KHÔNG lưu',
        (tester) async {
      final notifier = _FakeRecurringNotifier([]);
      await _pumpScreen(tester, notifier: notifier);

      await tester.tap(find.byKey(const Key('recurring_addButton')));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('recurringSheet_nameField')), '   ');
      await tester.enterText(
          find.byKey(const Key('recurringSheet_amountField')), '0');
      await tester.enterText(
          find.byKey(const Key('recurringSheet_dueDayField')), '29');
      await tester.tap(find.byKey(const Key('recurringSheet_saveButton')));
      await tester.pumpAndSettle();

      expect(find.text('Nhập tên khoản'), findsOneWidget);
      expect(find.text('Số tiền phải lớn hơn 0'), findsOneWidget);
      expect(find.text('Ngày đến hạn từ 1 đến 28'), findsOneWidget);
      expect(notifier.calls.where((c) => c.startsWith('add:')), isEmpty);
    });

    testWidgets('AC 4.4 — tap dòng → sheet sửa prefill; lưu → updateEntry nhận đủ tham số',
        (tester) async {
      final notifier =
          _FakeRecurringNotifier([_entry('e1', 'Netflix', amount: 200000)]);
      await _pumpScreen(tester, notifier: notifier);

      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recurringExpenseSheet')), findsOneWidget);
      // Prefill đúng giá trị hiện có.
      final amountField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('recurringSheet_amountField')),
          matching: find.byType(TextField),
        ),
      );
      expect(amountField.controller!.text, '200000');

      await tester.enterText(
          find.byKey(const Key('recurringSheet_amountField')), '260000');
      await tester.tap(find.byKey(const Key('recurringSheet_saveButton')));
      await tester.pumpAndSettle();

      expect(
        notifier.calls,
        contains('update:e1:Netflix:260000:5:1'), // id + tên giữ nguyên
      );
    });

    testWidgets('AC 4.10 — card gợi ý: tên + tiền + "xuất hiện N lần/3 tháng"; '
        'tap → sheet prefill; lưu xong → gợi ý biến mất', (tester) async {
      final notifier = _FakeRecurringNotifier([]);
      await _pumpScreen(
        tester,
        notifier: notifier,
        suggestions: [_suggestion('Netflix', 200000, 3)],
      );

      expect(find.byKey(const Key('recurringSuggestionCard')), findsOneWidget);
      expect(find.text('Có vẻ là khoản định kỳ'), findsOneWidget);
      expect(find.textContaining('200.000đ'), findsOneWidget);
      expect(find.textContaining('xuất hiện 3 lần/3 tháng'), findsOneWidget);

      // Tap gợi ý → sheet thêm đã prefill (ngày đến hạn = ngày mua gần nhất).
      await tester
          .tap(find.byKey(const Key('recurringSuggestion_convert_netflix')));
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('recurringSheet_nameField')),
          matching: find.byType(TextField),
        ),
      );
      final amountField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('recurringSheet_amountField')),
          matching: find.byType(TextField),
        ),
      );
      final dueDayField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('recurringSheet_dueDayField')),
          matching: find.byType(TextField),
        ),
      );
      expect(nameField.controller!.text, 'Netflix');
      expect(amountField.controller!.text, '200000');
      expect(dueDayField.controller!.text, '2'); // ngày của lần mua gần nhất

      await tester.tap(find.byKey(const Key('recurringSheet_saveButton')));
      await tester.pumpAndSettle();

      expect(notifier.calls, contains('add:Netflix:200000:2:1'));
      // Lưu thành công → gợi ý trùng match_key biến mất khỏi card.
      expect(find.byKey(const Key('recurringSuggestionCard')), findsNothing);
    });

    testWidgets('AC 4.14 — không quyền notification → hint hướng dẫn, thao tác vẫn chạy',
        (tester) async {
      final notifier = _FakeRecurringNotifier([_entry('e1', 'Netflix')]);
      await _pumpScreen(
          tester, notifier: notifier, permissionDenied: true);

      expect(find.byKey(const Key('recurring_permissionHint')), findsOneWidget);
      expect(find.byKey(const Key('recurring_permissionSettings')), findsOneWidget);

      // Khoản vẫn lưu/toggle bình thường.
      await tester.tap(find.byKey(const Key('recurring_toggle_e1')));
      await tester.pumpAndSettle();
      expect(notifier.calls, contains('setActive:e1:false'));
    });
  });

  group('Entry point /profile → /recurring (spec Notes — nhóm Dữ liệu local)', () {
    GoRouter buildRouter() => GoRouter(
          initialLocation: '/profile',
          routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
            GoRoute(
              path: '/recurring',
              builder: (_, __) => const Scaffold(
                  key: Key('recurringStub'), body: Text('RECURRING_STUB')),
            ),
            GoRoute(
              path: '/login',
              builder: (_, __) =>
                  const Scaffold(body: Center(child: Text('LOGIN_STUB'))),
            ),
          ],
        );

    Future<void> pumpProfile(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(_UnauthAuthNotifier.new),
            syncProvider.overrideWith((ref) => _NoopSyncNotifier(ref)),
            localDataStatsProvider.overrideWith(
              (ref) async => const LocalDataStats(
                  items: 1, products: 1, priceHistories: 1),
            ),
          ],
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: buildRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tap "Khoản chi định kỳ" → mở /recurring', (tester) async {
      await pumpProfile(tester);

      expect(find.byKey(const Key('profile_recurringEntry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile_recurringEntry')));
      await tester.pumpAndSettle();

      expect(find.text('RECURRING_STUB'), findsOneWidget);
    });
  });
}

// ── Fakes cho profile entry ───────────────────────────────────────────────────

class _UnauthAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(status: AuthStatus.unauthenticated);
}

class _NoopSyncNotifier extends SyncNotifier {
  _NoopSyncNotifier(super.ref);
}
