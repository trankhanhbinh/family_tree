import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:familytree/core/router/app_router.dart';
import 'package:familytree/core/theme/app_theme.dart';
import 'package:familytree/features/auth/ui/admin_shell.dart';

class FamilyTreeApp extends ConsumerWidget {
  const FamilyTreeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Gia phả',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) =>
          AdminShell(child: child ?? const SizedBox.shrink()),
    );
  }
}