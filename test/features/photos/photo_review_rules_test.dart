import 'package:flutter_test/flutter_test.dart';
import 'package:familytree/features/photos/domain/photo_rules.dart';
import 'package:familytree/features/review/domain/change_request.dart';

const String _t0 = '2026-10-28T03:00:00.123456+00:00';

ChangeRequest _req({
  String entityType = 'person_photo',
  String action = 'create',
  Map<String, dynamic> payload = const {},
}) {
  return ChangeRequest(
    id: 'r1',
    requesterId: 'u1',
    nickname: 'Bác Hai',
    entityType: entityType,
    action: action,
    payload: payload,
    status: 'pending',
    createdAtRaw: _t0,
    createdAt: DateTime.parse(_t0),
  );
}

void main() {
  test('validatePendingLimit: dưới 10 hợp lệ, từ 10 trở lên báo lỗi', () {
    expect(validatePendingLimit(0), isNull);
    expect(validatePendingLimit(kMaxPendingPhotos - 1), isNull);
    expect(validatePendingLimit(kMaxPendingPhotos), kPendingPhotoLimitMessage);
    expect(validatePendingLimit(kMaxPendingPhotos + 3), kPendingPhotoLimitMessage);
  });

  test('buildPendingPhotoPath: {uid}/{id}.{đuôi}', () {
    expect(
      buildPendingPhotoPath(requesterId: 'u1', photoId: 'f1', extension: 'jpg'),
      'u1/f1.jpg',
    );
  });

  test('extensionOfStoragePath: nhận jpg, png, webp; còn lại null', () {
    expect(extensionOfStoragePath('p1/f1.jpg'), 'jpg');
    expect(extensionOfStoragePath('p1/f1.PNG'), 'png');
    expect(extensionOfStoragePath('p1/f1.webp'), 'webp');
    expect(extensionOfStoragePath('p1/f1.gif'), isNull);
    expect(extensionOfStoragePath('p1/f1'), isNull);
    expect(extensionOfStoragePath('p1/f1.'), isNull);
  });

  test('photoMoveOf: dựng đường dẫn file chờ và file công khai', () {
    final move = photoMoveOf(
      requesterId: 'u1',
      payload: {'id': 'f1', 'storage_path': 'p1/f1.png'},
    );
    expect(move, isNotNull);
    expect(move!.photoId, 'f1');
    expect(move.pendingPath, 'u1/f1.png');
    expect(move.publicPath, 'p1/f1.png');
  });

  test('photoMoveOf: thiếu id hoặc storage_path -> null', () {
    expect(photoMoveOf(requesterId: 'u1', payload: {'id': 'f1'}), isNull);
    expect(
      photoMoveOf(requesterId: 'u1', payload: {'storage_path': 'p1/f1.jpg'}),
      isNull,
    );
  });

  test('photoMovesOf: chỉ lấy dòng ảnh tạo mới', () {
    final moves = photoMovesOf([
      _req(payload: {'id': 'f1', 'storage_path': 'p1/f1.jpg'}),
      _req(entityType: 'person', payload: {'id': 'x', 'storage_path': 'a/x.jpg'}),
      _req(action: 'update', payload: {'id': 'f2', 'storage_path': 'p1/f2.jpg'}),
    ]);
    expect(moves.length, 1);
    expect(moves.single.photoId, 'f1');
  });
}