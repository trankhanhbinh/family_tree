import 'package:familytree/features/branch/domain/branch_delete_check.dart';

/// Đoạn "Vì sao chưa xóa được?" (chữ đời thường cho người lớn tuổi).
const String kBranchBlockedReason =
    'Ứng dụng chỉ cho xóa một chi khi chi đó đã hoàn toàn trống: không còn chi '
    'con và không còn ai thuộc chi đó. Nếu xóa khi còn người, những người này '
    'sẽ bị mất thông tin chi ngay và sau này rất khó biết họ từng thuộc chi '
    'nào. Người đã xóa cũng được tính, vì khi khôi phục họ cũng sẽ không còn '
    'chi nữa.';

const String kStepChildren =
    'Chuyển từng chi con sang chi khác: ở màn "Quản lý chi/nhánh", chạm vào '
    'chi con rồi chọn "Chuyển sang chi khác".';

const String kStepLiving =
    'Chuyển những người đang sống của chi này sang một chi khác (nút ở mục '
    '"Tình trạng hiện tại" phía trên).';

const String kStepDeleted =
    'Chuyển những người đã xóa sang một chi khác (nút ở mục "Tình trạng hiện '
    'tại" phía trên). Họ vẫn là người đã xóa, chỉ đổi chi.';

const String kStepFinal =
    'Quay lại danh sách chi, chạm vào chi này và chọn "Xóa chi" lần nữa.';

/// Các bước cần làm (chưa đánh số), đúng thứ tự: chi con, người sống, người đã xóa,
/// rồi bước cuối. Chi đã trống thì không cần bước nào.
List<String> branchBlockedSteps(BranchDeleteBlockers blockers) {
  if (blockers.canDelete) {
    return const <String>[];
  }
  return [
    if (blockers.childBranches.isNotEmpty) kStepChildren,
    if (blockers.livingPeople.isNotEmpty) kStepLiving,
    if (blockers.deletedPeople.isNotEmpty) kStepDeleted,
    kStepFinal,
  ];
}

String childBranchesTitle(int count) => 'Còn $count chi con';

String livingPeopleTitle(int count) =>
    'Còn $count người đang sống thuộc chi này';

String deletedPeopleTitle(int count) =>
    'Còn $count người đã xóa thuộc chi này';

String moveMembersButtonLabel(int count) => 'Chuyển $count người sang chi khác';

/// Nội dung hộp thoại xác nhận khi chuyển nhóm người sang chi khác.
String describeMoveMembers({
  required int count,
  required bool areDeleted,
  required String fromName,
  required String toPath,
}) {
  final who = areDeleted ? 'đã xóa' : 'đang sống';
  final lines = <String>[
    'Chuyển $count người $who',
    'Từ chi: $fromName',
    'Sang chi: $toPath',
  ];
  if (areDeleted) {
    lines.add('Họ vẫn là người đã xóa, chỉ đổi chi.');
  }
  return lines.join('\n');
}