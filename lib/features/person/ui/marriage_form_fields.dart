import 'package:flutter/material.dart';

import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/person/domain/person_create.dart';
import 'package:familytree/features/tree/domain/marriage.dart';

/// Trạng thái form hôn nhân (dùng cho màn Sửa hôn nhân).
class MarriageFormController extends ChangeNotifier {
  MarriageFormController(this.initial, {this.initialNotes = ''})
      : startDay = TextEditingController(text: initial.startDay),
        startMonth = TextEditingController(text: initial.startMonth),
        startYear = TextEditingController(text: initial.startYear),
        endDay = TextEditingController(text: initial.endDay),
        endMonth = TextEditingController(text: initial.endMonth),
        endYear = TextEditingController(text: initial.endYear),
        notes = TextEditingController(text: initialNotes),
        _status = initial.status {
    for (final c in _controllers) {
      c.addListener(notifyListeners);
    }
  }

  final MarriageFormValues initial;
  final String initialNotes;

  final TextEditingController startDay;
  final TextEditingController startMonth;
  final TextEditingController startYear;
  final TextEditingController endDay;
  final TextEditingController endMonth;
  final TextEditingController endYear;
  final TextEditingController notes;

  MarriageStatus _status;
  Map<MarriageField, String> errors = {};

  final GlobalKey startKey = GlobalKey();
  final GlobalKey endKey = GlobalKey();

  List<TextEditingController> get _controllers => [
        startDay,
        startMonth,
        startYear,
        endDay,
        endMonth,
        endYear,
        notes,
      ];

  MarriageStatus get status => _status;

  void setStatus(MarriageStatus value) {
    _status = value;
    errors.remove(MarriageField.end);
    notifyListeners();
  }

  MarriageFormValues collect() {
    return MarriageFormValues(
      status: _status,
      startDay: startDay.text,
      startMonth: startMonth.text,
      startYear: startYear.text,
      endDay: endDay.text,
      endMonth: endMonth.text,
      endYear: endYear.text,
    );
  }

  bool get isDirty {
    final v = collect();
    return v.status != initial.status ||
        v.startDay != initial.startDay ||
        v.startMonth != initial.startMonth ||
        v.startYear != initial.startYear ||
        v.endDay != initial.endDay ||
        v.endMonth != initial.endMonth ||
        v.endYear != initial.endYear ||
        notes.text.trim() != initialNotes.trim();
  }

  Map<MarriageField, String> validate({required int nowYear}) {
    final result = validateMarriageForm(collect(), nowYear: nowYear);
    errors = result;
    notifyListeners();
    return result;
  }

  void clearError(MarriageField field) {
    if (errors.remove(field) != null) {
      notifyListeners();
    }
  }

  void scrollToFirstError(Map<MarriageField, String> found) {
    final key = found.containsKey(MarriageField.start) ? startKey : endKey;
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }
}

/// Card hôn nhân: tình trạng, ngày bắt đầu, ngày kết thúc, ghi chú.
class MarriageFormFields extends StatelessWidget {
  const MarriageFormFields({super.key, required this.controller});

  final MarriageFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return FormCard(
          title: 'Hôn nhân',
          children: [
            const FieldLabel('Tình trạng'),
            BigChoiceList<MarriageStatus>(
              options: const [
                (MarriageStatus.married, 'Đang kết hôn'),
                (MarriageStatus.divorced, 'Đã ly hôn'),
                (MarriageStatus.widowed, 'Đã góa'),
              ],
              selected: controller.status,
              onChanged: controller.setStatus,
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Ngày không bắt buộc. Chỉ nhớ năm thì chỉ nhập năm '
                '(hệ thống lưu là ngày 1/1 của năm đó).',
                style: TextStyle(fontSize: 15),
              ),
            ),
            const FieldLabel('Ngày bắt đầu'),
            KeyedSubtree(
              key: controller.startKey,
              child: DateFieldsRow(
                day: controller.startDay,
                month: controller.startMonth,
                year: controller.startYear,
                error: controller.errors[MarriageField.start],
                onChanged: () => controller.clearError(MarriageField.start),
              ),
            ),
            if (controller.status != MarriageStatus.married) ...[
              const FieldLabel('Ngày kết thúc'),
              KeyedSubtree(
                key: controller.endKey,
                child: DateFieldsRow(
                  day: controller.endDay,
                  month: controller.endMonth,
                  year: controller.endYear,
                  error: controller.errors[MarriageField.end],
                  onChanged: () => controller.clearError(MarriageField.end),
                ),
              ),
            ],
            AppTextField(
              controller: controller.notes,
              label: 'Ghi chú về hôn nhân',
              minLines: 2,
              maxLines: 4,
            ),
          ],
        );
      },
    );
  }
}