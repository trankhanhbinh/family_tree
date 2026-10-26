import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/features/auth/data/auth_service.dart';
import 'package:familytree/features/auth/data/nickname_store.dart';
import 'package:familytree/features/auth/ui/contributor_gate.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

/// TẠM THỜI cho khối 4A. Xóa file này khi 4B có nút "Đề xuất sửa" thật.
class DevAuthCheckScreen extends ConsumerStatefulWidget {
  const DevAuthCheckScreen({super.key});

  @override
  ConsumerState<DevAuthCheckScreen> createState() =>
      _DevAuthCheckScreenState();
}

class _DevAuthCheckScreenState extends ConsumerState<DevAuthCheckScreen> {
  String _log = 'Chưa chạy gì.';

  void _setLog(String value) {
    if (!mounted) {
      return;
    }
    setState(() => _log = value);
  }

  Future<void> _checkContributor() async {
    final contributor = await ensureContributor(context, ref);
    _setLog(
      contributor == null
          ? 'Bị hủy hoặc có lỗi.'
          : 'OK: ${contributor.nickname} / ${contributor.userId}',
    );
  }

  Future<void> _editNickname() async {
    final name = await editNickname(context, ref);
    _setLog(name == null ? 'Không đổi tên.' : 'Đã đổi thành: $name');
  }

  Future<void> _clearNickname() async {
    await ref.read(nicknameProvider.notifier).clear();
    _setLog('Đã xóa nickname.');
  }

  Future<void> _signOut() async {
    // Giữ mạng BẬT khi bấm. Tạo người dùng ẩn danh mới ở lần đăng nhập sau.
    await ref.read(supabaseClientProvider).auth.signOut();
    _setLog('Đã đăng xuất (dev).');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authServiceProvider).currentUser;
    final nickname = ref.watch(nicknameProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm tra 4A (dev)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đã đăng nhập: ${user != null ? 'có' : 'chưa'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Ẩn danh: ${user?.isAnonymous}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'User id: ${user?.id ?? '-'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Nickname: ${nickname ?? '(chưa có)'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kết quả: $_log',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _DevButton('Thử đăng nhập + hỏi nickname', _checkContributor),
          _DevButton('Đổi nickname', _editNickname),
          _DevButton('Xóa nickname (dev)', _clearNickname),
          _DevButton('Đăng xuất (dev)', _signOut),
          const Divider(height: 32),
          _DevButton(
            'Hiện lỗi: quá 10 đề xuất',
            () => showErrorDialog(
              context,
              PostgrestException(
                message: 'REQUEST_LIMIT_REACHED',
                code: 'P0001',
              ),
            ),
          ),
          _DevButton(
            'Hiện lỗi: vòng lặp tổ tiên',
            () => showErrorDialog(
              context,
              PostgrestException(message: 'CYCLE_DETECTED', code: 'P0001'),
            ),
          ),
          _DevButton(
            'Hiện lỗi: mã lạ',
            () => showErrorDialog(
              context,
              PostgrestException(message: 'SOMETHING_WEIRD'),
            ),
          ),
          _DevButton(
            'Hiện lỗi: mất mạng',
            () => showErrorDialog(
              context,
              const SocketException('Failed host lookup'),
            ),
          ),
          const Divider(height: 32),
          _DevButton('Vào cây gia phả', () => context.go('/home')),
        ],
      ),
    );
  }
}

class _DevButton extends StatelessWidget {
  const _DevButton(this.label, this.onPressed);

  final String label;
  final FutureOr<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 56,
        child: FilledButton.tonal(
          onPressed: () => onPressed(),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}