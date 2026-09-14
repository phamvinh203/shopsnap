# Biên bản họp UI/UX Redesign — ShopSnap Mobile

**Ngày:** 2026-09-14 | **Chủ trì:** Leader (ZCode) | **Thành phần:** BA, Flutter FE, QA
**Chủ đề:** Chủ project đánh giá UI/UX hiện tại "xấu quá" — cần phương án làm lại giao diện.
**Kết luận chung:** KHÔNG viết lại app. Làm lại theo lớp: **tokens → component library → restyle từng màn hình → dark mode → polish**. Giữ nguyên providers/ApiClient/DAOs và toàn bộ logic 6 wave API integration.

---

## 1. Chẩn đoán: vì sao UI đang xấu (dẫn chứng từ code)

| # | Vấn đề | Dẫn chứng |
|---|--------|-----------|
| 1 | Design system chỉ hiện thực ~20%: theme 72 dòng, không spacing/radius/shadow tokens, không dark mode, không component library (`lib/widgets` chỉ có update_dialog) | `lib/core/theme/app_theme.dart`, `app_colors.dart` |
| 2 | Tap vào item không có gì xảy ra — không có màn Item Detail/Edit, vi phạm PRD Feature 1 | `home_screen.dart:347` `onTap: () {}` |
| 3 | Lỗi bị nuốt lặng lẽ: budget card/chips tự biến mất khi API lỗi; nơi khác hiện raw `'Lỗi: $e'` không có nút Thử lại | `home_screen.dart:271,287,313`; summary/history/budget |
| 4 | Budget nửa vời: home hardcode "Ngân sách hôm nay" dù backend hỗ trợ week/month; form budget validate im lặng; thiếu toggle cảnh báo 80%/100% | `budget_progress_card.dart:33`, `budget_settings_screen.dart:398` |
| 5 | Ép đăng nhập dù định vị offline-first; không có forgot password | `app_router.dart:39` |
| 6 | Style viết tay rải rác: radius 4→24, font 9→28; microcopy lộn xộn ("Xóa/Xoá", "items/vật phẩm"); hint giá hiện "(−100%)" khi giá trống | toàn bộ `lib/screens`, `price_comparison_hint.dart:23-31` |

**Kết luận của cả phòng:** UI xấu không phải do màu/font chọn sai, mà do **thiếu hệ thống** — mỗi màn tự dựng layout tay nên không màn nào giống màn nào, và thiếu state chuẩn (loading/error/empty).

## 2. Hướng thị giác được FE khuyên: "Friendly Ledger"

- Material 3 tinh gọn, giữ brand tím `#6C63FF` + Nunito.
- Nền phẳng elevation-0 + hairline border; card radius 16; duy nhất **1 hero card gradient tím radius 20** mỗi màn.
- Home: hero number "Còn lại" 34sp/w800 tabular figures.
- Giữ BottomAppBar + FAB giữa (thân thiện 1 tay) — không dùng floating nav.
- Định vị: app sổ tay chi tiêu cho user Việt Nam, nhiều số tiền → cần number rõ, tương phản cao, ít nhiễu.

## 3. Kế hoạch thực hiện (đồng thuận BA + FE + QA)

| Phase | Nội dung | Effort | Rủi ro test |
|-------|----------|--------|-------------|
| P1 | Design tokens: `AppSpacing/AppRadius/AppShadows` + ThemeExtension `SnapColors` (có fallback `?? SnapColors.light()` — bẫy null của widget test pump bare MaterialApp) | 1 buổi | Thấp (cẩn thận 5 test so màu cứng) |
| P2 | 18 shared components trong `lib/widgets/ui/` (AppCard, buttons, AppTextField, MoneyText, EmptyState, ErrorState, LoadingSkeleton, ConfirmDialog, AppScaffold...) + thay chỗ an toàn | 2–3 buổi | Vỡ finder `byType` nếu thay `GestureDetector`/`Dismissible` thiếu cẩn thận |
| P3 | Restyle screen theo thứ tự: **Home+ItemCard → Auth → AddItem → Shell → Summary/History → Scan/OCR/AR**. Ship được sau P2 (app "đổi da" rõ). | 4–5 buổi | 4 file widget test khoá finder ở Home (Dismissible, "Xóa vật phẩm?", LinearProgressIndicator màu, "Thêm item") |
| P4 | Dark mode + quét `Colors.white` hardcoded | 1 buổi | 5 test so màu cứng |
| P5 | Polish: animation, haptic, a11y | 1–2 buổi | Thấp |

**Tổng: ~9–12 buổi thực (~1.5–2 tuần lịch), mỗi phase chốt bằng `flutter analyze` + 182 test xanh.**

Xen kẽ (từ BA, chìm trong restyle): bổ sung state chuẩn loading/error/empty cho mọi màn; thêm màn **Item Detail/Edit** (P1 UX — hiện tap item chết); mềm hoá auth gate; thống nhất glossary tiếng Việt.

## 4. Definition of Done (QA đề xuất)

1. 182/182 test cũ vẫn xanh (cập nhật test chỉ khi có lý do ghi rõ).
2. Component library có widget test theo `Key` (hiện toàn app **0** `find.byKey`, 18 `find.text` — quy ước mới: key const cho widget quan trọng).
3. Golden test light/dark × 2 cỡ màn cho components (đề xuất `alchemist`, cuối P2).
4. Smoke navigation test mới cho router (24 screen hiện không có test nào).
5. `flutter analyze` không tăng lint mới (baseline hiện: lib sạch, 13 info trong `test/unit/sync_service_test.dart`).
6. Manual checklist 10 case chung × từng màn trên máy 5" và 6.7", light/dark; 3 lần chạy liên tiếp không flaky.

## 5. Hồi hộp cần PO chốt trước khi vào P3 (6 điểm mở, chi tiết memo BA mục 7)

1. **Auth gate mềm** — cho xem dữ liệu local không cần login? (khuyến nghị: có, đúng định vị offline-first)
2. **Phạm vi Item Detail/Edit** — màn mới hoàn chỉnh hay chỉ bottom-sheet sửa nhanh? (khuyến nghị: bottom-sheet trước, màn đầy đủ sau)
3. Ngân sách hiển thị mặc định: hôm nay hay tuần/tháng có toggle?
4. Giữ brand tím hiện tại hay đổi màu? (khuyến nghị: giữ)
5. Độ ưu tiên scan/OCR/AR trong redesign (ch restoring hay restyle luôn)?
6. Forgot password có làm ngay không?

## Phụ lục — Memo đầy đủ

- [01-ba-ux-audit.md](01-ba-ux-audit.md) — chẩn đoán UX + ưu tiên + acceptance criteria
- [02-fe-redesign-proposal.md](02-fe-redesign-proposal.md) — tokens, 18 components, 3 hướng style, phase plan + code mẫu
- [03-qa-regression-plan.md](03-qa-regression-plan.md) — phân loại 182 test, rủi ro từng phase, quy ước key, golden, checklist

**Baseline đã Leader xác minh 2026-09-14:** `flutter test` → **182/182 pass (~50s)** (số 142 cũ trong ghi chú dự án là lạc hậu); `flutter analyze` → lib/ sạch.

---

## TRẠNG THÁI THỰC THI (cập nhật cuối ngày 2026-09-14)

PO duyệt "làm đi" — đã thực thi P1→P4 + 2 bug UX chính trong cùng ngày:

| Phase | Kết quả | Verify Leader (analyze + test thật) |
|-------|---------|-------------------------------------|
| P1 tokens + P2 components (18 widgets, 57 test) | Xong | 239/239 |
| P3a Home + ItemDetailSheet + ErrorState retry + fix "(−100%)" | Xong | 253/253 |
| P3b Auth + AddItem + Shell + **auth gate mềm** | Xong | 265/265 |
| P3c Summary/History/Budget/Scan/OCR/AR + fix validate im lặng budget | Xong | 274/274 |
| P4 Dark mode + setting Giao diện trong sheet Cài đặt | Xong | 284/284 |
| QA regression độc lập (smoke navigation + price validation tests) | Verdict SHIP ĐƯỢC, 0 blocker/major | 291/291 |
| Fix M2 (lọc ký tự field giá ItemDetailSheet) | Xong | **291/291 (lần cuối)** |

**Definition of Done: 5/6 đạt.** Chưa làm: golden test (cần thêm package alchemist — đang cấm thêm package) và manual checklist trên máy thật (cần thiết bị). Chi tiết: [04-qa-final-report.md](04-qa-final-report.md).

**Backlog chuyển tiếp:** sửa số lượng item (cần cột DAO + backend PATCH), route /profile thay pseudo-tab Cài đặt, forgot password (chưa có backend), toggle cảnh báo 80%/100% (cần backend lưu preference), golden test, manual checklist dark mode trên máy thật, M1 (ghi chú lý do sửa expectation trong 2 test cũ), thống nhất chính tả "Xóa"→"Xoá" ở chuỗi bị test khoá.

**Git: 49 file thay đổi, CHƯA commit** (đợi chủ project duyệt).
