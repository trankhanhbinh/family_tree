import 'package:familytree/features/tree/data/collapsed_ids_provider.dart';
import 'package:familytree/features/tree/data/focus_request_provider.dart';
import 'package:familytree/features/tree/domain/collapse_utils.dart';
import 'package:familytree/features/tree/domain/family_node.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sample_family.dart';

void main() {
  late FamilyForest forest;

  setUp(() {
    forest = buildSampleForest();
  });

  test('collapseBlockersOf: người chính', () {
    final blockers = collapseBlockersOf(forest);
    expect(blockers['01'], isEmpty);
    expect(blockers['03'], ['01']);
    expect(blockers['15'], ['01', '03', '09']);
    expect(blockers['16'], ['01', '03', '09']);
    expect(blockers['12'], ['01', '04']);
  });

  test('collapseBlockersOf: vợ/chồng lấy tổ tiên của người chính', () {
    final blockers = collapseBlockersOf(forest);
    expect(blockers['02'], isEmpty);
    expect(blockers['06'], ['01']);
    expect(blockers['14'], ['01', '03']);
  });

  test('focusOn mở các tổ tiên đang thu gọn và giữ nguyên nhánh khác', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(collapsedIdsProvider.notifier)
        .collapseAll({'01', '03', '04', '09'});
    container.read(focusRequestProvider.notifier).focusOn('15', forest);

    expect(container.read(collapsedIdsProvider), {'04'});
    expect(container.read(focusRequestProvider)!.personId, '15');
  });

  test('token tăng mỗi lần focusOn; clear đưa về null', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(focusRequestProvider.notifier);

    notifier.focusOn('15', forest);
    final first = container.read(focusRequestProvider)!.token;
    notifier.focusOn('15', forest);
    final second = container.read(focusRequestProvider)!.token;
    expect(second, greaterThan(first));

    notifier.clear();
    expect(container.read(focusRequestProvider), isNull);
  });
}