import 'package:familytree/features/history/domain/history_entry.dart';

String _two(int value) => value.toString().padLeft(2, '0');

/// Ngày giờ theo giờ của máy: dd/MM/yyyy HH:mm.
String formatHistoryTime(DateTime time) {
  final local = time.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// Ai thực hiện lần thay đổi này. Phân biệt bằng request_id chứ KHÔNG dựa
/// vào actor_name: người đóng góp đặt biệt danh "Admin" thì sau khi được
/// duyệt vẫn không giả được là admin sửa trực tiếp.
String historyActorLabel(HistoryGroup group) {
  final approved = group.entries.any((entry) => entry.requestId != null);
  if (approved) {
    return 'Đề xuất của ${group.actorName}, admin đã duyệt';
  }
  return 'Admin sửa trực tiếp';
}