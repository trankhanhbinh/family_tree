import 'package:vnlunar/vnlunar.dart'
    show convertLunar2Solar, convertSolar2Lunar;

/// Năm dương lịch mà thư viện vnlunar hỗ trợ.
const int minLunarSupportedYear = 1800;
const int maxLunarSupportedYear = 2199;

/// Âm lịch Việt Nam tính theo GMT+7 (khác lịch Trung Quốc GMT+8).
const int _vietnamTimeZone = 7;

/// Một ngày âm lịch. [isLeap] = true nếu là tháng nhuận.
class LunarDate {
  const LunarDate({
    required this.day,
    required this.month,
    required this.year,
    required this.isLeap,
  });

  final int day;
  final int month;
  final int year;
  final bool isLeap;

  @override
  bool operator ==(Object other) {
    return other is LunarDate &&
        other.day == day &&
        other.month == month &&
        other.year == year &&
        other.isLeap == isLeap;
  }

  @override
  int get hashCode => Object.hash(day, month, year, isLeap);

  @override
  String toString() {
    final leap = isLeap ? ' nhuận' : '';
    return 'LunarDate($day/$month$leap/$year)';
  }
}

/// Đổi ngày dương lịch sang âm lịch. Chỉ dùng ngày/tháng/năm của [date]
/// (bỏ qua giờ). Trả null nếu năm dương nằm ngoài 1800-2199.
LunarDate? solarToLunar(DateTime date) {
  if (date.year < minLunarSupportedYear || date.year > maxLunarSupportedYear) {
    return null;
  }
  final List<int> r = convertSolar2Lunar(
    date.day,
    date.month,
    date.year,
    _vietnamTimeZone,
  );
  if (r.length < 4 || r[0] < 1 || r[1] < 1) {
    return null;
  }
  return LunarDate(day: r[0], month: r[1], year: r[2], isLeap: r[3] == 1);
}

/// Đổi ngày âm lịch sang dương lịch. Trả null nếu ngày âm không tồn tại
/// (ví dụ ngày 30 của tháng chỉ có 29 ngày, hoặc tháng nhuận không có),
/// hoặc nằm ngoài phạm vi hỗ trợ.
///
/// Thuật toán gốc không báo lỗi với ngày không tồn tại mà tràn sang tháng
/// sau, nên ở đây quy đổi ngược lại để kiểm tra.
DateTime? lunarToSolar(LunarDate lunar) {
  if (lunar.day < 1 || lunar.day > 30) {
    return null;
  }
  if (lunar.month < 1 || lunar.month > 12) {
    return null;
  }
  if (lunar.year < minLunarSupportedYear ||
      lunar.year > maxLunarSupportedYear) {
    return null;
  }
  final List<int> r = convertLunar2Solar(
    lunar.day,
    lunar.month,
    lunar.year,
    lunar.isLeap,
    _vietnamTimeZone,
  );
  if (r.length < 3 || r[0] < 1 || r[1] < 1 || r[2] < 1) {
    return null;
  }
  final DateTime solar = DateTime(r[2], r[1], r[0]);
  final LunarDate? back = solarToLunar(solar);
  if (back != lunar) {
    return null;
  }
  return solar;
}