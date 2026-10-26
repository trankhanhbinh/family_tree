import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/errors/app_error_messages.dart';
import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/features/auth/data/auth_service.dart';
import 'package:familytree/features/auth/data/nickname_store.dart';
import 'package:familytree/features/auth/ui/nickname_dialog.dart';

class Contributor {
  const Contributor({required this.userId, required this.nickname});

  final String userId;
  final String nickname;
}

/// Cổng cho mọi thao tác "Đề xuất" (4B, 4C, 4F gọi hàm này đầu tiên).
/// Trả về null nếu người dùng hủy hoặc có lỗi (lỗi đã được báo bằng hộp thoại).
Future<Contributor?> ensureContributor(
  BuildContext context,
  WidgetRef ref,
) async {
  final auth = ref.read(authServiceProvider);

  try {
    await auth.ensureSignedIn();
  } catch (error) {
    if (context.mounted) {
      await showErrorDialog(context, error);
    }
    return null;
  }

  final userId = auth.currentUser?.id;
  if (userId == null) {
    if (context.mounted) {
      await showMessageDialog(
        context,
        title: 'Chưa thực hiện được',
        message: kGenericErrorMessage,
        icon: Icons.error_outline,
        isError: true,
      );
    }
    return null;
  }

  var nickname = await ref.read(nicknameProvider.future);
  if (nickname == null || nickname.isEmpty) {
    if (!context.mounted) {
      return null;
    }
    final entered = await showNicknameDialog(context);
    if (entered == null || !context.mounted) {
      return null;
    }
    await ref.read(nicknameProvider.notifier).save(entered);
    nickname = entered;
  }

  return Contributor(userId: userId, nickname: nickname);
}

/// Cho sửa lại nickname sau này. Trả về tên mới, hoặc null nếu hủy.
Future<String?> editNickname(BuildContext context, WidgetRef ref) async {
  final current = await ref.read(nicknameProvider.future);
  if (!context.mounted) {
    return null;
  }
  final result = await showNicknameDialog(context, initialValue: current);
  if (result == null || !context.mounted) {
    return null;
  }
  await ref.read(nicknameProvider.notifier).save(result);
  return result;
}