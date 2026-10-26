import 'package:flutter/material.dart';

/// Thanh nút "Gửi đề xuất" cố định ở đáy màn hình, cao 56.
class SubmitBar extends StatelessWidget {
  const SubmitBar({
    super.key,
    required this.submitting,
    required this.onPressed,
    this.label = 'Gửi đề xuất',
  });

  final bool submitting;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
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
              onPressed: submitting ? null : onPressed,
              icon: Icon(
                submitting ? Icons.hourglass_top : Icons.send,
                size: 24,
              ),
              label: Text(
                submitting ? 'Đang gửi...' : label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}