import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';
import 'package:familytree/features/tree/data/family_forest_provider.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/ui/tree_view.dart';

class TreeScreen extends ConsumerWidget {
  const TreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forestAsync = ref.watch(familyForestProvider);
    final clanName = ref.watch(clanNameProvider).value ?? 'Gia phả';

    return Scaffold(
      appBar: AppBar(
        title: Text(clanName),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(clanNameProvider);
              ref.invalidate(treeDataProvider);
            },
          ),
        ],
      ),
      body: forestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _TreeErrorView(
          onRetry: () => ref.invalidate(treeDataProvider),
        ),
        data: (forest) {
          if (forest.roots.isEmpty) {
            return const Center(child: Text('Chưa có dữ liệu gia phả.'));
          }
          return TreeView(
            forest: forest,
            onPersonTap: (personId) => context.push('/person/$personId'),
          );
        },
      ),
    );
  }
}

class _TreeErrorView extends StatelessWidget {
  const _TreeErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Không tải được gia phả. Vui lòng thử lại.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}