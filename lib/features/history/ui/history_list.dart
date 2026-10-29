import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/errors/app_error_messages.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/history/data/history_repository.dart';
import 'package:familytree/features/history/domain/history_describer.dart';
import 'package:familytree/features/history/domain/history_entry.dart';
import 'package:familytree/features/history/domain/history_feed_state.dart';
import 'package:familytree/features/history/domain/history_labels.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/branch.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

const TreeData _emptyTree = TreeData(
  people: [],
  branches: [],
  parentChildren: [],
  marriages: [],
  photos: [],
);

/// Danh sách lịch sử thay đổi (chỉ admin). [personId] = null: toàn dòng họ.
class HistoryList extends ConsumerWidget {
  const HistoryList({super.key, this.personId});

  final String? personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const _CenteredText('Chỉ quản trị viên xem được lịch sử.');
    }

    final feedProvider = historyFeedProvider(personId);
    final feedAsync = ref.watch(feedProvider);
    final tree = ref.watch(treeDataProvider).value ?? _emptyTree;
    final feed = feedAsync.value;

    if (feed == null) {
      final error = feedAsync.error;
      if (error != null) {
        return _ErrorView(
          message: vietnameseErrorMessage(error),
          onRetry: () => ref.invalidate(feedProvider),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final groups = feed.groups;
    if (groups.isEmpty) {
      return const _CenteredText('Chưa có thay đổi nào được ghi lại.');
    }

    final nameOf = buildHistoryNameLookup(tree: tree, entries: feed.entries);
    final showFooter =
        feed.hasMore || feed.loadingMore || feed.loadError != null;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= groups.length) {
          return _Footer(
            feed: feed,
            onLoadMore: () => ref.read(feedProvider.notifier).loadMore(),
          );
        }
        return _HistoryGroupCard(
          group: groups[index],
          nameOf: nameOf,
          branches: tree.branches,
        );
      },
    );
  }
}

class _HistoryGroupCard extends StatelessWidget {
  const _HistoryGroupCard({
    required this.group,
    required this.nameOf,
    required this.branches,
  });

  final HistoryGroup group;
  final HistoryNameLookup nameOf;
  final List<Branch> branches;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatHistoryTime(group.createdAt),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              historyActorLabel(group),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in group.entries)
              _EntryBlock(
                described: describeHistoryEntry(
                  entry,
                  nameOf: nameOf,
                  branches: branches,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryBlock extends StatelessWidget {
  const _EntryBlock({required this.described});

  final DescribedHistoryEntry described;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ${described.title}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          for (final line in described.details)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 2),
              child: Text(
                line,
                style: const TextStyle(fontSize: 14, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.feed, required this.onLoadMore});

  final HistoryFeedState feed;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (feed.loadingMore) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = feed.loadError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              vietnameseErrorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.3),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.tonal(
            onPressed: onLoadMore,
            child: Text(
              error == null ? 'Xem thêm' : 'Thử lại',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenteredText extends StatelessWidget {
  const _CenteredText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, height: 1.4),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('Thử lại', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}