import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/core/utils/uuid.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/person/domain/person_create.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/person/ui/person_form_controller.dart';
import 'package:familytree/features/person/ui/person_form_fields.dart';
import 'package:familytree/features/proposals/ui/proposal_placeholder_screen.dart';
import 'package:familytree/features/proposals/ui/submit_bar.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/branch.dart';

class AddRootScreen extends ConsumerWidget {
  const AddRootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const ProposalPlaceholderScreen(
        title: 'Thêm người đầu tiên',
        message: 'Chỉ quản trị viên mới thêm được người đầu tiên.',
      );
    }

    final async = ref.watch(treeDataProvider);
    final data = async.value;
    if (data == null) {
      return ProposalPlaceholderScreen(
        title: 'Thêm người đầu tiên',
        message: async.hasError ? 'Không tải được dữ liệu.' : null,
      );
    }
    return _AddRootForm(branches: data.branches);
  }
}

class _AddRootForm extends ConsumerStatefulWidget {
  const _AddRootForm({required this.branches});

  final List<Branch> branches;

  @override
  ConsumerState<_AddRootForm> createState() => _AddRootFormState();
}

class _AddRootFormState extends ConsumerState<_AddRootForm> {
  late final PersonFormController _form = PersonFormController(
    PersonFormValues(generation: '1'),
    requireGenderChoice: true,
  );

  // Id người mới: sinh MỘT lần cho màn hình này (gửi lại sau lỗi mạng vẫn
  // cùng id, không tạo hai người).
  late final String _personId = generateUuidV4();

  bool _submitting = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final nowYear = DateTime.now().year;

    final errors = _form.validate(nowYear: nowYear, validateGeneration: true);
    if (errors.isNotEmpty) {
      final lines = errors.values.map((e) => '• $e').join('\n');
      await showMessageDialog(
        context,
        title: 'Chưa lưu được',
        message: 'Vui lòng sửa các ô báo đỏ rồi lưu lại:\n\n$lines',
        icon: Icons.error_outline,
        isError: true,
      );
      if (!mounted) {
        return;
      }
      _form.scrollToFirstError(errors);
      return;
    }

    final values = _form.collect();
    final drafts = planAddRoot(
      values: values,
      personId: _personId,
      nowYear: nowYear,
    );

    final name = values.fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final proceed = await confirmSubmit(
      context,
      isAdmin: true,
      summary: 'Thêm "$name" làm người đầu tiên của gia phả.',
      slots: drafts.length,
    );
    if (!proceed || !mounted) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final outcome = await submitChanges(
        context,
        ref,
        drafts: drafts,
        note: null,
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
    return ListenableBuilder(
      listenable: _form,
      builder: (context, _) {
        return PopScope(
          canPop: !_form.isDirty,
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
            appBar: AppBar(title: const Text('Thêm người đầu tiên')),
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
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Bạn đang thêm trực tiếp người đầu tiên của gia '
                            'phả. Người này hiện trên cây ngay sau khi lưu. '
                            '"Số đời" mặc định là 1, bạn có thể đổi.',
                            style: TextStyle(fontSize: 16, height: 1.4),
                          ),
                        ),
                        PersonFormFields(
                          controller: _form,
                          branches: widget.branches,
                          showGeneration: true,
                        ),
                      ],
                    ),
                  ),
                ),
                SubmitBar(
                  submitting: _submitting,
                  onPressed: _submit,
                  label: 'Lưu người này',
                  submittingLabel: 'Đang lưu...',
                  icon: Icons.save,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
