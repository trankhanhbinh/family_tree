import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/photos/data/pending_photo_service.dart';
import 'package:familytree/features/photos/data/photo_service.dart';
import 'package:familytree/features/review/domain/request_describer.dart';

/// Ảnh xem trước của một đề xuất ảnh:
/// - đang chờ: lấy từ bucket riêng bằng đường dẫn tạm,
/// - đã duyệt: lấy từ bucket công khai,
/// - bị từ chối: file đã bị xóa nên chỉ hiện dòng chữ.
class ReviewPhotoPreview extends ConsumerStatefulWidget {
  const ReviewPhotoPreview({
    super.key,
    required this.photo,
    required this.bundleStatus,
  });

  final PhotoRef photo;
  final String bundleStatus;

  @override
  ConsumerState<ReviewPhotoPreview> createState() => _ReviewPhotoPreviewState();
}

class _ReviewPhotoPreviewState extends ConsumerState<ReviewPhotoPreview> {
  Future<String>? _signedUrl;

  @override
  void initState() {
    super.initState();
    if (widget.bundleStatus == 'pending') {
      _signedUrl = ref
          .read(pendingPhotoServiceProvider)
          .signedUrl(widget.photo.pendingPath);
    }
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: const TextStyle(fontSize: 15, height: 1.3)),
    );
  }

  Widget _image(String url, String cacheKey) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        cacheKey: cacheKey,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, _) => const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, _, _) => const SizedBox(
          height: 120,
          child: Center(child: Text('Không tải được ảnh.')),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bundleStatus == 'approved') {
      final url =
          ref.watch(photoServiceProvider).publicUrl(widget.photo.publicPath);
      return _image(url, widget.photo.publicPath);
    }
    if (widget.bundleStatus == 'rejected') {
      return _note('Ảnh đã được xóa sau khi từ chối.');
    }
    return FutureBuilder<String>(
      future: _signedUrl,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _note('Không xem được ảnh (tệp có thể đã bị xóa).');
        }
        final url = snapshot.data;
        if (url == null) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _image(url, widget.photo.pendingPath);
      },
    );
  }
}