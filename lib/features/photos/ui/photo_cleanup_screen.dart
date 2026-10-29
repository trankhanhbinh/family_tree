import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/errors/app_error_messages.dart';
import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/photos/data/photo_cleanup_repository.dart';
import 'package:familytree/features/photos/domain/orphan_files.dart';

/// Quét và xóa file ảnh thừa trong Storage (chỉ admin).
/// Route: /admin/photo-cleanup.
class PhotoCleanupScreen extends ConsumerStatefulWidget {
  const PhotoCleanupScreen({super.key});

  @override
  ConsumerState<PhotoCleanupScreen> createState() => _PhotoCleanupScreenState();
}

class _PhotoCleanupScreenState extends ConsumerState<PhotoCleanupScreen> {
  bool _cleaning = false;

  Future<void> _clean(OrphanScan scan) async {
    if (_cleaning) {
      return;
    }
    // Lấy sẵn mọi thứ cần từ ref/context TRƯỚC các await.
    final repository = ref.read(photoCleanupRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);

    // Nút chính = "Xem lại" vì không chọn gì cũng được tính là nút chính:
    // lỡ tay thì KHÔNG xóa.
    final review = await showChoiceDialog(
      context,
      title: 'Xóa ${scan.totalCount} file thừa?',
      message: 'Các file này không còn dùng cho ảnh hay đề xuất nào. '
          'Xóa xong không khôi phục được.',
      primaryLabel: 'Xem lại',
      secondaryLabel: 'Xóa ${scan.totalCount} file',
    );
    if (review || !mounted) {
      return;
    }

    setState(() => _cleaning = true);
    try {
      final result = await repository.remove(scan);
      container.invalidate(photoOrphanScanProvider);
      if (!mounted) {
        return;
      }
      await showMessageDialog(
        context,
        title: 'Đã dọn xong',
        message: describeCleanupResult(result),
        icon: Icons.check_circle_outline,
      );
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _cleaning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dọn file ảnh thừa'),
        actions: [
          if (isAdmin)
            TextButton.icon(
              onPressed: _cleaning
                  ? null
                  : () => ref.invalidate(photoOrphanScanProvider),
              icon: const Icon(Icons.refresh, size: 26),
              label: const Text(
                'Quét lại',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
        ],
      ),
      body: isAdmin
          ? _body()
          : const _Message('Chỉ quản trị viên xem được mục này.'),
    );
  }

  Widget _body() {
    final async = ref.watch(photoOrphanScanProvider);
    final scan = async.value;

    if (scan == null) {
      final error = async.error;
      if (error != null) {
        return _ErrorView(
          message: vietnameseErrorMessage(error),
          onRetry: () => ref.invalidate(photoOrphanScanProvider),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Đang kiểm tra file ảnh...',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GroupCard(
          title: 'Ảnh công khai',
          text: describeOrphanGroup(scan.publicFiles),
        ),
        const SizedBox(height: 12),
        _GroupCard(
          title: 'Ảnh chờ duyệt',
          text: describeOrphanGroup(scan.pendingFiles),
        ),
        const SizedBox(height: 16),
        const Text(
          'File thừa là file ảnh không còn dòng ảnh hoặc đề xuất nào dùng tới. '
          'File mới tạo chưa được tính: dưới 1 giờ với ảnh công khai, '
          'dưới 24 giờ với ảnh chờ duyệt.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (scan.isEmpty)
          const Text(
            'Không có file thừa. Mọi file ảnh đều đang được dùng.',
            style: TextStyle(fontSize: 18, height: 1.4),
          )
        else
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _cleaning ? null : () => _clean(scan),
              child: _cleaning
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        SizedBox(width: 12),
                        Text('Đang xóa...', style: TextStyle(fontSize: 18)),
                      ],
                    )
                  : const Text(
                      'Xóa file thừa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(text, style: const TextStyle(fontSize: 18, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

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