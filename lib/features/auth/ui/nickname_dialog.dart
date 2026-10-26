import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:familytree/features/auth/domain/nickname_rules.dart';

/// Hỏi tên người đóng góp. Trả về tên đã chuẩn hóa, hoặc null nếu bấm "Hủy".
Future<String?> showNicknameDialog(
  BuildContext context, {
  String? initialValue,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NicknameDialog(initialValue: initialValue),
  );
}

class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog({this.initialValue});

  final String? initialValue;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = validateNickname(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(normalizeNickname(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text(
        'Bạn tên là gì?',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tên này sẽ hiện cho quản trị viên khi bạn gửi đề xuất.',
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(fontSize: 20),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              LengthLimitingTextInputFormatter(kNicknameMaxLength),
            ],
            decoration: InputDecoration(
              labelText: 'Tên của bạn',
              errorText: _error,
              errorStyle: const TextStyle(fontSize: 16),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
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
            minimumSize: const Size(100, 56),
            textStyle: const TextStyle(fontSize: 18),
          ),
          onPressed: _submit,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}