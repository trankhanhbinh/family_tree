import 'package:familytree/core/utils/lunar_converter.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';

/// Kết quả tính ngày giỗ từ ngày mất. Thành công: day/month/isLeap có giá trị.
/// Thất bại: error là câu tiếng Việt để hiện cho người dùng.
class MemorialFromDeath {
  const MemorialFromDeath({
    this.day,
    this.month,
    this.isLeap = false,
    this.error,
  });

  final int? day;
  final int? month;
  final bool isLeap;
  final String? error;

  bool get ok => error == null && day != null && month != null;
}

/// Ngày giỗ = ngày âm lịch của ngày mất. Cần ngày mất đủ ngày, tháng, năm.
MemorialFromDeath computeMemorialFromDeath({
  required String deathDay,
  required String deathMonth,
  required String deathYear,
  required int nowYear,
}) {
  final parsed = parseDateParts(
    day: deathDay,
    month: deathMonth,
    year: deathYear,
    nowYear: nowYear,
  );
  if (parsed.isEmpty) {
    return const MemorialFromDeath(
      error: 'Bạn chưa nhập ngày mất.\n\n'
          'Hãy nhập đủ ngày, tháng, năm mất ở phần "Tình trạng" '
          'phía trên rồi bấm lại.',
    );
  }
  final parseError = parsed.error;
  if (parseError != null) {
    return MemorialFromDeath(
      error: 'Ngày mất chưa hợp lệ: $parseError\n\n'
          'Hãy sửa ô "Ngày mất" ở phần "Tình trạng" rồi bấm lại.',
    );
  }
  final date = parsed.date;
  if (date == null) {
    return const MemorialFromDeath(
      error: 'Mới có năm mất, chưa đủ ngày và tháng.\n\n'
          'Cần đủ ngày, tháng và năm mất thì mới tính được ngày giỗ. '
          'Nếu không biết rõ, bạn có thể nhập tay ngày giỗ ở các ô bên dưới.',
    );
  }
  final lunar = solarToLunar(date);
  if (lunar == null) {
    return MemorialFromDeath(
      error: 'Ngày mất nằm ngoài phạm vi tính âm lịch '
          '(từ năm $minLunarSupportedYear đến năm $maxLunarSupportedYear).\n\n'
          'Bạn có thể nhập tay ngày giỗ ở các ô bên dưới.',
    );
  }
  return MemorialFromDeath(
    day: lunar.day,
    month: lunar.month,
    isLeap: lunar.isLeap,
  );
}

/// Ô giỗ trong form đã có nhập gì chưa (ngày hoặc tháng khác trống).
bool hasMemorialInput(String day, String month) {
  return day.trim().isNotEmpty || month.trim().isNotEmpty;
}

/// Giá trị đang nhập có giống hệt kết quả tính được không.
bool isSameMemorial({
  required String currentDay,
  required String currentMonth,
  required bool currentIsLeap,
  required MemorialFromDeath computed,
}) {
  return computed.ok &&
      int.tryParse(currentDay.trim()) == computed.day &&
      int.tryParse(currentMonth.trim()) == computed.month &&
      currentIsLeap == computed.isLeap;
}