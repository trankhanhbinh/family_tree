import 'package:familytree/core/utils/date_format.dart';

/// "15 tháng 7 (âm lịch)", tháng nhuận: "2 tháng 2 nhuận (âm lịch)".
String formatMemorialLunar({
  required int day,
  required int month,
  required bool isLeap,
}) {
  final leap = isLeap ? ' nhuận' : '';
  return '$day tháng $month$leap (âm lịch)';
}

/// "hôm nay", "ngày mai", "còn 12 ngày".
String formatDaysLeft(int days) {
  if (days < 0) {
    return 'đã qua';
  }
  if (days == 0) {
    return 'hôm nay';
  }
  if (days == 1) {
    return 'ngày mai';
  }
  return 'còn $days ngày';
}

/// "18/08/2024 (còn 12 ngày)".
String formatNextMemorial(DateTime date, int daysLeft) {
  return '${formatDate(date)} (${formatDaysLeft(daysLeft)})';
}

/// Mô tả giá trị giỗ đang nhập trong form (có thể chưa đủ hoặc sai).
String describeMemorialInput({
  required String day,
  required String month,
  required bool isLeap,
}) {
  final d = int.tryParse(day.trim());
  final m = int.tryParse(month.trim());
  if (d != null && m != null && d >= 1 && d <= 30 && m >= 1 && m <= 12) {
    return formatMemorialLunar(day: d, month: m, isLeap: isLeap);
  }
  final dayText = day.trim().isEmpty ? '?' : day.trim();
  final monthText = month.trim().isEmpty ? '?' : month.trim();
  return 'ngày $dayText, tháng $monthText';
}