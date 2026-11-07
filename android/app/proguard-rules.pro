# Cấu hình đã test chạy ổn với dòng này; bỏ đi thì phải test lại cả emulator lẫn Samsung.
-dontobfuscate
# ---- flutter_local_notifications ----
-keep class com.dexterous.flutterlocalnotifications.** { *; }
# Thư viện này lưu lịch thông báo bằng Gson nên cần giữ các lớp kiểu của Gson.
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type

# ---- shared_preferences_android (từng mất hàm JNI khi bật R8) ----
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }