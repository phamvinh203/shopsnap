# UI Refresh Proposal — "INK LEDGER" (Sổ mực & bút dạ)

**Người viết:** Designer
**Ngày:** 2026-09-14
**Phạm vi:** CHỈ tầng theme + `lib/widgets/ui/` + layout screen. KHÔNG đụng providers / DAOs / ApiClient / router logic. KHÔNG thêm package mới.
**Input đã đọc:** 6 file `lib/core/theme/*`, 18 widget `lib/widgets/ui/*`, `home_screen.dart`, `main_shell.dart`, `login_screen.dart`, `summary_screen.dart`, `budget_progress_card.dart`, `item_card.dart`, `scan_screen.dart`, `ocr_result_list.dart`, `price_sticker_widget.dart`, memo redesign cũ (`2026-09-14-ui-ux-redesign/02-fe-redesign-proposal.md`), `shopsnap/design-spec.md`.

---

## RÀNG BUỘC CỨNG (FE đọc mục này trước khi code)

1. **Không thêm package nào.** `google_fonts ^6.2.1` + `fl_chart` đã có — đủ dùng.
2. **Không đụng** providers, DAOs, `ApiClient`, router logic. Chỉ sửa giá trị/bên trong: `lib/core/theme/*` (6 file), `lib/widgets/ui/*` (18 widget), layout của screen.
3. **Giữ nguyên kiến trúc token:** `buildAppTheme(Brightness)` giữ signature; `SnapColors` vẫn là ThemeExtension wire vào `ThemeData` với fallback `?? SnapColors.light` ở `context.snap`. **Đổi GIÁ TRỊ token, không xoá field cũ** — được phép THÊM field mới (proposal này thêm đúng 2 field: `accent`, `onAccent`).
4. **Number-first là yêu cầu cứng:** mọi số tiền đi qua `AppTypography.moneyOf(...)` với `FontFeature.tabularFigures()` — giữ nguyên signature, chỉ đổi font bên trong. `CurrencyFormatter` KHÔNG đổi (format `25.000đ` là nguồn sự thật).
5. **Dark mode vẫn toggle được** qua `themeModeProvider` + SegmentedButton trong sheet Cài đặt (MainShell) — không đổi logic, chỉ restyle.
6. **Các chuỗi/finder bị widget test khoá** — xem bảng ở mục 5. Quy tắc: nếu buộc phải break finder nào thì phải sửa test CÙNG commit và ghi trong PR. Theo spec này, **0 item bắt buộc sửa test**.

---

## 0. Chẩn đoán — vì sao rời "Friendly Ledger"

Đợt redesign sáng nay đã dựng xong phần "xương" (token layer + 18 shared widgets + dark mode) — đây là điều kiện lý tưởng để **đổi da bằng cách chỉ đổi giá trị token**, gần như không đụng logic. Về thẩm mỹ, "Friendly Ledger" an toàn đến mức trung tính: tím pastel `#6C63FF` + Nunito bo tròn + card trắng hairline là combo "starter template" thấy ở mọi app M3; app là **sổ ghi chép tiền** nhưng ngôn ngữ hình ảnh hiện tại lại là "app mạng xã hội dịu dàng" — số tiền không được đối xử xứng đáng. App dùng nhiều lần mỗi ngày, dày đặc số liệu, cần một chất liệu thị giác khiến con số là nhân vật chính và bề mặt app có "chất liệu vật" (giấy, mực) thay vì kính mờ pastel. Lý do khác biệt: đổi hue brand (tím → xanh/info tự nhiên), đổi chất liệu nền (trắng lạnh → giấy kem ấm), đổi ngôn ngữ card (hộp bo tròn bóng bẩy → mặt giấy phẳng, kẻ dòng, con dấu), đổi hệ chữ hoàn toàn (Nunito rounded → grotesque + serif editorial + số dạng mono-grotesque). Nhìn 3 giây là biết app khác.

---

## 1. Concept mới: **INK LEDGER — "sổ mực & bút dạ"**

### 1.1 Vibe

Một cuốn **sổ chi tiêu được dàn trang như tạp chí tài chính cá nhân**: giấy kem ấm, mực đen đậm, kẻ dòng sách vở, số tiền in lớn bằng font số kỹ thuật, và **bút dạ quang (highlighter) lime** quét ngang phần đang chọn. hierarchy bằng trọng lượng mực (ink weight) và kẻ dòng (rules) — KHÔNG bằng bóng đổ. Ẩn dụ: user đang "viết sổ" chứ không "lướt feed".

- **Light mode = buổi sáng trên giấy:** nền kem `#F6F3EA`, card là giấy trắng ấm, chữ mực đen, tương phản rất cao → đọc tốt ngoài trời nắng (điều kiện thực tế của user VN — đúng lý do memo cũ loại dark-first).
- **Dark mode = bảng đen dưới đèn:** nền xanh-đen `#141812`, chữ phấn kem, brand chuyển sang mint sáng. Panel hero (mực đen ở light) thành "mực trên bảng đen" ở dark.
- **Màu brand = xanh pine đậm** (liên tưởng tiền/tự nhiên) — ĐẶC BIỆT: không còn tím; success/warning/danger tách bạch rõ (success xanh tươi hơn, danger đỏ gạch ấm).
- **Chữ:** tiêu đề serif **Fraunces** (chất editorial, hơi "wonky"), thân = **Be Vietnam Pro** (grotesque thiết kế cho tiếng Việt), **số tiền = Space Grotesk** (grotesque mộc ra từ Space Mono — số thẳng cột tự nhiên, chất "máy tính sổ sách").

### 1.2 Phương án đã cân nhắc

| | **A. Ink Ledger** (editorial paper/ink) | B. Midnight Terminal (dark-first fintech, neon trên near-black) | C. Receipt Brutalism (neo-brutalist hoá đơn: mono toàn bộ, border 2px, shadow cứng offset) |
|---|---|---|---|
| Khác biệt với Friendly Ledger | Rất cao (hue + chất liệu + font + ngôn ngữ card đổi toàn bộ) | Cao | Rất cao, "nhìn là biết" nhất |
| Hợp app số tiền VN dùng daily | Cao: tương phản sáng, đọc nắng tốt, số là nhân vật | Thấp–trung: memo 2026-09-14 **đã loại dark-first** vì dùng ngoài trời; số dày đặc trên nền tối mỏi mắt | Trung: ấn tượng mạnh nhưng gimmick dần, border/shadow cứng khắp nơi gây ồn với tool app |
| Dark mode | Dễ (bảng đen tự nhiên) | Là mặc định (light mode sẽ thành "bản dịch") | Khó làm tinh tế |
| Chi phí triển khai trên kiến trúc hiện tại | **Thấp** (đổi token + restyle widget, không đổi API) | Trung | Trung–cao (nhiều widget cần structural decoration mới) |

**CHỌN A — Ink Ledger.** Lý do: bold mà không mời gọi phiền toái; number-first đúng bản chất; light-first hợp user VN; và kiến trúc token sẵn có cho phép "đổi da" rẻ — đúng như dự tính của memo redesign sáng nay.

---

## 2. Token mới (giá trị cụ thể)

### 2.1 Palette — `AppColors` (brand hex, cập nhật GIÁ TRỊ các field hiện có, không thêm field mới ở đây)

| Field (giữ tên) | Light (cũ → mới) | Dark (cũ → mới) | Ghi chú |
|---|---|---|---|
| `primary` | `#6C63FF` → **`#175E48`** (xanh pine) | `#8B85FF` → **`#8FE3BE`** (mint sáng) | links, icon interactive, selected state |
| `primaryDark` (pressed) | `#4B44CC` → **`#0E4635`** | `#544CE0` → **`#5FC79B`** | pressed/ripple |
| `primaryLight` | `#EEF0FF` → **`#DDEBE3`** (tint pine nhạt) | `#EEF0FF` → **`#1E3A2D`** (deep pine tint) | container tint |
| `accent` | `#FF6584` → **`#CDF163`** (bút dạ lime) | → **`#C7EE5E`** | highlighter: selection, badge nhấn |
| `success` | `#00C48C` → **`#1E8E5A`** | `#2ADBA5` → **`#4CC98B`** | budget OK, sync xong |
| `warning` | `#FFAB2D` → **`#C2801A`** (ochre) | → **`#E0A33E`** | budget ≥ 80% |
| `danger` | `#FF4D4D` → **`#C0402E`** (đỏ gạch) | → **`#E86A57`** | vượt budget, xoá |
| `bgMain` | `#F7F8FC` → **`#F6F3EA`** (giấy kem) | `#12121E` → **`#141812`** (bảng đen xanh) | scaffold |
| `bgCard` | `#FFFFFF` → **`#FFFDF6`** (giấy in) | `#1C1C2C` → **`#1C221B`** | surface |
| `textPrimary` | `#1A1A2E` → **`#1C1B17`** (mực đen ấm) | `#F2F2F7` → **`#F2EFE3`** (phấn kem) | |
| `textSecondary` | `#6B7280` → **`#6E6A5E`** (bút chì) | `#A5ADBB` → **`#A8A496`** | |
| `divider` | `#E5E7EB` → **`#DDD6C6`** (kẻ dòng giấy) | → **`#343B2F`** | rule/hairline |

Contrast đã check: ink/cream ~13:1; textSecondary trên bg ~4.6:1 (light) và ~5.5:1 (dark) — đạt AA cho text 12sp+; `primary` trên kem ~7:1; ink trên lime ~11:1.

### 2.2 Palette — `SnapColors` (đổi giá trị light/dark constants + THÊM 2 field)

Giữ nguyên 10 field hiện có (đổi hex theo bảng 2.1, map như sau) và **thêm 2 field mới** `accent`, `onAccent` (cập nhật `copyWith`/`lerp`/constructor tương ứng — không xoá gì):

| Token | Light | Dark |
|---|---|---|
| `tintPrimary` | `#DDEBE3` | `#1E3A2D` |
| `onTintPrimary` | `#0E4635` | `#8FE3BE` |
| `accent` (MỚI) | `#CDF163` | `#C7EE5E` |
| `onAccent` (MỚI) | `#1C1B17` | `#161A12` |
| `success` / `successDim` | `#1E8E5A` / `0x1F1E8E5A` | `#4CC98B` / `0x1F4CC98B` |
| `warning` | `#C2801A` | `#E0A33E` |
| `danger` | `#C0402E` | `#E86A57` |
| `hairline` | `#DDD6C6` | `#343B2F` |
| `skeleton` | `#E7E1D2` | `#2A3126` |
| `textPrimary` / `textSecondary` | `#1C1B17` / `#6E6A5E` | `#F2EFE3` / `#A8A496` |

Giữ nguyên `colorFor(BudgetLevel)` + `budgetLevelFromRatio` (ngưỡng 80%/100%) — test assert logic-so-sánh-`context.snap`, không assert hex, nên đổi hex không vỡ test.

### 2.3 `surfaceVariant` + ColorScheme trong `buildAppTheme`

- `surfaceVariant` (fill tonal, picker, chips nền): light `#EFE9DC` / dark `#252C23`.
- `onSurface` = textPrimary, `onSurfaceVariant` = textSecondary, `outline` = hairline, `error` = danger (đổi hex, giữ mapping).
- `onPrimary`: light = **`#F6F3EA`** (kem trên pine), dark = **`#0F2A20`** (pine đậm trên mint) — dùng cho pie chart title trên slice màu và nút nền brand.
- Seed vẫn `primary` (giữ `ColorScheme.fromSeed` như hiện tại) — M3 tự sinh container hợp lệ với hue mới.

### 2.4 Typography — `AppTypography` (đổi font, giữ kiến thức hàm)

**3 font, tất cả đã confirm support subset tiếng Việt trên Google Fonts:** [Fraunces](https://fonts.google.com/specimen/Fraunces) (Vietnamese ✓), [Be Vietnam Pro](https://fonts.google.com/specimen/Be+Vietnam+Pro) (thiết kế cho tiếng Việt), [Space Grotesk](https://fonts.google.com/specimen/Space+Grotesk) (Vietnamese ✓ — có chứa ký tự `đ` cần cho `25.000đ`).

| Role | Font | Size / Weight | Ghi chú |
|---|---|---|---|
| `displayLarge` | Fraunces | 32 / w700 | statement lớn, letterSpacing −0.5 |
| `displaySmall` | Fraunces | 26 / w700 | |
| `headlineMedium` | Fraunces | 22 / w700 | tiêu đề màn ("Xin chào!", "Tổng kết chi tiêu") |
| `titleLarge` | Fraunces | 18 / w600 | appbar title |
| `titleMedium` | Be Vietnam Pro | 16 / w600 | tên item |
| `titleSmall` | Be Vietnam Pro | 14 / w600 | section phụ |
| `bodyMedium` | Be Vietnam Pro | 14 / w400 | nội dung |
| `bodySmall` | Be Vietnam Pro | 12 / w400, ls 0.1 | caption, thời gian |
| `labelLarge` | Be Vietnam Pro | 14 / w600, ls 0.2 | button |
| `labelSmall` | Be Vietnam Pro | 11 / w500 | nav, overline (uppercase do widget tự `toUpperCase` khi cần) |
| **`moneyOf`** | **Space Grotesk** | default 15 / w700, `FontFeature.tabularFigures()` | GIỮ NGUYÊN signature `moneyOf(TextTheme t, {double size, Color? color})`; bên trong dùng `GoogleFonts.spaceGrotesk(...)`. Mọi số tiền, %, số lượng đi qua đây |

Implement: `buildTextTheme` dùng `GoogleFonts.beVietnamProTextTheme(base)` rồi `copyWith` các role Fraunces (`GoogleFonts.fraunces(...)`); color onSurface/onSurfaceVariant giữ cơ chế brightness hiện có. Viết helper `AppTypography.overlineOf(TextTheme t, {Color? color})` (MỚI, optional): 11/w700, letterSpacing 1.2, uppercase — cho kicker/section label.

### 2.5 Radius — `AppRadius` (sắc hơn, "kẻ dòng sách vở" thay vì "kẹo dẻo")

| Field (giữ tên) | Cũ → Mới | Dùng cho |
|---|---|---|
| `sm` | 8 → **6** | chip, badge, con dấu (PriceTag), skeleton nhỏ |
| `md` | 12 → **10** | input, dialog nhỏ, nút phụ |
| `lg` | 16 → **14** | AppCard, item card, button chính, FAB |
| `xl` | 20 → **16** | hero card, sheet content |
| `sheet` | 24 → **20** | top radius bottom sheet |
| `pill` | 999 → **999** (giữ) | progress bar, nav pill |

### 2.6 Shadow philosophy — "in phẳng" (print flat)

**Không còn soft elevation.** Hierarchy = độ đậm mực + kẻ dòng + chênh tone giấy. Shadow chỉ còn kiểu **offset cứng không blur** cho phần tử nổi (giống giấy chồng nhau lệch 2px). Giữ tên field, đổi giá trị:

| Field | Giá trị mới | Dùng cho |
|---|---|---|
| `card` / `cardDark` | `[]` (rỗng) | AppCard: 0 shadow, chỉ hairline |
| `floating` (light) | `[BoxShadow(Color(0x291C1B17), blurRadius: 0, offset: Offset(0, 2))]` | FAB, bottom nav, snackbar |
| `floatingDark` | `[]` (dark phân tách bằng border, không shadow) | |
| `modal` / `modalDark` | giữ cơ chế cũ: light `[BoxShadow(Color(0x40000000), 24, Offset(0,-4))]` / dark `[BoxShadow(Color(0x99000000), 28, Offset(0,-4))]` | sheet/dialog scrim |
| `glowPrimary` | `[]` (không còn glow tím) | field giữ lại cho tương thích import |

### 2.7 Motion / micro-interaction

Durations giữ `AppDurations` (fast 150 / medium 300 / slow 600), không thêm token. 4 interaction chính:

1. **Highlighter swipe (signature):** selected state (chip, nav item, segment) — nền lime quét vào từ trái sang phải ~220ms `Curves.easeOutCubic` (implement bằng `AnimatedContainer` + `Align(widthFactor)` hoặc `TweenAnimationBuilder`; tương đương 250ms là được, không cần chính xác).
2. **Press = mực đậm xuống:** widget có onTap hạ độ sáng nền ~6% + dịch xuống 0.5dp, KHÔNG scale bounce (chất in ấn, không chất game).
3. **Progress bar** giữ `TweenAnimationBuilder` easeOut slow hiện có — không đổi logic.
4. **Số tiền thay đổi** (hero khi sửa/xoá item): `AnimatedSwitcher` fade + slide-up 4dp, 200ms. Tất cả animation phải tôn trọng `MediaQuery.disableAnimationsOf` (pattern có sẵn ở `LoadingSkeleton`).

---

## 3. Component-level changes (`lib/widgets/ui/`)

> API/key/chuỗi giữ nguyên 100% trừ nơi ghi rõ. Mọi màu qua `context.snap`/`context.cs` — hết thời đại hardcode.

### 3.1 AppCard — "tờ giấy kẻ dòng"

- `color: surface` (`#FFFDF6`/`#1C221B`), `radius: AppRadius.lg (14)`, border hairline 1px (giữ), **`boxShadow: []`** cả 2 mode.
- Padding mặc định giữ `AppSpacing.lg`. Thêm 1 optional param `topRule = false` (MỚI, không bắt buộc gọi): khi true vẽ rule ngang đỉnh 3dp màu `textPrimary` — dự phòng cho card section; không dùng cũng không sao.

### 3.2 Buttons — "mực in" là CTA

- **PrimaryButton:** bg = **mực** — light `#1C1B17` / dark `#F2EFE3` (in ngược), chữ màu đối ứng (kem/ink), radius `md (10)`, cao 52 (giữ). Icon 18 (giữ). Loading spinner giữ key `primaryButton_loading`, màu `onSurface` thay `onPrimary`. Nút đen chữ kem trên nền giấy là image đặc trưng nhất của concept.
- **SecondaryButton:** bg = **`accent` (lime)**, chữ `onAccent` (ink) — "quét bút dạ". Variant `danger`: bg `danger` @ 12%, chữ `danger` (cơ chế cũ giữ, chỉ đổi hex).
- **GhostButton:** TextButton chữ `textPrimary`, **có gạch chân** (`TextDecoration.underline`, thickness 1.5, offset 3) — chất editorial. Key giữ.

### 3.3 AppTextField — "ruled line" (chỉ gạch chân, bỏ hộp)

- `inputDecorationTheme` mới: `filled: false` (hoặc fill transparent), **`UnderlineInputBorder`** `borderRadius: BorderRadius.circular(2)`:
  - enabled border: hairline, width 1.2;
  - focused border: `textPrimary`, width 2;
  - error: `danger`, width 1.5 + errorStyle bodySmall danger.
- Label: floating, `labelSmall` hoa + letterSpacing 0.8; hint: textSecondary @ 70%. prefixIcon 20, màu textSecondary. contentPadding: `vertical: 12` (giữ logic 'loginScreen_emailField'/'loginScreen_passwordField' — chỉ là key, không đổi).
- Filled variants (surfaceVariant `#EFE9DC`) vẫn dùng được ở đâu cần khối nền (quick-amount box add_item) — inputDecorationTheme chuyển sang underline, chỗ nào muốn hộp sẽ set local `filled: true, fillColor: surfaceVariant`.

### 3.4 CategoryChip — bút dạ quét

- radius `sm (6)`. Unselected: transparent + border hairline, chữ textSecondary 13/w500. Selected: **không border, bg `accent` lime, chữ `onAccent` w600**.
- Badge "Gợi ý": đổi thành **pill nền ink, chữ kem** (`textPrimary`/`onSurface`) 10/w700 — con dấu. Key `categoryChip_suggestedBadge` + chuỗi "Gợi ý" giữ nguyên.

### 3.5 PriceTag — pill → "con dấu" (stamp)

- Bỏ pill: `borderRadius: BorderRadius.circular(AppRadius.sm)` + `border: Border.all(color: tone, width: 1.2)` + bg tone @ 8% (hoặc transparent).
- Mapping tone (đổi bên trong widget, enum giữ): `PriceTone.primary` → **`textPrimary` (mực)** thay vì `cs.primary` (giá mặc định là mực đen — tránh xung đột thị giác với success xanh); `success` → success; `danger` → danger.
- Text: `moneyOf(..., size: 13)` (Space Grotesk w700 tabular). Key `priceTag` + `CurrencyFormatter` giữ nguyên.

### 3.6 BudgetProgressBar / BudgetProgressCard — hero "thỏi mực"

- **BudgetProgressBar** (dùng trong item row/section): giữ key, chuỗi "Đã dùng: …"/"Còn lại: …"/"Chưa đặt ngân sách", `LinearProgressIndicator` + `colorFor(budgetLevelFromRatio)` 100%. Restyle: track = `hairline` đặc (thay tint 12%), bar cao 8 (compact) / 10 (full), %badge = stamp vuông radius 6, nền tone 12%, chữ `moneyOf` 13.
- **BudgetProgressCard (hero home):**
  - Light: bg **ink `#1C1B17`** (thỏi mực in trên giấy), radius `xl (16)`, KHÔNG gradient, KHÔNG glow. Chữ: "Ngân sách hôm nay" = labelSmall hoa kem @ 70%; hero number "Còn lại: …" = `moneyOf(size: 34, color: kem) w800` (chuỗi + key `budgetProgressCard_remaining` giữ Y NGUYÊN); "Đã dùng:" kem @ 70%.
  - Dark: bg `#0E120D` (đen hơn surface) + border hairline 1px — "mực trên bảng đen".
  - % badge trên hero: nền **lime `accent`**, chữ ink — điểm nhấn highlighter duy nhất của màn.
  - `LinearProgressIndicator` (key `budgetProgressCard_indicator`) vẫn màu semantic trên track kem @ 18% (light) / hairline (dark).

### 3.7 AppBottomNav + FAB — kẻ dòng đậm + dấu sao

- Nav: nền `surface`, **top rule 1.2px**: light = `textPrimary` (đường kẻ mực đậm — signature), dark = hairline. Bỏ `floating` shadow ở dark (border thay).
- Item: icon 22 + label `labelSmall` 11. Selected: pill radius `pill`, **nền lime, chữ/icon ink w600** (highlighter swipe). Unselected: textSecondary.
- Keys `appBottomNav`, `appBottomNav_item_$index` giữ nguyên.
- **FAB** (MainShell không đổi code, chỉ đổi `floatingActionButtonTheme`): shape **rounded-square radius 14**, bg ink (dark: kem), icon **lime** (dark: ink), elevation 0 + `AppShadows.floating` (offset cứng). `notchMargin` tăng 8→10 trong `AppBottomNav` để notch ôm FAB vuông; nếu notch xấu trên máy thật thì trả `CircleBorder` (visual-only, an toàn test).

### 3.8 EmptyState / ErrorState / LoadingSkeleton

- **EmptyState:** vòng tròn viền hairline **đứt nét** (CustomPaint ~20 dòng hoặc DashPathModifier tự viết — không thêm package; fallback: viền liền hairline 1.2), icon ink @ 40%. Title chuyển **Fraunces italic w600 16** (giọng tạp chí). Keys `emptyState*` giữ.
- **ErrorState:** cùng ngôn ngữ, icon danger, nút "Thử lại" = PrimaryButton ink. Keys giữ.
- **LoadingSkeleton:** tự đổi màu theo token mới (kem `#E7E1D2` shimmer lên surface) — code không đổi, chỉ hex.

### 3.9 AppSnackBar — toast mực + thanh tone

- Bỏ nền màu; **nền ink** (light `#1C1B17`, dark `#F2EFE3` với chữ ink — in ngược), radius `sm (6)`, margin 12 (giữ), floating (giữ).
- Tone = **rule dọc trái 3dp**: success → success, warning → warning, danger → danger, neutral → accent lime. Chữ/foreground: kem trên ink (light) / ink trên kem (dark). Keys `appSnackBar*` giữ.

### 3.10 Dialog / BottomSheet / SegmentedButton / AppBar (theme-level)

- **Dialog:** nền giấy, radius 14, title Fraunces 18/w700, content bodyMedium; nút confirm ink, "Huỷ" = GhostButton gạch chân (chuỗi giữ). 
- **BottomSheet:** radius top 20, handle 40×4 ink @ 20%, nền surface + **top rule hairline** thay shadow.
- **SegmentedButton** (period tabs, theme switcher): `segmentedButtonTheme` — selected bg = lime + fg ink w600, radius 6, border hairline; unselected fg textSecondary. (Summary dùng style local `ButtonStyle` — FE restyle chỗ đó theo cùng thông số; key không đổi.)
- **AppBar:** nền scaffold, title `titleLarge` (Fraunces 18/w600), `scrolledUnderElevation: 0` (giữ), thêm `bottom: PreferredSize` border hairline khi scroll là không cần thiết — giữ đơn giản.
- **Divider**: hairline (hex mới tự áp dụng).

### 3.11 MoneyText / SectionHeader — số là nhân vật

- **MoneyText:** font mới tự áp qua `moneyOf`; **đổi mapping `colored`**: `true` → `cs.onSurface` (mực) thay vì `cs.primary` — tổng tiền = mực đậm, không tô xanh (tránh success/primary lẫn lộn). Key `moneyText_text` giữ.
- **SectionHeader:** title = `overlineOf` (11/w700, ls 1.2, uppercase — "HÔM NAY · 5 MẶT HÀNG"), amount = `moneyOf(size: 14)` mực. Keys giữ.

---

## 4. Screen-by-screen highlights

### 4.1 Home (`home_screen.dart` + `budget_progress_card.dart`, `item_card.dart`)
- Header "Xin chào! 👋" → Fraunces 22 (chuỗi giữ), ngày tháng = overline nhỏ; sync icon giữ logic màu success/warning (hex mới).
- Hero budget card = **thỏi mực đen** (3.6) — khối đen duy nhất giữa trang giấy, số "Còn lại" 34 kem + badge % lime.
- Item list: item card giữ Dismissible/GestureDetector/56dp thumbnail; thumbnail placeholder nền `tintPrimary` → viền hairline + icon ink @ 40% (**giữ `Icons.shopping_bag_outlined`**); tên w600, category = emoji + tên (dữ liệu giữ), **giá bên phải = PriceTag stamp mực**.
- Category chips row: chip chọn = lime swipe (3.4).
- Update banner: tint `tintPrimary` mới (pale pine) — không cần đổi code.
- Empty state: Fraunces italic + CTA ink.

### 4.2 Shell/Nav (`main_shell.dart`, `app_bottom_nav.dart`)
- Kẻ mực 1.2px trên nav + pill lime selected; FAB vuông-bo mực với icon lime camera.
- Login banner: nền `tintPrimary` pale pine, chữ `onTintPrimary` — restyle tự động theo token; nút "Đăng nhập" gạch chân.
- Sheet Cài đặt: giấy kẻ dòng + handle mới; SegmentedButton "Hệ thống/Sáng/Tối" = lime selected (keys + chuỗi giữ nguyên).

### 4.3 Auth (`login_screen.dart`, `register_screen.dart`)
- `_AuthHeader`: khối 72dp `tintPrimary` → **logo chữ "ShopSnap" Fraunces w700** với gạch chân mực 3dp + quẹt lime sau chữ "Snap"; icon giỏ chuyển thành stamp vuông hairline.
- Input = ruled line (3.3) — trang auth như tờ phiếu đăng ký; nút "Đăng nhập" = khối mực.
- "Dùng app trước, đăng nhập sau" = Ghost gạch chân (key giữ).

### 4.4 Summary (`summary_screen.dart`)
- Hero tổng chi tiêu: cùng ngôn ngữ thỏi mực (light) / bảng đen (dark) — thay gradient tím, số 28 Space Grotesk kem, trend icon kem @ 70% (chuỗi "+X% so với kỳ trước" giữ).
- Pie chart trong AppCard giấy; legend đổi tiền sang `moneyOf`; slice màu lấy `categoryColor` server (giữ logic fallback `cs.primary`).
- Date nav + period tabs: overline + segmented lime; xuất CSV icon = ink.
- Insights: icon severity trên nền tone 12% radius 6 (stamp nhỏ), title w600.

### 4.5 Add item (`add_item_screen.dart`)
- Ô nhập giá = **khối surfaceVariant `#EFE9DC` radius 10** với số `moneyOf` 32 w700 canh phải — bàn phím số là sân khấu chính.
- Quick buttons = ruled tiles (AppCard padding sm, icon + label 12/w600), nhấn = press-ink effect.
- Category selector = CategoryChip lime; nút lưu = khối mực; suggest badge = con dấu ink.

### 4.6 Scan / OCR (`scan_screen.dart`, `ocr_result_list.dart`, AR sticker)
- Scan screen **đã nền đen — hợp sẵn concept**: giữ khung quét, thêm 4 góc lime 2dp (bracket) + chip hướng dẫn nền ink @ 60% chữ kem; nút nhập tay gạch chân kem.
- OCR result list: rows kẻ dòng (divider hairline), số lượng Space Grotesk; **nút "Thêm mặt hàng" giữ nguyên chuỗi + cấu trúc Container/Text mà test khoá** — chỉ restyle bg → ink / radius 6.
- **AR sticker (`price_sticker_widget`): KHÔNG đụng** — artwork giữ nguyên vẹn 100% (test khoá `'25.000đ'`, `Transform`, `Icons.local_offer_rounded`).

---

## 5. Bảng ràng buộc test cần bảo toàn

| # | Finder / ràng buộc (từ memo redesign) | Trạng thái trong proposal này |
|---|---|---|
| 1 | ItemCard: `'Cà phê'`, `'25.000'` (format), `'🍔'`, `'Ăn uống'`, placeholder `Icons.shopping_bag_outlined` | **GIỮ NGUYÊN** — chỉ restyle decoration (3.5, 4.1); tên/category/format không đụng |
| 2 | ItemCard: `Dismissible` + dialog `'Xóa vật phẩm?'` + `'Huỷ'` | **GIỮ NGUYÊN** — cấm thay `GestureDetector` ngoài cùng bằng widget khác (nếu ai vi phạm → phải sửa test cùng commit, ghi rõ PR) |
| 3 | BudgetProgressCard: `'Chưa đặt ngân sách'`, `'50%'`, `'0%'`, `'Còn lại: 0'` | **GIỮ NGUYÊN** — chỉ đổi style, không đổi chuỗi/key (`budgetProgressCard_remaining`, `budgetProgressCard_percent`) |
| 4 | BudgetProgressCard vẫn render `LinearProgressIndicator` màu semantic theo ngưỡng 80%/100% | **GIỮ NGUYÊN** — `colorFor(budgetLevelFromRatio)` không đổi; chỉ hex của success/warning/danger đổi (test so logic với `context.snap`, không assert hex) |
| 5 | OCR list: nút `'Thêm mặt hàng'` + cấu trúc Container/Text | **GIỮ NGUYÊN chuỗi + key**; restyle bg/radius bên trong Container cho phép |
| 6 | AR sticker gần như nguyên vẹn (artwork) | **KHÔNG ĐỤNG** |
| 7 | `CurrencyFormatter` không đổi | **GIỮ NGUYÊN** |
| 8 | Dark mode toggle (`themeModeProvider` + SegmentedButton keys `shell_themeOption_*`) | **GIỮ NGUYÊN logic** — chỉ restyle segmented (3.10) |
| 9 | `ItemCard` GestureDetector ngoài cùng cho tap | **GIỮ NGUYÊN** (liên quan #2) |
| 10 | Keys: `priceTag`, `sectionHeader*`, `moneyText_text`, `emptyState*`, `errorState*`, `appSnackBar*`, `appBottomNav*`, `loginScreen_*`, `summaryScreen_*` | **GIỮ NGUYÊN toàn bộ** — mọi thay đổi 3.x/4.x đều key-neutral |

Kết luận: theo đúng spec này, **không có item nào bắt buộc sửa test**. Hai khu vực cần kỷ luật: (a) ItemCard không đổi widget ngoài cùng; (b) mọi restyle đi qua token/key, không sửa chuỗi.

---

## 6. Thứ tự triển khai cho FE (mỗi phase phải `flutter analyze` sạch + `flutter test` xanh)

> Risk thấp dần theo phase vì Phase 1 chỉ đổi giá trị — mọi test assert logic/keys/chuỗi, không assert hex.

### Phase 1 — Token swap (0.5–1 buổi, không đụng widget nào)
- `app_colors.dart`: thay 12 hex theo bảng 2.1. `snap_colors.dart`: đổi `light`/`dark` + **thêm `accent`, `onAccent`** (constructor/copyWith/lerp). `app_dimens.dart`: đổi radius 2.5. `app_shadows.dart`: đổi giá trị 2.6. `app_typography.dart`: đổi font (2.4) + `moneyOf` → Space Grotesk + thêm `overlineOf`. `app_theme.dart`: surfaceVariant/onPrimary/dialog/sheet/segmented + **inputDecorationTheme → underline** (3.3) + FAB theme (3.7).
- Verify: app chạy, mọi text/điểm nhấn còn nguyên, screenshot trước/sau cả 2 mode. Test: phải xanh 100% (không test nào assert hex).

### Phase 2 — Core widgets (1–1.5 buổi)
- Restyle bên trong: `app_button`, `app_card`, `app_text_field` (đã ở theme), `category_chip`, `price_tag`, `app_snack_bar`, `app_states`, `section_header`, `money_text` (mapping `colored` → onSurface), `confirm_dialog`, `app_bottom_sheet`, `loading_skeleton` (hex tự theo token), `app_bottom_nav` (+ notchMargin).
- Verify: `flutter test` (ItemCard/BudgetProgressCard/OCR/AR test phải xanh — chưa đụng screen).

### Phase 3 — Home + Shell (1 buổi)
- `budget_progress_card` (thỏi mực), `item_card` (restyle decoration, GIỮ GestureDetector/Dismissible/keys), `category_chips_row`, header home (Fraunces/overline), scan frame góc lime (nếu muốn gom chung cũng được nhưng an toàn để Phase 5).
- Verify: chạy app + test item_card + budget_progress_card.

### Phase 4 — Summary + Auth + Add item (1–1.5 buổi)
- Summary hero (bỏ gradient → ink panel), legend/insights/segmented style, auth header + ruled form, add_item amount block + quick tiles.
- Verify: `flutter test` + screenshot 2 mode từng màn.

### Phase 5 — Scan/OCR polish + motion + a11y (0.5–1 buổi)
- OCR row restyle (giữ "Thêm mặt hàng"), motion highlighter swipe + AnimatedSwitcher số (đều gate `disableAnimationsOf`), contrast pass AA cả 2 mode trên máy thật ngoài trời, chụp bộ screenshot trước/sau cho thư mục meeting.
- Verify: full `flutter test --test-randomize-ordering-seed=random`.

**Tổng: ~4–6 buổi.** Rủi ro chính: (1) SegmentedButton M3 đôi khi khó style selected-bg — fallback dùng `ButtonStyle` local như summary đang làm; (2) FAB vuông + notch — fallback `CircleBorder`; (3) `google_fonts` tải font lúc chạy đầu (Fraunces + Space Grotesk + Be Vietnam Pro là 3 family mới) — nếu app đang bundle font assets thì Phase 1 cần thêm 3 family vào bundle theo cơ chế hiện có; (4) Fraunces italic phát sinh file tải thêm — nếu muốn gọn, chỉ dùng Fraunces thường và bỏ italic EmptyState.

---

## 7. Điều NOT làm (tránh scope creep)

- Không đổi fl_chart config ngoài màu; không đổi icon set; không đổi emoji category (dữ liệu).
- Không thêm package, không đổi router, không đổi provider/DAO/ApiClient, không đổi `CurrencyFormatter`, không đổi AR sticker.
- Không xoá bất kỳ field token nào — chỉ đổi giá trị / thêm `accent`, `onAccent`, `topRule`, `overlineOf`.
