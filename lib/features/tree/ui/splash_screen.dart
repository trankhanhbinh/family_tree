import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tải xong thì chuyển sang màn hình chính
    ref.listen<AsyncValue<String>>(clanNameProvider, (previous, next) {
      if (next.hasValue) context.go('/home');
    });

    final state = ref.watch(clanNameProvider);

    return Scaffold(
      body: Center(
        child: state.when(
          data: (_) => const CircularProgressIndicator(),
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) {
            debugPrint('Lỗi tải clan_info: $error');
            return _ErrorView(
              onRetry: () => ref.invalidate(clanNameProvider),
            );
          },
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
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          const Text(
            'Không tải được dữ liệu.\nVui lòng kiểm tra kết nối mạng.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}