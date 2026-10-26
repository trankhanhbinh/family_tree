import 'package:flutter/material.dart';

/// Màn hình tạm khi dữ liệu chưa tải xong / lỗi / không thấy người.
/// message = null nghĩa là đang tải.
class ProposalPlaceholderScreen extends StatelessWidget {
  const ProposalPlaceholderScreen({
    super.key,
    required this.title,
    this.message,
  });

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: text == null
            ? const CircularProgressIndicator()
            : Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}