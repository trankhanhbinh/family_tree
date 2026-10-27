import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/person/domain/person_edit_form.dart';
import 'package:familytree/features/person/domain/relation_changes.dart';
import 'package:familytree/features/review/data/review_repository.dart';
import 'package:familytree/features/review/domain/change_request.dart';
import 'package:familytree/features/review/domain/request_describer.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

const Color _kWarningColor = Color(0xFFB26A00);

/// Chi tiết một gói đề xuất: xem từng thay đổi, rồi Duyệt hoặc Từ chối cả gói.
class BundleDetailScreen extends ConsumerStatefulWidget {
  const BundleDetailScreen({super.key, required this.bundle});

  final ReviewBundle bundle;

  @override
  ConsumerState<BundleDetailScreen> createState() => _BundleDetailScreenState();
}

class _BundleDetailScreenState extends ConsumerState<BundleDetailScreen> {
  bool _busy = false;

  void _refreshLists() {
    ref.invalidate(pendingBundlesProvider);
    ref.invalidate(processedBundlesProvider);
  }

  Future<void> _approve(int changeCount) async {
    if (_busy) {
      return;
    }
    final bundle = widget.bundle;

    if (bundle.hasUnsupported) {
      await showMessageDialog(
        context,
        title: 'Chưa duyệt được',
        message: 'Gói này có mục mà app chưa hỗ trợ duyệt (ví dụ ảnh). '
            'Hãy xử lý trong Supabase.',
        icon: Icons.info_outline,
        isError: true,
      );
      return;
    }

    // Nút chính là "Xem lại" vì chạm ra ngoài hộp thoại được tính là nút chính:
    // lỡ chạm ra ngoài thì KHÔNG duyệt.
    final review = await showChoiceDialog(
      context,
      title: 'Duyệt đề xuất này?',
      message: 'Duyệt $changeCount thay đổi của "${bundle.nickname}".\n\n'
          'Thay đổi được áp dụng ngay.',
      primaryLabel: 'Xem lại',
      secondaryLabel: 'Duyệt',
    );
    if (review || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(reviewRepositoryProvider).approveBundle(bundle.requestIds);
      if (!mounted) {
        return;
      }
      _refreshLists();
      ref.invalidate(treeDataProvider);
      await showMessageDialog(
        context,
        title: 'Đã duyệt',
        message: 'Thay đổi đã được áp dụng và hiện trên cây.',
        icon: Icons.check_circle_outline,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _refreshLists();
      await showErrorDialog(context, error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reject() async {
    if (_busy) {
      return;
    }
    final reason = await showRejectReasonDialog(context);
    if (reason == null || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(reviewRepositoryProvider)
          .rejectBundle(widget.bundle.requestIds, reason);
      if (!mounted) {
        return;
      }
      _refreshLists();
      await showMessageDialog(
        context,
        title: 'Đã từ chối',
        message: 'Đề xuất đã được từ chối và lưu lý do.',
        icon: Icons.check_circle_outline,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _refreshLists();
      await showErrorDialog(context, error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundle = widget.bundle;
    final tree = ref.watch(treeDataProvider).value;
    final scheme = Theme.of(context).colorScheme;

    if (tree == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết đề xuất')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final described = describeBundle(bundle, tree);
    final note = bundle.note;

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đề xuất')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Đề xuất của ${bundle.nickname}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gửi lúc ${formatDateTime(bundle.createdAt)}',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  if (!bundle.isPending) _statusCard(bundle, scheme),
                  if (note != null)
                    FormCard(
                      title: 'Ghi chú của người gửi',
                      children: [
                        Text(note, style: const TextStyle(fontSize: 17, height: 1.4)),
                      ],
                    ),
                  FormCard(
                    title: 'Các thay đổi (${described.length})',
                    children: [
                      for (final item in described) _RequestTile(item: item),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (bundle.isPending) _actionBar(described.length, scheme),
        ],
      ),
    );
  }

  Widget _statusCard(ReviewBundle bundle, ColorScheme scheme) {
    final approved = bundle.status == 'approved';
    final reviewed = bundle.reviewedAt;
    final reason = bundle.rejectReason;
    return FormCard(
      title: bundle.statusLabel,
      children: [
        if (reviewed != null)
          Text(
            'Xử lý lúc ${formatDateTime(reviewed)}',
            style: const TextStyle(fontSize: 16),
          ),
        if (!approved && reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Lý do: $reason',
              style: TextStyle(fontSize: 17, height: 1.4, color: scheme.error),
            ),
          ),
      ],
    );
  }

  Widget _actionBar(int changeCount, ColorScheme scheme) {
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _busy ? null : _reject,
                    child: const Text('Từ chối'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _busy ? null : () => _approve(changeCount),
                    child: Text(_busy ? 'Đang xử lý...' : 'Duyệt'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.item});

  final DescribedRequest item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warning = item.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          for (final line in item.details)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• $line',
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ),
          if (warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber, size: 22, color: _kWarningColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        color: _kWarningColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!item.supported)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'App chưa hỗ trợ duyệt mục này.',
                style: TextStyle(fontSize: 15, color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hộp thoại nhập lý do từ chối. Trả về lý do, hoặc null nếu bấm "Hủy".
Future<String?> showRejectReasonDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _RejectReasonDialog(),
  );
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final error = validateReason(_controller.text, required: true);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text(
        'Từ chối đề xuất',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vui lòng ghi lý do để người gửi hiểu vì sao.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              maxLength: kRequestNoteMaxLength,
              style: const TextStyle(fontSize: 18),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Lý do từ chối',
                errorText: _error,
                errorStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(100, 56),
            textStyle: const TextStyle(fontSize: 18),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(140, 56),
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          onPressed: _confirm,
          child: const Text('Từ chối'),
        ),
      ],
    );
  }
}