import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/default_portrait.dart';
import 'package:familytree/core/ui/portrait_frame.dart';
import 'package:familytree/features/person/domain/person_photo.dart';
import 'package:familytree/features/photos/data/photo_service.dart';
import 'package:familytree/features/photos/domain/photo_rules.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

class PhotoAvatar extends ConsumerWidget {
  const PhotoAvatar({
    super.key,
    required this.personId,
    required this.width,
    required this.accent,
  });

  final String personId;

  /// Chiều cao tự tính theo tỉ lệ 3:4.
  final double width;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(
      treeDataProvider.select((async) => async.value?.photos),
    );
    final avatar = avatarOf(
      photosOfPerson(photos ?? const <PersonPhoto>[], personId),
    );

    if (avatar == null) {
      return DefaultPortrait(width: width, accent: accent);
    }

    final url = ref.watch(photoServiceProvider).publicUrl(avatar.storagePath);
    return PortraitFrame(
      width: width,
      accent: accent,
      image: CachedNetworkImageProvider(url, maxWidth: 400),
    );
  }
}
