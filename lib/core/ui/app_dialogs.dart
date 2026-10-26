import 'package:flutter/material.dart';

import 'package:familytree/core/errors/app_error_messages.dart';

/// Hộp thoại to, chữ lớn, nút "Đóng" rộng. Dùng thay SnackBar.
/// Lưu ý: gọi sau khi await thì phải kiểm tra context.mounted trước.
Future<void> showMessageDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.info_outline,
  bool isError = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: Icon(
          icon,
          size: 44,
          color: isError ? scheme.error : scheme.primary,
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, height: 1.4),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      );
    },
  );
}

/// Hiện lỗi bất kỳ bằng tiếng Việt (qua vietnameseErrorMessage).
Future<void> showErrorDialog(BuildContext context, Object error) {
  return showMessageDialog(
    context,
    title: 'Chưa thực hiện được',
    message: vietnameseErrorMessage(error),
    icon: Icons.error_outline,
    isError: true,
  );
}