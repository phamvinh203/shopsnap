# UI Redesign Proposal — ShopSnap Mobile (Flutter)

**Người viết:** Flutter Frontend Dev
**Ngày:** 2026-09-14
**Phạm vi:** CHỈ tầng UI (theme, shared widgets, screen layout). KHÔNG đụng providers / ApiClient / DAOs / router logic. Mục tiêu: 142 test giữ xanh sau mỗi phase.
**Input đã đọc:** `app_colors.dart` (12 màu tĩnh), `app_theme.dart` (M3 + seed tím, 72 dòng), `home_screen.dart` (412 dòng), `item_card.dart`, `budget_progress_card.dart`, `login_screen.dart`, `add_item_screen.dart` (678 dòng), `main_shell.dart`, `summary_screen.dart` (593 dòng), `shopsnap/design-spec.md`, 4 file widget test.

---

## 0. Chẩn đoán hiện trạng (vấn đề gốc của "UI xấu")

| # | Vấn đề | Bằng chứng |
|---|--------|-----------|
| 1 | Không có token layer: spacing/radius/shadow hardcode rải rác | `BorderRadius.circular(16)` lặp ở ≥8 chỗ; `BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))` copy-paste y nguyên trong `item_card.dart:58` và `budget_progress_card.dart:29` |
| 2 | Không có shared component library | `lib/widgets/` chỉ có `update_dialog.dart`. Mỗi screen tự dựng: `_SkeletonCard` (home), `_EmptyState` (summary), `_Label`, `_QuickBtn` (add_item), `_NavItem` (shell) — cùng bản chất, khác style |
| 3 | Màu hardcode trong widget, không dark-mode-able | `summary_screen.dart` dùng `Colors.white` cho card + appbar; `_AddCategorySheet` background `Colors.white`; nhiều `TextStyle(color: AppColors.textPrimary)` thay vì đọc `colorScheme` |
| 4 | Trạng thái bất đồng bộ đối xử tệ | `error: (_, __) => SizedBox.shrink()` (home budget/category) hoặc raw `Text('Lỗi: $e')` (home, summary) — không có ErrorState/EmptyState/Retry chuẩn |
| 5 | Typography không tối ưu cho "nhiều số tiền" | Nunito OK cho tone thân thiện nhưng số tiền không dùng tabular figures → list giá không thẳng cột; thiếu style riêng cho hero number |
| 6 | Visual noise | Emoji làm icon chính (🛍️ 🧾 💾 🚀 💰), mix icon outline + emoji, thiếu hierarchy nhất quán |

Kết luận: vấn đề không nằm ở "thiếu ý tưởng" (design-spec.md đã có direction tốt) mà ở **thiếu hệ thống**. Redesign = dựng hệ thống (tokens + components) rồi restyle màn theo hệ thống đó.

---

## 1. Design Tokens Layer

### 1.1 Cơ chế chọn: Static tokens (const) + một ThemeExtension duy nhất

Ba lựa chọn đã cân nhắc:

| Phương án | Ưu | Nhược | Verdict |
|-----------|----|-------|---------|
| A. Static const class (AppSpacing…) cho layout + **ThemeExtension** cho semantic colors | `const` giữ được trong widget tree (perf, đọc được dễ), zero boilerplate; colors auto-switch theo brightness và đi kèm ThemeData | Phải viết fallback khi test pump bare `MaterialApp` | **CHỌN** |
| B. Toàn bộ qua InheritedWidget | Kiểm soát đầy đủ | Trùng lặp đúng cái ThemeExtension đã làm sẵn trong ThemeData; thêm boilerplate rebuild; khó dùng trong `const` | Bỏ |
| C. Extension getters trên `ThemeData` thuần (`theme.appSpacing`) | Gọn | Vẫn phải extension class + không có cơ chế lerp/brightness; chỉ là cú pháp | Chỉ dùng làm sugar trên A |

**Lý do thenh chốt của A:**
1. Spacing/radius/shadow **không đổi theo dark mode** → static const là đủ, và chỉ static const mới cho phép `const EdgeInsets.all(AppSpacing.md)` — giữ nguyên khả năng const của widget hiện có.
2. Semantic colors (surface, text, tint container) **đổi theo brightness** → ThemeExtension trong `ThemeData` là cơ chế chính chủ của Material 3, tự lerp khi chuyển theme, và widget test vẫn đọc được qua `Theme.of(context)`.
3. Widget test hiện tại pump **bare `MaterialApp`** (không qua `buildAppTheme`) → `Theme.of(context).extension<SnapColors>()` sẽ trả **null** trong test. Bắt buộc fallback (mã bên dưới) — đây là bẫy lớn nhất của phase token.

### 1.2 Cấu trúc file đề xuất

```
lib/core/theme/
  app_colors.dart        # GIỮ: brand hex constants (nguồn sự thật của màu thương hiệu)
  app_dimens.dart        # NEW: AppSpacing, AppRadius, AppSizes, AppDurations
  app_shadows.dart       # NEW: AppShadows (card / floating / modal / glow) — light & dark
  app_typography.dart    # NEW: buildTextTheme(Brightness) + money/hero number styles
  snap_colors.dart       # NEW: class SnapColors extends ThemeExtension<SnapColors>
  app_theme.dart         # SỬA: buildAppTheme(Brightness) → light + dark, wire component themes
```

Helper đọc (extension trên BuildContext, đặt cuối `snap_colors.dart`):

```dart
extension SnapColorsX on BuildContext {
  SnapColors get snap => Theme.of(this).extension<SnapColors>() ?? SnapColors.light();
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
```

### 1.3 Giá trị token đề xuất

**Spacing (4pt grid, khớp usage hiện tại để diff nhỏ):**

```dart
abstract final class AppSpacing {
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;   // gutter chuẩn của screen (hiện là 16)
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}
```

**Radius (map thẳng sang usage đang có 8/12/16/20/24):**

```dart
abstract final class AppRadius {
  static const double sm   = 8;    // chip nhỏ, badge
  static const double md   = 12;   // input, quick button, dialog nhỏ
  static const double lg   = 16;   // AppCard, item card
  static const double xl   = 20;   // hero/budget card, sheet content
  static const double sheet= 24;   // top radius của bottom sheet
  static const double pill = 999;  // price tag, progress bar
}
```

**Shadows (thang 3 bậc + glow; dark mode dùng đen đậm hơn):**

```dart
abstract final class AppShadows {
  static const card     = [BoxShadow(color: Color(0x0D101828), blurRadius: 8,  offset: Offset(0, 2))];
  static const floating = [BoxShadow(color: Color(0x1A101828), blurRadius: 18, offset: Offset(0, 6))];
  static const modal    = [BoxShadow(color: Color(0x26000000), blurRadius: 28, offset: Offset(0, -4))];
  static const glowPrimary = [BoxShadow(color: Color(0x406C63FF), blurRadius: 22, offset: Offset(0, 8))];
  // Dark: card → [BoxShadow(Color(0x66000000), 10, (0,3))], bỏ glow (dùng border hairline thay)
}
```

**Typography (giữ Nunito — rounded, thân thiện, hợp shopping app VN; thêm 2 style thiếu):**

| Token | Size/Weight | Dùng cho |
|-------|------------|----------|
| `displayLarge` | 34 / w800 | Hero number "Còn lại" trên home |
| `displaySmall` (mới) | 28 / w800 | Hero tổng chi tiêu summary |
| `headlineMedium` | 20 / w700 | Tiêu đề màn |
| `titleMedium` / `titleSmall` | 16 / 600 · 14 / 600 | Tên item, section header |
| `bodyMedium` / `bodySmall` | 14 / 400 · 12 / 400 | Nội dung, caption |
| `labelLarge` | 14 / w600 | Button |

Money style (thẳng cột danh sách giá):

```dart
static TextStyle moneyOf(TextTheme t, {double size = 15}) => t.titleMedium!.copyWith(
  fontSize: size, fontWeight: FontWeight.w700,
  fontFeatures: const [FontFeature.tabularFigures()],
);
```

**Semantic colors qua ThemeExtension + dark palette:**

```dart
@immutable
class SnapColors extends ThemeExtension<SnapColors> {
  final Color tintPrimary;      // container tint (light #EEF0FF / dark #26244A)
  final Color onTintPrimary;
  final Color success, successDim, warning, danger;
  final Color hairline;         // border thay elevation (light #E5E7EB / dark #2A2A3A)
  final Color skeleton;         // shimmer base

  const SnapColors({required this.tintPrimary, /* ... */});

  static const light = SnapColors(/* tintPrimary #EEF0FF, hairline #E5E7EB ... */);
  static const dark  = SnapColors(/* tintPrimary #26244A, hairline #2A2A3A ... */);

  @override
  SnapColors lerp(SnapColors? other, double t) => /* lerp từng field */;
  @override
  SnapColors copyWith({...}) => /* ... */;
}
```

Bảng màu dark mode đề xuất (light giữ nguyên bảng hiện tại — nó đã ổn):

| Token | Light | Dark |
|-------|-------|------|
| `primary` | `#6C63FF` | `#8B85FF` (sáng hơn để contrast trên nền tối) |
| `primaryDark` (pressed) | `#4B44CC` | `#544CE0` |
| tint container | `#EEF0FF` | `#26244A` |
| `bgMain` / scaffold | `#F7F8FC` | `#12121E` |
| `bgCard` / surface | `#FFFFFF` | `#1C1C2C` |
| surfaceVariant (input fill) | `#F1F2F8` | `#262638` |
| `textPrimary` | `#1A1A2E` | `#F2F2F7` |
| `textSecondary` | `#6B7280` | `#A5ADBB` |
| `divider`/`hairline` | `#E5E7EB` | `#2A2A3A` |
| `success` | `#00C48C` | `#2ADBA5` |
| `warning` | `#FFAB2D` | `#FFBC55` |
| `danger` | `#FF4D4D` | `#FF6B6B` |

Trong `buildAppTheme`, các màu semantic được map vào `ColorScheme` (surface, onSurface, surfaceContainerHighest…) để **mọi Material component tự dark**; `AppColors.*` giữ lại làm brand hex, dần đánh `// TODO: migrate` các chỗ đọc trực tiếp.

---

## 2. Shared Component Library (`lib/widgets/ui/`)

Nguyên tắc API: stateless, nhận data + callback, **không** tự gọi provider; mọi text hiển thị đều giữ nguyên chuỗi tiếng Việt hiện có nếu widget thay thế widget cũ có test.

| Widget | API ngắn gọn | Ghi chú |
|--------|--------------|---------|
| `AppScaffold` | `({title, actions, body, floatingActionButton, bottomNav, safeArea = true})` | Scaffold + AppBar + SafeArea chuẩn; thay ~10 chỗ khai báo lặp |
| `AppCard` | `({child, onTap?, padding = AppSpacing.lg, radius = AppRadius.lg, tint?, hairline = true})` | Material+InkWell, elevation 0 + `AppShadows.card` + hairline border; thay Container copy-paste |
| `PrimaryButton` | `({label, onPressed, loading = false, icon?, expand = true})` | Loading spinner thay label; disable khi loading |
| `SecondaryButton` | `({label, onPressed, danger = false})` | Tint background + primary text |
| `GhostButton` | `({label, onPressed})` | Text-only cho action phụ ("Huỷ") |
| `AppTextField` | `({controller, hint, label, prefixIcon, suffix?, validator, keyboardType, obscure, maxLines})` | Wrap TextFormField + label đều nhau (thay `_Label` thủ công) |
| `MoneyText` | `({int amount, style, colored = false})` | LUÔN tabular figures — dùng mọi nơi hiển thị tiền |
| `CategoryChip` | `({icon, label, selected, suggested, onTap})` | Badge "Gợi ý" tích hợp; thay `category_chips_row` + `category_selector` |
| `PriceTag` | `({int amount, tone = PriceTone.primary})` | Pill price tag (thay Container pill trong ItemCard); tone: `primary/success/danger` |
| `BudgetProgressBar` | `({spent, total, compact = false})` | Giữ `LinearProgressIndicator` + đúng chuỗi "Chưa đặt ngân sách"/"Còn lại:" (test phụ thuộc) |
| `EmptyState` | `({icon, title, message?, actionLabel?, onAction?})` | Thay emoji-Column thủ công ở home/summary |
| `ErrorState` | `({message, onRetry})` | Thay `Text('Lỗi: $e')` + nút thử lại |
| `LoadingSkeleton` | `({width, height, radius})` + `SkeletonList` | shimmer tự viết bằng AnimationController (không thêm package) |
| `SectionHeader` | `({title, trailing?, amount?})` | Thay Row "Hôm nay · N items | 123.000đ" |
| `AppBottomSheet` | `show({context, builder, title})` | Handle bar + radius 24 + padding keyboard chuẩn |
| `ConfirmDialog` | `show({context, title, message, confirmLabel, destructive = false})` | Thay 3 AlertDialog copy-paste (xóa item, đăng xuất, duplicate) — **giữ nguyên label "Huỷ"/"Xóa"/"Xóa vật phẩm?"** |
| `AppSnackBar` | `show({context, message, tone, floating = true})` | Thay ~8 chỗ `ScaffoldMessenger…showSnackBar` style lặp |
| `AppBottomNav` | `({currentIndex, onTap})` | Restyle `BottomAppBar` notched (mục 3.4), tách khỏi `main_shell` |

Snippet 3 widget quan trọng nhất:

```dart
// lib/widgets/ui/app_card.dart
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  const AppCard({super.key, required this.child, this.onTap,
      this.padding = const EdgeInsets.all(AppSpacing.lg),
      this.radius = AppRadius.lg});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: context.cs.surface,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: context.snap.hairline), // hairline thay elevation
            boxShadow: dark ? AppShadows.cardDark : AppShadows.card,
          ),
          child: child,
        ),
      ),
    );
  }
}
```

```dart
// lib/widgets/ui/primary_button.dart
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.md))),
      ),
      child: loading
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : Text(label),
    );
  }
}
```

```dart
// lib/widgets/ui/empty_state.dart
class EmptyState extends StatelessWidget {
  final IconData icon; final String title; final String? message;
  final String? actionLabel; final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title,
      this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 56, color: context.snap.tintPrimary == context.cs.surface
          ? context.cs.outline : context.cs.primary.withOpacity(.35)),
      const SizedBox(height: AppSpacing.lg),
      Text(title, style: context.text.titleMedium),
      if (message != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(message!, style: context.text.bodySmall, textAlign: TextAlign.center),
      ],
      if (actionLabel != null) ...[
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(label: actionLabel!, onPressed: onAction),
      ],
    ]),
  );
}
```

Quy mô: **18 widget**, mỗi widget kèm 1 file test nhẹ (pump light + dark). Không thêm package nào mới (shimmer tự viết ~40 dòng; nếu sau này muốn mượt hơn mới cân nhắc `shimmer` pub).

---

## 3. Hướng phong cách thị giác — 3 phương án

| | A. "Friendly Ledger" (M3 gọn + brand tím) | B. Soft-UI rounded, whitespace nhiều | C. Dark-first fintech |
|---|---|---|---|
| Vibe | Sạch, có hệ thống, number-first | Dịu, "app lifestyle" | Đẹp ảnh, ngân hàng số |
| Rủi ro | Thấp (tiếp nối design-spec) | Soft shadow nặng máy, dễ bị "giả iOS" | Đổi máu toàn bộ; user VN dùng app ngoại hiệu ngoài trời nắng → dark-first khó đọc |
| Effort | Thấp–trung | Trung | Cao |

### KHUYÊN: Phương án A — "Friendly Ledger", chi tiết như sau

Lý do (đúng 3 ràng buộc của app): **(1)** đối tượng user Việt Nam dùng hàng ngày, quen M3 (Google Wallet, Zalo profile) — tonal surface + hairline đọc tự nhiên; **(2)** app dày đặc số tiền → cần contrast cao, tabular figures, hierarchy number-first thay vì decoration; **(3)** dùng 1 tay → mọi CTA nằm nửa dưới màn, touch target ≥ 48dp, bottom nav to. A cũng re-use 90% direction của `design-spec.md` (tím `#6C63FF`, Nunito, card phẳng) nên migration rẻ nhất.

Mô tả đến mức triển khai được:

- **Màu:** nền `#F7F8FC`, card trắng phẳng, 1 màu brand tím duy nhất cho interactive; success/warning/danger CHỈ dùng cho trạng thái budget và giá so sánh. Khắc phục hiện trạng "tím ở khắp mọi nơi".
- **Gradient hay phẳng:** **phẳng là mặc định** (elevation 0 + hairline + shadow bậc `card`). Gradient tím CHỈ dành cho 1 hero card duy nhất mỗi màn (budget card ở home, total card ở summary) → hierarchy rõ, không lạm dụng.
- **Độ bo góc:** card 16, hero card 20, input/quick-btn 12, chip 8, price tag pill. Bottom sheet top 24.
- **Kiểu card:** 3 loại chuẩn — (i) `AppCard` trắng hairline; (ii) HeroCard gradient tím `#6C63FF → #4B44CC` chữ trắng, glow nhẹ `glowPrimary`; (iii) ListTile-card cho item list (thumbnail 56 radius 12).
- **Bottom nav:** GIỮ pattern `BottomAppBar` + FAB giữa đã có (rất hợp 1 tay — FAB "thêm nhanh" đúng ngón cái), restyle: cao 64, nền surface, elevation 0 + hairline top + `floating` shadow, item selected có pill tint + label w600. KHÔNG chuyển sang FloatingNavigationBar trôi — nó che content và tăng complexity với lợi ích thẩm mỹ không đáng.
- **Hero number trên home:** Budget card thành HeroCard — label nhỏ "Ngân sách hôm nay", số lớn **"Còn lại 150.000đ"** (`displayLarge` 34/w800 trắng), progress bar mảnh 8px trắng-24 nền, % badge pill. Số tiền là nhân vật chính, đếm count-up khi vào màn (phase polish).
- **Icon:** bỏ emoji khỏi vị trí icon UI (giữ emoji cho category icon vì đó là dữ liệu user/server), dùng Material Symbols round đồng bộ.

---

## 4. Migration Plan theo phase (1 dev Flutter)

> Nguyên tắc xuyên suốt: mỗi phase kết thúc phải `flutter analyze` sạch + `flutter test` xanh + chạy được app; mỗi phase là 1 nhánh/commit riêng, không trộn.

### Phase 1 — Token layer (1 buổi, ~4–5h)
- Tạo `app_dimens.dart`, `app_shadows.dart`, `snap_colors.dart`, `app_typography.dart`; sửa `app_theme.dart` thành `buildAppTheme(Brightness)` (tạm chỉ wire light).
- **Không sửa screen nào.**
- Rủi ro test: GẦN ZERO — không widget nào bị đổi. Rủi ro kỹ thuật duy nhất: fallback `?? SnapColors.light()` trong extension (widget test pump bare MaterialApp) — bắt buộc viết ngay từ đầu.
- Verify: app chạy y hệt trước đó (so sánh screenshot).

### Phase 2 — Shared components (2–3 buổi)
- Build 18 widget ở mục 2 + test từng cái (light/dark pump).
- Thay thế nội bộ ở mức **an toàn nhất trước**: `AppSnackBar`, `ConfirmDialog`, `AppCard`, `EmptyState`, `LoadingSkeleton` vào home/summary (giữ nguyên chuỗi text + giữ `_SkeletonCard` cho đến khi test pass).
- Rủi ro test: `item_card_test` tap `find.byType(GestureDetector).first` — khi bọc ItemCard bằng InkWell, thứ tự GestureDetector trong tree đổi → **chưa đụng ItemCard ở phase này**; `ConfirmDialog` phải giữ label "Huỷ" đúng chữ.
- Verify: `flutter test` (142 xanh), home hoạt động, error state giờ có nút Retry.

### Phase 3 — Restyle từng screen (4–5 buổi), thứ tự ưu tiên
1. **Home + ItemCard + BudgetCard (1 buổi):** hero budget card, item card mới, EmptyState, SectionHeader. ⚠️ File test đụng trực tiếp: giữ `Dismissible`, giữ dialog "Xóa vật phẩm?"/"Huỷ", giữ icon placeholder `Icons.shopping_bag_outlined`, giữ text "🍔"/"Ăn uống"/format `25.000` — nếu buộc đổi structure (GestureDetector→InkWell) thì sửa test cùng commit và ghi rõ trong PR.
2. **Auth (0.5 buổi):** `AppTextField` + `PrimaryButton` + logo header mới; test không đụng → rủi ro thấp.
3. **Add item (1 buổi):** form dùng `AppTextField`, `_QuickBtn` → `QuickActionTile` (từ AppCard), category selector dùng `CategoryChip`. Rủi ro: logic suggest/classify KHÔNG đụng — chỉ đổi layout.
4. **Shell/BottomNav + FAB (0.5 buổi):** tách `AppBottomNav`.
5. **Summary + History + Price history (1 buổi):** giữ fl_chart, chỉ restyle card/legend/hero; thay `Colors.white` bằng `context.cs.surface` (tiền đề cho dark mode).
6. **Scan/OCR/AR + Budget settings (0.5–1 buổi):** overlay scan thêm dim/hairline; OCR result list dùng component. ⚠️ `ocr_result_list_test` yêu cầu giữ "Thêm item" và cấu trúc Container/Text.

### Phase 4 — Dark mode (1 buổi)
- Wire `darkTheme: buildAppTheme(Brightness.dark)` + `themeMode` qua 1 provider MỚI (`themeModeProvider`, SharedPreferences — thêm mới, không sửa provider cũ) + toggle trong settings sheet.
- Quét nốt chỗ hardcode: `Colors.white` trong summary/`_AddCategorySheet`/item card background → colorScheme.
- Rủi ro test: rất thấp (test mặc định light). Rủi ro thật: contrast — bắt buộc rà bằng máy thật cả 2 mode.

### Phase 5 — Polish (1–2 buổi)
- Micro-interactions theo design-spec: card slide-in khi thêm item, progress bar TweenAnimation (đã có), shake khi vượt budget, hero number count-up.
- Haptic nhẹ (`HapticFeedback.selectionClick`) cho chip/nav, medium cho lưu thành công.
- A11y pass: touch ≥ 48dp, contrast AA, `Semantics` cho số tiền hero.
- Rủi ro: animation làm widget test timeout (`pumpAndSettle`) — mọi animation phải tôn trọng `disableAnimations` / dùng duration ngắn, hoặc gate bằng `MediaQuery.disableAnimationsOf`.

**Tổng effort: ~9–12 buổi làm việc thực (~1.5–2 tuần lịch), có thể ship từng phase riêng biệt** — sau Phase 2 app đã "đổi da" đáng kể dù chưa restyle hết màn.

---

## 5. Kiểm tra nhanh test/ — những gì UI migration phải bảo toàn

Kết quả grep finder trong 4 file widget test (unit test không đụng UI):

| File test | Finder bị đụng | Ràng buộc khi redesign |
|-----------|----------------|------------------------|
| `test/widget/item_card_test.dart` (8 testWidgets) | `find.text('Cà phê')`, `textContaining('25.000')`, `'🍔'`, `'Ăn uống'`, `byType(GestureDetector).first` tap, `byIcon(Icons.shopping_bag_outlined)`, drag `byType(Dismissible)`, dialog `'Xóa vật phẩm?'` + `'Huỷ'` | Giữ Dismissible + confirm dialog + placeholder icon + category icon/name + CurrencyFormatter. Nếu thay GestureDetector bằng InkWell ngoài cùng → phải sửa test **cùng commit** |
| `test/widget/budget_progress_card_test.dart` (7) | `'Chưa đặt ngân sách'`, `'50%'`, `'0%'`, `textContaining('Còn lại: 0')`, `byType(LinearProgressIndicator)` + **kiểm tra màu** xanh/vàng/đỏ | Nếu hero-card hoá, vẫn phải render `LinearProgressIndicator` với màu semantic đúng ngưỡng 80%/100% và đủ text trên |
| `test/widget/ocr_result_list_test.dart` (5) | `'Thêm item'`, tên item, `byType(Container) findsWidgets`, tăng quantity `'1'`→`'2'` | Giữ nút "Thêm item" và row editable |
| `test/widget/price_sticker_widget_test.dart` (4) | `'25.000đ'`, `byType(Transform)`, `byIcon(Icons.local_offer_rounded)` | AR sticker gần như để nguyên (nó là artwork) |
| `test/widget_test.dart` (1) | `byType(MaterialApp)` | Không ảnh hưởng |

Khuyến nghị giảm rủi ro: (1) thêm `Key('…')` cho control mới thay vì dựa finder kiểu type; (2) chạy `flutter test --test-randomize-ordering-seed=random` sau phase 2; (3) mọi thay đổi break finder phải kèm sửa test trong cùng PR, không để "sửa test sau".

---

## 6. Phụ lục — thứ tự làm việc ngay sau cuộc họp

1. Duyệt memo, chốt phương án A + bảng token (đặc biệt: giữ tím `#6C63FF` hay đổi seed).
2. Phase 1 (tokens) — không cần chờ design mới, xuất phát từ design-spec.md.
3. Chốt hero card home bằng 1 mock đơn giản (Figma hoặc even ASCII) trước Phase 3.1.
4. Sau mỗi phase: `flutter analyze && flutter test`, đính kèm 2 screenshot (trước/sau) vào thư mục meetings này.
