import 'dart:typed_data';

import 'package:familytree/core/errors/app_error_messages.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/review/domain/change_request.dart';

/// Giới hạn của bucket (3 MB/tệp, JPEG/PNG/WebP).
const int kMaxPhotoBytes = 3 * 1024 * 1024;
const int kPhotoCaptionMaxLength = 200;

/// Thu nhỏ ngay khi chọn ảnh để vừa giới hạn 3 MB.
const double kMaxPhotoSide = 1600;
const int kPhotoQuality = 85;

const String kPhotoEmptyMessage = 'Không đọc được ảnh. Hãy chọn ảnh khác.';

/// Nhận diện loại ảnh từ NỘI DUNG (không tin tên tệp):
/// 'jpg' | 'png' | 'webp', hoặc null nếu không phải loại được phép.
String? detectPhotoExtension(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'jpg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'png';
  }
  // WebP: "RIFF" .... "WEBP"
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'webp';
  }
  return null;
}

String photoContentType(String extension) {
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}

/// Trả về câu báo lỗi tiếng Việt, hoặc null nếu ảnh hợp lệ.
String? validatePhoto({required int sizeBytes, required String? extension}) {
  if (sizeBytes <= 0) {
    return kPhotoEmptyMessage;
  }
  if (extension == null) {
    return kPhotoTypeMessage;
  }
  if (sizeBytes > kMaxPhotoBytes) {
    return kPhotoTooLargeMessage;
  }
  return null;
}

String? validateCaption(String raw) {
  if (raw.trim().length > kPhotoCaptionMaxLength) {
    return 'Mô tả quá dài (tối đa $kPhotoCaptionMaxLength ký tự).';
  }
  return null;
}

/// Đường dẫn trong bucket person-photos: {person_id}/{photo_id}.{đuôi}
String buildPhotoStoragePath({
  required String personId,
  required String photoId,
  required String extension,
}) {
  return '$personId/$photoId.$extension';
}

/// Ảnh của một người, xếp theo sort_order rồi theo id.
List<PersonPhoto> photosOfPerson(Iterable<PersonPhoto> all, String personId) {
  return all.where((p) => p.personId == personId).toList()
    ..sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
}

PersonPhoto? avatarOf(Iterable<PersonPhoto> photos) {
  for (final p in photos) {
    if (p.isAvatar) {
      return p;
    }
  }
  return null;
}

/// sort_order cho ảnh mới: xếp cuối.
int nextSortOrder(Iterable<PersonPhoto> photos) {
  var max = -1;
  for (final p in photos) {
    if (p.sortOrder > max) {
      max = p.sortOrder;
    }
  }
  return max + 1;
}

// ---------- 4F-2: ảnh chờ duyệt ----------

/// Mỗi người đóng góp tối đa 10 ảnh chờ (khớp policy của bucket pending-photos).
const int kMaxPendingPhotos = 10;

const String kPendingPhotoLimitMessage =
    'Bạn đang có $kMaxPendingPhotos ảnh chờ duyệt. '
    'Hãy đợi quản trị viên xử lý bớt rồi gửi tiếp.';
const String kPhotoPendingMissingMessage =
    'Không tìm thấy tệp ảnh của đề xuất này (có thể người gửi đã xóa). '
    'Hãy từ chối đề xuất này.';
const String kInvalidPhotoRequestMessage =
    'Đề xuất ảnh này có nội dung không hợp lệ. Hãy từ chối đề xuất này.';
const String kPhotoInvalidFileMessage =
    'Tệp ảnh của đề xuất không hợp lệ (sai loại hoặc quá lớn). '
    'Hãy từ chối đề xuất này.';

/// Trả về câu báo lỗi nếu đã đủ số ảnh chờ, hoặc null nếu còn được gửi.
String? validatePendingLimit(int currentCount) {
  return currentCount >= kMaxPendingPhotos ? kPendingPhotoLimitMessage : null;
}

/// Đường dẫn file chờ trong bucket pending-photos: {uid}/{photo_id}.{đuôi}
String buildPendingPhotoPath({
  required String requesterId,
  required String photoId,
  required String extension,
}) {
  return '$requesterId/$photoId.$extension';
}

/// Đuôi tệp (jpg/png/webp) của một đường dẫn, hoặc null nếu không nhận ra.
String? extensionOfStoragePath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) {
    return null;
  }
  final extension = path.substring(dot + 1).toLowerCase();
  const allowed = ['jpg', 'png', 'webp'];
  return allowed.contains(extension) ? extension : null;
}

/// Một ảnh cần chép từ bucket chờ sang bucket công khai khi duyệt.
class PhotoMove {
  const PhotoMove({
    required this.photoId,
    required this.pendingPath,
    required this.publicPath,
  });

  final String photoId;
  final String pendingPath;
  final String publicPath;
}

/// Dựng đường dẫn chép từ payload của đề xuất ảnh. null nếu payload thiếu/sai.
PhotoMove? photoMoveOf({
  required String requesterId,
  required Map<String, dynamic> payload,
}) {
  final id = payload['id'];
  final storagePath = payload['storage_path'];
  if (id is! String || storagePath is! String) {
    return null;
  }
  final extension = extensionOfStoragePath(storagePath);
  if (extension == null) {
    return null;
  }
  return PhotoMove(
    photoId: id,
    pendingPath: buildPendingPhotoPath(
      requesterId: requesterId,
      photoId: id,
      extension: extension,
    ),
    publicPath: storagePath,
  );
}

/// Các ảnh cần chép của một nhóm đề xuất (chỉ dòng person_photo + create).
List<PhotoMove> photoMovesOf(Iterable<ChangeRequest> requests) {
  final moves = <PhotoMove>[];
  for (final r in requests) {
    if (r.entityType != 'person_photo' || r.action != 'create') {
      continue;
    }
    final move = photoMoveOf(requesterId: r.requesterId, payload: r.payload);
    if (move != null) {
      moves.add(move);
    }
  }
  return moves;
}