import 'package:flutter_test/flutter_test.dart';
import 'package:shopsnap/core/utils/relative_time.dart';

/// F-#12 (AC 12.9) — thời gian tương đối trên Notification Feed.
void main() {
  final now = DateTime(2026, 9, 15, 10, 30);

  test('dưới 1 phút → "Vừa xong"', () {
    expect(
      formatRelativeTime(now.subtract(const Duration(seconds: 20)), now: now),
      'Vừa xong',
    );
    // Tương lai (clock lệch giữa máy và server) → vẫn "Vừa xong", không âm.
    expect(
      formatRelativeTime(now.add(const Duration(minutes: 5)), now: now),
      'Vừa xong',
    );
  });

  test('dưới 1 giờ → "n phút trước"', () {
    expect(
      formatRelativeTime(now.subtract(const Duration(minutes: 1)), now: now),
      '1 phút trước',
    );
    expect(
      formatRelativeTime(now.subtract(const Duration(minutes: 59)), now: now),
      '59 phút trước',
    );
  });

  test('dưới 24 giờ → "n giờ trước"', () {
    expect(
      formatRelativeTime(now.subtract(const Duration(hours: 5)), now: now),
      '5 giờ trước',
    );
    expect(
      formatRelativeTime(now.subtract(const Duration(hours: 23)), now: now),
      '23 giờ trước',
    );
  });

  test('dưới 7 ngày → "n ngày trước"', () {
    expect(
      formatRelativeTime(now.subtract(const Duration(days: 1)), now: now),
      '1 ngày trước',
    );
    expect(
      formatRelativeTime(now.subtract(const Duration(days: 6)), now: now),
      '6 ngày trước',
    );
  });

  test('≥ 7 ngày → dd/MM/yyyy (không phụ thuộc giờ trong ngày)', () {
    expect(
      formatRelativeTime(now.subtract(const Duration(days: 7)), now: now),
      '08/09/2026',
    );
    expect(
      formatRelativeTime(DateTime(2025, 12, 31, 23, 59), now: now),
      '31/12/2025',
    );
  });
}
