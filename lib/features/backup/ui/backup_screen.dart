import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/features/backup/data/backup_repository.dart';
import 'package:familytree/features/backup/data/backup_share.dart';
import 'package:familytree/features/backup/domain/backup_builder.dart';

/// Xuất file sao lưu JSON (ai cũng dùng được). Route: /backup.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  String? _lastSummary;

  Future<void> _export() async {
    if (_busy) {
      return;
    }
    // Lấy sẵn repository TRƯỚC các await.
    final repository = ref.read(backupRepositoryProvider);

    setState(() => _busy = true);
    try {
      final raw = await repository.fetchAll();
      final now = DateTime.now();
      final data = raw.withoutDeleted();
      final json = encodeBackup(buildBackupMap(data, now));
      if (!mounted) {
        return;
      }
      setState(() => _lastSummary = describeBackupCounts(data.counts));
      await shareBackupFile(fileName: backupFileName(now), json: json);
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = _lastSummary;

    return Scaffold(
      appBar: AppBar(title: const Text('Sao lưu dữ liệu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'File sao lưu (.json) chứa thông tin cả dòng họ: các chi/nhánh, '
            'người, quan hệ cha mẹ - con, hôn nhân và danh sách ảnh '
            '(không gồm các file ảnh).',
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'File có thông tin cả dòng họ, chỉ gửi cho người tin cậy.',
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: scheme.error,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _busy ? null : _export,
              child: _busy
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Đang chuẩn bị...',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    )
                  : const Text(
                      'Xuất file sao lưu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          if (summary != null) ...[
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lần xuất gần nhất',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: const TextStyle(fontSize: 18, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}