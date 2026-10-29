import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/history/data/history_repository.dart';
import 'package:familytree/features/history/ui/history_list.dart';
import 'package:familytree/features/proposals/ui/proposal_placeholder_screen.dart';
import 'package:familytree/features/review/data/review_repository.dart';
import 'package:familytree/features/review/domain/change_request.dart';
import 'package:familytree/features/review/domain/request_describer.dart';
import 'package:familytree/features/review/ui/bundle_detail_screen.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

enum _ReviewTab { pending, processed, history }

/// Màn hình admin: gói đề xuất chờ duyệt / đã xử lý / lịch sử thay đổi.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  _ReviewTab _tab = _ReviewTab.pending;

  void _refresh() {
    ref.invalidate(pendingBundlesProvider);
    ref.invalidate(processedBundlesProvider);
    ref.invalidate(historyFeedProvider(null));
    ref.invalidate(treeDataProvider);
  }

  void _open(ReviewBundle bundle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BundleDetailScreen(bundle: bundle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const ProposalPlaceholderScreen(
        title: 'Duyệt đề xuất',
        message: 'Bạn không có quyền xem màn hình này.',
      );
    }

    final treeAsync = ref.watch(treeDataProvider);
    final AsyncValue<List<ReviewBundle>>? listAsync = switch (_tab) {
      _ReviewTab.pending => ref.watch(pendingBundlesProvider),
      _ReviewTab.processed => ref.watch(processedBundlesProvider),
      _ReviewTab.history => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt đề xuất'),
        actions: [
          TextButton.icon(
            onPressed: _refresh,
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: BigSegmented<_ReviewTab>(
              options: const [
                (_ReviewTab.pending, 'Chờ duyệt'),
                (_ReviewTab.processed, 'Đã xử lý'),
                (_ReviewTab.history, 'Lịch sử'),
              ],
              selected: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
          ),
          Expanded(
            child: listAsync == null
                ? const HistoryList()
                : _content(listAsync, treeAsync),
          ),
        ],
      ),
    );
  }

  Widget _content(
    AsyncValue<List<ReviewBundle>> listAsync,
    AsyncValue<TreeData> treeAsync,
  ) {
    final bundles = listAsync.value;
    final tree = treeAsync.value;

    if (listAsync.hasError || (treeAsync.hasError && tree == null)) {
      return _ErrorView(onRetry: _refresh);
    }
    if (bundles == null || tree == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bundles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _tab == _ReviewTab.pending
                ? 'Không có đề xuất nào đang chờ duyệt.'
                : 'Chưa có đề xuất nào được xử lý.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, height: 1.4),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bundles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final bundle = bundles[index];
        return BundleCard(
          bundle: bundle,
          described: describeBundle(bundle, tree),
          onTap: () => _open(bundle),
        );
      },
    );
  }
}

class BundleCard extends StatelessWidget {
  const BundleCard({
    super.key,
    required this.bundle,
    required this.described,
    required this.onTap,
  });

  final ReviewBundle bundle;
  final List<DescribedRequest> described;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = described.take(3).toList();
    final more = described.length - shown.length;
    final needsCheck =
        described.any((d) => d.warning != null || !d.supported);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bundle.nickname,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    formatDateTime(bundle.createdAt),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final item in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${item.title}',
                    style: const TextStyle(fontSize: 16, height: 1.3),
                  ),
                ),
              if (more > 0)
                Text(
                  '… và $more thay đổi khác',
                  style: const TextStyle(fontSize: 16),
                ),
              if (needsCheck)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Có mục cần kiểm tra',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB26A00),
                    ),
                  ),
                ),
              if (!bundle.isPending)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    bundle.statusLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: bundle.status == 'approved'
                          ? const Color(0xFF2E7D32)
                          : scheme.error,
                    ),
                  ),
                ),
              if (bundle.status == 'rejected' && bundle.rejectReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Lý do: ${bundle.rejectReason}',
                    style: const TextStyle(fontSize: 16, height: 1.3),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Xem chi tiết',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
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
              'Không tải được danh sách đề xuất.\nVui lòng thử lại.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, height: 1.4),
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