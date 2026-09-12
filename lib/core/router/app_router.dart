import 'package:go_router/go_router.dart';
import '../../screens/shell/main_shell.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/add_item/add_item_screen.dart';
import '../../screens/summary/summary_screen.dart';
import '../../screens/history/history_screen.dart';
import '../../screens/budget_settings/budget_settings_screen.dart';
import '../../screens/scan/scan_screen.dart';
import '../../screens/ocr/ocr_screen.dart';
import '../../screens/ar_sticker/ar_sticker_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/',        builder: (c, s) => const HomeScreen()),
        GoRoute(path: '/summary', builder: (c, s) => const SummaryScreen()),
        GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
      ],
    ),
    GoRoute(path: '/add',    builder: (c, s) => const AddItemScreen()),
    GoRoute(path: '/scan',   builder: (c, s) => const ScanScreen()),
    GoRoute(path: '/ocr',    builder: (c, s) => const OcrScreen()),
    GoRoute(path: '/ar',     builder: (c, s) => const ArStickerScreen()),
    GoRoute(path: '/budget', builder: (c, s) => const BudgetSettingsScreen()),
  ],
);
