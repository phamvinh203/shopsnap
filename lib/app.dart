import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';

class ShopSnapApp extends ConsumerWidget {
  const ShopSnapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // F-#12 (AC 12.5): bấm notification hệ thống → deep-link tới đúng ngữ cảnh
    // (budget → /budget, price → /shopping-list — route đã lọc whitelist trước
    // ở parseNotificationRoute nên push không bao giờ gặp route lạ). Price
    // alert có kèm item id → mở Shopping List và scroll-to + highlight món đó.
    NotificationService.onNotificationTap = (route, {String? itemId}) {
      try {
        router.push(
          itemId == null || itemId.isEmpty
              ? route
              : '$route?item=${Uri.encodeQueryComponent(itemId)}',
        );
      } catch (_) {}
    };
    // Phase 4 — dark mode: light + dark cùng nguồn token (buildAppTheme),
    // themeMode theo preference của user (default system khi prefs chưa
    // load xong — xem theme_provider.dart).
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'ShopSnap',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
