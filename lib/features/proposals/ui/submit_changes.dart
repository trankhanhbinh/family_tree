import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/auth/ui/contributor_gate.dart';
import 'package:familytree/features/proposals/data/change_request_repository.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

enum SubmitOutcome {
  /// Người dùng hủy (đóng hộp thoại tên) hoặc đã có lỗi được báo.
  cancelled,

  /// Người thường: đã gửi đề xuất.
  proposed,

  /// Admin: đã lưu trực tiếp.
  saved,
}

/// MỘT chỗ duy nhất quyết định: admin thì lưu trực tiếp, người thường thì gửi đề xuất.
/// Ném lỗi nếu thất bại (nơi gọi hiện bằng showErrorDialog).
Future<SubmitOutcome> submitChanges(
  BuildContext context,
  WidgetRef ref, {
  required List<RequestDraft> drafts,
  String? note,
  int noteIndex = 0,
}) async {
  // Lấy sẵn mọi thứ cần dùng SAU các lệnh await (màn hình có thể đã đóng).
  final container = ProviderScope.containerOf(context, listen: false);
  final repository = container.read(changeRequestRepositoryProvider);
  final isAdmin = container.read(isAdminProvider);

  if (!isAdmin) {
    final contributor = await ensureContributor(context, ref);
    if (contributor == null) {
      return SubmitOutcome.cancelled;
    }
    await repository.submitAll(
      requesterId: contributor.userId,
      nickname: contributor.nickname,
      drafts: drafts,
      note: note,
      noteIndex: noteIndex,
    );
    return SubmitOutcome.proposed;
  }

  await repository.applyAsAdmin(drafts);
  container.invalidate(treeDataProvider);
  return SubmitOutcome.saved;
}

/// Hộp thoại báo thành công, nội dung tùy kết quả.
Future<void> showSubmitDone(BuildContext context, SubmitOutcome outcome) {
  if (outcome == SubmitOutcome.saved) {
    return showMessageDialog(
      context,
      title: 'Đã lưu thay đổi',
      message: 'Thay đổi đã được áp dụng và hiện trên cây ngay.',
      icon: Icons.check_circle_outline,
    );
  }
  return showMessageDialog(
    context,
    title: 'Đã gửi đề xuất',
    message: 'Quản trị viên sẽ xem và duyệt đề xuất của bạn.\n'
        'Thay đổi sẽ hiện trên cây sau khi được duyệt.',
    icon: Icons.check_circle_outline,
  );
}

/// Hộp thoại xác nhận trước khi gửi/lưu. Trả về true = tiếp tục.
/// Admin: nút chính là "Xem lại" (chạm ra ngoài hộp thoại = KHÔNG lưu).
/// Người thường: giữ như cũ, có số "suất" chờ duyệt.
Future<bool> confirmSubmit(
  BuildContext context, {
  required bool isAdmin,
  required String summary,
  required int slots,
}) async {
  if (isAdmin) {
    final review = await showChoiceDialog(
      context,
      title: 'Lưu thay đổi này?',
      message: '$summary\n\nThay đổi được áp dụng ngay.',
      primaryLabel: 'Xem lại',
      secondaryLabel: 'Lưu thay đổi',
    );
    return !review;
  }
  return showChoiceDialog(
    context,
    title: 'Gửi đề xuất này?',
    message: '$summary\n\n'
        'Đề xuất dùng $slots trong tối đa 10 suất chờ duyệt.',
    primaryLabel: 'Gửi đề xuất',
    secondaryLabel: 'Xem lại',
  );
}