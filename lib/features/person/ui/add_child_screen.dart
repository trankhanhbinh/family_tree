import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/core/utils/uuid.dart';
import 'package:familytree/features/auth/ui/contributor_gate.dart';
import 'package:familytree/features/person/domain/person.dart';
import 'package:familytree/features/person/domain/person_create.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/person/domain/person_relations.dart';
import 'package:familytree/features/person/ui/person_form_controller.dart';
import 'package:familytree/features/person/ui/person_form_fields.dart';
import 'package:familytree/features/proposals/data/change_request_repository.dart';
import 'package:familytree/features/proposals/ui/proposal_placeholder_screen.dart';
import 'package:familytree/features/proposals/ui/sender_card.dart';
import 'package:familytree/features/proposals/ui/submit_bar.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/branch.dart';
import 'package:familytree/features/tree/domain/parent_child.dart';

/// Đề xuất thêm một người con cho [personId] (khối 4C-1).
class AddChildScreen extends ConsumerWidget {
  const AddChildScreen({super.key, required this.personId});

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
      return ProposalPlaceholderScreen(title: 'Thêm con', message: message);
    }

    final relations = PersonRelations.of(
      person.id,
      people: data.people,
      parentChildren: data.parentChildren,
      marriages: data.marriages,
    );
    return _AddChildForm(
      person: person,
      spouses: [for (final s in relations.spouses) s.person],
      branches: data.branches,
    );
  }
}

class _AddChildForm extends ConsumerStatefulWidget {
  const _AddChildForm({
    required this.person,
    required this.spouses,
    required this.branches,
  });

  final Person person;
  final List<Person> spouses;
  final List<Branch> branches;

  @override
  ConsumerState<_AddChildForm> createState() => _AddChildFormState();
}

class _AddChildFormState extends ConsumerState<_AddChildForm> {
  late final PersonFormController _form = PersonFormController(
    PersonFormValues(branchId: widget.person.branchId),
    requireGenderChoice: true,
  );
  final TextEditingController _adminNote = TextEditingController();
  late final Listenable _all = Listenable.merge([_form, _adminNote]);

  // Id người mới: sinh MỘT lần cho màn hình này (gửi lại sau lỗi mạng vẫn
  // cùng id, không tạo hai người khác nhau).
  late final String _childId = generateUuidV4();

  // '' = "Chưa rõ"; null = chưa chọn (chỉ xảy ra khi có từ 2 vợ/chồng trở lên).
  late final String? _initialOther = widget.spouses.isEmpty
      ? ''
      : (widget.spouses.length == 1 ? widget.spouses.first.id : null);
  late String? _otherChoice = _initialOther;
  RelationType _relation = RelationType.biological;
  String? _otherError;
  final GlobalKey _otherKey = GlobalKey();

  bool _submitting = false;

  @override
  void dispose() {
    _form.dispose();
    _adminNote.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _form.isDirty ||
      _adminNote.text.trim().isNotEmpty ||
      _relation != RelationType.biological ||
      _otherChoice != _initialOther;

  String _relationLabel(RelationType relation) {
    return switch (relation) {
      RelationType.biological => 'con ruột',
      RelationType.adopted => 'con nuôi',
      RelationType.step => 'con riêng',
    };
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final nowYear = DateTime.now().year;

    final errors = _form.validate(nowYear: nowYear);
    final otherMissing = _otherChoice == null;
    setState(() {
      _otherError =
          otherMissing ? 'Vui lòng chọn con này sinh cùng với ai.' : null;
    });

    if (errors.isNotEmpty || otherMissing) {
      final lines = [
        ...errors.values,
        if (otherMissing) 'Vui lòng chọn con này sinh cùng với ai.',
      ].map((e) => '• $e').join('\n');
      await showMessageDialog(
        context,
        title: 'Chưa gửi được',
        message: 'Vui lòng sửa các mục báo đỏ rồi gửi lại:\n\n$lines',
        icon: Icons.error_outline,
        isError: true,
      );
      if (!mounted) {
        return;
      }
      if (errors.isNotEmpty) {
        _form.scrollToFirstError(errors);
      } else {
        final target = _otherKey.currentContext;
        if (target != null && target.mounted) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 300),
            alignment: 0.1,
          );
        }
      }
      return;
    }

    final otherId = _otherChoice;
    final Person? other = (otherId == null || otherId.isEmpty)
        ? null
        : widget.spouses.where((s) => s.id == otherId).firstOrNull;

    final values = _form.collect();
    final drafts = planAddChild(
      values: values,
      childId: _childId,
      parent: widget.person,
      otherParent: other,
      relation: _relation,
      nowYear: nowYear,
    );

    final childName = values.fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final parentsText = other == null
        ? widget.person.fullName
        : '${widget.person.fullName} và ${other.fullName}';
    final confirmed = await showChoiceDialog(
      context,
      title: 'Gửi đề xuất này?',
      message: 'Thêm "$childName" là ${_relationLabel(_relation)} của '
          '$parentsText.\n\n'
          'Đề xuất dùng ${drafts.length} trong tối đa 10 suất chờ duyệt.',
      primaryLabel: 'Gửi đề xuất',
      secondaryLabel: 'Xem lại',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final contributor = await ensureContributor(context, ref);
      if (contributor == null || !mounted) {
        return;
      }
      final note = _adminNote.text.trim();
      await ref.read(changeRequestRepositoryProvider).submitAll(
            requesterId: contributor.userId,
            nickname: contributor.nickname,
            drafts: drafts,
            note: note.isEmpty ? null : note,
          );
      if (!mounted) {
        return;
      }
      await showMessageDialog(
        context,
        title: 'Đã gửi đề xuất',
        message: 'Quản trị viên sẽ xem và duyệt.\n'
            'Người mới sẽ hiện trên cây sau khi được duyệt.',
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

  @override
  Widget build(BuildContext context) {
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
            appBar: AppBar(title: const Text('Thêm con')),
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
                        _otherParentCard(),
                        _relationCard(),
                        PersonFormFields(
                          controller: _form,
                          branches: widget.branches,
                        ),
                        SenderCard(noteController: _adminNote),
                      ],
                    ),
                  ),
                ),
                SubmitBar(submitting: _submitting, onPressed: _submit),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _intro() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 16, height: 1.4),
          children: [
            const TextSpan(text: 'Bạn đang đề xuất thêm một người con cho '),
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

  Widget _otherParentCard() {
    final spouses = widget.spouses;
    if (spouses.isEmpty) {
      return FormCard(
        title: 'Cha/mẹ của con',
        children: [
          Text(
            '${widget.person.fullName} chưa có vợ/chồng nào trong gia phả, '
            'nên con sẽ chỉ được gắn với ${widget.person.fullName}. '
            'Muốn ghi cả cha/mẹ còn lại, hãy gửi đề xuất "Thêm vợ/chồng" '
            'trước và đợi được duyệt.',
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
        ],
      );
    }
    final error = _otherError;
    return KeyedSubtree(
      key: _otherKey,
      child: FormCard(
        title: 'Con này sinh cùng với ai?',
        children: [
          BigChoiceList<String>(
            options: [
              for (final s in spouses) (s.id, s.fullName),
              ('', 'Chưa rõ / không ghi'),
            ],
            selected: _otherChoice,
            onChanged: (value) {
              setState(() {
                _otherChoice = value;
                _otherError = null;
              });
            },
          ),
          if (error != null) ErrorText(error),
        ],
      ),
    );
  }

  Widget _relationCard() {
    return FormCard(
      title: 'Loại quan hệ cha mẹ - con',
      children: [
        BigChoiceList<RelationType>(
          options: const [
            (RelationType.biological, 'Con ruột'),
            (RelationType.adopted, 'Con nuôi'),
            (RelationType.step, 'Con riêng'),
          ],
          selected: _relation,
          onChanged: (value) => setState(() => _relation = value),
        ),
      ],
    );
  }
}