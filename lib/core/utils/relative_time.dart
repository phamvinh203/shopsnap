/// F-#12 (AC 12.9) — thời gian tương đối cho Notification Feed, thuần và unit
/// test độc lập. KHÔNG sửa `date_helper.dart` (file cấm) — helper mới đặt
/// riêng tại đây vì chỉ phục vụ feed.
library;

/// 'Vừa xong' → 'n phút trước' → 'n giờ trước' → 'n ngày trước' → dd/MM/yyyy.
///
/// [now] inject để test. Thời điểm tương lai (clock lệch) coi như 'Vừa xong'.
String formatRelativeTime(DateTime dateTime, {required DateTime now}) {
  final diff = now.difference(dateTime);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';

  final d = '${dateTime.day.toString().padLeft(2, '0')}/'
      '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  return d;
}
