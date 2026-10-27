import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/auth/data/admin_provider.dart';

/// Bọc toàn bộ app (qua builder của MaterialApp.router): khi là admin thì
/// hiện dải vàng ở đầu MỌI màn hình.
/// Cấu trúc Column luôn cố định để Navigator không bị dựng lại khi đổi chế độ.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        isAdmin ? const _AdminBanner() : const SizedBox.shrink(),
        Expanded(
          // Dải đã chiếm chỗ thanh trạng thái nên bỏ padding trên của phần còn
          // lại, tránh AppBar bị cộng đôi khoảng trống.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: isAdmin,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _AdminBanner extends StatelessWidget {
  const _AdminBanner();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: const Color(0xFFFFB300),
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: const SizedBox(
          height: 32,
          child: Center(
            child: Text(
              'Chế độ quản trị viên',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}