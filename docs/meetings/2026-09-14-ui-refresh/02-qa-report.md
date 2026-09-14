# 02 — QA Report: Regression UI refresh "INK LEDGER" (pre-approval)

- **Ngày:** 2026-09-14
- **Tác giả:** QA Engineer (vòng regression độc lập, CHỈ ĐỌC — không sửa code production, không commit)
- **Phạm vi:** đợt UI refresh "INK LEDGER" trên working tree (30 file: 6 token theme + 11 widget `lib/widgets/ui/` + 11 screen + 2 file test do FE sửa), đối chiếu ràng buộc `01-design-proposal.md` mục 5 và format báo cáo trước (`../2026-09-14-ui-ux-redesign/04-qa-final-report.md`).
- **VERDICT: SHIP ĐƯỢC** — 0 BLOCKER, 0 MAJOR; 1 MINOR (test hygiene) + 3 NIT/OBSERVATION, không chặn duyệt.

---

## 1. Kết quả chạy thật (QA tự chạy trên working tree, chưa commit)

| Lệnh | Kết quả | Kết luận |
|---|---|---|
| `flutter analyze` | `13 issues found. (ran in 14.1s)` — 100% info `prefer_const_constructors` tại `test\unit\sync_service_test.dart` (dòng 28, 29, 109, 119, 129, 158, 160, 252, 290, 358, 361, 385, 403) | **Đúng baseline cũ, từng dòng khớp** (04-qa-final-report N3). 0 error, 0 warning, `lib/` sạch → **ĐẠT** |
| `flutter test` (FULL) | `01:09 +291: All tests passed!` (exit code 0) | **291/291 pass** — đúng kỳ vọng, không test nào bị bỏ → **ĐẠT** |
| Lô test hợp đồng (chạy riêng 7 file: theme_mode_setting, home_screen, item_card, budget_progress_card, ocr_result_list, app_typography, price_sticker_widget) | `00:06 +37: All tests passed!` | 37/37 xanh — bằng chứng trực tiếp cho các ràng buộc chuỗi/key/dark mode |

Evidence analyze (paste nguyên văn):

```
   info - Use 'const' with the constructor to improve performance - test\unit\sync_service_test.dart:28:27 - prefer_const_constructors
   ... (13 dòng, toàn bộ test\unit\sync_service_test.dart) ...
   info - Use 'const' with the constructor to improve performance - test\unit\sync_service_test.dart:403:27 - prefer_const_constructors

13 issues found. (ran in 14.1s)
```

Evidence test FULL (dòng cuối của output):

```
01:09 +291: C:/Users/Admin/Desktop/project_shopsnap/mobile/test/widget_test.dart: (tearDownAll)
01:09 +291: All tests passed!
```

> Ghi nhận quy trình: lần chạy lô 7 file đầu tiên ra `+32 -1: Some tests failed` do QA truyền SAI ĐƯỜNG DẪN `test/widget/ui/price_sticker_widget_test.dart` (file thật nằm ở `test/widget/price_sticker_widget_test.dart`) → lỗi **loading `[E]` do path sai của QA, không phải lỗi sản phẩm**. Chạy lại đúng path: 37/37 xanh. Không có flaky.

---

## 2. Bảng kết quả từng mục kiểm

| # | Mục kiểm | Trạng thái | Bằng chứng |
|---|---|---|---|
| 1 | `flutter analyze` 0 error/warning, chỉ 13 info baseline | **ĐẠT** | 13 info đúng file + đúng 13 dòng baseline cũ; `lib/` 0 issue |
| 2 | `flutter test` FULL 291/291 | **ĐẠT** | `+291: All tests passed!`, exit 0 |
| 3 | Scope: không đụng `providers/`, `database/` (DAOs), `core/network/`, `core/router/`, `services/`, `models/` | **ĐẠT** | `git diff --name-only` × grep các vùng cấm → 0 file. 30 file sửa = 6 `lib/core/theme/` + 11 `lib/widgets/ui/` + 11 `lib/screens/` + 2 `test/`, đúng phạm vi proposal |
| 4a | Chuỗi khoá: `'Xóa vật phẩm?'`, `'Huỷ'` | **ĐẠT** | `item_card.dart:35` `title: 'Xóa vật phẩm?'` + comment cảnh báo ":32 KHÔNG đổi chính tả"; `'Huỷ'` là default `cancelLabel` của `ConfirmDialog` (`confirm_dialog.dart:20` — file không đổi). Diff `item_card.dart` chỉ đổi decoration thumbnail + comment |
| 4b | Chuỗi khoá: `'Chưa đặt ngân sách'` | **ĐẠT** | `budget_progress_card.dart:36` (test xanh); `budget_progress_bar.dart:88` (file không đổi) |
| 4c | OCR: nút "Thêm item"/"Thêm mặt hàng" không đổi copy trong đợt này | **ĐẠT** | Diff `ocr_result_list.dart` không đụng chuỗi label (chỉ đổi widget Text số thứ tự). Lưu ý: label đã là `'Thêm mặt hàng'` từ glossary R14 của đợt redesign SÁNG hôm nay (xem NIT N1 về proposal ghi constraint cũ) |
| 4d | `CurrencyFormatter` không đổi | **ĐẠT** | `git diff -- lib/core/utils/` → TRỐNG |
| 4e | `price_sticker_widget.dart` không đổi | **ĐẠT** | Không có trong `git diff --name-only`; test `price_sticker_widget_test` xanh trong lô 37/37 |
| 4f | Keys: `budgetProgressCard_*`, `sectionHeader*`, `itemCard_*`… | **ĐẠT** | `budget_progress_card.dart:37,43,84,134` đủ `remaining/percent/indicator`; `section_header.dart` giữ `sectionHeader_title`; test home/item_card/budget xanh |
| 5 | Dark mode wiring nguyên vẹn | **ĐẠT** | `app.dart:17` `ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system`; `app.dart:20-21` `theme: buildAppTheme(Brightness.light)` + `darkTheme: buildAppTheme(Brightness.dark)`; `main_shell.dart:195/201/207` đủ 3 key `shell_themeOption_system/light/dark`. `theme_mode_setting_test.dart` xanh (trong lô 37/37 và trong 291) |
| 6 | Spot-check 3 file rủi ro | **ĐẠT** | Chi tiết mục 3 dưới |

---

## 3. Spot-check code review 3 file rủi ro nhất (chỉ đọc, không sửa)

### 3.1. `lib/core/theme/snap_colors.dart` — ĐẠT
- `accent` + `onAccent` (field mới INK LEDGER) đầy đủ ở cả 4 chỗ bắt buộc:
  - constructor `required` (dòng 70-71);
  - `SnapColors.light` (`#CDF163` / `#1C1B17`, dòng 85-86) và `SnapColors.dark` (`#C7EE5E` / `#161A12`, dòng 100-101);
  - `copyWith` (dòng 128-129 + 142-143);
  - `lerp` (dòng 161-162).
- Logic semantic KHÔNG đổi: `budgetLevelFromRatio` vẫn `≥1.0 → danger, ≥0.80 → warning` (dòng 23-27); `colorFor` map 1-1 (dòng 113-122); fallback `context.snap ?? SnapColors.light` giữ nguyên (dòng 179-180) — bẫy bare-`MaterialApp` trong widget test vẫn được chặn, `snap_colors_test.dart` xanh.

### 3.2. `lib/core/theme/app_theme.dart` (inputDecorationTheme) — ĐẠT, không phá validator login
- Hộp → underline: `filled: false` + `UnderlineInputBorder` cho `border/enabledBorder/focusedBorder (ink, 2px)/errorBorder (dòng 186)` — đủ 4 trạng thái, có `errorStyle` 12sp màu `snap.danger` (dòng 162-165) → **thông báo lỗi validator vẫn hiện và có màu danger**.
- `login_screen.dart` giữ nguyên hợp đồng: key `loginScreen_emailField/passwordField/submitButton`, label 'Email'/'Mật khẩu', 2 validator (email regex + mật khẩu rỗng) không bị đụng. `login_screen_test` xanh trong 291.

### 3.3. `lib/screens/home/widgets/budget_progress_card.dart` — ĐẠT
- Vẫn render `LinearProgressIndicator` (dòng 133, trong `TweenAnimationBuilder` như cũ) với màu qua **một** nguồn sự thật: `colors.colorFor(budgetLevelFromRatio(_rawRatio))` (dòng 53) — test assert logic, không assert hex, nên đổi hex success/warning/danger không phá test.
- Chuỗi khoá nguyên vẹn: `'Chưa đặt ngân sách'` (:36), `'Còn lại: …'` (:42), `'Đã dùng:'` (:148); keys `budgetProgressCard_remaining/percent/indicator` (:37/:43/:84, :134).
- Ghi chú thiết kế (không phải lỗi): hero số tiền dùng `AppTypography.moneyOf(context.text, size: 34)` + w800 (dòng 44-45, Space Grotesk — "số là nhân vật"), KHÔNG dùng `displayLarge` 32/w700 Fraunces. Hai giá trị này thuộc 2 token khác nhau, khớp proposal (2.4 vs 3.6); ai đọc diff lần đầu dễ tưởng mâu thuẫn (xem OBS-2). Hex `#0E120D` hero dark có comment ghi rõ nguồn proposal 3.6.

---

## 4. Đánh giá 2 file test do FE sửa — CẢ HAI CHÍNH ĐÁNG VÀ ĐỦ

| File | Thay đổi | Đánh giá |
|---|---|---|
| `test/widget/ui/app_typography_test.dart:17-18` | `34/w800` → `32/w700` cho `displayLarge` | **CHÍNH ĐÁNG + ĐỦ.** Khớp code production `app_typography.dart:35-37` (`GoogleFonts.fraunces(fontSize: 32, fontWeight: w700)`) và đúng bảng 2.4 proposal. Có comment trích mốc spec. Không assertion nào khác phụ thuộc displayLarge → 1 chỗ sửa là đủ. Test xanh. **Còn 1 residue:** tên test dòng 6 vẫn ghi *"cùng hệ Nunito"* — xem M1 |
| `test/widget/home_screen_test.dart:157` | `'Hôm nay · 1 mặt hàng'` → `'HÔM NAY · 1 MẶT HÀNG'` | **CHÍNH ĐÁNG + ĐỦ.** Đây là behavior change thật của production: `section_header.dart:36` giờ render `title.toUpperCase()` (spec INK LEDGER 3.11 — overline HOA), không phải test "sửa cho xanh". Có comment lý do trong test. Các finder khác của home (keys `budgetProgressCard_*`, `categoryChipsRow_all`, `itemCard_i1`) không bị ảnh hưởng → chỉ 1 dòng là đủ. Test xanh trong lô 37/37 và trong 291 |

So với finding M1 của báo cáo trước (sửa test cũ KHÔNG ghi lý do), lần này cả 2 chỗ FE đều kèm comment lý do + trích spec — thủ tục đúng.

---

## 5. Findings theo severity

> 0 BLOCKER, 0 MAJOR. Toàn bộ thay đổi production đi qua token/key, không đụng logic provider/database/router.

### MINOR

**M1 — Tên test còn nhắc font cũ "Nunito" sau khi đổi font stack (test hygiene, không sai assertion)**
- File: `test/widget/ui/app_typography_test.dart:6` — tên test `'buildTextTheme: light/dark khác màu chữ, cùng hệ Nunito'`.
- Bước tái hiện: mở file, đối chiếu với `lib/core/theme/app_typography.dart` (Fraunces + Be Vietnam Pro + Space Grotesk; Nunito đã xoá).
- Mong đợi vs thực tế: tên test nên thành "…cùng font stack mới (Fraunces/Be Vietnam Pro)" — assertion hiện chỉ check size/weight/màu nên vẫn xanh, nhưng tên test giờ **sai sự thật** và gây hiểu nhầm người đọc sau. Lưu ý assertion không pin `fontFamily` (chấp nhận được — Google Fonts load trong test phụ thuộc môi trường, nhưng nên ghi comment điều đó).
- Mức độ MINOR: chỉ là tên test, không ảnh hưởng runtime. **FE sửa trong PR dọn dẹp (chỉ sửa test), không chặn ship.**

### NIT

**N1 — Proposal mục 5 (dòng 275) ghi constraint OCR cũ `'Thêm item'`**
- `01-design-proposal.md` bảng ràng buộc dòng 275 vẫn quote nút OCR là `'Thêm item'` "GIỮ NGUYÊN chuỗi", trong đó label thực tế trên working tree đã là `'Thêm mặt hàng'` từ glossary R14 của đợt redesign cùng ngày (commit trước đợt này). Đợt INK LEDGER **không đổi** label (diff ocr_result_list sạch chuỗi) nên không vi phạm tinh thần ràng buộc, nhưng văn bản constraint nên được cập nhật thành `'Thêm mặt hàng'` để người après này không tưởng label bị đổi trái phép.
- Đề xuất: BA/Leader sửa 1 dòng trong proposal (tài liệu, không phải code).

**N2 — Cặp số liệu 34/w800 (hero money) vs 32/w700 (displayLarge token) dễ gây nhầm khi review**
- `budget_progress_card.dart:14,31,44` hero dùng `moneyOf(size: 34)` + `FontWeight.w800` — chính xác theo chủ đích "số là nhân vật" (Space Grotesk), trong khi token `displayLarge` là 32/w700 Fraunces. Code có comment, nhưng nên thêm 1 dòng trong proposal 2.4/3.6 nói rõ hero KHÔNG dùng displayLarge để reviewer sau không report nhầm "quên đổi 34→32".

### OBSERVATION

**OBS-1 — Brief nói "12 widget `lib/widgets/ui/*`" nhưng diff chỉ có 11 file trong thư mục này**
- Đếm từ `git diff --stat`: `app_bottom_nav, app_bottom_sheet, app_button, app_card, app_snack_bar, app_states, budget_progress_bar, category_chip, money_text, price_tag, section_header` = 11. Widget thứ 12 theo proposal (input field) được restyle qua `app_theme.dart` `inputDecorationTheme`, không cần đụng file widget — phạm vi vẫn ĐÚNG spec, không có file production nào nằm ngoài danh sách được duyệt. Chỉ ghi nhận để đối sổ kế toán diff.

**OBS-2 — Không có test pin `fontFamily` mới (Fraunces/Be Vietnam Pro/Space Grotesk)**
- Chấp nhận được vì Google Fonts load trong widget test phụ thuộc môi trường; bù lại nên ưu tiên golden test (khoảng trống mục 6) để bắt lệch font/spacing bằng ảnh.

---

## 6. Khoảng trống kiểm thử (ưu tiên sau khi ship)

1. **Golden test cho component library** — đặc biệt quan trọng sau đợt đổi font + palette + radius, vì test hiện tại gần như không pin font family và không assert hex (đúng thiết kế, nhưng nghĩa là lệch font/khoảng trắng chỉ phát hiện bằng mắt). Đề xuất `alchemist`, bắt đầu từ `app_button`, `category_chip`, `price_tag`, `budget_progress_card`, ma trận light/dark.
2. **Test cho `SectionHeader.toUpperCase()` như một contract riêng** — hiện behavior HOA chỉ được phát hiện gián tiếp qua home test; nên có 1 widget test của `section_header.dart` assert chữ HOA + key + MoneyText amount (file này vừa bị đổi style nhưng chưa có test riêng trong `test/widget/ui/`).
3. **`snap_colors_test.dart` chưa assert `accent`/`onAccent`** (field mới): lô 37/37 có snap_colors_test nhưng cần bổ sung 2 assertion cho field mới và cho `lerp` giữa light/dark để khoá hex highlighter lime — đây là token brand mới, dễ bị đổi tay sau này.
4. Khoảng trống cũ từ báo cáo trước vẫn còn hiệu lực: flow login thành công end-to-end, screen test cho scan/ocr/price_history/register, manual checklist light/dark trên máy thật (đợt này đổi palette + underline input → nên chụp bộ screenshot 2 mode theo đúng Phase verify của proposal).

---

## Phụ lục — Lệnh tái hiện

```bash
cd mobile
flutter analyze
# → 13 issues found. (ran in 14.1s) — 13 info prefer_const_constructors, toàn bộ test/unit/sync_service_test.dart (28–403) = baseline

flutter test
# → 01:09 +291: All tests passed!  (exit 0)

flutter test test/widget/theme_mode_setting_test.dart test/widget/home_screen_test.dart test/widget/item_card_test.dart test/widget/budget_progress_card_test.dart test/widget/ocr_result_list_test.dart test/widget/ui/app_typography_test.dart test/widget/price_sticker_widget_test.dart
# → 00:06 +37: All tests passed!

git diff --name-only | grep -E "providers/|database/|core/network/|core/router/|services/|models/"
# → (rỗng — 0 file thuộc vùng cấm)
git diff --stat -- lib/core/utils/   # → rỗng (CurrencyFormatter không đổi)
```
