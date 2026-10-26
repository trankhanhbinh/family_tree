import 'package:flutter/material.dart';

/// Hộp thoại 2 lựa chọn, hai nút to xếp dọc.
/// Trả về true nếu bấm nút chính (primary), false nếu bấm nút phụ.
Future<bool> showChoiceDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String primaryLabel,
  required String secondaryLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 18, height: 1.4),
          ),
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(primaryLabel, style: const TextStyle(fontSize: 18)),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(secondaryLabel, style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      );
    },
  );
  return result ?? true;
}

/// Hỏi khi bấm quay lại giữa chừng. Trả về true nếu người dùng chọn THOÁT.
Future<bool> confirmLeaveWithoutSending(BuildContext context) async {
  final stay = await showChoiceDialog(
    context,
    title: 'Thoát mà không gửi?',
    message: 'Các thông tin bạn vừa nhập sẽ bị mất.',
    primaryLabel: 'Ở lại',
    secondaryLabel: 'Thoát, không gửi',
  );
  return !stay;
}