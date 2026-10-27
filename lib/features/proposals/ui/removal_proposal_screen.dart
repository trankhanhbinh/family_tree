import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/person/domain/relation_changes.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/proposals/ui/sender_card.dart';
import 'package:familytree/features/proposals/ui/submit_bar.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';

/// Màn hình chung cho thao tác gỡ/xóa: giải thích điều sẽ xảy ra, xác nhận
/// rồi gửi cả gói. Người thường: bắt buộc nhập lý do và gửi đề xuất.
/// Admin: không cần lý do, lưu trực tiếp.
class RemovalProposalScreen extends ConsumerStatefulWidget {
  const RemovalProposalScreen({
    super.key,
    required this.title,
    required this.headline,
    required this.lines,
    required this.drafts,
    required this.confirmMessage,
    required this.noteIndex,
    this.submitLabel = 'Gửi đề xuất',
    this.adminTitle,
    this.adminSubmitLabel = 'Lưu thay đổi',
    this.goHomeAfterAdminSave = false,
  });

  final String title;
  final String headline;
  final List<String> lines;
  final List<RequestDraft> drafts;
  final String confirmMessage;

  /// Dòng của gói sẽ mang lý do (với gói xóa người: dòng xóa người, ở cuối).
  final int noteIndex;
  final String submitLabel;

  /// Tiêu đề màn hình khi là admin (mặc định dùng [title]).
  final String? adminTitle;

  /// Chữ trên nút khi là admin.
  final String adminSubmitLabel;

  /// Admin lưu xong thì về thẳng màn cây (dùng khi xóa người: màn chi tiết
  /// của người đó không còn nữa).
  final bool goHomeAfterAdminSave;

  @override
  ConsumerState<RemovalProposalScreen> createState() =>
      _RemovalProposalScreenState();
}

class _RemovalProposalScreenState extends ConsumerState<RemovalProposalScreen> {
  final TextEditingController _reason = TextEditingController();
  String? _reasonError;
  bool _submitting = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final isAdmin = ref.read(isAdminProvider);

    if (!isAdmin) {
      final error = validateReason(_reason.text, required: true);
      setState(() => _reasonError = error);
      if (error != null) {
        await showMessageDialog(
          context,
          title: 'Chưa gửi được',
          message: error,
          icon: Icons.error_outline,
          isError: true,
        );
        return;
      }
    }

    final proceed = await confirmSubmit(
      context,
      isAdmin: isAdmin,
      summary: widget.confirmMessage,
      slots: widget.drafts.length,
    );
    if (!proceed || !mounted) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final outcome = await submitChanges(
        context,
        ref,
        drafts: widget.drafts,
        note: isAdmin ? null : _reason.text.trim(),
        noteIndex: widget.noteIndex,
      );
      if (outcome == SubmitOutcome.cancelled || !mounted) {
        return;
      }
      await showSubmitDone(context, outcome);
      if (!mounted) {
        return;
      }
      if (outcome == SubmitOutcome.saved && widget.goHomeAfterAdminSave) {
        context.go('/home');
      } else {
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
      listenable: _reason,
      builder: (context, _) {
        return PopScope(
          canPop: _reason.text.trim().isEmpty,
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
            appBar: AppBar(
              title: Text(
                isAdmin ? (widget.adminTitle ?? widget.title) : widget.title,
              ),
            ),
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            widget.headline,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ),
                        FormCard(
                          title: 'Điều gì sẽ xảy ra',
                          children: [
                            for (final line in widget.lines)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '• $line',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (!isAdmin)
                          SenderCard(
                            noteController: _reason,
                            noteLabel: 'Lý do *',
                            noteError: _reasonError,
                            onNoteChanged: () {
                              if (_reasonError != null) {
                                setState(() => _reasonError = null);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                SubmitBar(
                  submitting: _submitting,
                  onPressed: _submit,
                  label: isAdmin ? widget.adminSubmitLabel : widget.submitLabel,
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
}