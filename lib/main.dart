import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familytree/app.dart';
import 'package:familytree/core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  final firebaseReady = await _initFirebase();

  runApp(const ProviderScope(child: FamilyTreeApp()));

  if (firebaseReady) {
    unawaited(_debugFirebaseCheck());
  }
}

/// Khởi tạo Firebase. Lỗi (thiếu Google Play Services, thiếu file cấu hình)
/// không làm app dừng: người xem vẫn dùng bình thường, chỉ mất thông báo đẩy.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } catch (error) {
    debugPrint('FCM_INIT_FAILED: $error');
    return false;
  }
}

/// TẠM THỜI cho 5F-1 (xóa ở 5F-2): xin quyền thông báo, đăng ký với FCM và in
/// Firebase Installation ID (FID) ra log để thử gửi.
Future<void> _debugFirebaseCheck() async {
  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission();
    debugPrint('FCM_PERMISSION: ${settings.authorizationStatus.name}');

    // Phải lắng nghe onRegistered TRƯỚC khi gọi register().
    final fidFuture = messaging.onRegistered.first;
    await messaging.register();
    final fid = await fidFuture.timeout(const Duration(seconds: 30));

    debugPrint('FCM_OK');
    debugPrint('FCM_FID: $fid');
  } catch (error) {
    debugPrint('FCM_CHECK_FAILED: $error');
  }
}