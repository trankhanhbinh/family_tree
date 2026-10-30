import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/features/memorial/domain/upcoming_memorials.dart';
import 'package:familytree/features/person/domain/memorial_labels.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

/// Danh sách giỗ sắp tới. Route: /memorials (ai cũng xem được).
class MemorialsScreen extends ConsumerWidget {
  const MemorialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(treeDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ngày giỗ sắp tới')),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorView(
          onRetry: () => ref.invalidate(treeDataProvider),
        ),
        data: (data) {
          final result = buildUpcomingMemorials(
            people: data.people,
            today: DateTime.now(),
          );
          return _MemorialList(result: result);
        },
      ),
    );
  }
}

class _MemorialList extends StatelessWidget {
  const _MemorialList({required this.result});

  final UpcomingMemorials result;

  @override
  Widget build(BuildContext context) {
    final items = result.items;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Những người đã mất có giỗ trong $kMemorialLookaheadDays ngày tới '
          '(tính từ hôm nay).',
          style: TextStyle(fontSize: 16, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Không có ngày giỗ nào trong $kMemorialLookaheadDays ngày tới.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, height: 1.4),
            ),
          ),
        for (final item in items)
          _MemorialCard(
            item: item,
            onTap: () => context.push('/person/${item.person.id}'),
          ),
        if (result.missingCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Còn ${result.missingCount} người đã mất chưa có ngày giỗ.',
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
          ),
      ],
    );
  }
}

class _MemorialCard extends StatelessWidget {
  const _MemorialCard({required this.item, required this.onTap});

  final UpcomingMemorial item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = item.daysLeft <= 1;
    return Card(
      color: highlight ? scheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.person.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Giỗ: ${formatMemorialLunar(day: item.lunarDay, month: item.lunarMonth, isLeap: item.isLeap)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatNextMemorial(item.date, item.daysLeft),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            highlight ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Không tải được dữ liệu. Vui lòng thử lại.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            SizedBox(
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