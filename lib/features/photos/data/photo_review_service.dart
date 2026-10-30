import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/core/errors/app_error_messages.dart';
import 'package:familytree/features/photos/data/pending_photo_service.dart';
import 'package:familytree/features/photos/data/photo_service.dart';
import 'package:familytree/features/photos/domain/photo_rules.dart';
import 'package:familytree/features/review/domain/change_request.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

/// Phần xử lý FILE khi admin duyệt/từ chối đề xuất ảnh.
/// Thứ tự duyệt: chép file sang bucket công khai -> approve_change_bundle
/// -> xóa file chờ. Lỗi giữa chừng thì xóa bản sao (trừ khi dòng ảnh đã tồn tại).
class PhotoReviewService {
  PhotoReviewService(this._client, this._pending, this._photos);

  final SupabaseClient _client;
  final PendingPhotoService _pending;
  final PhotoService _photos;

  /// Chép mọi ảnh của gói sang bucket công khai. Trả về các bản sao đã tạo
  /// (để hoàn tác nếu bước duyệt thất bại). Lỗi thì tự dọn các bản sao dở dang.
  Future<List<PhotoMove>> copyForApproval(ReviewBundle bundle) async {
    final photoRequests = bundle.requests
        .where((r) => r.entityType == 'person_photo' && r.action == 'create')
        .toList();
    if (photoRequests.isEmpty) {
      return const <PhotoMove>[];
    }

    final moves = photoMovesOf(bundle.requests);
    if (moves.length != photoRequests.length) {
      throw const UserFacingException(kInvalidPhotoRequestMessage);
    }

    final copied = <PhotoMove>[];
    try {
      for (final move in moves) {
        final bytes = await _downloadPending(move.pendingPath);
        final extension = detectPhotoExtension(bytes);
        if (extension == null || bytes.length > kMaxPhotoBytes) {
          throw const UserFacingException(kPhotoInvalidFileMessage);
        }
        await _photos.upload(
          storagePath: move.publicPath,
          bytes: bytes,
          contentType: photoContentType(extension),
        );
        copied.add(move);
      }
    } catch (_) {
      await rollbackCopies(copied);
      rethrow;
    }
    return copied;
  }

  Future<Uint8List> _downloadPending(String path) async {
    try {
      return await _pending.download(path);
    } on StorageException catch (error) {
      final status = error.statusCode ?? '';
      final message = error.message.toLowerCase();
      if (status == '404' || status == '400' || message.contains('not found')) {
        throw const UserFacingException(kPhotoPendingMissingMessage);
      }
      rethrow;
    }
  }

  /// Xóa các bản sao ở bucket công khai. AN TOÀN: nếu dòng ảnh đã tồn tại
  /// (ví dụ người khác vừa duyệt xong) hoặc không kiểm tra được thì GIỮ file.
  Future<void> rollbackCopies(List<PhotoMove> copies) async {
    for (final move in copies) {
      try {
        final rows = await _client
            .from('person_photos')
            .select('id')
            .eq('id', move.photoId);
        if (rows.isNotEmpty) {
          continue;
        }
        await _photos.removeQuietly(move.publicPath);
      } catch (error) {
        debugPrint('Không dọn được bản sao ảnh ${move.publicPath}: $error');
      }
    }
  }

  /// Xóa file chờ của mọi ảnh trong gói (sau khi duyệt hoặc từ chối).
  Future<void> deletePendingFiles(ReviewBundle bundle) async {
    for (final move in photoMovesOf(bundle.requests)) {
      await _pending.removeQuietly(move.pendingPath);
    }
  }
}

final photoReviewServiceProvider = Provider<PhotoReviewService>((ref) {
  return PhotoReviewService(
    ref.watch(supabaseClientProvider),
    ref.watch(pendingPhotoServiceProvider),
    ref.watch(photoServiceProvider),
  );
});