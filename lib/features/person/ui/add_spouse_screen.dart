import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/core/utils/uuid.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_create.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/person/ui/person_form_controller.dart';
import 'package:familytree/features/person/ui/person_form_fields.dart';
import 'package:familytree/features/proposals/ui/proposal_placeholder_screen.dart';
import 'package:familytree/features/proposals/ui/sender_card.dart';
import 'package:familytree/features/proposals/ui/submit_bar.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/branch.dart';
import 'package:familytree/features/tree/domain/marriage.dart';

/// Đề xuất thêm vợ/chồng cho [personId] (khối 4C-1).
class AddSpouseScreen extends ConsumerWidget {
  const AddSpouseScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(treeDataProvider);
    final data = async.value;
    final person = data?.people.where((p) => p.id == personId).firstOrNull;

    if (data == null || person == null) {
      String? message;
      if (async.hasError) {
        message = 'Không tải được dữ liệu.';
      } else if (data != null) {
        message = 'Không tìm thấy người này.';
      }
      return ProposalPlaceholderScreen(
        title: 'Thêm vợ/chồng',
        message: message,
      );
    }
    return _AddSpouseForm(person: person, branches: data.branches);
  }
}

class _AddSpouseForm extends ConsumerStatefulWidget {
  const _AddSpouseForm({required this.person, required this.branches});

  final Person person;
  final List<Branch> branches;

  @override
  ConsumerState<_AddSpouseForm> createState() => _AddSpouseFormState();
}

Gender _oppositeGender(Gender gender) {
  if (gender == Gender.male) {
    return Gender.female;
  }
  if (gender == Gender.female) {
    return Gender.male;
  }
  return Gender.other;
}

class _AddSpouseFormState extends ConsumerState<_AddSpouseForm> {
  // Giới tính chọn sẵn là giới ngược lại (cho đổi). Nếu người này giới tính
  // "Khác" thì bắt chọn.
  late final PersonFormController _form = PersonFormController(
    PersonFormValues(gender: _oppositeGender(widget.person.gender)),
    requireGenderChoice: widget.person.gender == Gender.other,
  );
  final TextEditingController _adminNote = TextEditingController();

  final TextEditingController _startDay = TextEditingController();
  final TextEditingController _startMonth = TextEditingController();
  final TextEditingController _startYear = TextEditingController();
  final TextEditingController _endDay = TextEditingController();
  final TextEditingController _endMonth = TextEditingController();
  final TextEditingController _endYear = TextEditingController();

  late final Listenable _all = Listenable.merge([
    _form,
    _adminNote,
    _startDay,
    _startMonth,
    _startYear,
    _endDay,
    _endMonth,
    _endYear,
  ]);

  // Id người mới: sinh MỘT lần cho màn hình này.
  late final String _spouseId = generateUuidV4();

  MarriageStatus _status = MarriageStatus.married;
  Map<MarriageField, String> _marriageErrors = {};
  final GlobalKey _startKey = GlobalKey();
  final GlobalKey _endKey = GlobalKey();

  bool _submitting = false;

  @override
  void dispose() {
    _form.dispose();
    for (final c in [
      _adminNote,
      _startDay,
      _startMonth,
      _startYear,
      _endDay,
      _endMonth,
      _endYear,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _dateControllers => [
        _startDay,
        _startMonth,
        _startYear,
        _endDay,
        _endMonth,
        _endYear,
      ];

  bool get _dirty =>
      _form.isDirty ||
      _adminNote.text.trim().isNotEmpty ||
      _status != MarriageStatus.married ||
      _dateControllers.any((c) => c.text.isNotEmpty);

  MarriageFormValues _collectMarriage() {
    return MarriageFormValues(
      status: _status,
      startDay: _startDay.text,
      startMonth: _startMonth.text,
      startYear: _startYear.text,
      endDay: _endDay.text,
      endMonth: _endMonth.text,
      endYear: _endYear.text,
    );
  }

  void _clearMarriageError(MarriageField field) {
    if (_marriageErrors.containsKey(field)) {
      setState(() => _marriageErrors = {..._marriageErrors}..remove(field));
    }
  }

  String _statusLabel(MarriageStatus status) {
    return switch (status) {
      MarriageStatus.married => 'đang kết hôn',
      MarriageStatus.divorced => 'đã ly hôn',
      MarriageStatus.widowed => 'đã góa',
    };
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final isAdmin = ref.read(isAdminProvider);
    final nowYear = DateTime.now().year;

    final personErrors =
        _form.validate(nowYear: nowYear, validateGeneration: isAdmin);
    final marriage = _collectMarriage();
    final marriageErrors = validateMarriageForm(marriage, nowYear: nowYear);
    setState(() => _marriageErrors = marriageErrors);

    if (personErrors.isNotEmpty || marriageErrors.isNotEmpty) {
      final lines = [...personErrors.values, ...marriageErrors.values]
          .map((e) => '• $e')
          .join('\n');
      await showMessageDialog(
        context,
        title: isAdmin ? 'Chưa lưu được' : 'Chưa gửi được',
        message: 'Vui lòng sửa các mục báo đỏ rồi '
            '${isAdmin ? 'lưu' : 'gửi'} lại:\n\n$lines',
        icon: Icons.error_outline,
        isError: true,
      );
      if (!mounted) {
        return;
      }
      if (personErrors.isNotEmpty) {
        _form.scrollToFirstError(personErrors);
      } else if (marriageErrors.containsKey(MarriageField.start)) {
        _scrollTo(_startKey);
      } else {
        _scrollTo(_endKey);
      }
      return;
    }

    final values = _form.collect();
    final drafts = planAddSpouse(
      values: values,
      spouseId: _spouseId,
      partner: widget.person,
      marriage: marriage,
      nowYear: nowYear,
      useFormGeneration: isAdmin,
    );

    final spouseName = values.fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final proceed = await confirmSubmit(
      context,
      isAdmin: isAdmin,
      summary: 'Thêm "$spouseName" là vợ/chồng của ${widget.person.fullName} '
          '(${_statusLabel(_status)}).',
      slots: drafts.length,
    );
    if (!proceed || !mounted) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final note = _adminNote.text.trim();
      final outcome = await submitChanges(
        context,
        ref,
        drafts: drafts,
        note: (isAdmin || note.isEmpty) ? null : note,
      );
      if (outcome == SubmitOutcome.cancelled || !mounted) {
        return;
      }
      await showSubmitDone(context, outcome);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return ListenableBuilder(
      listenable: _all,
      builder: (context, _) {
        return PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            final leave = await confirmLeaveWithoutSending(context);
            if (leave && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Thêm vợ/chồng')),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _intro(isAdmin),
                        _marriageCard(),
                        PersonFormFields(
                          controller: _form,
                          branches: widget.branches,
                          showGeneration: isAdmin,
                        ),
                        if (!isAdmin) SenderCard(noteController: _adminNote),
                      ],
                    ),
                  ),
                ),
                SubmitBar(
                  submitting: _submitting,
                  onPressed: _submit,
                  label: isAdmin ? 'Lưu thay đổi' : 'Gửi đề xuất',
                  submittingLabel: isAdmin ? 'Đang lưu...' : 'Đang gửi...',
                  icon: isAdmin ? Icons.save : Icons.send,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _intro(bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 16, height: 1.4),
          children: [
            TextSpan(
              text: isAdmin
                  ? 'Bạn đang thêm trực tiếp vợ/chồng cho '
                  : 'Bạn đang đề xuất thêm vợ/chồng cho ',
            ),
            TextSpan(
              text: widget.person.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(
              text: '. Người mới chỉ hiện trên cây sau khi được duyệt.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _marriageCard() {
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
          selected: _status,
          onChanged: (value) => setState(() => _status = value),
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
          key: _startKey,
          child: DateFieldsRow(
            day: _startDay,
            month: _startMonth,
            year: _startYear,
            error: _marriageErrors[MarriageField.start],
            onChanged: () => _clearMarriageError(MarriageField.start),
          ),
        ),
        if (_status != MarriageStatus.married) ...[
          const FieldLabel('Ngày kết thúc'),
          KeyedSubtree(
            key: _endKey,
            child: DateFieldsRow(
              day: _endDay,
              month: _endMonth,
              year: _endYear,
              error: _marriageErrors[MarriageField.end],
              onChanged: () => _clearMarriageError(MarriageField.end),
            ),
          ),
        ],
      ],
    );
  }
}