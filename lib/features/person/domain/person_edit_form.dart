import 'package:familytree/features/person/domain/person.dart';

const int kPersonNameMaxLength = 100;
const int kPersonTextMaxLength = 200;
const int kPersonNotesMaxLength = 2000;
const int kRequestNoteMaxLength = 500;
const int kMinYear = 1000;

/// Nhóm ô có thể báo lỗi (theo thứ tự xuất hiện trên màn hình).
enum PersonField { fullName, birth, death, memorial }

/// Giá trị người dùng đang nhập (chuỗi thô, chưa chuẩn hóa).
class PersonFormValues {
  PersonFormValues({
    this.fullName = '',
    this.otherName = '',
    this.gender = Gender.male,
    this.branchId,
    this.birthDay = '',
    this.birthMonth = '',
    this.birthYear = '',
    this.birthPlace = '',
    this.isAlive = true,
    this.deathDay = '',
    this.deathMonth = '',
    this.deathYear = '',
    this.burialPlace = '',
    this.memorialDay = '',
    this.memorialMonth = '',
    this.memorialIsLeap = false,
    this.notes = '',
  });

  factory PersonFormValues.fromPerson(Person p) {
    final birth = _splitDate(p.birthDate, p.birthYear);
    final death = _splitDate(p.deathDate, p.deathYear);
    return PersonFormValues(
      fullName: p.fullName,
      otherName: p.otherName ?? '',
      gender: p.gender,
      branchId: p.branchId,
      birthDay: birth.day,
      birthMonth: birth.month,
      birthYear: birth.year,
      birthPlace: p.birthPlace ?? '',
      isAlive: p.isAlive,
      deathDay: death.day,
      deathMonth: death.month,
      deathYear: death.year,
      burialPlace: p.burialPlace ?? '',
      memorialDay: p.memorialLunarDay?.toString() ?? '',
      memorialMonth: p.memorialLunarMonth?.toString() ?? '',
      memorialIsLeap: p.memorialIsLeap,
      notes: p.notes ?? '',
    );
  }

  String fullName;
  String otherName;
  Gender gender;
  String? branchId;
  String birthDay;
  String birthMonth;
  String birthYear;
  String birthPlace;
  bool isAlive;
  String deathDay;
  String deathMonth;
  String deathYear;
  String burialPlace;
  String memorialDay;
  String memorialMonth;
  bool memorialIsLeap;
  String notes;

  List<Object?> get _props => [
        fullName,
        otherName,
        gender,
        branchId,
        birthDay,
        birthMonth,
        birthYear,
        birthPlace,
        isAlive,
        deathDay,
        deathMonth,
        deathYear,
        burialPlace,
        memorialDay,
        memorialMonth,
        memorialIsLeap,
        notes,
      ];

  /// Hai bộ giá trị giống hệt nhau (dùng để biết form đã bị sửa chưa).
  bool sameAs(PersonFormValues other) {
    final a = _props;
    final b = other._props;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

({String day, String month, String year}) _splitDate(DateTime? date, int? year) {
  if (date != null) {
    return (day: '${date.day}', month: '${date.month}', year: '${date.year}');
  }
  return (day: '', month: '', year: year == null ? '' : '$year');
}

/// Kết quả đọc bộ ba Ngày/Tháng/Năm.
/// - cả ba trống: không có ngày (isEmpty)
/// - chỉ năm: year có giá trị, date = null
/// - đủ ba: date và year cùng có giá trị
class ParsedDate {
  const ParsedDate({this.date, this.year, this.error});

  final DateTime? date;
  final int? year;
  final String? error;

  bool get isEmpty => date == null && year == null && error == null;
}

ParsedDate parseDateParts({
  required String day,
  required String month,
  required String year,
  required int nowYear,
}) {
  final d = day.trim();
  final m = month.trim();
  final y = year.trim();

  if (d.isEmpty && m.isEmpty && y.isEmpty) {
    return const ParsedDate();
  }
  if (y.isEmpty) {
    return const ParsedDate(error: 'Vui lòng nhập năm.');
  }
  final yearValue = int.tryParse(y);
  if (yearValue == null || yearValue < kMinYear || yearValue > nowYear) {
    return ParsedDate(error: 'Năm phải từ $kMinYear đến $nowYear.');
  }
  if (d.isEmpty && m.isEmpty) {
    return ParsedDate(year: yearValue);
  }
  if (d.isEmpty || m.isEmpty) {
    return const ParsedDate(
      error: 'Hãy nhập cả ngày và tháng, hoặc để trống cả hai.',
    );
  }
  final dayValue = int.tryParse(d);
  final monthValue = int.tryParse(m);
  if (dayValue == null || monthValue == null) {
    return const ParsedDate(error: 'Ngày hoặc tháng không hợp lệ.');
  }
  final date = DateTime(yearValue, monthValue, dayValue);
  if (date.year != yearValue ||
      date.month != monthValue ||
      date.day != dayValue) {
    return ParsedDate(error: 'Ngày $dayValue/$monthValue/$yearValue không có thật.');
  }
  return ParsedDate(date: date, year: yearValue);
}

/// Trả về các lỗi theo nhóm ô (rỗng = hợp lệ).
Map<PersonField, String> validatePersonForm(
  PersonFormValues values, {
  required int nowYear,
}) {
  final errors = <PersonField, String>{};

  final name = _collapseSpaces(values.fullName);
  if (name.isEmpty) {
    errors[PersonField.fullName] = 'Vui lòng nhập họ và tên.';
  } else if (name.length < 2) {
    errors[PersonField.fullName] = 'Họ và tên quá ngắn.';
  } else if (name.length > kPersonNameMaxLength) {
    errors[PersonField.fullName] =
        'Họ và tên quá dài (tối đa $kPersonNameMaxLength ký tự).';
  }

  final birth = parseDateParts(
    day: values.birthDay,
    month: values.birthMonth,
    year: values.birthYear,
    nowYear: nowYear,
  );
  if (birth.error != null) {
    errors[PersonField.birth] = 'Ngày sinh: ${birth.error}';
  }

  if (!values.isAlive) {
    final death = parseDateParts(
      day: values.deathDay,
      month: values.deathMonth,
      year: values.deathYear,
      nowYear: nowYear,
    );
    if (death.error != null) {
      errors[PersonField.death] = 'Ngày mất: ${death.error}';
    } else if (birth.error == null) {
      final birthDate = birth.date;
      final deathDate = death.date;
      final birthYear = birth.year;
      final deathYear = death.year;
      if (birthDate != null &&
          deathDate != null &&
          deathDate.isBefore(birthDate)) {
        errors[PersonField.death] = 'Ngày mất không thể trước ngày sinh.';
      } else if (birthYear != null &&
          deathYear != null &&
          deathYear < birthYear) {
        errors[PersonField.death] =
            'Năm mất ($deathYear) không thể nhỏ hơn năm sinh ($birthYear).';
      }
    }

    final memorialError = _validateMemorial(values);
    if (memorialError != null) {
      errors[PersonField.memorial] = memorialError;
    }
  }

  return errors;
}

String? _validateMemorial(PersonFormValues values) {
  final d = values.memorialDay.trim();
  final m = values.memorialMonth.trim();
  if (d.isEmpty && m.isEmpty) {
    return null;
  }
  if (d.isEmpty || m.isEmpty) {
    return 'Ngày giỗ: hãy nhập cả ngày và tháng, hoặc để trống cả hai.';
  }
  final dayValue = int.tryParse(d);
  final monthValue = int.tryParse(m);
  if (dayValue == null || dayValue < 1 || dayValue > 30) {
    return 'Ngày giỗ (âm lịch) phải từ 1 đến 30.';
  }
  if (monthValue == null || monthValue < 1 || monthValue > 12) {
    return 'Tháng giỗ (âm lịch) phải từ 1 đến 12.';
  }
  return null;
}

/// Tạo payload cho change_requests (update): CHỈ gồm cột thực sự thay đổi.
/// Ném ArgumentError nếu dữ liệu chưa hợp lệ (gọi validatePersonForm trước).
///
/// Quy tắc:
/// - xóa trắng một ô -> gửi null
/// - chuyển "đã mất" -> "còn sống": gửi null cho toàn bộ dữ liệu mất/giỗ
/// - người vốn còn sống và vẫn còn sống: không đụng tới cột mất/giỗ
Map<String, dynamic> buildPersonUpdatePayload(
  Person original,
  PersonFormValues values, {
  required int nowYear,
}) {
  final errors = validatePersonForm(values, nowYear: nowYear);
  if (errors.isNotEmpty) {
    throw ArgumentError('Dữ liệu chưa hợp lệ: ${errors.values.join('; ')}');
  }

  final payload = <String, dynamic>{};
  void put(String column, Object? before, Object? after) {
    if (before != after) {
      payload[column] = after;
    }
  }

  put(
    'full_name',
    _collapseSpaces(original.fullName),
    _collapseSpaces(values.fullName),
  );
  put('other_name', _text(original.otherName), _text(values.otherName));
  put('gender', original.gender.name, values.gender.name);
  put('branch_id', original.branchId, values.branchId);

  final birth = parseDateParts(
    day: values.birthDay,
    month: values.birthMonth,
    year: values.birthYear,
    nowYear: nowYear,
  );
  put('birth_date', _dateKey(original.birthDate), _dateKey(birth.date));
  put('birth_year', original.birthYear ?? original.birthDate?.year, birth.year);
  put('birth_place', _text(original.birthPlace), _text(values.birthPlace));
  put('is_alive', original.isAlive, values.isAlive);

  final alive = values.isAlive;
  if (!(alive && original.isAlive)) {
    final death = alive
        ? const ParsedDate()
        : parseDateParts(
            day: values.deathDay,
            month: values.deathMonth,
            year: values.deathYear,
            nowYear: nowYear,
          );
    put('death_date', _dateKey(original.deathDate), _dateKey(death.date));
    put(
      'death_year',
      original.deathYear ?? original.deathDate?.year,
      death.year,
    );
    put(
      'burial_place',
      _text(original.burialPlace),
      alive ? null : _text(values.burialPlace),
    );

    final memorialDay = alive ? null : int.tryParse(values.memorialDay.trim());
    final memorialMonth =
        alive ? null : int.tryParse(values.memorialMonth.trim());
    final hasMemorial = memorialDay != null && memorialMonth != null;
    put(
      'memorial_lunar_day',
      original.memorialLunarDay,
      hasMemorial ? memorialDay : null,
    );
    put(
      'memorial_lunar_month',
      original.memorialLunarMonth,
      hasMemorial ? memorialMonth : null,
    );
    put(
      'memorial_is_leap',
      original.memorialIsLeap,
      hasMemorial && values.memorialIsLeap,
    );
  }

  put('notes', _notes(original.notes), _notes(values.notes));
  return payload;
}

String _collapseSpaces(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String? _text(String? input) {
  final t = _collapseSpaces(input ?? '');
  return t.isEmpty ? null : t;
}

String? _notes(String? input) {
  final t = (input ?? '').trim();
  return t.isEmpty ? null : t;
}

String? _dateKey(DateTime? d) {
  if (d == null) {
    return null;
  }
  final yyyy = d.year.toString().padLeft(4, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}