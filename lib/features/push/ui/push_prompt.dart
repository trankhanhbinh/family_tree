import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/push/data/push_device_controller.dart';
import 'package:familytree/features/push/domain/push_rules.dart';

/// Gọi ngay sau khi admin đăng nhập thành công.
/// Đã cấp quyền thông báo (hoặc Firebase không dùng được) thì không làm gì.
/// Ngược lại: hộp thoại giải thích, rồi để hệ thống hỏi quyền.
/// Không bao giờ ném lỗi, để không làm hỏng việc đăng nhập.
Future<void> promptEnablePush(BuildContext context, WidgetRef ref) async {
  try {
    final controller = ref.read(pushDeviceControllerProvider);

    final needsPrompt = await controller.needsLoginPrompt();
    if (!needsPrompt || !context.mounted) {
      return;
    }

    // Nút chính = "Để sau" vì đóng hộp thoại ra ngoài được tính là nút chính:
    // lỡ chạm ra ngoài thì chỉ là bỏ qua, không gây hại.
    final later = await showChoiceDialog(
      context,
      title: 'Bật thông báo đề xuất mới?',
      message: 'Khi có người gửi đề xuất mới, điện thoại sẽ báo cho bạn biết. '
          'Sau khi bấm “Bật thông báo”, máy sẽ hỏi thêm một lần nữa, '
          'bạn hãy chọn “Cho phép”.',
      primaryLabel: 'Để sau',
      secondaryLabel: 'Bật thông báo',
    );
    if (later || !context.mounted) {
      return;
    }

    final result = await controller.enable();
    if (!context.mounted) {
      return;
    }

    switch (result) {
      case PushEnableResult.enabled:
        await showMessageDialog(
          context,
          title: 'Đã bật thông báo',
          message: 'Từ giờ, khi có đề xuất mới, điện thoại sẽ báo cho bạn.',
          icon: Icons.notifications_active_outlined,
        );
      case PushEnableResult.denied:
        await showMessageDialog(
          context,
          title: 'Chưa bật được thông báo',
          message: 'Để nhận thông báo, hãy mở Cài đặt của máy, vào Ứng dụng, '
              'chọn familytree, chọn Thông báo rồi bật lên.',
          icon: Icons.notifications_off_outlined,
        );
      case PushEnableResult.saveFailed:
        await showMessageDialog(
          context,
          title: 'Chưa lưu được lên hệ thống',
          message: 'Đã bật thông báo trên máy nhưng chưa lưu được lên hệ '
              'thống. Hãy mở lại ứng dụng khi có mạng, máy sẽ tự thử lại.',
          icon: Icons.cloud_off_outlined,
          isError: true,
        );
      case PushEnableResult.unavailable:
        await showMessageDialog(
          context,
          title: 'Chưa dùng được thông báo',
          message: 'Máy này chưa dùng được thông báo đẩy. Bạn vẫn dùng ứng '
              'dụng bình thường.',
          icon: Icons.notifications_off_outlined,
        );
    }
  } catch (error) {
    debugPrint('Hỏi bật thông báo thất bại (bỏ qua): $error');
  }
}