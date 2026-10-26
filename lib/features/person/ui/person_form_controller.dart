import 'package:flutter/material.dart';

import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';

/// Giữ toàn bộ trạng thái form người (dùng cho cả màn Sửa và màn Thêm).
/// requireGenderChoice = true: giới tính chưa chọn sẵn, bắt buộc chọn.
class PersonFormController extends ChangeNotifier {
  PersonFormController(this.initial, {this.requireGenderChoice = false})
      : fullName = TextEditingController(text: initial.fullName),
        otherName = TextEditingController(text: initial.otherName),
        birthDay = TextEditingController(text: initial.birthDay),
        birthMonth = TextEditingController(text: initial.birthMonth),
        birthYear = TextEditingController(text: initial.birthYear),
        birthPlace = TextEditingController(text: initial.birthPlace),
        deathDay = TextEditingController(text: initial.deathDay),
        deathMonth = TextEditingController(text: initial.deathMonth),
        deathYear = TextEditingController(text: initial.deathYear),
        burialPlace = TextEditingController(text: initial.burialPlace),
        memorialDay = TextEditingController(text: initial.memorialDay),
        memorialMonth = TextEditingController(text: initial.memorialMonth),
        notes = TextEditingController(text: initial.notes),
        _gender = requireGenderChoice ? null : initial.gender,
        _branchId = initial.branchId,
        _isAlive = initial.isAlive,
        _memorialIsLeap = initial.memorialIsLeap {
    for (final c in _textControllers) {
      c.addListener(notifyListeners);
    }
  }

  final PersonFormValues initial;
  final bool requireGenderChoice;

  final TextEditingController fullName;
  final TextEditingController otherName;
  final TextEditingController birthDay;
  final TextEditingController birthMonth;
  final TextEditingController birthYear;
  final TextEditingController birthPlace;
  final TextEditingController deathDay;
  final TextEditingController deathMonth;
  final TextEditingController deathYear;
  final TextEditingController burialPlace;
  final TextEditingController memorialDay;
  final TextEditingController memorialMonth;
  final TextEditingController notes;

  Gender? _gender;
  String? _branchId;
  bool _isAlive;
  bool _memorialIsLeap;

  /// Lỗi hiện tại theo nhóm ô.
  Map<PersonField, String> errors = {};

  /// Khóa để cuộn tới ô lỗi.
  final Map<PersonField, GlobalKey> keys = {
    for (final field in PersonField.values) field: GlobalKey(),
  };

  List<TextEditingController> get _textControllers => [
        fullName,
        otherName,
        birthDay,
        birthMonth,
        birthYear,
        birthPlace,
        deathDay,
        deathMonth,
        deathYear,
        burialPlace,
        memorialDay,
        memorialMonth,
        notes,
      ];

  Gender? get gender => _gender;
  bool get genderChosen => _gender != null;
  String? get branchId => _branchId;
  bool get isAlive => _isAlive;
  bool get memorialIsLeap => _memorialIsLeap;

  void setGender(Gender value) {
    _gender = value;
    errors.remove(PersonField.gender);
    notifyListeners();
  }

  void setBranch(String? id) {
    _branchId = id;
    notifyListeners();
  }

  void setAlive(bool value) {
    _isAlive = value;
    notifyListeners();
  }

  void setMemorialIsLeap(bool value) {
    _memorialIsLeap = value;
    notifyListeners();
  }

  void clearError(PersonField field) {
    if (errors.remove(field) != null) {
      notifyListeners();
    }
  }

  /// Giá trị hiện tại của form. Giới tính chưa chọn thì lấy giá trị ban đầu
  /// (validate() sẽ báo lỗi riêng).
  PersonFormValues collect() {
    return PersonFormValues(
      fullName: fullName.text,
      otherName: otherName.text,
      gender: _gender ?? initial.gender,
      branchId: _branchId,
      birthDay: birthDay.text,
      birthMonth: birthMonth.text,
      birthYear: birthYear.text,
      birthPlace: birthPlace.text,
      isAlive: _isAlive,
      deathDay: deathDay.text,
      deathMonth: deathMonth.text,
      deathYear: deathYear.text,
      burialPlace: burialPlace.text,
      memorialDay: memorialDay.text,
      memorialMonth: memorialMonth.text,
      memorialIsLeap: _memorialIsLeap,
      notes: notes.text,
    );
  }

  /// Đã có thay đổi so với lúc mở form chưa.
  bool get isDirty {
    if (!collect().sameAs(initial)) {
      return true;
    }
    return requireGenderChoice && _gender != null;
  }

  /// Kiểm tra form, lưu lỗi để hiện lên màn hình và trả về.
  Map<PersonField, String> validate({required int nowYear}) {
    final result = validatePersonForm(
      collect(),
      nowYear: nowYear,
      genderChosen: genderChosen,
    );
    errors = result;
    notifyListeners();
    return result;
  }

  void scrollToFirstError(Map<PersonField, String> errors) {
    for (final field in PersonField.values) {
      if (errors.containsKey(field)) {
        final target = keys[field]?.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 300),
            alignment: 0.1,
          );
        }
        return;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers) {
      c.dispose();
    }
    super.dispose();
  }
}