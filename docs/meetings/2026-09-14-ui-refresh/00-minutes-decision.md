# Minutes & Decision — UI Refresh "INK LEDGER"

**Ngày:** 2026-09-14 (buổi 2, sau đợt redesign "Friendly Ledger" sáng cùng ngày)
**PO yêu cầu:** đổi tiếp sang một giao diện mới hoàn toàn cho `mobile/`.
**Thành phần:** Leader (điều phối + verify cuối) · Designer (frontend-dev) · FE (frontend-dev) · QA (qa-engineer).

## Quy trình đã chạy

1. **Designer** khảo sát 6 file theme + 18 widget + 5 screen + memo redesign sáng, đề xuất 3 phương án (Ink Ledger / Midnight Terminal / Receipt Brutalism) → chốt **A. Ink Ledger** ("sổ mực & bút dạ": giấy kem + mực đen + xanh pine + highlighter lime). Deliverable: `01-design-proposal.md` — đầy đủ hex/font/radius/component spec + bảng ràng buộc test (chốt 0 item bắt buộc sửa test).
2. **FE** triển khai 5 phase đúng proposal (token swap → core widgets → home/shell → summary/auth/add_item → scan/ocr + motion), mỗi phase chạy analyze+test. Leader phát hiện `history_screen` còn gradient cũ → đẩy lại chính FE đó qua ticket đồng bộ history + price_history. Tổng **28 file lib/test sửa, +976/−468 dòng**.
3. **QA** regression độc lập: verdict **SHIP ĐƯỢC (0 blocker / 0 major)**. Deliverable: `02-qa-report.md`.
4. **Leader re-verify** (không tin số agent): `flutter analyze` = 13 issues đúng baseline (toàn info `prefer_const_constructors` trong `test/unit/sync_service_test.dart`, lib/ sạch); `flutter test` = **291/291 pass**. Leader tự sửa nốt: radius hero history `lg`→`xl` (đồng bộ hero summary), đổi tên test còn ghi "Nunito" (M1), sửa 3 dòng proposal còn ghi chuỗi OCR cũ "Thêm item" → "Thêm mặt hàng" (N1).

## Decision chốt

- Áp dụng **Ink Ledger** làm skin mới: palette pine `#175E48` / kem `#F6F3EA` / mực `#1C1B17` + accent lime `#CDF163` (SnapColors thêm `accent`/`onAccent`, không xoá field cũ); font **Fraunces** (display) + **Be Vietnam Pro** (body) + **Space Grotesk** (mọi số tiền, tabular); radius sắc hơn (6/10/14/16/20); shadow print-flat (card rỗng, floating offset cứng 2px); input underline thay hộp; CTA = khối mực; selected = quét lime; hero card = "thỏi mực" (light) / bảng đen (dark).
- Kiến trúc token + component + dark mode **giữ nguyên** — chỉ đổi giá trị/style. Không thêm package. AR sticker, CurrencyFormatter, providers/DAOs/ApiClient/router không đụng.

## Sai lệch có chủ đích so với proposal (đã ghi nhận)

1. Spinner PrimaryButton dùng `cs.surface` (không phải `onSurface`) vì `onSurface` trùng màu nền mực → spinner tàng hình.
2. GhostButton underline bỏ `offset 3` (Flutter TextStyle không hỗ trợ), giữ `decorationThickness: 1.5`.
3. Hero dark `#0E120D` hardcode có comment tại 3 hero (proposal không cho thêm field token mới).
4. FAB không set được shadow qua `FloatingActionButtonThemeData` → chỉ elevation 0.
5. 2 file test sửa có chính đáng: `app_typography_test` (assert token cũ 34/w800 → 32/w700 theo bảng 2.4) + `home_screen_test:157` (SectionHeader chuyển overline HOA).

## DoD & kết thúc

- [x] `flutter analyze` lib/ sạch (baseline 13 info giữ nguyên)
- [x] `flutter test` 291/291 xanh (Leader tự chạy lại)
- [x] Scope check: 0 file providers/database/network/router/services/models bị sửa
- [x] Ràng buộc chuỗi/finder test khoá: giữ nguyên toàn bộ
- [x] Docs meeting: proposal + QA report + minutes này
- [ ] Manual checklist light/dark trên máy thật ngoài trời (backlog chung với đợt sáng)
- [ ] Golden tests cho component library (cần alchemist — vẫn banned)

## Backlog phát sinh từ buổi họp

- Pin fontFamily mới + assert `accent`/`onAccent` trong `snap_colors_test` (QA OBS)
- Widget test riêng cho SectionHeader (behavior HOA mới)
- Cảm nhận press-ink / highlighter swipe / snackbar rule trên máy thật
