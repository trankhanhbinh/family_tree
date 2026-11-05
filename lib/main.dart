import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familytree/app.dart';
import 'package:familytree/core/config/env.dart';
import 'package:familytree/features/push/data/firebase_ready_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  final firebaseReady = await _initFirebase();

  runApp(
    ProviderScope(
      overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
      child: const FamilyTreeApp(),
    ),
  );
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
