import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/branch/domain/branch_delete_check.dart';
import 'package:familytree/features/branch/domain/branch_delete_texts.dart';
import 'package:familytree/features/branch/domain/branch_usage.dart';
import 'package:familytree/features/tree/domain/branch.dart';

const Branch _child = Branch(id: 'c', name: 'Nhánh con', sortOrder: 0);

const BranchMember _living = BranchMember(
  id: 'p1',
  fullName: 'A',
  branchId: 'b',
  isDeleted: false,
);

const BranchMember _deleted = BranchMember(
  id: 'p2',
  fullName: 'B',
  branchId: 'b',
  isDeleted: true,
);

void main() {
  group('branchBlockedSteps', () {
    test('chỉ còn chi con: bước chi con rồi bước cuối', () {
      final steps = branchBlockedSteps(
        const BranchDeleteBlockers(
          childBranches: [_child],
          livingPeople: [],
          deletedPeople: [],
        ),
      );
      expect(steps, [kStepChildren, kStepFinal]);
    });

    test('còn người sống và người đã xóa: hai bước theo thứ tự rồi bước cuối', () {
      final steps = branchBlockedSteps(
        const BranchDeleteBlockers(
          childBranches: [],
          livingPeople: [_living],
          deletedPeople: [_deleted],
        ),
      );
      expect(steps, [kStepLiving, kStepDeleted, kStepFinal]);
    });

    test('còn cả ba thứ: chi con, người sống, người đã xóa, bước cuối', () {
      final steps = branchBlockedSteps(
        const BranchDeleteBlockers(
          childBranches: [_child],
          livingPeople: [_living],
          deletedPeople: [_deleted],
        ),
      );
      expect(steps, [kStepChildren, kStepLiving, kStepDeleted, kStepFinal]);
    });

    test('chi đã trống thì không cần bước nào', () {
      final steps = branchBlockedSteps(
        const BranchDeleteBlockers(
          childBranches: [],
          livingPeople: [],
          deletedPeople: [],
        ),
      );
      expect(steps, isEmpty);
    });
  });

  group('describeMoveMembers', () {
    test('người đang sống', () {
      expect(
        describeMoveMembers(
          count: 3,
          areDeleted: false,
          fromName: 'Nhánh 1',
          toPath: 'Chi Cả › Nhánh 2',
        ),
        'Chuyển 3 người đang sống\n'
        'Từ chi: Nhánh 1\n'
        'Sang chi: Chi Cả › Nhánh 2',
      );
    });

    test('người đã xóa có thêm dòng nhắc họ vẫn là người đã xóa', () {
      expect(
        describeMoveMembers(
          count: 2,
          areDeleted: true,
          fromName: 'Nhánh 1',
          toPath: 'Chi Nhì',
        ),
        'Chuyển 2 người đã xóa\n'
        'Từ chi: Nhánh 1\n'
        'Sang chi: Chi Nhì\n'
        'Họ vẫn là người đã xóa, chỉ đổi chi.',
      );
    });
  });

  test('tiêu đề các thẻ vướng mắc', () {
    expect(childBranchesTitle(2), 'Còn 2 chi con');
    expect(livingPeopleTitle(5), 'Còn 5 người đang sống thuộc chi này');
    expect(deletedPeopleTitle(1), 'Còn 1 người đã xóa thuộc chi này');
  });

  test('nhãn nút chuyển người', () {
    expect(moveMembersButtonLabel(4), 'Chuyển 4 người sang chi khác');
  });
}