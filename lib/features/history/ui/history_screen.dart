import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/features/history/data/history_repository.dart';
import 'package:familytree/features/history/ui/history_list.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

/// Lịch sử thay đổi của MỘT người (chỉ admin). Route: /person/:id/history.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(treeDataProvider).value;
    final name =
        tree?.people.where((p) => p.id == personId).firstOrNull?.fullName;

    return Scaffold(
      appBar: AppBar(
        title: Text(name == null ? 'Lịch sử thay đổi' : 'Lịch sử: $name'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.invalidate(historyFeedProvider(personId)),
            icon: const Icon(Icons.refresh, size: 26),
            label: const Text(
              'Làm mới',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      body: HistoryList(personId: personId),
    );
  }
}