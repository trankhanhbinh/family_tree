import 'package:familytree/features/person/domain/memorial_date.dart';
import 'package:familytree/features/person/domain/person.dart';

/// Số ngày tới (tính cả hôm nay) mà màn "Ngày giỗ sắp tới" liệt kê.
const int kMemorialLookaheadDays = 60;

/// Một người có giỗ sắp tới.
class UpcomingMemorial {
  const UpcomingMemorial({
    required this.person,
    required this.lunarDay,
    required this.lunarMonth,
    required this.isLeap,
    required this.date,
    required this.daysLeft,
  });

  final Person person;
  final int lunarDay;
  final int lunarMonth;
  final bool isLeap;

  /// Ngày dương lịch của giỗ (chỉ ngày/tháng/năm).
  final DateTime date;

  /// Số ngày còn lại tính từ hôm nay (0 = hôm nay).
  final int daysLeft;
}

class UpcomingMemorials {
  const UpcomingMemorials({required this.items, required this.missingCount});

  /// Danh sách giỗ trong khoảng, gần nhất trước.
  final List<UpcomingMemorial> items;

  /// Số người đã mất chưa có đủ ngày + tháng giỗ.
  final int missingCount;
}

int _compareUpcoming(UpcomingMemorial a, UpcomingMemorial b) {
  final byDays = a.daysLeft.compareTo(b.daysLeft);
  if (byDays != 0) {
    return byDays;
  }
  final byName = a.person.fullName.compareTo(b.person.fullName);
  if (byName != 0) {
    return byName;
  }
  return a.person.id.compareTo(b.person.id);
}

/// Lọc người đã mất (chưa xóa) có giỗ từ hôm nay đến [withinDays] ngày tới.
/// Người đã mất mà thiếu ngày hoặc tháng giỗ được đếm vào missingCount.
/// Dữ liệu giỗ không hợp lệ (ví dụ ngày 31) bị bỏ qua, không tính là thiếu.
UpcomingMemorials buildUpcomingMemorials({
  required List<Person> people,
  required DateTime today,
  int withinDays = kMemorialLookaheadDays,
}) {
  final base = dateOnly(today);
  final items = <UpcomingMemorial>[];
  var missing = 0;

  for (final person in people) {
    if (person.isAlive || person.deletedAt != null) {
      continue;
    }
    final day = person.memorialLunarDay;
    final month = person.memorialLunarMonth;
    if (day == null || month == null) {
      missing++;
      continue;
    }
    final next = nextMemorialDate(
      lunarDay: day,
      lunarMonth: month,
      today: base,
    );
    if (next == null) {
      continue;
    }
    final daysLeft = daysBetween(base, next);
    if (daysLeft > withinDays) {
      continue;
    }
    items.add(
      UpcomingMemorial(
        person: person,
        lunarDay: day,
        lunarMonth: month,
        isLeap: person.memorialIsLeap,
        date: next,
        daysLeft: daysLeft,
      ),
    );
  }

  items.sort(_compareUpcoming);
  return UpcomingMemorials(items: items, missingCount: missing);
}