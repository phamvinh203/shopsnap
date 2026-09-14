# 03 — QA Regression Plan for UI Redesign

- **Ngày:** 2026-09-14
- **Tác giả:** QA Engineer
- **Phạm vi:** Kế hoạch đảm bảo redesign UI/UX ShopSnap (Flutter) không phá vỡ hệ thống test và logic đang xanh. Memo này KHÔNG kèm thay đổi code production.
- **Baseline đã verify bởi QA (chạy thật ngày 2026-09-14):**
  - `flutter test`: **182/182 pass (~35s)** — không phải 142/142 như báo cáo trước đó. Số liệu 142 đã stale; mọi mốc DoD dưới đây dùng 182 làm baseline. Cần confirm lại với chủ project con số nào là mốc chính thức.
  - `flutter analyze`: `lib/` sạch. Tuy nhiên **13 lint info** (`prefer_const_constructors`) trong `test/unit/sync_service_test.dart` — "analyze clean" chỉ đúng một phần (minor, không chặn redesign; AI test có thể dọn sau).

---

## 1. Inventory test hiện có

### 1.1. Cấu trúc thư mục `mobile/test/`

```
test/
├── widget_test.dart                      (1 test  — smoke boot app)
├── widget/   ← 4 file, 26 testWidgets    (ĐỤNG UI TRỰC TIẾP)
│   ├── item_card_test.dart               (6)
│   ├── budget_progress_card_test.dart    (8)
│   ├── ocr_result_list_test.dart         (6)
│   └── price_sticker_widget_test.dart    (5)
└── unit/     ← 16 file, 156 test         (THUẦN LOGIC — an toàn với redesign)
    ├── models: item, category, budget, ai_assistant, price_history (47)
    ├── services: sync, budget_api, item_api, summary_api, barcode_cache,
    │   barcode_contribute, category_classifier, ocr_parse, ocr_vision,
    │   update (109)
    └── utils: currency_formatter (15)
```

**Tổng: 182 case trong 21 file. UI-coupled chỉ chiếm 27/182 (~15%).**

### 1.2. Phân loại theo độ nhạy với redesign

| Nhóm | Test | Dự đoán khi redesign |
|---|---|---|
| **Thuần logic** (unit/ — mocktail, `MockClient` của http, `SharedPreferences.setMockInitialValues`) | 156 | **An toàn 100%** — không import screens/theme. Chỉ vỡ nếu redesign lấn sang models/DAOs/ApiClient (cấm theo phạm vi dự án). |
| **Smoke** (`widget_test.dart` — chỉ `expect(find.byType(MaterialApp), findsOneWidget)`) | 1 | Gần như bất tử; chỉ vỡ nếu đổi tên `ShopSnapApp` hoặc bỏ `ProviderScope`. |
| **Widget test theo key** | 0 | Không tồn tại — **0 lượt `find.byKey` trong toàn bộ test/`. Đây là lỗ hổng lớn nhất.** |
| **Widget test theo text/icon/type/style** | 26 | **Vulnerable — xem chi tiết 1.3.** |

### 1.3. Điểm yếu cụ thể của 26 widget test (bằng chứng từ file thật)

Thống kê finder trong `test/widget/`: **18 `find.text`, 5 `find.textContaining`, 3 `find.byIcon`, 8 `find.byType`, 5 assert style/màu cứng, 0 `find.byKey`.**

| File | Vụn khi... | Ví dụ dòng thật |
|---|---|---|
| `test/widget/item_card_test.dart` | Đổi label nút dialog, thay `Dismissible` bằng swipe component khác, thay `GestureDetector` bằng `InkWell`/component mới, đổi icon mặc định | `expect(find.text('Huỷ'), ...)` (dòng 83); `find.byType(GestureDetector).first` (49); `find.byType(Dismissible)` (68); `find.byIcon(Icons.shopping_bag_outlined)` (59); `find.text('Xóa vật phẩm?')` (70) |
| `test/widget/budget_progress_card_test.dart` | **Đổi design tokens** (3 test so màu cứng `AppColors.success/warning/danger`), hoặc thay `LinearProgressIndicator` bằng custom progress bar, đổi copy trạng thái | `expect(indicator.color, AppColors.success)` (40, 51, 62); `find.byType(LinearProgressIndicator)` (37); `find.text('Chưa đặt ngân sách')` (14); `find.textContaining('Còn lại: 0')` (78) |
| `test/widget/ocr_result_list_test.dart` | Đổi label nút thêm dòng, đổi icon xoá, restructure row | `find.text('Thêm item')` (29, 38); `find.byIcon(Icons.close).first` (49); `find.text('1')/'2'` (71-72) |
| `test/widget/price_sticker_widget_test.dart` | Đổi logic chọn màu chữ (2 test so style cứng), đổi icon tag, bỏ `Transform.scale` | `expect(text.style?.color, Colors.white)` (21); `expect(text.style?.color, Colors.black87)` (29); `find.byIcon(Icons.local_offer_rounded)` (44) |

### 1.4. Khoảng trống nghiêm trọng

**24 file trong `lib/screens/` (login, register, home, add_item, scan, ocr, budget_settings, summary, history, main_shell…) không có MỘT test nào.** Nghĩa là:
- Restyle screen sẽ gần như không làm vỡ test tự động — nghe có vẻ tốt nhưng thực tế là **không có lưới an toàn**: lỗi logic (mất `onTap`, sai route, mất empty state) sẽ không bị phát hiện.
- Chỉ 4 widget con (`ItemCard`, `BudgetProgressCard`, `OcrResultList`, `PriceStickerWidget`) được bảo vệ.
- Router (`app_router.dart` — redirect auth, shell route) cũng chưa có test.

---

## 2. Rủi ro cụ thể theo phase redesign

| Phase | Mức rủi ro vỡ test | Test sẽ vỡ | Giải thích + ví dụ |
|---|---|---|---|
| **P1 — Design tokens** (rebuild `app_colors.dart`, `app_theme.dart`, spacing/radius) | **CAO** | 5/26 widget test | `budget_progress_card_test` so màu trực tiếp với `AppColors.success/warning/danger` — đổi hex hoặc chuyển sang `ColorScheme`/semantic token là fail ngay 3 test (dòng 32–63). `price_sticker_widget_test` so `Colors.white`/`Colors.black87` — đổi contrast rule là fail 2 test (dòng 16–30). Nếu xoá/đổi tên constant `AppColors.*` được import nơi khác → compile error lan rộng. 156 unit test vẫn an toàn. |
| **P2 — Shared component library** (gói UI cũ vào component mới) | **CAO** | tới 26/26 widget test | Thay `GestureDetector` → `InkWell` làm `item_card_test` fail (`find.byType(GestureDetector).first`). Thay `LinearProgressIndicator` bằng custom bar làm cả 3 test màu + 5 test khác fail. Đổi icon delete `Icons.close` trong `OcrResultList` fail `ocr_result_list_test`. Đây là phase **bắt buộc phải run test trước–sau từng PR**. |
| **P3 — Restyle từng screen** (auth → home → …) | THẤP về test vỡ, **CAO về regression không được phát hiện** | ~0 test vỡ tự động | Không có screen test nên gần như không fail — nhưng cũng không có gì chặn việc vô tình xoá `onTap`, đổi route `context.push('/add')` trong `main_shell.dart`, mất `pumpAndSettle` state. Rủi ro thật: **hư logic mà CI vẫn xanh**. Bù bằng smoke navigation test (mục 7) + manual checklist (mục 5). |
| **P4 — Dark mode** (thêm `ThemeData` dark, `themeMode`) | TRUNG BÌNH | 5 test màu cứng + có thể thêm | Widget test wrap bằng `MaterialApp` mặc định light; nếu component resolve màu qua `Theme.of(context)` và mock không set theme → kết quả khác expectation. 3 test `AppColors.*` của BudgetProgressCard + 2 test style của PriceSticker là ứng viên fail đầu tiên. |
| **P5 — Polish** (animation, micro-interaction, rounded corner…) | THẤP về test, TRUNG BÌNH về flaky | ít | Animation mới có thể làm test cũ thiếu `pumpAndSettle` treo/timeout (flaky). Test nào bắt đầu flaky sau P5 phải xử lý ngay, không chấp nhận "chạy lại lại pass". |

**Nguyên tắc chung:** khi 1 test vỡ, dev KHÔNG được xoá/comment test cho pass. Test vỡ phải được xử lý theo một trong hai cách, ghi rõ trong PR: (a) behavior cố tình đổi → cập nhật expectation kèm lý do; (b) behavior không đổi → sửa component để giữ contract.

---

## 3. Quy ước bắt buộc cho code + test mới

### Cho production code (nhờ frontend-dev thực hiện)

1. **Mọi widget tương tác quan trọng phải có key const:** `key: const Key('login_submit_button')`. Convention đặt tên `<màn_hình>_<phần_tử>` snake_case. Danh sách tối thiểu: nút submit chính, text field chính, item row, empty state, error banner, loading indicator, bottom nav item, FAB, nút đóng sheet/dialog.
2. **Không đổi khi redesign (ngoài phạm vi):** route path (`/login`, `/add`, `/scan`…), tên provider Riverpod, signature `ApiClient`/DAO/model, format tiền `CurrencyFormatter` (25.000đ, 25k).
3. **Component mới nhận semantic input, không hard-code màu:** ví dụ `BudgetProgressBar` nhận enum `level { ok, warning, danger }` hoặc `progress` 0–1, màu map ở MỘT chỗ trong token layer — để test assert logic chứ không assert hex.
4. **Copy text (tiếng Việt) gom về một chỗ** (string constants hoặc l10n-lite) để đổi wording không phải rà 24 screen.

### Cho test (QA + dev cùng giữ)

5. **Test mới chỉ dùng `find.byKey`** cho widget có key; cấm test mới dùng `find.text` cho nút/label có khả năng đổi wording (text data như tên item, số tiền thì vẫn được).
6. **Cấm assert style cứng** (`style?.color == Colors.white`, `indicator.color == AppColors.x`) trong widget test. Nếu cần kiểm chứng token mapping (success/warning/danger), viết test riêng ở tầng token/theme, tách khỏi widget.
7. Widget test mới phải set theme tường minh khi render: `_wrap(child, theme: lightTheme)` và một bản dark khi component hỗ trợ dark mode — tránh phụ thuộc theme mặc định của `MaterialApp`.
8. Mọi widget test có animation/async phải `pumpAndSettle()` đúng chỗ; test flaky 2 lần liên tiếp → gắn tag và sửa ngay trong sprint đó.
9. Mỗi PR redesign: `flutter test` xanh + `flutter analyze` không tăng số lint mới, chạy trước khi merge; diff không được chạm `lib/providers/`, `lib/core/network/`, `lib/database/`, `lib/services/` (CI/review chặn).

---

## 4. Golden test — có đáng setup không?

**Kết luận: CÓ, nhưng phạm vi hẹp — chỉ cho shared component library (bắt đầu ở P2), KHÔNG golden cho 24 screen.**

Lý do phù hợp: app sắp đổi tokens hàng loạt; golden cho component là cách rẻ nhất phát hiện "đổi token làm vỡ hình dạng component" mà widget test thường không thấy.

Lý do KHÔNG golden toàn screen: 24 screen × light/dark × 2 device = ~96 ảnh phải regen mỗi lần chỉnh token → chi phí maintain vượt lợi ích; `google_fonts` (Nunito) fetch runtime làm pixel khác nhau giữa máy dev/CI → flaky cao; nhiều screen phụ thuộc camera/QR (scan) không deterministic trong test.

**Đề xuất cấu trúc:**

- Package: **`alchemist`** (ưu tiên — maintain tích cực, API hiện đại; phương án thay thế: `golden_toolkit`). Thêm `flutter_test` config để fail khi golden thiếu (`flutter test --update-goldens` chỉ để regen có chủ đích).
- Vị trí: `test/golden/<component>_golden_test.dart`, ảnh golden trong `test/golden/goldens/`.
- Ma trận mỗi component: light + dark × nhỏ (5" ~ 360×740) + lớn (6.7" ~ 412×915) = 4 ảnh/component, chỉ áp cho ~8–12 component đầu tiên của library (button, card, input, chip, progress bar, empty state, sticker, list row).
- Chống flaky font: `GoogleFonts.config.allowRuntimeFetching = false` trong test + override `textTheme` bằng font fallback deterministic khi render golden.
- Thời điểm: dựng khung golden ở **cuối P2**, sau khi component API ổn định; regen golden là bước bắt buộc trong mọi PR chỉnh token (P1/P4) từ đó trở đi.

---

## 5. Manual QA checklist sau khi restyle từng screen (tiếng Việt)

> Chạy trên: máy ảo/-device Android **nhỏ ~5"** (vd 360×740) và **lớn ~6.7"** (vd 412×915), mỗi loại × light/dark. Tick đủ 2 device × 2 theme cho mỗi mục.

### 5.1. Case bắt buộc chung (mọi screen)

1. **Empty state:** dữ liệu rỗng hiển thị đúng placeholder, không frame trắng/không crash.
2. **Loading:** có spinner/skeleton trong lúc gọi API; không nhấp nháy layout (layout shift) khi dữ liệu về.
3. **Error offline:** tắt mạng → thao tác tạo/sửa → hiện thông báo lỗi tiếng Việt dễ hiểu, không crash, có nút thử lại (nếu thiết kế có).
4. **Tiếng Việt dài bị overflow:** nhập tên dài (≥ 40 ký tự, có dấu, có khoảng trắng dài, không khoảng trắng: "Supercalifragilistic…") → không `overflow` (không sọc vàng đen), text xuống dòng hoặc ellipsis đúng.
5. **Số tiền dài:** giá 1.500.000đ / 12.000.000đ hiển thị đủ ở cỡ chữ lớn nhất (set font scale 1.3 trong Settings hệ điều hành).
6. **Dark mode:** mọi text còn đủ contrast; không còn vùng nền trắng sót (card, dialog, sheet, keyboard accessory); progress bar/icon đúng màu semantic.
7. **Màn hình nhỏ 5":** không cut nội dung quan trọng, nút chính vẫn chạm được (target ≥ 44dp), không cần cuộn ngang.
8. **Màn hình lớn 6.7":** layout không bị giãn xấu/trống trải bất thường; list không vỡ khoảng cách.
9. **Điều hướng:** forward/back (nút hệ thống + gesture) không kẹt, không mất state dữ liệu đã nhập khi quay lại.
10. **Trạng thái bàn phím:** focus field không che nút chính (keyboard inset), tap ngoài huỷ đúng.

### 5.2. Case riêng theo screen

- **auth (login/register):** validate email/sai mật khẩu hiện đúng lỗi; redirect sau login về `/`; register quay lại login giữ email; nút hiện/ẩn password còn hoạt động.
- **home:** pull-to-refresh; item vừa thêm xuất hiện đúng thứ tự; swipe-to-delete hiện dialog xác nhận; budget progress đổi màu đúng ngưỡng 0/80%/100% (kết hợp với test tự động).
- **add_item:** chọn ảnh từ gallery/camera; bỏ trống tên → vẫn chặn submit; chọn category hoạt động; hint so sánh giá không đè lên field.
- **scan:** cấp quyền camera bị từ chối → có hướng dẫn mở Settings; scan QR/barcode đổ đúng dữ liệu vào form; đóng scanner không giữ camera nền.
- **ocr:** chọn ảnh mờ → row cần review được đánh dấu; sửa giá inline lưu đúng; xoá row không xoá nhầm row khác.
- **ar_sticker:** sticker hiển thị đúng màu chữ theo nền sáng/tối; share/capture không cắt sticker.
- **budget_settings:** nhập số tiền 0 / âm / rất lớn; lưu rồi vào lại vẫn đúng giá trị.
- **summary:** biểu đồ (fl_chart) render đúng cả dark mode; tháng không dữ liệu không vỡ trục; AI assistant card xử lý lỗi API.
- **history:** đổi tháng; nhóm theo tháng đúng thứ tự; item dài không chồng chữ ngày.
- **shell/main_shell:** bottom nav highlight đúng tab; FAB mở `/add`; sheet Cài đặt: đăng xuất hiện confirm, hủy không đăng xuất.

---

## 6. Definition of Done cho toàn bộ redesign

Mỗi **PR** được coi là xong khi:
1. `flutter test` xanh toàn bộ (baseline 182/182, sau P2 sẽ nhiều hơn do golden + test component mới).
2. `flutter analyze`: không tăng số lint so với baseline (13 info hiện tại, chỉ nằm ở `test/unit/sync_service_test.dart`).
3. Diff KHÔNG chạm `lib/providers/`, `lib/core/network/`, `lib/database/`, `lib/services/`, `lib/models/` (nếu lỡ chạm phải có lý do ghi trong PR và QA review riêng).
4. Test cũ bị sửa/xoá phải có lý do behavior-change ghi rõ; cấm xoá test cho pass.

Toàn bộ **redesign** được coi là xong khi:
1. Baseline **182/182 test cũ vẫn xanh** (hoặc đã cập nhật có chủ đích, có lý do trong PR tương ứng).
2. **Component library 100% có test riêng**: widget test theo `find.byKey` + golden light/dark × 2 cỡ màn cho từng component public.
3. **Smoke navigation test mới** (trước P3) phủ: redirect chưa login → `/login`, login xong → `/`, bottom nav 3 tab, FAB → `/add`, settings sheet → `/budget`.
4. `flutter analyze` clean ở mức không lint mới (muốn đạt chuẩn: dọn luôn 13 lint cũ trong test).
5. **Manual checklist mục 5 đã tick đủ cho từng screen** (10 case chung + case riêng) trên 5" và 6.7", light và dark, do ít nhất 1 người khác dev của screen đó thực hiện; bug phát hiện được log và đóng (blocker/major = 0 còn mở).
6. Không còn test flaky: 3 lần chạy `flutter test` liên tiếp cùng kết quả.

---

## 7. Khoảng trống kiểm thử cần bổ sung (ưu tiên)

| Ưu tiên | Việc | Khi nào |
|---|---|---|
| P0 | Smoke navigation test cho router/auth redirect (`app_router.dart` hiện 0 test) — bảo vệ cho toàn bộ P3 | Trước khi bắt đầu redesign |
| P0 | Dọn 13 lint `prefer_const_constructors` trong `test/unit/sync_service_test.dart` để "analyze clean" thành mệnh đề đúng | Trước khi bắt đầu |
| P1 | Đổi 5 test assert màu/style cứng (`budget_progress_card`, `price_sticker`) sang assert qua contract/enum cấp component, để P1/P4 không phải dọn đống test màu | Cùng phase P1 |
| P1 | Thêm `Key('...')` cho widget tương tác chính của từng screen trước khi restyle screen đó (dev làm trong cùng PR restyle, QA kiểm tra bằng grep) | Theo từng screen ở P3 |
| P2 | Widget test cho component library mới + golden (mục 4) | Cuối P2 |
| P3 | Test state screen quan trọng bằng `ProviderScope` overrides (home: empty/list/error của `itemsProvider`, `budgetProvider`) — bổ sung dần cho screen traffic cao nhất trước (home, add_item, summary) | Song song P3 |

## Phụ lục — lệnh baseline

```bash
cd mobile
flutter test                 # 182/182 pass, ~35s (QA verify 2026-09-14)
flutter analyze              # 13 info (toàn bộ ở test/unit/sync_service_test.dart)
```
