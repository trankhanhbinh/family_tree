import 'package:familytree/core/utils/lunar_converter.dart';

/// Bỏ phần giờ, giữ ngày/tháng/năm (giờ máy).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Số ngày từ [from] đến [to] (chỉ tính ngày, bỏ giờ, không lệch do giờ mùa hè).
/// Âm nếu [to] trước [from].
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Ngày dương của giỗ trong năm âm [lunarYear].
///
/// Quy ước: dùng THÁNG THƯỜNG (không nhuận) có cùng số tháng. Nếu giỗ vào
/// ngày 30 mà tháng đó chỉ có 29 ngày thì giỗ vào ngày 29.
/// Trả null nếu dữ liệu không hợp lệ hoặc ngoài phạm vi thư viện.
DateTime? memorialSolarDateInLunarYear({
  required int lunarDay,
  required int lunarMonth,
  required int lunarYear,
}) {
  if (lunarDay < 1 || lunarDay > 30 || lunarMonth < 1 || lunarMonth > 12) {
    return null;
  }
  final exact = lunarToSolar(
    LunarDate(
      day: lunarDay,
      month: lunarMonth,
      year: lunarYear,
      isLeap: false,
    ),
  );
  if (exact != null) {
    return exact;
  }
  if (lunarDay == 30) {
    return lunarToSolar(
      LunarDate(day: 29, month: lunarMonth, year: lunarYear, isLeap: false),
    );
  }
  return null;
}

/// Ngày giỗ kế tiếp tính từ [today] (nếu giỗ đúng hôm nay thì trả về hôm nay).
/// Chỉ dùng ngày của [today], bỏ giờ. Trả null nếu dữ liệu không hợp lệ
/// hoặc ngoài phạm vi thư viện.
DateTime? nextMemorialDate({
  required int lunarDay,
  required int lunarMonth,
  required DateTime today,
}) {
  final base = dateOnly(today);
  final lunarToday = solarToLunar(base);
  if (lunarToday == null) {
    return null;
  }
  for (var offset = 0; offset <= 1; offset++) {
    final candidate = memorialSolarDateInLunarYear(
      lunarDay: lunarDay,
      lunarMonth: lunarMonth,
      lunarYear: lunarToday.year + offset,
    );
    if (candidate != null && !candidate.isBefore(base)) {
      return candidate;
    }
  }
  return null;
}