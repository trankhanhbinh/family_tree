import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/auth/ui/contributor_gate.dart';
import 'package:familytree/features/person/domain/relation_changes.dart';
import 'package:familytree/features/proposals/data/change_request_repository.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/proposals/ui/sender_card.dart';
import 'package:familytree/features/proposals/ui/submit_bar.dart';

/// Màn hình chung cho thao tác gỡ/xóa: giải thích điều sẽ xảy ra,
/// bắt buộc nhập lý do, xác nhận rồi gửi cả gói đề xuất cùng lúc.
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
  });

  final String title;
  final String headline;
  final List<String> lines;
  final List<RequestDraft> drafts;
  final String confirmMessage;

  /// Dòng của gói sẽ mang lý do (với gói xóa người: dòng xóa người, ở cuối).
  final int noteIndex;
  final String submitLabel;

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

    final confirmed = await showChoiceDialog(
      context,
      title: 'Gửi đề xuất này?',
      message: '${widget.confirmMessage}\n\n'
          'Đề xuất dùng ${widget.drafts.length} trong tối đa 10 suất chờ duyệt.',
      primaryLabel: widget.submitLabel,
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
      await ref.read(changeRequestRepositoryProvider).submitAll(
            requesterId: contributor.userId,
            nickname: contributor.nickname,
            drafts: widget.drafts,
            note: _reason.text.trim(),
            noteIndex: widget.noteIndex,
          );
      if (!mounted) {
        return;
      }
      await showMessageDialog(
        context,
        title: 'Đã gửi đề xuất',
        message: 'Quản trị viên sẽ xem và duyệt.\n'
            'Thay đổi chỉ áp dụng sau khi được duyệt.',
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
            appBar: AppBar(title: Text(widget.title)),
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
                  label: widget.submitLabel,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}