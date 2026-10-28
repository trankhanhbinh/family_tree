import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/form_widgets.dart';
import 'package:familytree/features/review/data/review_repository.dart';
import 'package:familytree/features/review/domain/change_request.dart';
import 'package:familytree/features/review/domain/request_describer.dart';
import 'package:familytree/features/review/ui/bundle_detail_screen.dart';
import 'package:familytree/features/review/ui/review_screen.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';
import 'package:familytree/features/tree/domain/tree_data.dart';

/// Màn hình người đóng góp: các đề xuất đã gửi từ máy này và kết quả.
class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  bool _showPending = true;

  @override
  void initState() {
    super.initState();
    // Mở màn hình là lấy dữ liệu mới (admin có thể đã duyệt từ lúc trước).
    unawaited(
      Future<void>.microtask(() {
        if (mounted) {
          ref.invalidate(myBundlesProvider);
        }
      }),
    );
  }

  void _refresh() {
    ref.invalidate(myBundlesProvider);
    ref.invalidate(treeDataProvider);
  }

  void _open(ReviewBundle bundle) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BundleDetailScreen(bundle: bundle, readOnly: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(treeDataProvider);
    final listAsync = ref.watch(myBundlesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đề xuất của tôi'),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Chỉ hiện các đề xuất gửi từ máy này.',
              style: TextStyle(fontSize: 15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: BigSegmented<bool>(
              options: const [
                (true, 'Đang chờ'),
                (false, 'Đã xử lý'),
              ],
              selected: _showPending,
              onChanged: (value) => setState(() => _showPending = value),
            ),
          ),
          Expanded(child: _content(listAsync, treeAsync)),
        ],
      ),
    );
  }

  Widget _content(
    AsyncValue<List<ReviewBundle>> listAsync,
    AsyncValue<TreeData> treeAsync,
  ) {
    final all = listAsync.value;
    final tree = treeAsync.value;

    if (listAsync.hasError || (treeAsync.hasError && tree == null)) {
      return _ErrorView(onRetry: _refresh);
    }
    if (all == null || tree == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final bundles = all.where((b) => b.isPending == _showPending).toList();
    if (bundles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _showPending
                ? 'Bạn chưa có đề xuất nào đang chờ duyệt.'
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