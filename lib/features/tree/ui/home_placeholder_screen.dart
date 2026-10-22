import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

/// Màn hình tạm để kiểm tra khối B. Khối F sẽ thay bằng màn hình cây.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clanName = ref.watch(clanNameProvider).value ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Gia phả')),
      body: Center(
        child: Text(
          clanName,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}