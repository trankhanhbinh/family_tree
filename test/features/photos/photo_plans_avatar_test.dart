import 'package:flutter_test/flutter_test.dart';

import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/photos/domain/photo_plans.dart';
import 'package:familytree/features/proposals/domain/request_draft.dart';

void main() {
  group('planAddPhotoAsAvatar', () {
    test('chưa có ảnh đại diện: chỉ tạo ảnh mới có cờ', () {
      final drafts = planAddPhotoAsAvatar(
        photoId: 'p2',
        personId: 'a',
        storagePath: 'a/p2.jpg',
        caption: '  Chân dung  ',
        sortOrder: 1,
      );

      expect(drafts, hasLength(1));
      expect(drafts.single.action, kActionCreate);
      expect(drafts.single.payload['id'], 'p2');
      expect(drafts.single.payload['is_avatar'], isTrue);
      expect(drafts.single.payload['caption'], 'Chân dung');
    });

    test('đã có ảnh đại diện: bỏ cờ ảnh cũ trước rồi tạo ảnh mới', () {
      const old = PersonPhoto(
        id: 'p1',
        personId: 'a',
        storagePath: 'a/p1.jpg',
        isAvatar: true,
        sortOrder: 0,
      );

      final drafts = planAddPhotoAsAvatar(
        photoId: 'p2',
        personId: 'a',
        storagePath: 'a/p2.jpg',
        caption: '',
        sortOrder: 1,
        currentAvatar: old,
      );

      expect(drafts, hasLength(2));
      expect(drafts[0].action, kActionUpdate);
      expect(drafts[0].entityId, 'p1');
      expect(drafts[0].payload, {'is_avatar': false});
      expect(drafts[1].action, kActionCreate);
      expect(drafts[1].payload['id'], 'p2');
      expect(drafts[1].payload['is_avatar'], isTrue);
    });
  });
}
