import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/history/domain/field_display.dart';
import 'package:familytree/features/tree/domain/branch.dart';

void main() {
  test('chi cha bỏ trống -> "Chi gốc"', () {
    expect(displayHistoryValue('parent_branch_id', null, const []), 'Chi gốc');
  });

  test('chi/nhánh của người bỏ trống vẫn là "Không thuộc chi nào"', () {
    expect(
      displayHistoryValue('branch_id', null, const []),
      'Không thuộc chi nào',
    );
  });

  test('chi cha không tra được -> "(chi đã xóa)"', () {
    expect(
      displayHistoryValue('parent_branch_id', 'zzz', const []),
      '(chi đã xóa)',
    );
  });

  test('chi cha tra được -> đường dẫn', () {
    const branches = [
      Branch(id: 'b1', name: 'Chi Nhất', sortOrder: 0),
      Branch(id: 'b3', name: 'Nhánh Nhất-1', parentBranchId: 'b1', sortOrder: 0),
    ];
    expect(
      displayHistoryValue('parent_branch_id', 'b3', branches),
      'Chi Nhất › Nhánh Nhất-1',
    );
  });

  test('nguồn gốc dài bị cắt ở 60 ký tự', () {
    final text = displayHistoryValue('origin', 'a' * 100, const []);
    expect(text, '${'a' * 60}…');
  });

  test('văn bản ngắn giữ nguyên, ghi chú của người không bị cắt', () {
    expect(
      displayHistoryValue('description', 'Gốc Thanh Hóa', const []),
      'Gốc Thanh Hóa',
    );
    expect(displayHistoryValue('notes', 'b' * 100, const []), 'b' * 100);
  });

  test('khác nhau chỉ ở phần bị cắt vẫn có dòng thông báo', () {
    final lines = diffHistoryLines(
      before: {'description': '${'a' * 70}x'},
      after: {'description': '${'a' * 70}y'},
      labels: kHistoryClanLabels,
      branches: const [],
    );
    expect(lines, ['Giới thiệu: đã sửa phần nội dung phía sau']);
  });

  test('giống hệt nhau thì không có dòng nào', () {
    final lines = diffHistoryLines(
      before: {'name': 'Họ Nguyễn', 'origin': 'Gốc'},
      after: {'name': 'Họ Nguyễn', 'origin': 'Gốc'},
      labels: kHistoryClanLabels,
      branches: const [],
    );
    expect(lines, isEmpty);
  });
}