import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/features/auth/data/auth_service.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Đăng nhập ẩn danh âm thầm. Thất bại thì vẫn xem được cây
    // (xem không cần đăng nhập); chỉ khi bấm "Đề xuất" mới thử lại và báo lỗi.
    unawaited(ref.read(authServiceProvider).trySignInQuietly());
  }

  void _goNext() {
    if (!mounted) {
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String>>(clanNameProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        debugPrint('Lỗi tải clan_info: ${next.error}');
      }
      if (next.hasValue) {
        _goNext();
      }
    });

    final state = ref.watch(clanNameProvider);

    return Scaffold(
      body: Center(
        child: state.when(
          data: (_) => const CircularProgressIndicator(),
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => _ErrorView(
            onRetry: () => ref.invalidate(clanNameProvider),
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
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 56,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          const Text(
            'Không tải được dữ liệu.\nVui lòng kiểm tra kết nối mạng.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.4),
          ),
          const SizedBox(height: 24),
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
    );
  }
}