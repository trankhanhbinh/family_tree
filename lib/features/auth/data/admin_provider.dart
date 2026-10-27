import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familytree/core/config/env.dart';
import 'package:familytree/core/errors/app_error_messages.dart';
import 'package:familytree/features/auth/domain/admin_login_rules.dart';
import 'package:familytree/features/tree/data/clan_info_provider.dart';
import 'package:familytree/features/tree/data/tree_repository.dart';

/// true = đang là quản trị viên (đã được server xác nhận bằng rpc is_admin).
class AdminNotifier extends Notifier<bool> {
  SupabaseClient get _client => ref.read(supabaseClientProvider);

  @override
  bool build() {
    final subscription = _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut && ref.mounted) {
        state = false;
      }
    });
    ref.onDispose(subscription.cancel);

    final user = _client.auth.currentUser;
    if (shouldVerifyAdminOnStart(
      hasSession: user != null,
      isAnonymous: user?.isAnonymous ?? true,
    )) {
      unawaited(_restore());
    }
    return false;
  }

  Future<bool> _checkIsAdmin() async {
    final result =
        await _client.rpc('is_admin').timeout(const Duration(seconds: 15));
    return result == true;
  }

  /// Mở lại app còn phiên admin cũ: hỏi server rồi bật chế độ admin.
  Future<void> _restore() async {
    try {
      final ok = await _checkIsAdmin();
      if (ok && ref.mounted) {
        state = true;
        ref.invalidate(treeDataProvider);
      }
    } catch (error) {
      debugPrint('Không xác nhận được quyền admin khi mở app: $error');
    }
  }

  /// Đăng nhập bằng mã. Ném lỗi nếu thất bại (nơi gọi hiện bằng showErrorDialog).
  Future<void> signIn(String code) async {
    final email = Env.adminEmail;
    if (email.isEmpty) {
      throw StateError('Chưa cấu hình ADMIN_EMAIL trong env.json');
    }

    await _client.auth.signInWithPassword(email: email, password: code);

    final bool isAdmin;
    try {
      isAdmin = await _checkIsAdmin();
    } catch (_) {
      await _signOutQuietly();
      rethrow;
    }

    if (!isAdmin) {
      await _signOutQuietly();
      throw const AdminAccessDeniedException();
    }

    if (ref.mounted) {
      state = true;
      ref.invalidate(treeDataProvider);
    }
  }

  Future<void> signOut() async {
    await _signOutQuietly();
    if (ref.mounted) {
      state = false;
      ref.invalidate(treeDataProvider);
    }
  }

  // local: chỉ thoát máy này (2 admin dùng chung tài khoản, không đá người kia).
  Future<void> _signOutQuietly() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      debugPrint('Đăng xuất lỗi (bỏ qua): $error');
    }
  }
}

final isAdminProvider =
    NotifierProvider<AdminNotifier, bool>(AdminNotifier.new);