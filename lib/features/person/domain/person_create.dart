import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/tree/domain/marriage.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

// ---------- Hôn nhân: giá trị form + kiểm tra ----------

enum MarriageField { start, end }

class MarriageFormValues {
  MarriageFormValues({
    this.status = MarriageStatus.married,
    this.startDay = '',
    this.startMonth = '',
    this.startYear = '',
    this.endDay = '',
    this.endMonth = '',
    this.endYear = '',
  });

  MarriageStatus status;
  String startDay;
  String startMonth;
  String startYear;
  String endDay;
  String endMonth;
  String endYear;
}

/// Cột start_date/end_date là kiểu ngày. Chỉ nhập năm thì lưu 1/1 của năm đó.
DateTime? marriageDateOf(ParsedDate parsed) {
  final date = parsed.date;
  if (date != null) {
    return date;
  }
  final year = parsed.year;
  return year == null ? null : DateTime(year);
}

Map<MarriageField, String> validateMarriageForm(
  MarriageFormValues values, {
  required int nowYear,
}) {
  final errors = <MarriageField, String>{};

  final start = parseDateParts(
    day: values.startDay,
    month: values.startMonth,
    year: values.startYear,
    nowYear: nowYear,
  );
  if (start.error != null) {
    errors[MarriageField.start] = 'Ngày bắt đầu: ${start.error}';
  }

  if (values.status != MarriageStatus.married) {
    final end = parseDateParts(
      day: values.endDay,
      month: values.endMonth,
      year: values.endYear,
      nowYear: nowYear,
    );
    if (end.error != null) {
      errors[MarriageField.end] = 'Ngày kết thúc: ${end.error}';
    } else if (start.error == null) {
      final startDate = start.date;
      final endDate = end.date;
      final startYear = start.year;
      final endYear = end.year;
      if (startDate != null && endDate != null) {
        if (endDate.isBefore(startDate)) {
          errors[MarriageField.end] =
              'Ngày kết thúc không thể trước ngày bắt đầu.';
        }
      } else if (startYear != null && endYear != null && endYear < startYear) {
        errors[MarriageField.end] =
            'Năm kết thúc ($endYear) không thể nhỏ hơn năm bắt đầu ($startYear).';
      }
    }
  }
  return errors;
}

// ---------- Payload ----------

/// Payload tạo người mới (create). Chỉ gồm cột có giá trị (không gửi null).
/// Ném ArgumentError nếu dữ liệu chưa hợp lệ (gọi validatePersonForm trước).
Map<String, dynamic> buildPersonCreatePayload(
  PersonFormValues values, {
  required String id,
  int? generation,
  required int nowYear,
}) {
  final errors = validatePersonForm(values, nowYear: nowYear);
  if (errors.isNotEmpty) {
    throw ArgumentError('Dữ liệu chưa hợp lệ: ${errors.values.join('; ')}');
  }

  final birth = parseDateParts(
    day: values.birthDay,
    month: values.birthMonth,
    year: values.birthYear,
    nowYear: nowYear,
  );

  final payload = <String, dynamic>{
    'id': id,
    'full_name': _clean(values.fullName),
    'gender': values.gender.name,
    'other_name': ?_orNull(values.otherName),
    'branch_id': ?values.branchId,
    'generation': ?generation,
    'birth_date': ?_iso(birth.date),
    'birth_year': ?birth.year,
    'birth_place': ?_orNull(values.birthPlace),
    'is_alive': values.isAlive,
  };

  if (!values.isAlive) {
    final death = parseDateParts(
      day: values.deathDay,
      month: values.deathMonth,
      year: values.deathYear,
      nowYear: nowYear,
    );
    final memorialDay = int.tryParse(values.memorialDay.trim());
    final memorialMonth = int.tryParse(values.memorialMonth.trim());
    payload.addAll({
      'death_date': ?_iso(death.date),
      'death_year': ?death.year,
      'burial_place': ?_orNull(values.burialPlace),
    });
    if (memorialDay != null && memorialMonth != null) {
      payload['memorial_lunar_day'] = memorialDay;
      payload['memorial_lunar_month'] = memorialMonth;
      payload['memorial_is_leap'] = values.memorialIsLeap;
    }
  }

  final notes = values.notes.trim();
  if (notes.isNotEmpty) {
    payload['notes'] = notes;
  }
  return payload;
}

Map<String, dynamic> buildParentChildCreatePayload({
  required String parentId,
  required String childId,
  required RelationType relation,
}) {
  return {
    'parent_id': parentId,
    'child_id': childId,
    'relation_type': relation.name,
  };
}

Map<String, dynamic> buildMarriageCreatePayload({
  required String person1Id,
  required String person2Id,
  required MarriageFormValues values,
  required int nowYear,
}) {
  final errors = validateMarriageForm(values, nowYear: nowYear);
  if (errors.isNotEmpty) {
    throw ArgumentError('Dữ liệu chưa hợp lệ: ${errors.values.join('; ')}');
  }

  final start = marriageDateOf(
    parseDateParts(
      day: values.startDay,
      month: values.startMonth,
      year: values.startYear,
      nowYear: nowYear,
    ),
  );
  final end = values.status == MarriageStatus.married
      ? null
      : marriageDateOf(
          parseDateParts(
            day: values.endDay,
            month: values.endMonth,
            year: values.endYear,
            nowYear: nowYear,
          ),
        );

  return {
    'person1_id': person1Id,
    'person2_id': person2Id,
    'status': values.status.name,
    'start_date': ?_iso(start),
    'end_date': ?_iso(end),
  };
}

// ---------- Kế hoạch gửi ----------

/// Quy ước dữ liệu: person1 là người NAM. Cả hai cùng nam hoặc không ai là nam
/// thì người đã có trong gia phả làm person1.
({String person1Id, String person2Id}) orderSpouses({
  required Person existing,
  required String newId,
  required Gender newGender,
}) {
  final newIsFirst = newGender == Gender.male && existing.gender != Gender.male;
  return newIsFirst
      ? (person1Id: newId, person2Id: existing.id)
      : (person1Id: existing.id, person2Id: newId);
}

/// Thêm con: người mới trước, rồi 1 hoặc 2 dòng cha-con (cùng loại quan hệ).
List<RequestDraft> planAddChild({
  required PersonFormValues values,
  required String childId,
  required Person parent,
  Person? otherParent,
  required RelationType relation,
  required int nowYear,
  bool useFormGeneration = false,
}) {
  final parentGeneration = parent.generation;
  final childGeneration = parentGeneration == null ? null : parentGeneration + 1;
  // Admin nhập "Số đời" thì dùng; để trống thì tự tính (đời cha/mẹ + 1).
  final formGeneration =
      useFormGeneration ? parseGeneration(values.generation).value : null;

  return [
    RequestDraft(
      entityType: kEntityPerson,
      action: kActionCreate,
      payload: buildPersonCreatePayload(
        values,
        id: childId,
        generation: formGeneration ?? childGeneration,
        nowYear: nowYear,
      ),
    ),
    for (final p in [parent, ?otherParent])
      RequestDraft(
        entityType: kEntityParentChild,
        action: kActionCreate,
        payload: buildParentChildCreatePayload(
          parentId: p.id,
          childId: childId,
          relation: relation,
        ),
      ),
  ];
}

/// Thêm vợ/chồng: người mới trước, rồi một dòng hôn nhân.
List<RequestDraft> planAddSpouse({
  required PersonFormValues values,
  required String spouseId,
  required Person partner,
  required MarriageFormValues marriage,
  required int nowYear,
  bool useFormGeneration = false,
}) {
  final formGeneration =
      useFormGeneration ? parseGeneration(values.generation).value : null;
  final order = orderSpouses(
    existing: partner,
    newId: spouseId,
    newGender: values.gender,
  );
  return [
    RequestDraft(
      entityType: kEntityPerson,
      action: kActionCreate,
      payload: buildPersonCreatePayload(
        values,
        id: spouseId,
        generation: formGeneration ?? partner.generation,
        nowYear: nowYear,
      ),
    ),
    RequestDraft(
      entityType: kEntityMarriage,
      action: kActionCreate,
      payload: buildMarriageCreatePayload(
        person1Id: order.person1Id,
        person2Id: order.person2Id,
        values: marriage,
        nowYear: nowYear,
      ),
    ),
  ];
}

// ---------- Hàm nhỏ ----------

String _clean(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String? _orNull(String input) {
  final text = _clean(input);
  return text.isEmpty ? null : text;
}

String? _iso(DateTime? d) {
  if (d == null) {
    return null;
  }
  final yyyy = d.year.toString().padLeft(4, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}