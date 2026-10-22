import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

/// Màn hình tạm để kiểm tra khối C. Khối F sẽ thay bằng màn hình cây.
class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clanName = ref.watch(clanNameProvider).value ?? '';
    final treeAsync = ref.watch(treeDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gia phả')),
      body: treeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được dữ liệu cây.'),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center), // tạm, để dễ debug
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(treeDataProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final people = [...data.people]..sort(
              (a, b) => (a.generation ?? 0).compareTo(b.generation ?? 0),
            );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                clanName,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Số người: ${data.people.length}'),
                      Text('Số chi/nhánh: ${data.branches.length}'),
                      Text('Số quan hệ cha-con: ${data.parentChildren.length}'),
                      Text('Số hôn nhân: ${data.marriages.length}'),
                      Text('Số ảnh: ${data.photos.length}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final p in people)
                ListTile(
                  dense: true,
                  title: Text(p.fullName),
                  subtitle: Text(
                    'Đời ${p.generation ?? '?'} • sinh ${p.birthYear ?? '?'}'
                    '${p.isAlive ? '' : ' • đã mất'}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}