import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';
import 'package:familytree/features/tree/data/collapsed_ids_provider.dart';
import 'package:familytree/features/tree/data/family_forest_provider.dart';
import 'package:familytree/features/tree/data/focus_request_provider.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/ui/tree_view.dart';
import 'package:familytree/features/auth/ui/admin_entry_bar.dart';

class TreeScreen extends ConsumerWidget {
  const TreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forestAsync = ref.watch(familyForestProvider);
    final clanName = ref.watch(clanNameProvider).value ?? 'Gia phả';
    final collapsedIds = ref.watch(collapsedIdsProvider);
    final focusRequest = ref.watch(focusRequestProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(clanName),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search, size: 26),
            label: const Text(
              'Tìm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          TextButton(
            onPressed: () => context.push('/backup'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            child: const Text(
              'Sao lưu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Không đụng collapsedIdsProvider: trạng thái thu gọn được giữ nguyên.
              ref.invalidate(clanNameProvider);
              ref.invalidate(treeDataProvider);
            },
          ),
        ],
      ),
      bottomNavigationBar: const AdminEntryBar(),
      body: forestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _TreeErrorView(
          onRetry: () => ref.invalidate(treeDataProvider),
        ),
        data: (forest) {
          if (forest.roots.isEmpty) {
            return const Center(child: Text('Chưa có dữ liệu gia phả.'));
          }
          final notifier = ref.read(collapsedIdsProvider.notifier);
          return TreeView(
            forest: forest,
            collapsedIds: collapsedIds,
            focusRequest: focusRequest,
            onPersonTap: (personId) => context.push('/person/$personId'),
            onToggleCollapse: notifier.toggle,
            onCollapseAll: notifier.collapseAll,
            onExpandAll: notifier.expandAll,
            onFocusHandled: ref.read(focusRequestProvider.notifier).clear,
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