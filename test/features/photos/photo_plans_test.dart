import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/photos/domain/photo_plans.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';

PersonPhoto _photo(String id, {bool isAvatar = false}) {
  return PersonPhoto(
    id: id,
    personId: 'p1',
    storagePath: 'p1/$id.jpg',
    isAvatar: isAvatar,
    sortOrder: 0,
  );
}

void main() {
  test('planAddPhoto: bỏ caption khi để trống', () {
    final drafts = planAddPhoto(
      photoId: 'f1',
      personId: 'p1',
      storagePath: 'p1/f1.jpg',
      caption: '   ',
      sortOrder: 0,
      makeAvatar: true,
    );
    expect(drafts.length, 1);
    expect(drafts.single.entityType, kEntityPersonPhoto);
    expect(drafts.single.action, kActionCreate);
    expect(drafts.single.payload.containsKey('caption'), isFalse);
    expect(drafts.single.payload['is_avatar'], true);
    expect(drafts.single.payload['storage_path'], 'p1/f1.jpg');
  });

  test('planAddPhoto: giữ caption đã cắt khoảng trắng', () {
    final drafts = planAddPhoto(
      photoId: 'f1',
      personId: 'p1',
      storagePath: 'p1/f1.jpg',
      caption: '  Ảnh Tết 1990  ',
      sortOrder: 2,
      makeAvatar: false,
    );
    expect(drafts.single.payload['caption'], 'Ảnh Tết 1990');
    expect(drafts.single.payload['sort_order'], 2);
    expect(drafts.single.payload['is_avatar'], false);
  });

  test('planSetAvatar: bỏ cờ ở ảnh cũ TRƯỚC rồi đặt cờ ảnh mới', () {
    final drafts = planSetAvatar(
      photo: _photo('new'),
      currentAvatar: _photo('old', isAvatar: true),
    );
    expect(drafts.length, 2);
    expect(drafts[0].entityId, 'old');
    expect(drafts[0].payload, {'is_avatar': false});
    expect(drafts[1].entityId, 'new');
    expect(drafts[1].payload, {'is_avatar': true});
  });

  test('planSetAvatar: ảnh đã là đại diện -> không có lệnh nào', () {
    final drafts = planSetAvatar(
      photo: _photo('a', isAvatar: true),
      currentAvatar: _photo('a', isAvatar: true),
    );
    expect(drafts, isEmpty);
  });

  test('planSetAvatar: chưa có ảnh đại diện -> chỉ một lệnh', () {
    final drafts = planSetAvatar(photo: _photo('a'));
    expect(drafts.length, 1);
    expect(drafts.single.payload, {'is_avatar': true});
  });

  test('planDeletePhoto: một lệnh xóa theo id ảnh', () {
    final drafts = planDeletePhoto(_photo('a'));
    expect(drafts.length, 1);
    expect(drafts.single.action, kActionDelete);
    expect(drafts.single.entityType, kEntityPersonPhoto);
    expect(drafts.single.entityId, 'a');
  });
}