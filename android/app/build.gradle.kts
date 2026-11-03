import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Đọc thông tin khóa ký từ android/key.properties (file này KHÔNG được commit).
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
val keystoreProperties = Properties()
if (hasReleaseKey) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

// Build release mà thiếu key.properties thì dừng ngay, không lặng lẽ ký bằng khóa debug.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any { task ->
        (task.name.startsWith("assemble") || task.name.startsWith("bundle")) &&
            task.name.endsWith("Release")
    }
    if (buildsRelease && !hasReleaseKey) {
        throw GradleException(
            "Missing android/key.properties - cannot sign the release build."
        )
    }
}

android {
    namespace = "com.binh.familytree"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.binh.familytree"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Lấy từ version trong pubspec.yaml (dạng 1.0.0+1: versionName+versionCode).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 đang TẮT: bật lên thì app đứng ở màn logo (mất lớp lúc khởi động).
            // Muốn thử lại cần log lỗi từ emulator; luật giữ lớp nằm trong proguard-rules.pro.
            isMinifyEnabled = false
            // Không cắt tài nguyên: lợi ít, dễ làm mất biểu tượng thông báo.
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}