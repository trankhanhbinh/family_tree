import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/photos/data/photo_service.dart';
import 'package:familytree/features/photos/domain/photo_rules.dart';
import 'package:familytree/features/photos/ui/photo_viewer_screen.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

/// Card "Ảnh" ở màn chi tiết người: lưới ảnh thu nhỏ, chạm để xem toàn màn hình.
/// Admin có thêm nút "Thêm ảnh".
class PersonPhotosSection extends ConsumerWidget {
  const PersonPhotosSection({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all =
        ref.watch(treeDataProvider.select((async) => async.value?.photos));
    final photos = photosOfPerson(all ?? const <PersonPhoto>[], personId);
    final isAdmin = ref.watch(isAdminProvider);
    final service = ref.watch(photoServiceProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ảnh',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (photos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Chưa có ảnh nào.', style: TextStyle(fontSize: 16)),
              )
            else
              GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final photo in photos)
                    _Thumb(
                      url: service.publicUrl(photo.storagePath),
                      isAvatar: photo.isAvatar,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PhotoViewerScreen(
                              personId: personId,
                              initialPhotoId: photo.id,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            if (isAdmin) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/person/$personId/add-photo'),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 28),
                  label: const Text(
                    'Thêm ảnh',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.url,
    required this.isAvatar,
    required this.onTap,
  });

  final String url;
  final bool isAvatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 300,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 32),
              ),
            ),
            if (isAvatar)
              Positioned(
                left: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Đại diện',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}