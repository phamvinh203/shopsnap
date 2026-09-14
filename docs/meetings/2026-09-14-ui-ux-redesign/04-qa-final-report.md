# 04 — QA Final Report: Regression độc lập sau redesign P1→P4

- **Ngày:** 2026-09-14
- **Tác giả:** QA Engineer (vòng regression độc lập, CHỈ ĐỌC + viết test mới)
- **Phạm vi:** verify toàn bộ redesign (P1 tokens → P4 dark mode) KHÔNG sửa code production, KHÔNG sửa test có sẵn.
- **VERDICT: SHIP ĐƯỢC** — 0 BLOCKER, 0 MAJOR; 2 MINOR + 3 NIT cần theo dõi, không chặn release.

---

## 1. Kết quả chạy thật (QA tự chạy, không dựa số liệu của Leader)

| Lệnh | Lần 1 | Lần 2 | Lần 3 | Kết luận |
|---|---|---|---|---|
| `flutter test` | **291/291 pass** (~53s) | **291/291 pass** (~93s) | **291/291 pass** (~74s) | Xanh 3 lần liên tiếp → **không flaky** |
| `flutter analyze` | 13 info | 13 info (sau khi thêm test mới) | — | Đúng baseline, **0 lint mới**, `lib/` sạch |

- Điểm xuất phát của vòng này (trước khi QA thêm test): **284/284 pass** — khớp đúng con số Leader verify.
- 13 lint info còn lại 100% nằm ở `test/unit/sync_service_test.dart` (`prefer_const_constructors`, dòng 28–403) — đúng baseline, `lib/` sạch.

### Đối chiếu số lượng test

| Nhóm | Số test | Ghi chú |
|---|---|---|
| 21 file test CŨ (trước redesign) | 183 | 182 cũ + 1 test MỚI thêm vào `item_card_test.dart` (additive, tên test ghi rõ "(P3a)") |
| `theme_provider_test.dart` (file mới, P4) | 6 | Nằm trong `test/unit/` |
| `test/widget/ui/` (17 file, P2) | 57 | Component library + tokens |
| `test/widget/` màn hình/router (8 file, P3) | 38 | soft-gate 4, budget_settings 5, home 5, item_detail_sheet 8, login 3, main_shell 5, summary 4, theme_mode 4 |
| **QA vòng này thêm** (2 file mới) | **7** | smoke_navigation 4 + item_detail_sheet giá 3 |
| **Tổng** | **291** | 284 + 7, khớp từng nhóm |

---

## 2. Đối chiếu Definition of Done (03-qa-regression-plan.md mục 6)

| # | Mệnh đề DoD | Trạng thái | Bằng chứng |
|---|---|---|---|
| 1 | 182/182 test cũ vẫn xanh (cập nhật chỉ khi có lý do) | **ĐẠT** (có 2 exception ghi bên dưới) | Chạy riêng 21 file cũ: 189/189 pass (= 182 + 1 additive + 6 theme_provider trong unit/). 2 expectation trong `ocr_result_list_test.dart` đổi `'Thêm item'` → `'Thêm mặt hàng'` theo glossary R14 — behavior-change có lý do trong code (`ocr_result_list.dart:70`) nhưng **không có note trong file test** (xem Finding M1) |
| 2a | Component library có widget test theo `find.byKey` | **ĐẠT** | 57 test / 17 file trong `test/widget/ui/`; 0→hàng trăm key `find.byKey` (`shell_fab`, `appBottomNav_item_N`, `itemDetailSheet_*`, `budgetSheet_*`, `loginScreen_*`…); test mới chỉ dùng key cho nút/label theo quy ước mục 3.5 |
| 2b | Golden light/dark × 2 cỡ màn cho components | **CHƯA ĐẠT** | Không có `test/golden/`, không có package `alchemist`/`golden_toolkit` trong `pubspec.yaml` |
| 3 | Smoke navigation test cho router | **ĐẠT** (sau vòng này) | Trước đó chỉ phủ một nửa: `app_router_soft_gate_test.dart` (router thật, nhưng chưa tap nav) + `main_shell_test.dart` (tap nav nhưng router GIẢ). QA bổ sung `smoke_navigation_test.dart`: boot chưa login → Home → 3 tab bằng ROUTER THẬT → FAB → /add → sheet Cài đặt → /budget. Mệnh đề cũ "redirect chưa login → /login" đã lỗi thời do PO chốt auth gate mềm — thay bằng 4 test soft-gate có sẵn |
| 4 | `flutter analyze` không tăng lint | **ĐẠT** | 13 info = baseline (đề xuất "dọn luôn 13 lint cũ" trong plan mục 7 P0 **chưa làm** — NIT N3) |
| 5 | Manual checklist 10 case × từng màn, 5"/6.7", light/dark | **KHÔNG XÁC MINH ĐƯỢC** | Không có tài liệu/bằng chứng tick checklist trong repo. Cần PO xác nhận ngoài repo hoặc bổ sung biên bản |
| 6 | 3 lần chạy liên tiếp không flaky | **ĐẠT** | 291/291 × 3 lần (thời gian 53s/93s/74s) |

**Kết quả: 5/6 mục ĐẠT; mục 2b (golden) CHƯA ĐẠT; mục 5 (manual) chưa có bằng chứng.**

---

## 3. Kiểm tra rủi ro redesign cụ thể (đọc code + test)

### 3.1. Auth gate mềm — ĐẠT, an toàn
- `lib/core/router/app_router.dart:38-52`: đã bỏ redirect ép `/login`; chỉ còn 2 rule: `restoring` cho đi qua, và `isAuthenticated && onAuthScreen → '/'` (login xong tự về Home qua `refreshListenable`).
- `lib/core/network/api_client.dart:104-108`: **vẫn chỉ attach `Authorization: Bearer` khi `auth: true` VÀ có token trong storage** — request guest không bao giờ mang header rác.
- Boot chưa login **không có API call nào cần auth**:
  - `itemsProvider` / `categoriesProvider` / `allBudgetsProvider`: `if (!authenticated) return local;` (đọc sqflite, không gọi mạng).
  - `serverSummaryProvider` / `summaryInsightsProvider` / `aiAssistantProvider`: unauth → trả `null`/`[]` ngay.
  - `syncProvider._init()`: chỉ đọc DB, `catch (_) {}` nuốt lỗi an toàn.
  - `authStateProvider.build()`: không có token → `unauthenticated` ngay, không refresh.
  - Lần duy nhất chạm mạng lúc boot là update check tới GitHub releases (public, best-effort, có catch) — không phải API bắt buộc auth.

### 3.2. 4 vùng test khoá ở Home — ĐẠT, giữ nguyên hành vi
| Vùng | Vị trí | Trạng thái |
|---|---|---|
| `Dismissible` swipe-to-delete | `item_card.dart:47` (endToStart, confirmDismiss → dialog, onDismissed → onDelete) | Giữ nguyên, 6 test cũ pass |
| Text `"Xóa vật phẩm?"` | `item_card.dart:35` (giữ đúng chính tả "Xóa", có comment cảnh báo không đổi) | Giữ nguyên |
| `LinearProgressIndicator` màu | `budget_progress_card.dart:106-111` — màu qua `context.snap.colorFor(budgetLevelFromRatio(...))`; hex `SnapColors.light` trùng khớp `AppColors` (`00C48C/FFAB2D/FF4D4D`) nên 3 test màu cũ vẫn pass | Giữ nguyên hợp đồng |
| Nút thêm dòng OCR | `ocr_result_list.dart:58-74` — InkWell + key `ocrResultList_addButton`; **nhưng label đổi** `'Thêm item'` → `'Thêm mặt hàng'` (glossary R14), 2 expectation cũ được cập nhật theo | Hành vi giữ nguyên, copy đổi (Finding M1) |

Bug tap chết ở Home đã sửa thật: `home_screen.dart:396` `onTap: () => ItemDetailSheet.show(context, item)` + `home_screen_test.dart:222` xác minh.

### 3.3. Quét `Colors.white`/hex trong `lib/screens` + `lib/widgets` — ĐẠT, không có vị trí ngoài danh sách ngoại lệ
42 vị trí còn sót, đối chiếu danh sách đã duyệt:
- **Hero gradient** (nền tím đặc, white là màu on-gradient đúng cả light/dark): `budget_progress_card.dart` (9), `summary_screen.dart:367-405` (9), `history_screen.dart:219-239` (6).
- **Camera dim / viewfinder**: `scan_screen.dart` (10), `scan_overlay.dart:122` (laser line), `ar_sticker_screen.dart` (7, gồm `Color(0xFF111827)` trong palette sticker).
- **Sticker contrast rule**: `price_sticker_widget.dart:18` (`isLight ? Colors.black87 : Colors.white` — đúng hợp đồng 2 test cũ).
- **Image scrim**: `image_picker_section.dart:55` (nút xoá trắng trên scrim đen đè lên ảnh đã chọn).
- **Swipe-red**: `item_card.dart:58,63` (icon + chữ "Xoá" trắng trên nền danger).
- **Hex parse**: `add_item_screen.dart:555` (`Color(0xFF000000 | int.parse(hex...)`) — parse màu danh mục, không phải màu UI).
- 4 file khác (`price_history`, `budget_settings`, `history`, `summary`, `barcode_contribute_sheet`) chỉ còn **comment** ghi nhận đã bỏ hardcode.

### 3.4. ItemDetailSheet — ĐẠT, không tự gọi HTTP
- `item_detail_sheet.dart:120,152`: chỉ gọi `itemsProvider.notifier.updateItem(...)` / `deleteItem(...)` — cả 2 method đều tồn tại (`items_provider.dart:136,174`); **0 import** service/ApiClient trong file.
- Có validate: tên rỗng, giá ≤ 0; `!hasChange` → chỉ pop; lỗi → `apiErrorMessage(e)` inline, không raw exception.
- quantity hiển thị chỉ-đọc với ghi chú rõ lý do chưa cho sửa.

### 3.5. Theme provider (P4) — ĐẠT
- Default `ThemeMode.system` (`theme_provider.dart:44-53`, giá trị lạ/null → system); key `'pref_theme_mode'` cố định (`:26`).
- Không blocking splash: `app.dart:17` `valueOrNull ?? ThemeMode.system` → frame đầu render ngay; `main.dart` không await prefs.
- `setMode` cập nhật state NGAY rồi persist async; decode/encode có unit test riêng (`theme_provider_test.dart`, 6 test); UI setting có 4 test (`theme_mode_setting_test.dart`), key theo chuẩn (`shell_themeOption_*`).

### 3.6. Các fix P3 đi kèm — xác nhận có trong code
- Hint giá "(−100%)": `price_comparison_hint.dart:23-25` — `currentPrice <= 0` → không render (audit I1/AC4).
- Budget validate im lặng: `budget_settings_screen.dart:338-341,397-405` — validator + snackbar danger, có test riêng (`budget_settings_screen_test.dart:167`).
- CSV export chặn khi chưa login: `summary_screen.dart:186-194` — snackbar mời đăng nhập có action → /login, có test riêng (`summary_screen_test.dart:137`).
- ErrorState/EmptyState + Thử lại: Home (3 chỗ `when(error:)`), Summary, History, BudgetSettings đều thay raw `'Lỗi: $e'`.

---

## 4. Findings theo severity

> Không có BLOCKER/MAJOR. Toàn bộ production code redesign đạt chất lượng test được.

### MINOR

**M1 — Test cũ bị sửa expectation mà thiếu note lý do trong file test (vi phạm thủ tục DoD mục 4, không vi phạm kết quả)**
- File: `test/widget/ocr_result_list_test.dart:24,29,32,38`
- Thực tế: 2 expectation đổi `'Thêm item'` → `'Thêm mặt hàng'` theo glossary R14 (lý do nằm ở comment production `lib/screens/ocr/widgets/ocr_result_list.dart:70`), nhưng trong file test không có dòng nào ghi "đã cập nhật theo glossary, lý do: …"; tên 2 test (`'shows "Thêm item" button'`, `'tapping "Thêm item" adds a new row'`) giờ **lệch với assertion**.
- Bước tái hiện: đối chiếu inventory `03-qa-regression-plan.md` mục 1.3 (ghi `find.text('Thêm item')` dòng 29, 38) với nội dung file hiện tại.
- Mong đợi: tên test khớp copy mới + 1 dòng comment lý do behavior-change. **Dev FE sửa trong PR dọn dẹp kế tiếp (chỉ sửa test, không chặn ship).**

**M2 — ItemDetailSheet cho paste ký tự không phải số vào giá → lưu giá trị "rác" im lặng**
- File: `lib/screens/home/widgets/item_detail_sheet.dart:198-204` (thiếu `inputFormatters: [FilteringTextInputFormatter.digitsOnly]`)
- Bước tái hiện (đã tự động hoá trong test QA thêm): mở sheet sửa item có giá 25.000 → paste `1abc0` vào ô Giá → bấm "Lưu thay đổi".
- Kết quả mong đợi: chặn/loại ký tự như AddItem (`add_item_screen.dart:363` có `digitsOnly`) và budget sheet (`budget_settings_screen.dart` cũng digitsOnly).
- Kết quả thực tế: `CurrencyFormatter.parse('1abc0')` → `10` → gọi `updateItem(price: 10)` thành công, không cảnh báo.
- Mức độ MINOR vì bàn phím số trên device hạn chế gõ chữ (nhưng paste được); gây data sai không hồi được sau khi server nhận.

### NIT

**N1 — Text 'Cài đặt' trùng 2 widget (nav label `app_bottom_nav.dart:28` + sheet title `main_shell.dart:75`)** — `find.text('Cài đặt')` không dùng được cho test; test mới phải neo qua key/text dài hơn.

**N2 — `LinearProgressIndicator` nằm trong `TweenAnimationBuilder` (`budget_progress_card.dart:102-113`)** — test cũ phải thêm `pumpAndSettle()` mới đọc được màu ổn định (đã có sẵn trong test, chỉ là ghi nhận rủi ro flaky nếu ai xoá `pumpAndSettle`).

**N3 — 13 lint `prefer_const_constructors` cũ ở `test/unit/sync_service_test.dart` (dòng 28, 29, 109, 119, 129, 158, 160, 252, 290, 358, 361, 385, 403) chưa dọn** — việc P0 trong plan mục 7 chưa ai nhận; analyze chưa bao giờ "clean 100%".

### Điểm cần PO xác nhận (ngoài phạm vi code)
- **Manual checklist** (DoD mục 6.5): chưa có biên bản tick 10 case × từng màn trên 5"/6.7" × light/dark. Nếu đã chạy tay, cần lưu biên bản vào thư mục meetings này.

---

## 5. Test QA đã thêm trong vòng này (7 test, 2 file mới, không đụng file có sẵn)

### `test/widget/smoke_navigation_test.dart` (4 test) — DoD mục 3
Smoke navigation qua **router thật** (`appRouterProvider`) + **màn hình thật**, chưa đăng nhập (auth gate mềm), override mọi provider nặng (không HTTP/sqflite thật; sqflite bị thay bằng future lỗi để khẳng định màn hình lỗi không crash):
1. boot chưa login → `MainShell` + `HomeScreen` + banner đăng nhập + EmptyState (không bị đá về /login).
2. bottom nav 3 tab thật: `/` → /summary ('Tổng kết chi tiêu') → /history ('Lịch sử chi tiêu' + ErrorState không crash, không leak 'StateError') → về `/`.
3. FAB giữa (`shell_fab`) → /add render `AddItemScreen` + `addItem_nameField`.
4. sheet Cài đặt (`appBottomNav_item_3`) → có mục theme P4 → tap 'Cài đặt ngân sách' → /budget render `BudgetSettingsScreen` + ErrorState đúng key.

### `test/widget/item_detail_sheet_price_validation_test.dart` (3 test) — soft-gate/form edge case chưa phủ
1. Giá nhập "0" → lỗi inline 'Giá tiền phải lớn hơn 0.', **không gọi** `updateItem`, sheet không đóng.
2. Giá paste "1abc0" → **document hành vi thật**: parse về 10 → gọi `updateItem(price: 10)` (chính là bằng chứng của Finding M2).
3. Giá "abc" → parse về 0 → lỗi inline, không gọi updateItem, không crash.

**Kết quả chạy test mới: 7/7 pass.** Tổng sau khi thêm: 291/291.

---

## 6. Khoảng trống kiểm thử còn lại (ưu tiên bổ sung sau)

1. **Golden test cho component library** (DoD 2b — mục duy nhất CHƯA ĐẠT): thêm `alchemist`, bắt đầu 8-12 component chính, ma trận light/dark × 2 cỡ màn; regen golden bắt buộc trong mọi PR chỉnh token.
2. **Flow login THÀNH CÔNG end-to-end**: hiện chỉ có test "đã authenticated đứng ở /login → redirect /" (`app_router_soft_gate_test.dart:168`); chưa có test mock `login()` thành công → auth đổi → router tự đưa về `/` khi user đang đứng ở /login (cùng rule redirect nhưng nên có 1 test đi qua `AuthNotifier.login`).
3. **Manual checklist** (mục 5 plan): cần biên bản thực thi hoặc gỡ khỏi DoD.
4. Screen test cho các màn còn lại chưa có: `scan`, `ocr`, `ar_sticker`, `price_history`, `register` (hiện 0 test; rủi ro thấp vì không nằm trong luồng boot, nhưng nên thêm dần theo P3 checklist).
5. `update_dialog.dart` (widget cũ ngoài component library) chưa có test — chấp nhận được, nhưng nếu P5 polish đụng tới thì thêm.

---

## Phụ lục — Lệnh tái hiện

```bash
cd mobile
flutter analyze        # 13 info (toàn bộ test/unit/sync_service_test.dart) — bằng baseline
flutter test           # 291/291 All tests passed! (chạy 3 lần liên tiếp, cùng kết quả)
flutter test test/widget/smoke_navigation_test.dart test/widget/item_detail_sheet_price_validation_test.dart  # 7/7 (test QA mới)
flutter test test/widget_test.dart test/widget/item_card_test.dart test/widget/budget_progress_card_test.dart test/widget/ocr_result_list_test.dart test/widget/price_sticker_widget_test.dart test/unit  # 189/189 (21 file cũ + theme_provider_test)
```
