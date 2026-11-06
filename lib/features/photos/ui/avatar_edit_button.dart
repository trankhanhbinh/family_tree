import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/auth/ui/contributor_gate.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/photos/data/photo_service.dart';
import 'package:familytree/features/photos/domain/photo_plans.dart';
import 'package:familytree/features/photos/domain/photo_rules.dart';
import 'package:familytree/features/proposals/ui/submit_changes.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

enum _AvatarChoice { newPhoto, existing }

/// Nút tròn nhỏ hình bút chì ở góc avatar (màn chi tiết người).
/// Admin: đổi ngay. Người thường: gửi đề xuất, chờ duyệt.
/// Vùng chạm 44dp, phần nhìn thấy là vòng tròn 30dp.
class AvatarEditButton extends ConsumerWidget {
  const AvatarEditButton({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Đổi ảnh đại diện',
      child: InkResponse(
        onTap: () => _openMenu(context, ref),
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: Icon(Icons.edit, size: 16, color: scheme.onPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context, WidgetRef ref) async {
    final isAdmin = ref.read(isAdminProvider);
    final photos = photosOfPerson(
      ref.read(treeDataProvider).value?.photos ?? const <PersonPhoto>[],
      personId,
    );
    final hasOthers = photos.any((p) => !p.isAvatar);

    final choice = await showModalBottomSheet<_AvatarChoice>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  isAdmin ? 'Đổi ảnh đại diện' : 'Đề xuất đổi ảnh đại diện',
                  style: Theme.of(sheetContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add_a_photo_outlined, size: 28),
                title: const Text(
                  'Chọn ảnh mới',
                  style: TextStyle(fontSize: 18),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AvatarChoice.newPhoto),
              ),
              if (hasOthers)
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, size: 28),
                  title: const Text(
                    'Chọn từ ảnh đã có',
                    style: TextStyle(fontSize: 18),
                  ),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_AvatarChoice.existing),
                ),
            ],
          ),
        );
      },
    );
    if (choice == null || !context.mounted) {
      return;
    }

    switch (choice) {
      case _AvatarChoice.newPhoto:
        context.push('/person/$personId/add-photo?avatar=1');
      case _AvatarChoice.existing:
        await _chooseExisting(context, ref, isAdmin);
    }
  }

  Future<void> _chooseExisting(
    BuildContext context,
    WidgetRef ref,
    bool isAdmin,
  ) async {
    final photos = photosOfPerson(
      ref.read(treeDataProvider).value?.photos ?? const <PersonPhoto>[],
      personId,
    );
    final candidates = photos.where((p) => !p.isAvatar).toList();
    final service = ref.read(photoServiceProvider);

    final picked = await showModalBottomSheet<PersonPhoto>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn ảnh làm đại diện',
                  style: Theme.of(sheetContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    shrinkWrap: true,
                    children: [
                      for (final photo in candidates)
                        InkWell(
                          onTap: () => Navigator.of(sheetContext).pop(photo),
                          borderRadius: BorderRadius.circular(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: service.publicUrl(photo.storagePath),
                              fit: BoxFit.cover,
                              memCacheWidth: 300,
                              placeholder: (_, _) => const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (_, _, _) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked == null || !context.mounted) {
      return;
    }
    await _setExisting(context, ref, isAdmin, picked);
  }

  Future<void> _setExisting(
    BuildContext context,
    WidgetRef ref,
    bool isAdmin,
    PersonPhoto photo,
  ) async {
    final tree = ref.read(treeDataProvider).value;
    final photos = photosOfPerson(
      tree?.photos ?? const <PersonPhoto>[],
      personId,
    );
    final personName =
        tree?.people.where((p) => p.id == personId).firstOrNull?.fullName ??
        'người này';
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
      isAdmin: isAdmin,
      summary: isAdmin
          ? 'Đặt ảnh này làm ảnh đại diện của $personName?'
          : 'Gửi đề xuất đổi ảnh đại diện của $personName?',
      slots: drafts.length,
    );
    if (!proceed || !context.mounted) {
      return;
    }

    try {
      if (!isAdmin) {
        final contributor = await ensureContributor(context, ref);
        if (contributor == null || !context.mounted) {
          return;
        }
      }
      final outcome = await submitChanges(context, ref, drafts: drafts);
      if (outcome == SubmitOutcome.cancelled || !context.mounted) {
        return;
      }
      await showMessageDialog(
        context,
        title: isAdmin ? 'Đã đặt ảnh đại diện' : 'Đã gửi đề xuất',
        message: isAdmin
            ? 'Ảnh đại diện đã được cập nhật.'
            : 'Quản trị viên sẽ xem và duyệt.',
        icon: Icons.check_circle_outline,
      );
    } catch (error) {
      if (context.mounted) {
        await showErrorDialog(context, error);
      }
    }
  }
}
