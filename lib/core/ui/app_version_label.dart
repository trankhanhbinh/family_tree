import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/config/app_version_provider.dart';

/// Dòng chữ nhỏ hiển thị số phiên bản. Chưa đọc xong hoặc lỗi thì không hiện gì.
class AppVersionLabel extends ConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionTextProvider);
    return switch (versionAsync) {
      AsyncData(:final value) => Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}