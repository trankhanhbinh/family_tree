import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/proposals/data/change_request_repository.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';

void main() {
  test('buildAdminApplyParams giữ đúng thứ tự và các trường', () {
    final params = buildAdminApplyParams(const [
      RequestDraft(
        entityType: kEntityPerson,
        action: kActionCreate,
        payload: {'id': 'p1', 'full_name': 'A'},
      ),
      RequestDraft(
        entityType: kEntityParentChild,
        action: kActionCreate,
        payload: {'id': 'c1', 'parent_id': 'p0', 'child_id': 'p1'},
      ),
    ]);

    expect(params.length, 2);
    expect(params[0]['entity_type'], 'person');
    expect(params[0]['action'], 'create');
    expect(params[0]['payload'], {'id': 'p1', 'full_name': 'A'});
    expect(params[1]['entity_type'], 'parent_child');
  });

  test('entity_id chỉ có khi bản nháp có entityId', () {
    final params = buildAdminApplyParams(const [
      RequestDraft(
        entityType: kEntityPerson,
        action: kActionCreate,
        payload: {'id': 'p1'},
      ),
      RequestDraft(
        entityType: kEntityMarriage,
        action: kActionDelete,
        entityId: 'm1',
        payload: {},
      ),
    ]);

    expect(params[0].containsKey('entity_id'), isFalse);
    expect(params[1]['entity_id'], 'm1');
    expect(params[1]['payload'], isEmpty);
  });
}