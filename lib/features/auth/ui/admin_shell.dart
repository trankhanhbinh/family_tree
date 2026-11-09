import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/theme/app_colors.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/push/data/push_device_controller.dart';

/// Bọc toàn bộ app (qua builder của MaterialApp.router): khi là admin thì
/// hiện dải xanh ở đầu MỌI màn hình.
/// Cấu trúc Column luôn cố định để Navigator không bị dựng lại khi đổi chế độ.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    // Vừa thành admin (đăng nhập hoặc mở lại app còn phiên cũ): nếu quyền
    // thông báo đã được cấp thì đăng ký thiết bị âm thầm, không hộp thoại.
    ref.listen(isAdminProvider, (_, next) {
      if (next) {
        unawaited(_onBecameAdmin(ref.read(pushDeviceControllerProvider)));
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        isAdmin ? const AdminModeBanner() : const SizedBox.shrink(),
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

Future<void> _onBecameAdmin(PushDeviceController controller) async {
  await controller.flushPendingDeletes();
  await controller.registerSilentlyIfGranted(isAdmin: true);
}

class AdminModeBanner extends StatelessWidget {
  const AdminModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: AppColors.info,
        child: Padding(
          padding: EdgeInsets.only(top: top),
          child: const SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                SizedBox(width: 6),
                Text(
                  'Chế độ quản trị viên',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
