import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/history/domain/history_entry.dart';
import 'package:familytree/features/history/domain/history_labels.dart';

HistoryGroup _group({required String actor, String? requestId}) {
  final entry = HistoryEntry.fromJson({
    'id': 'h1',
    'entity_type': 'person',
    'entity_id': 'a1',
    'action': 'update',
    'before_data': null,
    'after_data': null,
    'actor_name': actor,
    'actor_user_id': 'u1',
    'request_id': requestId,
    'created_at': '2026-10-28T06:48:25.087756+00:00',
  });
  return groupHistory([entry]).single;
}

void main() {
  test('formatHistoryTime: thêm số 0 đầu cho ngày, tháng, giờ, phút', () {
    expect(formatHistoryTime(DateTime(2026, 1, 5, 7, 3)), '05/01/2026 07:03');
  });

  test('admin sửa trực tiếp (không có request_id)', () {
    expect(
      historyActorLabel(_group(actor: 'Admin')),
      'Admin sửa trực tiếp',
    );
  });

  test('đề xuất đã duyệt: hiện biệt danh người gửi', () {
    expect(
      historyActorLabel(_group(actor: 'Bác Hai', requestId: 'r1')),
      'Đề xuất của Bác Hai, admin đã duyệt',
    );
  });

  test('biệt danh "Admin" nhưng có request_id: không giả được admin sửa trực tiếp',
      () {
    expect(
      historyActorLabel(_group(actor: 'Admin', requestId: 'r1')),
      'Đề xuất của Admin, admin đã duyệt',
    );
  });
}