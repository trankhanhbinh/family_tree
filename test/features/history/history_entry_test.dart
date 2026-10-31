import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/history/domain/history_entry.dart';
import 'package:familytree/features/history/domain/history_feed_state.dart';

const String _t1 = '2026-10-27T20:43:39.640461+00:00';
const String _t2 = '2026-10-28T06:48:25.087756+00:00';
const String _admin = '8677e050-b828-4df4-a917-79496172bbe4';

Map<String, dynamic> _row({
  String id = 'h1',
  String entityType = 'person',
  String entityId = 'e1',
  String action = 'update',
  Object? before,
  Object? after,
  String actor = 'Admin',
  String? actorUserId = _admin,
  String? requestId,
  String createdAt = _t1,
}) {
  return {
    'id': id,
    'entity_type': entityType,
    'entity_id': entityId,
    'action': action,
    'before_data': before,
    'after_data': after,
    'actor_name': actor,
    'actor_user_id': actorUserId,
    'request_id': requestId,
    'created_at': createdAt,
  };
}

HistoryEntry _entry({
  String id = 'h1',
  String entityType = 'person',
  String action = 'update',
  String? actorUserId = _admin,
  String createdAt = _t1,
}) {
  return HistoryEntry.fromJson(
    _row(
      id: id,
      entityType: entityType,
      action: action,
      actorUserId: actorUserId,
      createdAt: createdAt,
    ),
  );
}

List<HistoryEntry> _entries(int count) {
  return List.generate(count, (i) => _entry(id: 'e$i'));
}

void main() {
  test('fromJson: đọc đủ các trường', () {
    final entry = HistoryEntry.fromJson(
      _row(before: {'a': 1}, after: {'a': 2}, requestId: 'r1'),
    );
    expect(entry.id, 'h1');
    expect(entry.entityType, 'person');
    expect(entry.action, 'update');
    expect(entry.before, {'a': 1});
    expect(entry.after, {'a': 2});
    expect(entry.data, {'a': 2});
    expect(entry.actorName, 'Admin');
    expect(entry.requestId, 'r1');
    expect(entry.createdAt, DateTime.parse(_t1));
  });

  test('fromJson: before/after không phải đối tượng JSON -> null', () {
    final entry = HistoryEntry.fromJson(_row(before: 'null', after: null));
    expect(entry.before, isNull);
    expect(entry.after, isNull);
    expect(entry.data, isNull);
  });

  test('gom nhóm: cùng created_at và cùng người thì cùng nhóm', () {
    final groups = groupHistory([
      _entry(id: '1'),
      _entry(id: '2', entityType: 'parent_child', action: 'delete'),
      _entry(id: '3', actorUserId: 'u2'),
      _entry(id: '4', createdAt: _t2),
    ]);
    expect(groups, hasLength(3));
  });

  test('gom nhóm: nhóm mới nhất đứng trước', () {
    final groups = groupHistory([
      _entry(id: '1'),
      _entry(id: '4', createdAt: _t2),
    ]);
    expect(groups.first.entries.single.id, '4');
    expect(groups.first.createdAt, DateTime.parse(_t2));
  });

  test('trong nhóm: tạo người, xóa quan hệ, rồi xóa người', () {
    final groups = groupHistory([
      _entry(id: 'a', action: 'delete'),
      _entry(id: 'b', entityType: 'parent_child', action: 'delete'),
      _entry(id: 'c', action: 'create'),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.entries.map((e) => e.id).toList(), ['c', 'b', 'a']);
  });


  test('trong nhóm: thêm chi đứng trước thêm người', () {
    final groups = groupHistory([
      _entry(id: 'a', action: 'create'),
      _entry(id: 'b', entityType: 'branch', action: 'create'),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.entries.map((e) => e.id).toList(), ['b', 'a']);
  });
  
  test('phân trang: nhóm bị cắt giữa hai trang được ghép lại', () {
    final first = HistoryFeedState.firstPage([_entry(id: '1')]);
    final next = first.appendPage([
      _entry(id: '2', entityType: 'parent_child', action: 'delete'),
    ]);
    expect(next.groups, hasLength(1));
    expect(next.entries, hasLength(2));
  });

  test('phân trang: bỏ dòng trùng id và cộng đúng số dòng đã lấy', () {
    final first = HistoryFeedState.firstPage(_entries(kHistoryPageSize));
    expect(first.hasMore, isTrue);
    expect(first.fetchedCount, kHistoryPageSize);

    final next = first.appendPage([_entry(id: 'e49'), _entry(id: 'x1')]);
    expect(next.entries, hasLength(kHistoryPageSize + 1));
    expect(next.fetchedCount, kHistoryPageSize + 2);
    expect(next.hasMore, isFalse);
  });

  test('phân trang: trang đầu chưa đầy thì hết dữ liệu', () {
    final first = HistoryFeedState.firstPage(_entries(3));
    expect(first.hasMore, isFalse);
    expect(first.fetchedCount, 3);
  });

  test('bộ lọc theo người: 11 điều kiện', () {
    final parts = personHistoryFilter('P1').split(',');
    expect(parts, hasLength(11));
    expect(parts, contains('entity_id.eq.P1'));
    expect(parts, contains('before_data->>child_id.eq.P1'));
    expect(parts, contains('after_data->>person2_id.eq.P1'));
  });
}