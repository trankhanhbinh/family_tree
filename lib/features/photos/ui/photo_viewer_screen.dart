import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/photos/data/photo_service.dart';
import 'package:familytree/features/photos/domain/photo_plans.dart';
import 'package:familytree/features/photos/domain/photo_rules.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

/// Xem ảnh toàn màn hình: vuốt để đổi ảnh, hai ngón để phóng to.
/// Admin có thêm "Đặt làm ảnh đại diện" và "Xóa ảnh".
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.personId,
    required this.initialPhotoId,
  });

  final String personId;
  final String initialPhotoId;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late final PageController _pageController;
  int _index = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final photos = photosOfPerson(
      ref.read(treeDataProvider).value?.photos ?? const <PersonPhoto>[],
      widget.personId,
    );
    final start = photos.indexWhere((p) => p.id == widget.initialPhotoId);
    _index = start < 0 ? 0 : start;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _setAvatar(
    PersonPhoto photo,
    List<PersonPhoto> photos,
    String personName,
  ) async {
    if (_busy) {
      return;
    }
    final drafts = planSetAvatar(photo: photo, currentAvatar: avatarOf(photos));
    if (drafts.isEmpty) {
      await showMessageDialog(
        context,
        title: 'Đã là ảnh đại diện',
        message: 'Ảnh này đang là ảnh đại diện của $personName.',
        icon: Icons.info_outline,
      );
      return;
    }

    final proceed = await confirmSubmit(
      context,
      isAdmin: true,
      summary: 'Đặt ảnh này làm ảnh đại diện của $personName?',
      slots: drafts.length,
    );
    if (!proceed || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      final outcome = await submitChanges(context, ref, drafts: drafts);
      if (outcome == SubmitOutcome.cancelled || !mounted) {
        return;
      }
      await showMessageDialog(
        context,
        title: 'Đã đặt ảnh đại diện',
        message: 'Ảnh đại diện đã được cập nhật.',
        icon: Icons.check_circle_outline,
      );
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete(PersonPhoto photo, String personName) async {
    if (_busy) {
      return;
    }
    final drafts = planDeletePhoto(photo);
    final photoService = ref.read(photoServiceProvider);
    final proceed = await confirmSubmit(
      context,
      isAdmin: true,
      summary: 'Xóa ảnh này khỏi hồ sơ của $personName?',
      slots: drafts.length,
    );
    if (!proceed || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      final outcome = await submitChanges(context, ref, drafts: drafts);
      // Dòng ảnh đã xóa thành công thì mới xóa file thật. Lỗi xóa file được
      // bỏ qua lặng lẽ (file thừa sẽ được dọn bằng công cụ "Dọn file ảnh thừa").
      if (outcome == SubmitOutcome.saved) {
        await photoService.removeQuietly(photo.storagePath);
      }
      if (outcome == SubmitOutcome.cancelled || !mounted) {
        return;
      }
      await showMessageDialog(
        context,
        title: 'Đã xóa ảnh',
        message: 'Ảnh đã được xóa khỏi hồ sơ.',
        icon: Icons.check_circle_outline,
      );
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final tree = ref.watch(treeDataProvider).value;
    final photos = photosOfPerson(
      tree?.photos ?? const <PersonPhoto>[],
      widget.personId,
    );
    final isAdmin = ref.watch(isAdminProvider);
    final service = ref.watch(photoServiceProvider);
    final personName = tree?.people
            .where((p) => p.id == widget.personId)
            .firstOrNull
            ?.fullName ??
        'người này';

    if (photos.isEmpty) {
      // Đã xóa hết ảnh: đóng màn hình xem.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    final index = _index >= photos.length ? photos.length - 1 : _index;
    final photo = photos[index];
    final caption = photo.caption?.trim() ?? '';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Ảnh ${index + 1}/${photos.length}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: photos.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, i) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: service.publicUrl(photos[i].storagePath),
                      fit: BoxFit.contain,
                      placeholder: (_, _) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (_, _, _) => const Center(
                        child: Text(
                          'Không tải được ảnh.',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Material(
            color: scheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          caption,
                          style: const TextStyle(fontSize: 17, height: 1.4),
                        ),
                      ),
                    if (isAdmin) ...[
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: (_busy || photo.isAvatar)
                              ? null
                              : () => _setAvatar(photo, photos, personName),
                          icon: const Icon(Icons.account_circle_outlined, size: 26),
                          label: Text(
                            photo.isAvatar
                                ? 'Đang là ảnh đại diện'
                                : 'Đặt làm ảnh đại diện',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            side: BorderSide(color: scheme.error),
                          ),
                          onPressed:
                              _busy ? null : () => _delete(photo, personName),
                          icon: const Icon(Icons.delete_outline, size: 26),
                          label: const Text(
                            'Xóa ảnh',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Đóng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}