import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/errors/app_error_messages.dart';
import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/core/ui/choice_dialog.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/history/data/deleted_people_repository.dart';
import 'package:familytree/features/history/data/history_repository.dart';
import 'package:familytree/features/history/domain/deleted_person.dart';
import 'package:familytree/features/history/domain/history_labels.dart';
import 'package:familytree/features/history/domain/restore_result.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

/// Danh sách người đã xóa và nút khôi phục (chỉ admin). Route: /admin/deleted.
class DeletedPeopleScreen extends ConsumerWidget {
  const DeletedPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Người đã xóa'),
        actions: [
          if (isAdmin)
            TextButton.icon(
              onPressed: () => ref.invalidate(deletedPeopleProvider),
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
      body: isAdmin
          ? _body(context, ref)
          : const _Message('Chỉ quản trị viên xem được mục này.'),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deletedPeopleProvider);
    final people = async.value;

    if (people == null) {
      final error = async.error;
      if (error != null) {
        return _ErrorView(
          message: vietnameseErrorMessage(error),
          onRetry: () => ref.invalidate(deletedPeopleProvider),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (people.isEmpty) {
      return const _Message('Không có người nào đã bị xóa.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: people.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final person = people[index];
        return _DeletedCard(
          person: person,
          onRestore: () => _confirmAndRestore(context, ref, person),
        );
      },
    );
  }
}

/// Hỏi lại, khôi phục, rồi báo kết quả bằng hộp thoại to.
/// Mọi thứ cần từ ref/context được lấy TRƯỚC các await.
Future<void> _confirmAndRestore(
  BuildContext context,
  WidgetRef ref,
  DeletedPerson person,
) async {
  final repository = ref.read(deletedPeopleRepositoryProvider);
  final container = ProviderScope.containerOf(context, listen: false);

  // Tên để hiện trong hộp thoại kết quả: người trên cây và người đã xóa.
  final tree = container.read(treeDataProvider).value;
  final deleted = container.read(deletedPeopleProvider).value ?? const [];
  final names = <String, String>{
    if (tree != null)
      for (final p in tree.people) p.id: p.fullName,
    for (final d in deleted) d.id: d.fullName,
  };
  String? nameOf(Object? id) => id is String ? names[id] : null;

  // Nút chính = "Xem lại" vì chạm ra ngoài được tính là nút chính:
  // lỡ chạm ra ngoài thì KHÔNG khôi phục.
  final review = await showChoiceDialog(
    context,
    title: 'Khôi phục ${person.fullName}?',
    message: 'Người này sẽ được đưa trở lại cây gia phả, cùng các quan hệ '
        'đã bị gỡ lúc xóa (nếu người ở đầu kia vẫn còn trên cây).',
    primaryLabel: 'Xem lại',
    secondaryLabel: 'Khôi phục',
  );
  if (review || !context.mounted) {
    return;
  }

  try {
    final result = await repository.restore(person.id);
    container.invalidate(treeDataProvider);
    container.invalidate(deletedPeopleProvider);
    container.invalidate(historyFeedProvider(null));
    container.invalidate(historyFeedProvider(person.id));
    if (!context.mounted) {
      return;
    }
    await showMessageDialog(
      context,
      title: 'Đã khôi phục',
      message: describeRestoreResult(result, nameOf),
    );
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    if (error.toString().contains('NOT_DELETED')) {
      container.invalidate(deletedPeopleProvider);
      await showMessageDialog(
        context,
        title: 'Không cần khôi phục',
        message: 'Người này đã được khôi phục từ trước.',
      );
      return;
    }
    await showErrorDialog(context, error);
  }
}

class _DeletedCard extends StatelessWidget {
  const _DeletedCard({required this.person, required this.onRestore});

  final DeletedPerson person;
  final VoidCallback onRestore;

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
              person.fullName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(person.lifeSpan, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Đã xóa lúc ${formatHistoryTime(person.deletedAt)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: onRestore,
                child: const Text(
                  'Khôi phục',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
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