import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/snap_colors.dart';
import '../../core/utils/api_error_messages.dart';
import '../../providers/auth_provider.dart';
import '../../providers/export_provider.dart';
import '../../services/export_api_service.dart';
import '../../widgets/ui/ui.dart';

/// Khoảng dữ liệu export (AC 11.1): mặc định tháng hiện tại; tuỳ chọn "tất cả".
enum _ExportRange { thisMonth, all }

/// Màn xuất dữ liệu (/export) — F-#11.
///
/// Chọn format CSV (mặc định) / JSON + khoảng dữ liệu → bấm Export → loading →
/// lưu file `shopsnap_export_YYYYMMDD.(csv|json)` vào Documents → mở system
/// share sheet (AC 11.2). Thành công lưu [lastExportProvider] để chia sẻ lại
/// trong phiên không cần export lần nữa (AC 11.3).
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportFormat _format = ExportFormat.csv; // mặc định CSV (AC 11.1)
  _ExportRange _range = _ExportRange.thisMonth;
  bool _exporting = false;

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// Khoảng ngày tương ứng lựa chọn. [ASSUMPTION] "Tất cả" = 366 ngày gần
  /// nhất — BE /summary/export giới hạn tối đa 366 ngày (BR-18), chưa có
  /// param "from beginning"; khi BE hỗ trợ sẽ thay đây.
  (String, String) _resolveRange() {
    final today = DateTime.now();
    return switch (_range) {
      _ExportRange.thisMonth => (
          _fmt(DateTime(today.year, today.month, 1)),
          _fmt(today),
        ),
      _ExportRange.all => (
          _fmt(today.subtract(const Duration(days: 365))),
          _fmt(today),
        ),
    };
  }

  Future<void> _export() async {
    if (_exporting) return;
    final service = ref.read(exportServiceProvider);

    setState(() => _exporting = true);
    try {
      final (from, to) = _resolveRange();
      final outcome = await service.exportAndSave(
        format: _format,
        dateFrom: from,
        dateTo: to,
      );

      ref.read(lastExportProvider.notifier).state = outcome;

      // AC 11.2: bấm Export → loading → tạo file → mở system share sheet.
      await service.share(outcome.file.path);

      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: 'Đã tạo file ${outcome.filename} — sẵn sàng chia sẻ',
          tone: AppSnackBarTone.success,
        );
      }
    } catch (e) {
      // AC 11.4: lỗi rõ ràng (mất mạng/5xx), nút Export vẫn bấm được để thử
      // lại; timeout của ApiClient đảm bảo không treo loading vô hạn.
      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: 'Không xuất được dữ liệu: ${apiErrorMessage(e)}',
          tone: AppSnackBarTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareAgain() async {
    final last = ref.read(lastExportProvider);
    if (last == null) return;
    try {
      await ref.read(exportServiceProvider).share(last.file.path);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(
          context: context,
          message: 'Không mở được chia sẻ. Vui lòng thử lại.',
          tone: AppSnackBarTone.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authenticated =
        ref.watch(authStateProvider).valueOrNull?.isAuthenticated == true;
    final last = ref.watch(lastExportProvider);

    return AppScaffold(
      title: 'Xuất dữ liệu',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Chưa đăng nhập → disable + hint (auth gate mềm) ──────────────
          if (!authenticated) ...[
            AppCard(
              tint: context.snap.warning.withOpacity(0.10),
              child: Row(
                key: const Key('exportScreen_loginHint'),
                children: [
                  Icon(Icons.lock_outline, color: context.snap.warning),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Đăng nhập để tải dữ liệu từ máy chủ ra file.',
                      style: context.text.bodyMedium,
                    ),
                  ),
                  TextButton(
                    key: const Key('exportScreen_loginAction'),
                    onPressed: () => context.push('/login'),
                    child: const Text('Đăng nhập'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── Chọn format (AC 11.1 — mặc định CSV) ─────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Định dạng file', style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<ExportFormat>(
                  key: const Key('exportScreen_formatSection'),
                  segments: const [
                    ButtonSegment(
                      value: ExportFormat.csv,
                      icon: Icon(Icons.table_chart_outlined,
                          key: Key('exportScreen_formatCsv')),
                      label: Text('CSV'),
                    ),
                    ButtonSegment(
                      value: ExportFormat.json,
                      icon: Icon(Icons.data_object_rounded,
                          key: Key('exportScreen_formatJson')),
                      label: Text('JSON'),
                    ),
                  ],
                  selected: {_format},
                  onSelectionChanged: authenticated && !_exporting
                      ? (s) => setState(() => _format = s.first)
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _format == ExportFormat.csv
                      ? 'Bảng tính mở được bằng Excel (Unicode UTF-8).'
                      : 'Dữ liệu gốc dạng JSON — phù hợp để xử lý bằng công cụ khác.',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Chọn khoảng dữ liệu (AC 11.1 — mặc định tháng hiện tại) ──────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Khoảng dữ liệu', style: context.text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<_ExportRange>(
                  key: const Key('exportScreen_rangeSection'),
                  segments: const [
                    ButtonSegment(
                      value: _ExportRange.thisMonth,
                      icon: Icon(Icons.calendar_month_outlined,
                          key: Key('exportScreen_rangeThisMonth')),
                      label: Text('Tháng này'),
                    ),
                    ButtonSegment(
                      value: _ExportRange.all,
                      icon: Icon(Icons.date_range_outlined,
                          key: Key('exportScreen_rangeAll')),
                      label: Text('Tất cả'),
                    ),
                  ],
                  selected: {_range},
                  onSelectionChanged: authenticated && !_exporting
                      ? (s) => setState(() => _range = s.first)
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _range == _ExportRange.thisMonth
                      ? 'Từ đầu tháng đến hôm nay.'
                      // [ASSUMPTION] BE giới hạn 366 ngày (BR-18).
                      : '366 ngày gần nhất (giới hạn của máy chủ).',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Nút Export — loading thay label bằng spinner (AC 11.2), lỗi
          //    hoặc xong → về lại bình thường để thử lại (AC 11.4) ──────────
          PrimaryButton(
            key: const Key('exportScreen_exportButton'),
            label: 'Export',
            loading: _exporting,
            onPressed: authenticated ? _export : null,
          ),

          // ── Chia sẻ lại trong phiên (AC 11.3) ────────────────────────────
          if (last != null) ...[
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              key: const Key('exportScreen_shareAgainButton'),
              label: 'Chia sẻ lại ${last.filename}',
              onPressed: _exporting ? null : _shareAgain,
            ),
          ],
        ],
      ),
    );
  }
}
