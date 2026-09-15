import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shopsnap/core/network/api_exception.dart';
import 'package:shopsnap/core/theme/app_dimens.dart';
import 'package:shopsnap/core/theme/snap_colors.dart';
import 'package:shopsnap/core/utils/api_error_messages.dart';
import 'package:shopsnap/core/utils/currency_formatter.dart';
import 'package:shopsnap/core/utils/receipt_auto_match.dart';
import 'package:shopsnap/core/utils/receipt_duplicate.dart';
import 'package:shopsnap/models/category_model.dart';
import 'package:shopsnap/services/category_classifier.dart';
import 'package:shopsnap/services/item_api_service.dart';
import 'package:shopsnap/services/ocr_service.dart';
import 'package:shopsnap/providers/categories_provider.dart';
import 'package:shopsnap/providers/items_provider.dart';
import 'package:shopsnap/providers/ocr_confirm_provider.dart';
import 'package:shopsnap/widgets/ui/ui.dart';
import 'ocr_result_list.dart';

/// F-#5 Phase 1 + M-1 Phase 2 (Auto-Match) — màn CONFIRM từng dòng sau OCR:
///
/// 1. Mỗi dòng: tên + giá editable, dropdown category (mặc định = gợi ý của
///    `CategoryClassifier`, user đổi được — AC 5.1/5.2).
/// 2. Cảnh báo trùng với item local (≤ 7 ngày, giá ±10%) + checkbox "vẫn thêm"
///    mặc định KHÔNG tick; recompute real-time khi edit (AC 5.3–5.5).
/// 3. M-1 auto-match local trên sổ giá SQLite (90 ngày, ±10% / barcode):
///    dòng khớp cao tự tick "vẫn thêm" + badge "Tự khớp" (AC 5.15), bỏ tick
///    được (AC 5.21), recompute real-time (AC 5.22); dòng nghi trùng ≤ 7 ngày
///    thì KHÔNG tự tick — cảnh báo trùng thắng (AC 5.18); dòng uncertain giữ
///    nguyên luồng p1 (AC 5.19). Matching thuần local → chạy cả offline
///    (AC 5.25).
/// 4. "Xác nhận thêm N món" 2 chế độ (AC 5.23): "Gửi tất cả" (mặc định) /
///    "Chỉ dòng đã review" → POST /items/bulk source 'ocr' (AC 5.6), xử lý
///    partial failure (AC 5.7), chặn > 50 dòng trước khi gọi (AC 5.8),
///    429 giữ nguyên màn (AC 5.9), offline giữ nguyên state để thử lại
///    (AC 5.10), 0 dòng hợp lệ → nút disabled (AC 5.12). Thành công → xác
///    nhận "N món đã ghi vào sổ giá" (AC 5.24).
class OcrReviewConfirm extends ConsumerStatefulWidget {
  final OcrResult result;

  /// Gọi khi batch xử lý xong TOÀN BỘ (không còn dòng nào phải sửa lại) —
  /// screen pop về màn trước.
  final VoidCallback onFinished;

  /// "Chụp lại" — quay về bước idle.
  final VoidCallback onRetake;

  const OcrReviewConfirm({
    required this.result,
    required this.onFinished,
    required this.onRetake,
    super.key,
  });

  @override
  ConsumerState<OcrReviewConfirm> createState() => _OcrReviewConfirmState();
}

class _OcrReviewConfirmState extends ConsumerState<OcrReviewConfirm> {
  final TextEditingController _storeController = TextEditingController();

  List<ReceiptHistoryEntry> _entries = const [];

  /// M-1 — sổ giá local (90 ngày) dùng cho auto-match; load 1 lần khi mở màn
  /// qua [ocrMatchRecordsProvider], thuần SQLite (AC 5.25).
  List<PriceHistoryMatchRecord> _matchRecords = const [];
  List<OcrConfirmLine> _lines = const [];
  bool _submitting = false;

  /// AC 5.23 — chế độ nút xác nhận: true = "Gửi tất cả" (mặc định, không
  /// persist giữa các lần scan); false = "Chỉ dòng đã review".
  bool _sendAll = true;

  int _uidSeq = 0;

  String get _nextUid => 'line${++_uidSeq}';

  @override
  void initState() {
    super.initState();
    _storeController.text = widget.result.storeName ?? '';
    // AC 5.1: mỗi dòng khởi tạo từ kết quả OCR; category mặc định = gợi ý
    // (OcrService đã gán qua classifier — ở đây recompute qua `suggest` để
    // ăn cả lớp tự học đã seed từ lịch sử).
    _lines = widget.result.items
        .map((i) => OcrConfirmLine(
              uid: _nextUid,
              item: i.copyWith(categoryId: CategoryClassifier.suggest(i.name)),
            ))
        .toList();
  }

  @override
  void dispose() {
    _storeController.dispose();
    super.dispose();
  }

  // ── Duplicate detection (AC 5.3/5.5) + auto-match (M-1: 5.15–5.19) ────────

  OcrConfirmLine _recomputeLine(OcrConfirmLine line) {
    // 1) Cảnh báo trùng p1 (item local ≤ 7 ngày, ±10%) — chạy trước và THẮNG
    //    tuyệt đối (AC 5.18: không bao giờ tự tick một dòng đang nghi trùng).
    final dup = findReceiptDuplicate(
      name: line.item.name,
      price: line.item.price,
      existing: _entries,
    );

    // 2) Auto-match M-1 trên sổ giá local — CHỈ khi không nghi trùng
    //    (AC 5.18). Barcode dòng OCR hiện chưa có (contract pending —
    //    AC 5.16) → truyền null: nhánh barcode inert, không crash.
    final auto = dup == null
        ? findAutoMatch(
            name: line.item.name,
            price: line.item.price,
            barcode: null,
            history: _matchRecords,
          )
        : null;

    // 3) Trạng thái checkbox "vẫn thêm":
    //    - Đang nghi trùng → KHÔNG tự tick (AC 5.18); tick do chính user
    //      thao tác thì giữ nguyên (AC 5.4), tick thừa từ auto-match trước
    //      đó thì gỡ.
    //    - Auto-match mà user CHƯA từng đụng dòng → tự tick sẵn (AC 5.15).
    //      User đã thao tác (reviewed) → tôn trọng lựa chọn hiện tại: bỏ tick
    //      của user KHÔNG bị auto ghi đè lại (AC 5.21).
    //    - Không trùng, không match → reset (p1: trùng biến mất → không tick
    //      để lần trùng kế tiếp mặc định KHÔNG tick — AC 5.3/5.5).
    final bool keep;
    if (dup != null) {
      keep = line.reviewed ? line.keepAnyway : false;
    } else if (auto != null) {
      keep = line.reviewed ? line.keepAnyway : true;
    } else {
      keep = false;
    }

    return line.copyWith(
      duplicate: dup,
      clearDuplicate: dup == null,
      autoMatch: auto,
      clearAutoMatch: auto == null, // AC 5.22 — badge tắt real-time khi mất match
      keepAnyway: keep,
    );
  }

  void _recomputeAll() {
    setState(() => _lines = _lines.map(_recomputeLine).toList());
  }

  // ── Edit handlers ──────────────────────────────────────────────────────────

  void _edit(String uid, OcrLineEdit edit) {
    setState(() {
      _lines = _lines.map((line) {
        if (line.uid != uid) return line;

        var item   = line.item;
        var locked = edit.categoryLocked ?? line.categoryLocked;

        if (edit.name != null) {
          item = item.copyWith(name: edit.name!);
          // Chưa tự chọn category → gợi ý theo tên mới (kể cả lớp tự học).
          if (!locked) item = item.copyWith(categoryId: CategoryClassifier.suggest(edit.name!));
        }
        if (edit.price      != null) item = item.copyWith(price: edit.price!);
        if (edit.categoryId != null) item = item.copyWith(categoryId: edit.categoryId!);

        final contentChanged =
            edit.name != null || edit.price != null || edit.categoryId != null;

        var next = line.copyWith(
          item: item,
          categoryLocked: locked,
          keepAnyway: edit.keepAnyway ?? line.keepAnyway, // AC 5.4
          // AC 5.22/5.23 — mọi thao tác của user trên dòng (sửa tên/giá/
          // category hoặc tự thao tác checkbox) đánh dấu "đã review" để chế
          // độ "Chỉ dòng đã review" (AC 5.23) đếm đúng. Auto-tick của matcher
          // không set cờ này.
          reviewed: line.reviewed || contentChanged || edit.keepAnyway != null,
        );

        if (contentChanged) {
          // AC 5.2: user chủ động chọn category → học ngay để dòng cùng tên
          // (trong batch này hoặc lần OCR sau) được gợi ý lại đúng.
          if (edit.categoryId != null) {
            CategoryClassifier.learn(item.name, edit.categoryId!);
          }
          // Đã sửa nội dung → gỡ nhãn lỗi cũ của lần bulk trước (AC 5.7
          // "cho phép sửa và thử lại"); nhãn trùng recompute bên dưới.
          next = next.copyWith(clearFailedReason: true);
        }
        return _recomputeLine(next); // AC 5.5 — recompute real-time
      }).toList();
    });
  }

  void _addLine() {
    setState(() {
      _lines = [
        ..._lines,
        _recomputeLine(OcrConfirmLine(
          uid: _nextUid,
          item: OcrItem(name: '', price: 0, categoryId: 'cat_other', needsReview: true),
        )),
      ];
    });
  }

  void _removeLine(String uid) {
    setState(() => _lines = _lines.where((l) => l.uid != uid).toList());
  }

  // ── Submit (AC 5.6–5.10 + M-1 AC 5.23) ─────────────────────────────────────

  /// Dòng sẽ gửi theo chế độ nút xác nhận hiện hành (AC 5.23):
  /// - "Gửi tất cả" (mặc định): mọi dòng hợp lệ — auto-match lẫn manual.
  /// - "Chỉ dòng đã review": CHỈ dòng user đã tương tác VÀ đang hợp lệ —
  ///   dòng auto-tick chưa bị đụng tới bị loại.
  List<OcrConfirmLine> get _selectedLines => _lines
      .where((l) => l.isSubmittable && (_sendAll || l.reviewed))
      .toList();

  int get _confirmCount => _selectedLines.length;

  /// Lý do thất bại ngắn gọn tiếng Việt cho badge từng dòng (AC 5.7).
  String _bulkFailureReason(BulkItemFailure f) => switch (f.code) {
        'ITEM_DUPLICATE'        => 'trùng vật phẩm vừa thêm',
        'ITEM_INVALID_CATEGORY' => 'danh mục không hợp lệ',
        'ITEM_INVALID_PRICE'    => 'giá không hợp lệ',
        _                       => f.message.isNotEmpty ? f.message : 'lỗi không rõ',
      };

  Future<void> _submit() async {
    if (_submitting) return;
    final selected = _selectedLines;
    if (selected.isEmpty) return; // AC 5.12 — nút đã disabled, chặn phòng hờ

    // AC 5.8 — chặn TRƯỚC khi gọi API.
    final limitError =
        bulkBatchLimitError(selected.length, maxItems: ref.read(bulkMaxProvider));
    if (limitError != null) {
      AppSnackBar.show(context: context, message: limitError, tone: AppSnackBarTone.danger);
      return;
    }

    setState(() => _submitting = true); // AC 5.6 — loading trong lúc gọi
    try {
      final store = _storeController.text.trim();
      final result = await ref.read(itemsProvider.notifier).bulkAdd(
            selected
                .map((l) => ItemPayload(
                      name:        l.item.name.trim(),
                      price:       l.item.price,
                      quantity:    l.item.quantity,
                      categoryId:  l.item.categoryId,
                      source:      'ocr', // AC 5.6 — đánh dấu nguồn hóa đơn
                      purchaseDate: widget.result.purchaseDate,
                    ))
                .toList(),
            storeName: store.isEmpty ? null : store, // áp chung cả batch
          );

      if (!mounted) return;

      // AC 5.7 — map failure theo đúng vị trí trong batch đã gửi.
      final failedByUid = <String, String>{};
      for (final f in result.failed) {
        if (f.index >= 0 && f.index < selected.length) {
          failedByUid[selected[f.index].uid] = _bulkFailureReason(f);
        }
      }
      final createdCount = selected.length - failedByUid.length;
      final selectedUids = {for (final s in selected) s.uid};

      final remaining = <OcrConfirmLine>[];
      for (final line in _lines) {
        final reason = failedByUid[line.uid];
        if (reason != null) {
          remaining.add(line.copyWith(failedReason: reason));
        } else if (selectedUids.contains(line.uid)) {
          // Dòng đã tạo thành công → LOẠI khỏi editor để lần thử lại KHÔNG
          // tạo trùng (AC 5.7). Dòng không hợp lệ/chưa tick "vẫn thêm" thì giữ.
          continue;
        } else {
          remaining.add(line);
        }
      }

      setState(() => _lines = remaining);

      if (failedByUid.isEmpty) {
        AppSnackBar.show(
          context: context,
          // AC 5.24 — xác nhận sau bulk: N = số dòng BE đã created (barcode/
          // price history do BE ghi trong cùng transaction — mobile không làm
          // gì thêm). Partial failure → nhánh dưới (AC 5.7 giữ nguyên).
          message: '$createdCount món đã ghi vào sổ giá',
          tone: AppSnackBarTone.success,
        );
        widget.onFinished();
      } else {
        AppSnackBar.show(
          context: context,
          message: 'Đã thêm $createdCount/${selected.length} món — '
              '${failedByUid.length} món chưa lưu, hãy sửa rồi thử lại.',
          tone: AppSnackBarTone.warning,
          duration: const Duration(seconds: 4),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'RATE_LIMITED') {
        // AC 5.9 — throttle 5 req/phút (BR-19): message thân thiện, giữ nguyên
        // màn, không crash.
        AppSnackBar.show(
          context: context,
          message: 'Bạn đang thao tác quá nhanh, thử lại sau ít phút',
          tone: AppSnackBarTone.warning,
        );
      } else {
        // AC 5.10 — NETWORK_ERROR (statusCode null) maps sang message tiếng Việt
        // rõ ràng; TOÀN BỘ state confirm giữ nguyên (không reset gì ở đây).
        AppSnackBar.show(context: context, message: apiErrorMessage(e), tone: AppSnackBarTone.danger);
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: 'Đã có lỗi xảy ra. Vui lòng thử lại.',
          tone: AppSnackBarTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = context.snap;

    // Danh mục user (offline-first: categoriesProvider tự fallback local).
    final catsAsync = ref.watch(categoriesProvider);
    final List<CategoryModel> categories = catsAsync.valueOrNull ?? const [];

    // Dữ liệu đối chiếu trùng + auto-match — load xong recompute toàn bộ dòng
    // (badge/tự tick hiện đúng mà không đợi user gõ lại gì).
    final entriesAsync = ref.watch(ocrRecentEntriesProvider);
    final entries = entriesAsync.valueOrNull ?? const <ReceiptHistoryEntry>[];
    final matchAsync = ref.watch(ocrMatchRecordsProvider);
    final matchRecords =
        matchAsync.valueOrNull ?? const <PriceHistoryMatchRecord>[];
    if (!identical(entries, _entries) ||
        !identical(matchRecords, _matchRecords)) {
      _entries = entries;
      _matchRecords = matchRecords;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recomputeAll();
      });
    }

    final total = _lines.fold(0, (s, l) => s + l.item.price);
    final quality = widget.result.quality;
    final isGemini = widget.result.source == OcrSource.geminiVision;
    final bannerColor =
        isGemini ? colors.onTintPrimary : _qualityColor(context, quality);

    return Column(children: [
      // Source & Quality banner
      Container(
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bannerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          border: Border.all(color: bannerColor.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(
            isGemini ? Icons.auto_awesome : _qualityIcon(quality),
            color: bannerColor,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isGemini
                  ? '✨ Phân tích bởi Gemini AI Vision'
                  : _qualityText(quality),
              style: context.text.bodySmall
                  ?.copyWith(color: bannerColor, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            key: const Key('ocrScreen_retakeButton'),
            onTap: widget.onRetake,
            child: Text('Chụp lại',
                style: context.text.labelLarge
                    ?.copyWith(color: context.cs.primary, fontSize: 12)),
          ),
        ]),
      ),

      // Items list
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Store & Date card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront_outlined,
                          size: 18, color: context.cs.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          key: const Key('ocrScreen_storeField'),
                          controller: _storeController,
                          decoration: const InputDecoration(
                            hintText: 'Tên siêu thị / cửa hàng (tùy chọn)',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
                            border: InputBorder.none,
                            filled: false,
                          ),
                          style: context.text.titleSmall
                              ?.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  if (widget.result.purchaseDate != null) ...[
                    const Divider(height: AppSpacing.md + 2),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: context.cs.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Ngày mua: ${widget.result.purchaseDate!.day}/'
                          '${widget.result.purchaseDate!.month}/'
                          '${widget.result.purchaseDate!.year}',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Row(children: [
              Text('Nhận diện được ${_lines.length} mặt hàng',
                  style: context.text.titleSmall),
              const Spacer(),
              // Tổng tiền — MoneyText tabular figures, màu brand.
              MoneyText(
                key: const Key('ocrScreen_total'),
                amount: total,
                colored: true,
              ),
            ]),
            if (widget.result.totalFromReceipt != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tổng trên hóa đơn: ${CurrencyFormatter.format(widget.result.totalFromReceipt!)}  '
                '${(total - widget.result.totalFromReceipt!).abs() < 1000 ? "Khớp" : "Lệch"}',
                style: context.text.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OcrResultList(
              lines:      _lines,
              categories: categories,
              onEdit:     _edit,
              onRemove:   _removeLine,
              onAdd:      _addLine,
            ),
          ],
        ),
      ),

      // Bottom action — M-1 AC 5.23: selector 2 chế độ ("Gửi tất cả" mặc định
      // / "Chỉ dòng đã review", không persist) + AC 5.4/5.12: N = số dòng sẽ
      // thêm THEO CHẾ ĐỘ hiện hành; 0 → disabled (không gửi request rỗng).
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 0),
        child: Row(children: [
          Expanded(
            child: ChoiceChip(
              key: const Key('ocrConfirm_mode_all'),
              label: Text('Gửi tất cả',
                  style: context.text.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight:
                        _sendAll ? FontWeight.w700 : FontWeight.w400,
                  )),
              selected: _sendAll,
              onSelected: (_) => setState(() => _sendAll = true),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ChoiceChip(
              key: const Key('ocrConfirm_mode_reviewed'),
              label: Text('Chỉ dòng đã review',
                  style: context.text.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight:
                        !_sendAll ? FontWeight.w700 : FontWeight.w400,
                  )),
              selected: !_sendAll,
              onSelected: (_) => setState(() => _sendAll = false),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: PrimaryButton(
          key: const Key('ocrConfirm_submitButton'),
          label: 'Xác nhận thêm $_confirmCount món',
          loading: _submitting,
          onPressed: _confirmCount == 0 ? null : _submit,
        ),
      ),
    ]);
  }

  Color _qualityColor(BuildContext context, OcrQuality q) => switch (q) {
    OcrQuality.good => context.snap.success,
    OcrQuality.fair => context.snap.warning,
    OcrQuality.poor => context.snap.danger,
  };

  IconData _qualityIcon(OcrQuality q) => switch (q) {
    OcrQuality.good => Icons.check_circle_outline,
    OcrQuality.fair => Icons.warning_amber_outlined,
    OcrQuality.poor => Icons.error_outline,
  };

  String _qualityText(OcrQuality q) => switch (q) {
    OcrQuality.good => 'Nhận diện tốt — vui lòng kiểm tra lại',
    OcrQuality.fair => 'Một số mục cần kiểm tra (vàng)',
    OcrQuality.poor => 'Chất lượng thấp — nên chụp lại',
  };
}
