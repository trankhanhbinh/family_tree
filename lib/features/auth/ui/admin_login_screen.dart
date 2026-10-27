import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:familytree/core/config/env.dart';
import 'package:familytree/core/ui/app_dialogs.dart';
import 'package:familytree/features/auth/data/admin_provider.dart';
import 'package:familytree/features/auth/domain/admin_login_rules.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    FocusScope.of(context).unfocus();

    if (Env.adminEmail.isEmpty) {
      await showMessageDialog(
        context,
        title: 'Chưa cấu hình',
        message: 'Ứng dụng chưa có email quản trị (ADMIN_EMAIL trong '
            'env.json). Vui lòng báo người làm app.',
        icon: Icons.settings,
        isError: true,
      );
      return;
    }

    final problem = validateAdminCode(_codeController.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(isAdminProvider.notifier)
          .signIn(normalizeAdminCode(_codeController.text));
      if (!mounted) {
        return;
      }
      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      await showErrorDialog(context, error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản trị viên')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Dành cho quản trị viên dòng họ. '
              'Nhập mã quản trị để đăng nhập.',
              style: TextStyle(fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 24),
            const Text(
              'Mã quản trị',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              enabled: !_busy,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                errorText: _error,
                errorStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed:
                    _busy ? null : () => setState(() => _obscure = !_obscure),
                child: Text(
                  _obscure ? 'Hiện mã' : 'Ẩn mã',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Text('Đăng nhập', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Người đóng góp không cần đăng nhập ở đây.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}