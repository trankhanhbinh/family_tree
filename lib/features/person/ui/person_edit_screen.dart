import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/features/auth/data/nickname_store.dart';
import 'package:familytree/features/auth/ui/contributor_gate.dart';
import 'package:familytree/features/person/domain/branch_path.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/proposals/data/change_request_repository.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/branch.dart';

/// Màn hình đề xuất sửa thông tin một người (khối 4B).
class PersonEditScreen extends ConsumerWidget {
  const PersonEditScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(treeDataProvider);
    final data = async.value;
    final person = data?.people.where((p) => p.id == personId).firstOrNull;

    if (data == null || person == null) {
      final String message;
      if (async.hasError) {
        message = 'Không tải được dữ liệu.';
      } else if (data != null) {
        message = 'Không tìm thấy người này.';
      } else {
        message = '';
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Đề xuất sửa thông tin')),
        body: Center(
          child: message.isEmpty
              ? const CircularProgressIndicator()
              : Text(message, style: const TextStyle(fontSize: 18)),
        ),
      );
    }

    return _PersonEditForm(person: person, branches: data.branches);
  }
}

class _PersonEditForm extends ConsumerStatefulWidget {
  const _PersonEditForm({required this.person, required this.branches});

  final Person person;
  final List<Branch> branches;

  @override
  ConsumerState<_PersonEditForm> createState() => _PersonEditFormState();
}

class _BranchChoice {
  const _BranchChoice(this.id);

  final String? id;
}

class _BranchEntry {
  const _BranchEntry(this.id, this.path);

  final String id;
  final String path;
}

class _PersonEditFormState extends ConsumerState<_PersonEditForm> {
  late final PersonFormValues _initial =
      PersonFormValues.fromPerson(widget.person);

  late final TextEditingController _fullName =
      TextEditingController(text: _initial.fullName);
  late final TextEditingController _otherName =
      TextEditingController(text: _initial.otherName);
  late final TextEditingController _birthDay =
      TextEditingController(text: _initial.birthDay);
  late final TextEditingController _birthMonth =
      TextEditingController(text: _initial.birthMonth);
  late final TextEditingController _birthYear =
      TextEditingController(text: _initial.birthYear);
  late final TextEditingController _birthPlace =
      TextEditingController(text: _initial.birthPlace);
  late final TextEditingController _deathDay =
      TextEditingController(text: _initial.deathDay);
  late final TextEditingController _deathMonth =
      TextEditingController(text: _initial.deathMonth);
  late final TextEditingController _deathYear =
      TextEditingController(text: _initial.deathYear);
  late final TextEditingController _burialPlace =
      TextEditingController(text: _initial.burialPlace);
  late final TextEditingController _memorialDay =
      TextEditingController(text: _initial.memorialDay);
  late final TextEditingController _memorialMonth =
      TextEditingController(text: _initial.memorialMonth);
  late final TextEditingController _notes =
      TextEditingController(text: _initial.notes);
  final TextEditingController _adminNote = TextEditingController();

  late Gender _gender = _initial.gender;
  late String? _branchId = _initial.branchId;
  late bool _isAlive = _initial.isAlive;
  late bool _memorialIsLeap = _initial.memorialIsLeap;

  Map<PersonField, String> _errors = {};
  bool _submitting = false;

  final Map<PersonField, GlobalKey> _keys = {
    for (final field in PersonField.values) field: GlobalKey(),
  };

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _otherName,
      _birthDay,
      _birthMonth,
      _birthYear,
      _birthPlace,
      _deathDay,
      _deathMonth,
      _deathYear,
      _burialPlace,
      _memorialDay,
      _memorialMonth,
      _notes,
      _adminNote,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  PersonFormValues _collect() {
    return PersonFormValues(
      fullName: _fullName.text,
      otherName: _otherName.text,
      gender: _gender,
      branchId: _branchId,
      birthDay: _birthDay.text,
      birthMonth: _birthMonth.text,
      birthYear: _birthYear.text,
      birthPlace: _birthPlace.text,
      isAlive: _isAlive,
      deathDay: _deathDay.text,
      deathMonth: _deathMonth.text,
      deathYear: _deathYear.text,
      burialPlace: _burialPlace.text,
      memorialDay: _memorialDay.text,
      memorialMonth: _memorialMonth.text,
      memorialIsLeap: _memorialIsLeap,
      notes: _notes.text,
    );
  }

  bool _isDirty() {
    return !_collect().sameAs(_initial) || _adminNote.text.trim().isNotEmpty;
  }

  void _changed([PersonField? field]) {
    setState(() {
      if (field != null) {
        _errors.remove(field);
      }
    });
  }

  // ---------- Gửi đề xuất ----------

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final values = _collect();
    final nowYear = DateTime.now().year;

    final errors = validatePersonForm(values, nowYear: nowYear);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      final lines = errors.values.map((e) => '• $e').join('\n');
      await showMessageDialog(
        context,
        title: 'Chưa gửi được',
        message: 'Vui lòng sửa các ô báo đỏ rồi gửi lại:\n\n$lines',
        icon: Icons.error_outline,
        isError: true,
      );
      if (!mounted) {
        return;
      }
      _scrollToFirstError(errors);
      return;
    }

    final payload = buildPersonUpdatePayload(
      widget.person,
      values,
      nowYear: nowYear,
    );
    if (payload.isEmpty) {
      await showMessageDialog(
        context,
        title: 'Bạn chưa thay đổi gì',
        message: 'Hãy sửa ít nhất một thông tin rồi bấm "Gửi đề xuất".',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final contributor = await ensureContributor(context, ref);
      if (contributor == null || !mounted) {
        return;
      }
      final note = _adminNote.text.trim();
      await ref.read(changeRequestRepositoryProvider).submit(
            requesterId: contributor.userId,
            nickname: contributor.nickname,
            entityType: kEntityPerson,
            entityId: widget.person.id,
            action: kActionUpdate,
            payload: payload,
            note: note.isEmpty ? null : note,
          );
      if (!mounted) {
        return;
      }
      await showMessageDialog(
        context,
        title: 'Đã gửi đề xuất',
        message: 'Quản trị viên sẽ xem và duyệt đề xuất của bạn.\n'
            'Thay đổi sẽ hiện trên cây sau khi được duyệt.',
        icon: Icons.check_circle_outline,
      );
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

  void _scrollToFirstError(Map<PersonField, String> errors) {
    for (final field in PersonField.values) {
      if (errors.containsKey(field)) {
        final target = _keys[field]?.currentContext;
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

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Thoát mà không gửi?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Các thay đổi bạn vừa nhập sẽ bị mất.',
            style: TextStyle(fontSize: 18, height: 1.4),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Ở lại', style: TextStyle(fontSize: 18)),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(
                  'Thoát, không gửi',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        );
      },
    );
    return leave ?? false;
  }

  Future<void> _pickBranch() async {
    final entries = <_BranchEntry>[
      for (final b in widget.branches)
        _BranchEntry(b.id, branchPathOf(b.id, widget.branches) ?? b.name),
    ]..sort((a, b) => a.path.compareTo(b.path));

    final picked = await showModalBottomSheet<_BranchChoice>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Chọn chi/nhánh',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                minTileHeight: 56,
                title: const Text(
                  'Không thuộc chi nào',
                  style: TextStyle(fontSize: 18),
                ),
                selected: _branchId == null,
                trailing: _branchId == null
                    ? const Icon(Icons.check, size: 28)
                    : null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(const _BranchChoice(null)),
              ),
              for (final entry in entries)
                ListTile(
                  minTileHeight: 56,
                  title: Text(entry.path, style: const TextStyle(fontSize: 18)),
                  selected: _branchId == entry.id,
                  trailing: _branchId == entry.id
                      ? const Icon(Icons.check, size: 28)
                      : null,
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_BranchChoice(entry.id)),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _branchId = picked.id);
  }

  Future<void> _changeNickname() async {
    await editNickname(context, ref);
  }

  // ---------- Giao diện ----------

  @override
  Widget build(BuildContext context) {
    final dirty = _isDirty();

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final leave = await _confirmLeave();
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Đề xuất sửa thông tin')),
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
                    _intro(),
                    _basicSection(),
                    _birthSection(),
                    _statusSection(),
                    if (!_isAlive) _memorialSection(),
                    _notesSection(),
                    _sendSection(),
                  ],
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 16, height: 1.4),
          children: [
            const TextSpan(text: 'Bạn đang đề xuất sửa thông tin của '),
            TextSpan(
              text: widget.person.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(
              text: '. Thay đổi sẽ được quản trị viên xem và duyệt, '
                  'chưa áp dụng ngay.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _basicSection() {
    return _FormCard(
      title: 'Thông tin cơ bản',
      children: [
        KeyedSubtree(
          key: _keys[PersonField.fullName],
          child: _textField(
            controller: _fullName,
            label: 'Họ và tên *',
            field: PersonField.fullName,
            maxLength: kPersonNameMaxLength,
            capitalization: TextCapitalization.words,
          ),
        ),
        _textField(
          controller: _otherName,
          label: 'Tên khác (tên thường gọi, tên húy...)',
          capitalization: TextCapitalization.words,
        ),
        const _FieldLabel('Giới tính'),
        SegmentedButton<Gender>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            minimumSize: const Size(0, 56),
            textStyle: const TextStyle(fontSize: 18),
          ),
          segments: const [
            ButtonSegment(value: Gender.male, label: Text('Nam')),
            ButtonSegment(value: Gender.female, label: Text('Nữ')),
            ButtonSegment(value: Gender.other, label: Text('Khác')),
          ],
          selected: {_gender},
          onSelectionChanged: (selection) {
            setState(() => _gender = selection.first);
          },
        ),
        const SizedBox(height: 16),
        const _FieldLabel('Chi/nhánh'),
        _branchField(),
        const SizedBox(height: 16),
        _textField(
          controller: _birthPlace,
          label: 'Nơi sinh',
          capitalization: TextCapitalization.words,
        ),
      ],
    );
  }

  Widget _branchField() {
    final label = _branchId == null
        ? 'Không thuộc chi nào'
        : (branchPathOf(_branchId, widget.branches) ?? 'Không rõ');
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(fontSize: 18),
        ),
        onPressed: _pickBranch,
        child: Row(
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down, size: 32),
          ],
        ),
      ),
    );
  }

  Widget _birthSection() {
    return _FormCard(
      title: 'Ngày sinh',
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Chỉ nhớ năm thì chỉ cần nhập năm, để trống ngày và tháng.',
            style: TextStyle(fontSize: 15),
          ),
        ),
        _dateFields(
          field: PersonField.birth,
          day: _birthDay,
          month: _birthMonth,
          year: _birthYear,
        ),
      ],
    );
  }

  Widget _statusSection() {
    return _FormCard(
      title: 'Tình trạng',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Đã mất',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _isAlive ? 'Hiện đang còn sống' : 'Nhập thêm thông tin bên dưới',
            style: const TextStyle(fontSize: 16),
          ),
          value: !_isAlive,
          onChanged: (isDead) => setState(() => _isAlive = !isDead),
        ),
        if (!_isAlive) ...[
          const SizedBox(height: 8),
          const _FieldLabel('Ngày mất'),
          _dateFields(
            field: PersonField.death,
            day: _deathDay,
            month: _deathMonth,
            year: _deathYear,
          ),
          _textField(
            controller: _burialPlace,
            label: 'Nơi an táng',
            capitalization: TextCapitalization.words,
          ),
        ],
      ],
    );
  }

  Widget _memorialSection() {
    final error = _errors[PersonField.memorial];
    return _FormCard(
      title: 'Ngày giỗ (âm lịch)',
      children: [
        KeyedSubtree(
          key: _keys[PersonField.memorial],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _numberField(
                      _memorialDay,
                      'Ngày (1 đến 30)',
                      2,
                      PersonField.memorial,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _numberField(
                      _memorialMonth,
                      'Tháng (1 đến 12)',
                      2,
                      PersonField.memorial,
                    ),
                  ),
                ],
              ),
              if (error != null) _ErrorText(error),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Tháng nhuận', style: TextStyle(fontSize: 18)),
                value: _memorialIsLeap,
                onChanged: (value) {
                  setState(() => _memorialIsLeap = value ?? false);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notesSection() {
    return _FormCard(
      title: 'Ghi chú',
      children: [
        _textField(
          controller: _notes,
          label: 'Ghi chú về người này',
          maxLength: kPersonNotesMaxLength,
          minLines: 3,
          maxLines: 8,
        ),
      ],
    );
  }

  Widget _sendSection() {
    final nickname = ref.watch(nicknameProvider).value;
    final hasName = nickname != null && nickname.isNotEmpty;
    return _FormCard(
      title: 'Thông tin người gửi',
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasName
                    ? 'Gửi với tên: $nickname'
                    : 'Bạn sẽ được hỏi tên khi gửi.',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(100, 56),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: _changeNickname,
              child: const Text('Đổi tên'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _textField(
          controller: _adminNote,
          label: 'Lý do / ghi chú cho quản trị viên (không bắt buộc)',
          maxLength: kRequestNoteMaxLength,
          minLines: 2,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: Icon(
                _submitting ? Icons.hourglass_top : Icons.send,
                size: 24,
              ),
              label: Text(
                _submitting ? 'Đang gửi...' : 'Gửi đề xuất',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Ô nhập ----------

  Widget _textField({
    required TextEditingController controller,
    required String label,
    PersonField? field,
    int maxLength = kPersonTextMaxLength,
    int minLines = 1,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.sentences,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 18),
        minLines: minLines,
        maxLines: maxLines,
        keyboardType:
            maxLines > 1 ? TextInputType.multiline : TextInputType.text,
        textCapitalization: capitalization,
        inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 16),
          errorText: field == null ? null : _errors[field],
          errorStyle: const TextStyle(fontSize: 16),
          errorMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _changed(field),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    int maxDigits,
    PersonField field,
  ) {
    final hasError = _errors.containsKey(field);
    final errorColor = Theme.of(context).colorScheme.error;
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 20),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxDigits),
      ],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 16),
        border: const OutlineInputBorder(),
        enabledBorder: hasError
            ? OutlineInputBorder(
                borderSide: BorderSide(color: errorColor, width: 2),
              )
            : null,
      ),
      onChanged: (_) => _changed(field),
    );
  }

  Widget _dateFields({
    required PersonField field,
    required TextEditingController day,
    required TextEditingController month,
    required TextEditingController year,
  }) {
    final error = _errors[field];
    return KeyedSubtree(
      key: _keys[field],
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(flex: 2, child: _numberField(day, 'Ngày', 2, field)),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _numberField(month, 'Tháng', 2, field)),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: _numberField(year, 'Năm', 4, field)),
              ],
            ),
            if (error != null) _ErrorText(error),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}