import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/review/domain/change_request.dart';

const String _t0 = '2026-10-28T03:00:00.123456+00:00';
const String _t1 = '2026-10-28T04:00:00.000000+00:00';

ChangeRequest _req({
  String id = 'r1',
  String requester = 'u1',
  String created = _t0,
  String entityType = 'person',
  String action = 'create',
  String? entityId,
  Map<String, dynamic> payload = const {},
  String? note,
  String status = 'pending',
}) {
  return ChangeRequest(
    id: id,
    requesterId: requester,
    nickname: 'Bác Hai',
    entityType: entityType,
    entityId: entityId,
    action: action,
    payload: payload,
    note: note,
    status: status,
    createdAtRaw: created,
    createdAt: DateTime.parse(created),
  );
}

void main() {
  test('fromJson đọc đủ các trường', () {
    final r = ChangeRequest.fromJson({
      'id': 'r1',
      'requester_id': 'u1',
      'nickname': 'Bác Hai',
      'entity_type': 'person',
      'entity_id': null,
      'action': 'create',
      'payload': {'full_name': 'A'},
      'note': 'ghi chú',
      'status': 'pending',
      'reviewed_by': null,
      'reviewed_at': null,
      'reject_reason': null,
      'created_at': _t0,
    });
    expect(r.id, 'r1');
    expect(r.nickname, 'Bác Hai');
    expect(r.entityId, isNull);
    expect(r.payload['full_name'], 'A');
    expect(r.note, 'ghi chú');
    expect(r.createdAtRaw, _t0);
    expect(r.reviewedAt, isNull);
    expect(r.bundleKey, 'u1|$_t0');
  });

  test('fromJson: payload không phải object -> map rỗng', () {
    final r = ChangeRequest.fromJson({
      'id': 'r1',
      'requester_id': 'u1',
      'nickname': 'A',
      'entity_type': 'person',
      'action': 'delete',
      'payload': null,
      'status': 'pending',
      'created_at': _t0,
    });
    expect(r.payload, isEmpty);
  });

  test('groupRequests: cùng người gửi và cùng thời điểm -> một gói', () {
    final bundles = groupRequests([
      _req(id: 'a'),
      _req(id: 'b', entityType: 'parent_child'),
      _req(id: 'c', entityType: 'parent_child'),
    ]);
    expect(bundles.length, 1);
    expect(bundles.single.requests.length, 3);
  });

  test('groupRequests: khác thời điểm hoặc khác người gửi -> gói riêng', () {
    final bundles = groupRequests([
      _req(id: 'a'),
      _req(id: 'b', created: _t1),
      _req(id: 'c', requester: 'u2'),
    ]);
    expect(bundles.length, 3);
  });

  test('groupRequests: cũ nhất trước hoặc mới nhất trước', () {
    final input = [
      _req(id: 'new', created: _t1),
      _req(id: 'old', created: _t0),
    ];
    final oldestFirst = groupRequests(input);
    final newestFirst = groupRequests(input, oldestFirst: false);
    expect(oldestFirst.first.requests.single.id, 'old');
    expect(newestFirst.first.requests.single.id, 'new');
  });

  test('trong gói: tạo người trước quan hệ; xóa quan hệ trước khi xóa người', () {
    final create = groupRequests([
      _req(id: 'pc', entityType: 'parent_child'),
      _req(id: 'p', entityType: 'person'),
    ]).single;
    expect(create.requests.map((r) => r.id).toList(), ['p', 'pc']);

    final delete = groupRequests([
      _req(id: 'p', entityType: 'person', action: 'delete'),
      _req(id: 'm', entityType: 'marriage', action: 'delete'),
      _req(id: 'pc', entityType: 'parent_child', action: 'delete'),
    ]).single;
    expect(delete.requests.map((r) => r.id).toList(), ['pc', 'm', 'p']);
  });

  test('approvalRank: tạo < sửa < xóa', () {
    expect(
      approvalRank('person', 'create'),
      lessThan(approvalRank('parent_child', 'create')),
    );
    expect(
      approvalRank('marriage', 'create'),
      lessThan(approvalRank('person', 'update')),
    );
    expect(
      approvalRank('person', 'update'),
      lessThan(approvalRank('parent_child', 'delete')),
    );
    expect(
      approvalRank('parent_child', 'delete'),
      lessThan(approvalRank('person', 'delete')),
    );
  });

  test('note lấy ghi chú đầu tiên không rỗng; requestIds đủ id', () {
    final bundle = groupRequests([
      _req(id: 'a', note: '   '),
      _req(id: 'b', entityType: 'parent_child', note: 'Thêm nhầm người'),
    ]).single;
    expect(bundle.note, 'Thêm nhầm người');
    expect(bundle.requestIds.toSet(), {'a', 'b'});
  });

  test('hasUnsupported: chi/nhánh -> true; người, cha-con, hôn nhân -> false', () {
    final branch = groupRequests([_req(entityType: 'branch')]).single;
    expect(branch.hasUnsupported, isTrue);

    final normal = groupRequests([
      _req(id: 'a', entityType: 'person'),
      _req(id: 'b', entityType: 'parent_child'),
      _req(id: 'c', entityType: 'marriage'),
    ]).single;
    expect(normal.hasUnsupported, isFalse);
  });
}