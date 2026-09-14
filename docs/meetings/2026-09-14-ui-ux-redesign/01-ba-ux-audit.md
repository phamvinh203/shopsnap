# Memo — UX Audit & Redesign Requirements (ShopSnap Mobile)

| | |
|---|---|
| **Ngày** | 2026-09-14 |
| **Người viết** | BA — phòng IT (góc nhìn BA/UX) |
| **Loại** | Memo cuộc họp khẩn về việc làm lại UI/UX app mobile. KHÔNG sửa code production. |
| **Phạm vi kiểm tra** | `shopsnap/PRD.md`, `shopsnap/design-spec.md`, toàn bộ `mobile/lib/screens/**`, `mobile/lib/core/theme/**`, `mobile/lib/core/router/app_router.dart` |
| **Ràng buộc bất di bất dịch** | Redesign CHỈ đụng tầng UI (screens, widgets, theme). KHÔNG đụng providers, ApiClient, DAOs, services. 142 test phải giữ xanh. |

---

## 1. Tóm tắt điều hành

- Tầng theme hiện tại (app_colors.dart 16 dòng, app_theme.dart 72 dòng) **không đủ mang một redesign**: không có spacing/radius/elevation/typography tokens dùng được, không có dark mode, không có shared component library (`lib/widgets` chỉ có update_dialog.dart).
- Hệ quả: 24 screen file tự style thủ công (font size 9→28, radius 4→24 viết rải rác), dẫn đến **thiếu nhất quán** — đây là nguyên nhân gốc của cảm giác "xấu", nhiều hơn là thiếu màu đẹp.
- Nghiêm trọng hơn thẩm mỹ: có các **lỗ hổng UX chức năng** — item không mở được detail (dead tap), budget card không dẫn tới cài đặt ngân sách, lỗi bị nuốt lặng lẽ, app ép đăng nhập dù định vị offline-first, microcopy lai tiếng Anh/dev-speak.
- Đề xuất: redesign làm **3 lớp theo thứ tự** — (1) Design token + component library, (2) IA/navigation + state chuẩn, (3) polish từng flow. Chi tiết ở mục 5–6.

---

## 2. Chẩn đoán UX theo user flow

### 2.1 Flow Onboarding / Auth (login, register)

| # | Vấn đề | Bằng chứng |
|---|--------|-----------|
| A1 | **Ép đăng nhập trước khi thấy được app**, mâu thuẫn với định vị offline-first (PRD NFR: "Offline mode hoạt động đầy đủ không cần internet"). User mới không thể "thử app" trước khi cam kết tạo tài khoản. | `app_router.dart:39` — mọi route chưa đăng nhập redirect về `/login` |
| A2 | **Không có forgot password / reset password** — user quên mật khẩu thì bế tắc hoàn toàn. | `login_screen.dart` (toàn file, không có action nào ngoài đăng ký) |
| A3 | Microcopy register hứa "đồng bộ dữ liệu lên đám mây" trong khi PRD mục Privacy cam kết "toàn bộ data lưu local, không upload lên server" — mâu thuẫn thông điệp tin cậy. | `register_screen.dart:78` |
| A4 | Không có error state inline cho lỗi server ngoài snackbar; không có giới hạn hiển thị rõ chính sách mật khẩu (chỉ hintText "tối thiểu 8 ký tự", không strength indicator). | `login_screen.dart:50-57`, `register_screen.dart:121` |
| A5 | Không có onboarding/permission priming: lần đầu dùng, camera (scan/OCR/AR) và notification sẽ xin quyền mà không có giải thích trước — tỷ lệ từ chối quyền sẽ cao. | `ar_sticker_screen.dart:70` chỉ có placeholder khi denied; scan/OCR không thấy state denied |

### 2.2 Flow Home

| # | Vấn đề | Bằng chứng |
|---|--------|-----------|
| H1 | **Tap vào item card không làm gì cả** (dead tap), trong khi design-spec yêu cầu "Tap item card → mở detail" và PRD Feature 1 yêu cầu "có thể chỉnh sửa... sau khi lưu". Toàn app **không tồn tại màn item detail/edit**. | `home_screen.dart:347` — `onTap: () {}`; router `app_router.dart:45-63` không có route detail |
| H2 | **Lỗi bị nuốt lặng lẽ**: budget card, category chips, section header đều `error: (_, __) => SizedBox.shrink()` — khi API lỗi, UI biến mất mà user không hiểu tại sao. | `home_screen.dart:271, 287, 313` |
| H3 | Budget card hiện "Chưa đặt ngân sách" nhưng **không tap được** để đi tới cài đặt — Dead End. | `budget_progress_card.dart:60-63` |
| H4 | Header dành 2 icon kỹ thuật (sync, update check) cho vị trí đắt giá nhất; snackbar sync "Đồng bộ xong (đẩy: X, kéo: Y)" là dev-speak, user thường không hiểu "đẩy/kéo". | `home_screen.dart:125-183, 158` |
| H5 | Lời chào không cá nhân hóa "Xin chào! 👋" dù user đã đăng nhập và có `displayName` (design-spec: "👋 Xin chào, Minh!"). | `home_screen.dart:117` |
| H6 | Category chips chỉ có tên, không có số tiền theo danh mục như wireframe (🍜 80k); chip "Tất cả" dùng emoji 🔍 (ngữ nghĩa search, không phải "all"). Filter chọn xong không có cách nào thấy rõ đang filter (chỉ đổi màu chip). | `category_chips_row.dart:25-31` |
| H7 | Xóa item: swipe + confirm dialog + **không có Undo**. Confirm dialog đi ngược intent quick-delete của design-spec (swipe = xóa nhanh), nhưng lại không có safety net (undo) thay thế. | `item_card.dart:33-49` |
| H8 | Empty state chỉ có emoji + text, CTA "Nhấn + để thêm vật phẩm đầu tiên" bắt user tự tìm FAB thay vì nút bấm trực tiếp. | `home_screen.dart:324-338` |

### 2.3 Flow Thêm item (manual / scan / OCR / AR)

| # | Vấn đề | Bằng chứng |
|---|--------|-----------|
| I1 | **Price hint sai khi giá chưa nhập**: `currentPrice = parse("") = 0` → so với lần trước thành "Lần trước: 85,000đ (−100%)" — gợi ý phản cảm tính ngay khi user chưa gõ giá. | `add_item_screen.dart:423-430` + `price_comparison_hint.dart:23-31` |
| I2 | **Không có guards dữ liệu chưa lưu**: Form thêm item không có PopScope/confirm khi bấm ✕ giữa chừng — mất toàn bộ input đã gõ. (grep toàn screens: không có PopScope/WillPopScope nào). | `add_item_screen.dart:280-292` |
| I3 | Giá tiền nhập dạng digits raw, **không format phân cách hàng nghìn khi đang gõ** (user gõ 120000 nhìn thấy "120000", wireframe là "120,000"). Lặp lại ở form budget. | `add_item_screen.dart:406-420`, `budget_settings_screen.dart:327-336` |
| I4 | Entry point OCR bị **lặp 2 chỗ** trên cùng màn (appbar action + quick action row) — gây nhiễu và nhầm lẫn thứ bậc. | `add_item_screen.dart:286-290` và `329-333` |
| I5 | Quick action buttons dùng GestureDetector trần: **không ripple, không haptic, không semantics** (screen reader đọc không được). | `add_item_screen.dart:504-519` |
| I6 | Category tự đổi theo tên gõ (auto-classify + server suggest) mà **không có giải thích tại sao** — user thấy chip nhảy gây mất kiểm soát. Badge "Gợi ý" có nhưng quá kín đáo. | `add_item_screen.dart:64-116` |
| I7 | Nút Lưu dùng emoji "💾" trong label — lệch design system, render khác nhau giữa thiết bị. Tương tự "✅ Lưu tất cả N items" ở OCR. | `add_item_screen.dart:476`, `ocr_screen.dart:303` |
| I8 | Scan/OCR dùng thuật ngữ Anh nguyên: "Scan barcode", "AR Sticker"; OCR xong báo "Đã lưu N items" — mixing ngôn ngữ trong cùng luồng ("vật phẩm" ở nơi khác). | `add_item_screen.dart:302, 336`, `ocr_screen.dart:85, 275` |
| I9 | Chỉ có duy nhất 1 haptic trong cả app (scan thành công). Lưu item, xóa item, đạt ngưỡng budget — không có feedback vật lý nào. | `scan_screen.dart:41` (grep toàn app) |

### 2.4 Flow Budget

| # | Vấn đề | Bằng chứng |
|---|--------|-----------|
| B1 | **Home card hardcode "Ngân sách hôm nay"** trong khi hệ budget hỗ trợ day/week/month và list ở budget settings. User chỉ đặt budget tháng → home vẫn báo "Chưa đặt ngân sách" (sai ngữ nghĩa). | `budget_progress_card.dart:33, 62` vs `budget_settings_screen.dart:163-168` |
| B2 | **Validation im lặng**: submit form budget với số tiền rỗng/≤0 thì `return;` — nút bấm không phản hồi gì, user tưởng app chết. | `budget_settings_screen.dart:398-399` |
| B3 | **Thiếu toàn bộ mục Cảnh báo** mà PRD Feature 6 và design-spec Screen 7 yêu cầu: toggle cảnh báo 80%, cảnh báo vượt mức, giờ nhắc tổng kết. Budget settings hiện chỉ có CRUD ngân sách. | `budget_settings_screen.dart` (toàn file, không có notification prefs) |
| B4 | Cảnh báo budget không có moment UI trên home khi vượt (design-spec: progress bar shake + đổi đỏ; thực tế chỉ đổi màu tĩnh). | `budget_progress_card.dart:11-17` |

### 2.5 Flow Summary (Tổng kết)

| # | Vấn đề | Bằng chứng |
|---|--------|-----------|
| S1 | Xuất CSV thành công hiện **đường dẫn file thô** trong snackbar — dev-speak; user không biết "Documents" ở đâu. Nên dùng share sheet của OS. | `summary_screen.dart:159` |
| S2 | Danh sách items chỉ hiện với period "Ngày", tuần/tháng/năm tự dưng mất section mà không có giải thích. | `summary_screen.dart:120` |
| S3 | Loading là full-screen spinner (không skeleton) trong khi home dùng skeleton — trải nghiệm chờ không nhất quán. | `summary_screen.dart:107-109`, `history_screen.dart:153-155` |
| S4 | Export chỉ có CSV; PRD Feature 8 yêu cầu export PDF/share ảnh "story" — chưa có (đây là gap tính năng, nêu để xác nhận phạm vi, không ép trong lần redesign này). | `summary_screen.dart:73-89` |

### 2.6 Flow History

| # | Vấn đề | Bằng chứng |
|---|--------|-----------|
| Y1 | Bar chart: tap vào cột để xem items trong ngày là **tương tác ẩn, không có affordance/hint** ("Chạm vào cột để xem chi tiết"). | `history_screen.dart:248-253` |
| Y2 | Thiếu filter (theo danh mục) và search như design-spec Screen 8 vẽ `[Filter▼]`; không có pagination cho tháng nhiều items. | `history_screen.dart` (toàn file) |
| Y3 | "Biến động giá" (price history) điều hướng bằng `Navigator.push + MaterialPageRoute` trong khi cả app dùng go_router — lệch pattern, mất deep-link. | `history_screen.dart:108-110` |
| Y4 | Screen query SQL trực tiếp (`rawQuery`) ngay trong file screen — vi phạm phân tầng; không phải việc của redesign UI nhưng cần ghi nhận để redesign không paddingLeft thêm. | `history_screen.dart:40-48` |

### 2.7 Vấn đề hệ thống (chẩn đoán gốc rễ của "xấu")

1. **Không có token hệ**: spacing/radius/elevation không tồn tại trong code; radius thực tế dùng rải rác 4/8/10/12/14/16/20/24 (spec chỉ cho 8/12/16/24/pill); font size 9→28 tùy hứng; shadow tự viết từng chỗ.
2. **textTheme được định nghĩa nhưng gần như không dùng**: screens viết `TextStyle(fontSize: ..., fontWeight: ...)` inline hàng trăm lần → cùng cấp thông tin nhưng khác cỡ chữ giữa các màn.
3. **Không có shared components**: SnackBar style copy-paste thủ công ở ≥6 file; grab handle của bottom sheet tái hiện 3 lần (`main_shell.dart:68-75`, `add_item_screen.dart:585-591`, `budget_settings_screen.dart:312-318`); dialog mỗi nơi một kiểu.
4. **Hardcode `Colors.white`** ở appbar/card thay vì `colorScheme.surface` → dark mode sau này sẽ vỡ (`summary_screen.dart:68`, `history_screen.dart:101`, `budget_settings_screen.dart:36`).
5. **Không có accessibility**: 0 chỗ dùng Semantics/semanticsLabel (grep toàn screens); touch target của `_NavItem`/`_QuickBtn` có thể < 48dp; emoji dùng làm icon (💰🧾🛍️📭🚀) — screen reader đọc tên emoji, không theme được.
6. **Microcopy tiếng Việt chưa chuẩn**: trashed chính tả lẫn lộn "Xóa" (`item_card.dart:30,37,43`) vs "Xoá" (`budget_settings_screen.dart:113,120`; `image_picker_section.dart:103`); danh từ lai "items"/"vật phẩm"; lỗi hiển thị raw `'Lỗi: $e'` với text exception tiếng Anh (`home_screen.dart:364`, `summary_screen.dart:111`, `history_screen.dart:156,351`, `budget_settings_screen.dart:49`, `ocr_screen.dart:55`).

---

## 3. Đề xuất cải thiện — mức Requirement

### 3.1 Information Architecture & Navigation mới

- **R1. Bottom nav 5 vùng chuẩn hóa**: `Trang chủ | Tổng kết | (FAB +) | Lịch sử | Cá nhân`. Tab "Cài đặt" hiện tại là pseudo-tab mở bottom sheet và **không bao giờ ở trạng thái selected** (`main_shell.dart:43`) — chuyển thành route thật `/profile` chứa: tài khoản, cài đặt ngân sách, **cảnh báo/thông báo**, trạng thái sync, kiểm tra cập nhật, đăng xuất.
- **R2. Dọn header Home**: bỏ 2 icon sync/update khỏi header (chuyển vào /profile); giữ duy nhất 1 banner mảnh khi có bản cập nhật. Sync chỉ hiện badge nhỏ khi có pending ≥ 1.
- **R3. Bổ sung màn Item Detail/Edit** (route `/item/:id`): xem đầy đủ ảnh + metadata, sửa tên/giá/danh mục/ghi chú, xóa, xem lịch sử giá sản phẩm. Đóng cả 3 gap: dead tap (H1), PRD Feature 1 "chỉnh sửa sau khi lưu", và điểm vào price history.
- **R4. FAB + mở action sheet** (Manual / Scan barcode / Chụp hóa đơn / AR sticker) thay vì nhảy thẳng form — user chọn chế độ nhập đúng từ đầu; bỏ nút OCR trùng lặp trên appbar form (I4).
- **R5. Điều hướng thống nhất go_router**: price history chuyển thành route (`/price-history/:id?`) thay vì MaterialPageRoute (Y3).
- **R6. Auth gate mềm** (cần product owner chốt, xem mục 7): cho phép duyệt app không đăng nhập; chỉ yêu cầu đăng nhập khi dùng tính năng cần server (sync, suggest, contribute, export). Nếu giữ gate: thêm "Để sau" mode xem-only.

### 3.2 Các state bắt buộc (mọi màn có dữ liệu async)

- **R7. Bộ 4 state chuẩn hóa qua shared widget** (ví dụ `AsyncStateView`): Loading (skeleton đúng hình layout, không spinner trần), Empty (icon minh họa + 1 câu + CTA chính), Error (message tiếng Việt không chứa exception + **nút Thử lại**), Data. Cấm `error: (_, __) => SizedBox.shrink()` (H2) và cấm render `'Lỗi: $e'` raw.
- **R8. Feedback khi save/xóa**: haptic nhẹ (light impact) khi lưu thành công, medium khi xóa; snackbar xóa item có action **Undo** (soft-delete đã có sẵn ở tầng data nên undo khả thi) — thay confirm dialog cho swipe-delete.
- **R9. Guard dữ liệu chưa lưu**: mọi form (add item, budget sheet, category sheet) có PopScope confirm "Thoát? Thông tin chưa được lưu" khi có input dirty.

### 3.3 Accessibility

- **R10. Touch target ≥ 48x48dp** cho mọi nút (đặc biệt `_NavItem`, `_QuickBtn`); mọi IconButton icon-only phải có tooltip + semanticsLabel tiếng Việt.
- **R11. Contrast ≥ 4.5:1** cho text thường: kiểm tra white trên `#6C63FF` (~3.9:1 — cần darken primary cho text nhỏ hoặc tăng weight/size), `textSecondary #6B7280` trên `bgMain`.
- **R12. Thay emoji-as-icon bằng icon font** (Material Symbols) ở các chỗ icon có ngữ nghĩa điều hướng/thao tác; emoji chỉ giữ trong nội dung văn phong thân thiện.
- **R13. Đáp ứng text scaling**: dùng textTheme/`MediaQuery.textScaler`, test ở 1.3x — các label 10-11sp hiện tại sẽ vỡ.

### 3.4 Tiếng Việt hóa tự nhiên (glossary bắt buộc)

- **R14. Áp dụng bộ thuật ngữ thống nhất**: "vật phẩm" (không "item" trong UI), "Xoá" (dấu hỏi, không "Xóa"), "Huỷ" — chọn 1 chuẩn và rà toàn app; nút "Quét mã" thay "Scan barcode"; "Nhãn giá AR" thay "AR Sticker"; snackbar sync thành "Đã đồng bộ. Có X thay đổi vừa đẩy lên máy chủ."
- **R15. Microcopy cógiọng điệu, có động từ rõ**: empty state home "Hôm nay bạn chưa ghi gì. Chụp nhanh món vừa mua nhé!" + nút "Thêm vật phẩm"; budget trống là nút bấm dẫn thẳng sang /budget.

---

## 4. Bảng ưu tiên (Impact / Effort)

| # | Hạng mục | Impact | Effort | Thứ tự đề xuất |
|---|----------|--------|--------|----------------|
| 1 | Design tokens (spacing/radius/elevation/type/semantic colors) + shared component library (Button, Card, SnackBar, Sheet, Dialog, AsyncStateView) | **Cao** | Trung (1 lần, tất cả màn sau đó hưởng) | **Làm đầu tiên** — nền cho mọi thứ còn lại |
| 2 | State chuẩn: error + retry, empty + CTA, skeleton; cấm shrink/lỗi raw | Cao | Thấp | **P0** (cùng đợt 1) |
| 3 | Home + budget card: sửa "Ngân sách hôm nay" theo period, budget card bấm được, greeting cá nhân hóa, dọn header | Cao | Thấp–Trung | **P0** — màn nhìn nhiều nhất |
| 4 | Add item flow: sửa price hint (I1), PopScope guard (I2), format tiền khi gõ (I3), gộp entry OCR (I4), haptic + ripple (I5, I9) | Cao | Trung | **P1** — core loop của app |
| 5 | Item Detail/Edit + tích hợp price history (R3, R5) | Cao | Trung–Cao | **P1** — lấp gap chức năng của PRD |
| 6 | IA: /profile route thật, action sheet từ FAB, microcopy glossary (R1, R4, R14, R15) | Trung–Cao | Trung | **P1–P2** |
| 7 | Auth: forgot password flow, permission priming, (R6 nếu chốt) | Trung | Trung | **P2** (tần suất dùng thấp nhưng rủi ro churn cao lúc onboarding) |
| 8 | Summary/History polish: share sheet thay path CSV, affordance chart, filter history, skeleton thống nhất | Trung | Trung | **P2** |
| 9 | Dark mode + text scaling + accessibility audit đầy đủ (R10–R13) | Trung | Trung–Cao | **P3** — cần token (hạng 1) xong mới rẻ |
| 10 | Scan/AR polish (permission states, hướng dẫn trong viewfinder) | Thấp–Trung | Trung | **P3** — tính năng niche |

Nguyên tắc: mọi hạng mục trên **chỉ chạm tầng UI**; providers/ApiClient/DAOs giữ nguyên. Hạng 5 (detail/edit) là ngoại lệ cần provider đọc theo id — yêu cầu dev confirm khả thi không phá itemsProvider hiện có trước khi lên sprint.

---

## 5. Acceptance criteria cho redesign (top 5)

**AC1 — Không còn state lặng lẽ**
- Given một màn hình bất kỳ có dữ liệu async (home, summary, history, budget, price history),
- When API lỗi hoặc mất mạng,
- Then màn hiển thị error state tiếng Việt (không chứa text exception/code) kèm nút "Thử lại" bấm được và gọi lại đúng provider cũ; không có vùng nào tự biến mất (`SizedBox.shrink`).

**AC2 — Vòng lặp thêm→sửa→xóa khép kín**
- Given user đã lưu 1 vật phẩm,
- When tap item card trên Home,
- Then mở Item Detail; user sửa được tên/giá/danh mục và thay đổi phản ánh ngay trên Home; When swipe để xóa, Then xóa ngay (không dialog) kèm snackbar Undo trong 5 giây; Undo khôi phục đúng vật phẩm.

**AC3 — Design token được thực thi**
- Given toàn bộ file trong `lib/screens/` sau redesign,
- When review code,
- Then không có giá trị hex màu, font size, radius, spacing hardcoded ngoài theme/tokens; mọi component dùng chung (button, card, snackbar, bottom sheet) lấy từ component library; cùng 1 màn chạy ở light mode và dark mode (nếu làm P3) không có vùng "cháy trắng".

**AC4 — Form thêm vật phẩm an toàn & trung thực**
- Given user đang nhập dở form thêm vật phẩm,
- When bấm ✕, Then hiện confirm "Thông tin chưa được lưu";
- When user gõ tên đã mua trước đó nhưng chưa nhập giá, Then KHÔNG hiển thị hint so sánh giá nào (hint chỉ xuất hiện khi giá > 0);
- When gõ giá, Then giá hiển thị có phân cách hàng nghìn ngay khi đang gõ.

**AC5 — Tiếng Việt thống nhất**
- Given toàn bộ text UI,
- When rà soát theo glossary,
- Then chỉ dùng đúng 1 chính tả cho "Xoá/Huỷ"; không còn "items", "Scan barcode" nguyên si trong label hiển thị; không hiển thị đường dẫn file hay thuật ngữ kỹ thuật (đẩy/kéo, endpoint) cho end user.

---

## 6. Ngoài phạm vi lần này (chống phình to yêu cầu)

- Không đổi logic: sync engine, barcode lookup/contribute, OCR parsing, category classifier, API contracts, DB schema, 142 test hiện có.
- Không làm tính năng mới của PRD chưa có: export PDF/share ảnh story (Feature 8), AR template marketplace, push notification scheduling mới (chỉ làm UI toggle nếu B3 được duyệt).
- Không đụng backend NestJS.

---

## 7. Câu hỏi cần Product Owner / chủ project chốt trước khi vào code

1. **Auth gate (A1/R6)**: có cho phép dùng app không đăng nhập (local-only, đăng nhập sau để sync) không? Quyết định này thay đổi IA và flow onboarding nhiều nhất.
2. **Forgot password (A2)**: backend hiện đã có endpoint reset password chưa? Nếu chưa, đây là việc backend chứ không phải redesign UI — cần tách ticket.
3. **Item Detail/Edit (R3)**: xác nhận nằm trong phạm vi redesign (đụng 1 provider mới đọc theo id) hay tách phase sau?
4. **Budget cảnh báo (B3)**: các toggle 80%/100%/nhắc tổng kết — server đã lưu preference này chưa, hay chỉ local? Định hình trước khi vẽ lại màn budget.
5. **Dark mode**: có yêu cầu chính thức không? Nếu có, nên làm ngay từ lớp token (hạng mục 1) để tránh làm 2 lần.
6. **Undo xóa item (R8)**: chấp nhận pattern xóa-nhanh + Undo thay confirm dialog không (hiện confirm dialog, mất 1 step)?
