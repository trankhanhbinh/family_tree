import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/core/errors/app_error_messages.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/photos/domain/photo_rules.dart';

PersonPhoto _photo(
  String id, {
  String personId = 'p1',
  int sortOrder = 0,
  bool isAvatar = false,
}) {
  return PersonPhoto(
    id: id,
    personId: personId,
    storagePath: '$personId/$id.jpg',
    isAvatar: isAvatar,
    sortOrder: sortOrder,
  );
}

void main() {
  test('detectPhotoExtension nhận JPEG', () {
    final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]);
    expect(detectPhotoExtension(bytes), 'jpg');
  });

  test('detectPhotoExtension nhận PNG', () {
    final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]);
    expect(detectPhotoExtension(bytes), 'png');
  });

  test('detectPhotoExtension nhận WebP', () {
    final bytes = Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0,
    ]);
    expect(detectPhotoExtension(bytes), 'webp');
  });

  test('detectPhotoExtension: loại khác hoặc quá ngắn -> null', () {
    expect(detectPhotoExtension(Uint8List.fromList([0x47, 0x49, 0x46, 0x38])), isNull);
    expect(detectPhotoExtension(Uint8List.fromList([0xFF])), isNull);
    expect(detectPhotoExtension(Uint8List(0)), isNull);
  });

  test('validatePhoto: hợp lệ -> null', () {
    expect(validatePhoto(sizeBytes: 1000, extension: 'jpg'), isNull);
    expect(validatePhoto(sizeBytes: kMaxPhotoBytes, extension: 'png'), isNull);
  });

  test('validatePhoto: quá 3 MB -> báo lỗi', () {
    expect(
      validatePhoto(sizeBytes: kMaxPhotoBytes + 1, extension: 'jpg'),
      kPhotoTooLargeMessage,
    );
  });

  test('validatePhoto: sai loại -> báo lỗi', () {
    expect(validatePhoto(sizeBytes: 1000, extension: null), kPhotoTypeMessage);
  });

  test('validatePhoto: rỗng -> báo lỗi', () {
    expect(validatePhoto(sizeBytes: 0, extension: 'jpg'), kPhotoEmptyMessage);
  });

  test('validateCaption: tối đa 200 ký tự', () {
    expect(validateCaption(''), isNull);
    expect(validateCaption('a' * kPhotoCaptionMaxLength), isNull);
    expect(validateCaption('a' * (kPhotoCaptionMaxLength + 1)), isNotNull);
  });

  test('buildPhotoStoragePath: person_id/photo_id.đuôi', () {
    expect(
      buildPhotoStoragePath(personId: 'p1', photoId: 'f1', extension: 'webp'),
      'p1/f1.webp',
    );
  });

  test('photosOfPerson: lọc theo người và xếp theo sort_order', () {
    final result = photosOfPerson(
      [
        _photo('b', sortOrder: 2),
        _photo('x', personId: 'p2'),
        _photo('a', sortOrder: 1),
      ],
      'p1',
    );
    expect(result.map((p) => p.id).toList(), ['a', 'b']);
  });

  test('avatarOf: trả ảnh có cờ đại diện, không có thì null', () {
    expect(avatarOf([_photo('a'), _photo('b', isAvatar: true)])?.id, 'b');
    expect(avatarOf([_photo('a')]), isNull);
  });

  test('nextSortOrder: rỗng là 0, còn lại là lớn nhất + 1', () {
    expect(nextSortOrder(const <PersonPhoto>[]), 0);
    expect(nextSortOrder([_photo('a', sortOrder: 3), _photo('b', sortOrder: 1)]), 4);
  });
}