# TOTV+ Flutter Implementation Guide
## دليل التنفيذ الكامل لتطبيق TOTV+

---

## 📋 جدول المحتويات

1. [متطلبات المشروع](#متطلبات-المشروع)
2. [هيكل المشروع](#هيكل-المشروع)
3. [التبعيات (Dependencies)](#التبعيات)
4. [إعداد Firebase](#إعداد-firebase)
5. [إعداد Android (FLAG_SECURE)](#إعداد-android)
6. [إعداد iOS](#إعداد-ios)
7. [تشغيل التطبيق](#تشغيل-التطبيق)
8. [الأمان والحماية](#الأمان-والحماية)
9. [نصائح الأداء](#نصائح-الأداء)

---

## متطلبات المشروع

### 1. البرمجيات المطلوبة
```bash
- Flutter SDK >= 3.19.0
- Dart >= 3.3.0
- Android Studio / Xcode
- Firebase Account
```

### 2. المعرفة المطلوبة
- Clean Architecture
- BLoC State Management
- Video Streaming (HLS/M3U8)
- Firebase Services

---

## هيكل المشروع

```
totv_plus/
├── lib/
│   ├── core/
│   │   ├── config/
│   │   │   └── app_theme.dart
│   │   ├── services/
│   │   │   ├── video_player_service.dart
│   │   │   ├── firebase_remote_config_service.dart
│   │   │   └── force_update_service.dart
│   │   └── utils/
│   │       ├── encryption_utils.dart
│   │       └── ssl_pinning.dart
│   ├── data/
│   │   ├── models/
│   │   │   └── content_model.dart
│   │   ├── repositories/
│   │   │   └── content_repository_impl.dart
│   │   └── datasources/
│   │       ├── remote_data_source.dart
│   │       └── local_data_source.dart
│   ├── domain/
│   │   ├── entities/
│   │   │   └── content.dart
│   │   ├── repositories/
│   │   │   └── content_repository.dart
│   │   └── usecases/
│   │       └── get_trending_content.dart
│   ├── presentation/
│   │   ├── bloc/
│   │   │   └── home/
│   │   │       ├── home_bloc.dart
│   │   │       ├── home_event.dart
│   │   │       └── home_state.dart
│   │   ├── pages/
│   │   │   ├── home_page.dart
│   │   │   ├── video_player_page.dart
│   │   │   └── splash_screen.dart
│   │   └── widgets/
│   │       ├── player_controls.dart
│   │       ├── content_carousel.dart
│   │       ├── category_row.dart
│   │       └── bottom_nav_bar.dart
│   └── main.dart
├── android/
│   └── app/
│       └── src/
│           └── main/
│               └── kotlin/.../MainActivity.kt
├── ios/
└── pubspec.yaml
```

---

## التبعيات

### pubspec.yaml

```yaml
name: totv_plus
description: TOTV+ Streaming Platform
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  
  # Firebase
  firebase_core: ^2.24.2
  firebase_remote_config: ^4.3.8
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_analytics: ^10.8.0
  
  # Video Player
  video_player: ^2.8.2
  chewie: ^1.7.5
  
  # Networking
  dio: ^5.4.0
  http: ^1.2.0
  
  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  flutter_secure_storage: ^9.0.0
  
  # UI Components
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  flutter_svg: ^2.0.9
  
  # Utilities
  intl: ^0.18.1
  crypto: ^3.0.3
  path_provider: ^2.1.2
  package_info_plus: ^5.0.1
  device_info_plus: ^9.1.1
  connectivity_plus: ^5.0.2
  
  # Localization
  flutter_localizations:
    sdk: flutter
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  hive_generator: ^2.0.1
  build_runner: ^2.4.8

flutter:
  uses-material-design: true
  
  assets:
    - assets/images/
    - assets/icons/
    - assets/fonts/
  
  fonts:
    - family: Cairo
      fonts:
        - asset: assets/fonts/Cairo-Regular.ttf
        - asset: assets/fonts/Cairo-Bold.ttf
          weight: 700
```

---

## إعداد Firebase

### 1. إنشاء مشروع Firebase

```bash
1. انتقل إلى https://console.firebase.google.com
2. أنشئ مشروع جديد باسم "TOTV-Plus"
3. فعّل Google Analytics (اختياري)
```

### 2. إضافة تطبيقات (Android & iOS)

**للأندرويد:**
```bash
Package Name: com.totv.plus
SHA-1: (احصل عليه من Android Studio)
```

**لـ iOS:**
```bash
Bundle ID: com.totv.plus
```

### 3. تنزيل ملفات الإعداد

```bash
# Android
google-services.json → android/app/

# iOS
GoogleService-Info.plist → ios/Runner/
```

### 4. إعداد Remote Config

في Firebase Console → Remote Config:

```json
{
  "trending_content": "<encrypted_json>",
  "featured_content": "<encrypted_json>",
  "cdn_base_urls": "<encrypted_json>",
  "force_update_enabled": false,
  "min_supported_version": "1.0.0",
  "enable_downloads": true,
  "enable_pip": true,
  "primary_color": "#FF6B00"
}
```

---

## إعداد Android

### 1. MainActivity.kt - إضافة FLAG_SECURE

```kotlin
// android/app/src/main/kotlin/com/totv/plus/MainActivity.kt

package com.totv.plus

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val SECURITY_CHANNEL = "com.totv.plus/security"
    private val SCREEN_CHANNEL = "com.totv.plus/screen"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Security Channel (FLAG_SECURE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureFlag" -> {
                        val enable = call.argument<Boolean>("enable") ?: true
                        setSecureFlag(enable)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Screen Channel (Keep Awake)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepScreenOn" -> {
                        val enable = call.argument<Boolean>("enable") ?: true
                        keepScreenOn(enable)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setSecureFlag(enable: Boolean) {
        if (enable) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun keepScreenOn(enable: Boolean) {
        if (enable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
```

### 2. AndroidManifest.xml

```xml
<!-- android/app/src/main/AndroidManifest.xml -->

<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    
    <application
        android:label="TOTV+"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false"
        android:networkSecurityConfig="@xml/network_security_config">
        
        <activity
            android:name=".MainActivity"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
        </activity>
    </application>
</manifest>
```

### 3. Network Security Config

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->

<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- SSL Pinning for TOTV+ CDN -->
    <domain-config cleartextTrafficPermitted="false">
        <domain includeSubdomains="true">cdn1.totv.plus</domain>
        <domain includeSubdomains="true">cdn2.totv.plus</domain>
        <domain includeSubdomains="true">cdn3.totv.plus</domain>
        
        <pin-set>
            <!-- SHA-256 fingerprint of your SSL certificate -->
            <pin digest="SHA-256">AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</pin>
            <!-- Backup pin -->
            <pin digest="SHA-256">BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

---

## إعداد iOS

### Info.plist

```xml
<!-- ios/Runner/Info.plist -->

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<key>UISupportsDocumentBrowser</key>
<true/>
```

---

## تشغيل التطبيق

### 1. تثبيت التبعيات

```bash
flutter pub get
```

### 2. تشغيل Build Runner (لـ Hive)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. تشغيل التطبيق

```bash
# Android
flutter run

# iOS
flutter run -d ios

# Release Build
flutter build apk --release
flutter build ios --release
```

---

## الأمان والحماية

### 1. تشفير AES-256

```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

class EncryptionUtils {
  static String encrypt(String data, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    
    // XOR encryption (استخدم AES حقيقي في الإنتاج)
    final encrypted = <int>[];
    for (var i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return base64.encode(encrypted);
  }
  
  static String decrypt(String encrypted, String key) {
    final keyBytes = utf8.encode(key);
    final encryptedBytes = base64.decode(encrypted);
    
    final decrypted = <int>[];
    for (var i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return utf8.decode(decrypted);
  }
}
```

### 2. Root Detection

```dart
import 'package:flutter/services.dart';

class SecurityService {
  static const platform = MethodChannel('com.totv.plus/security');
  
  Future<bool> isDeviceRooted() async {
    try {
      final bool isRooted = await platform.invokeMethod('checkRootStatus');
      return isRooted;
    } catch (e) {
      return false;
    }
  }
}
```

---

## نصائح الأداء

### 1. تحسين الصور

```dart
CachedNetworkImage(
  imageUrl: content.posterUrl,
  memCacheWidth: 300,
  memCacheHeight: 450,
  placeholder: (context, url) => Shimmer.fromColors(
    baseColor: Colors.grey[800]!,
    highlightColor: Colors.grey[700]!,
    child: Container(color: Colors.grey[800]),
  ),
)
```

### 2. Lazy Loading

```dart
ListView.builder(
  itemCount: items.length,
  cacheExtent: 1000,
  itemBuilder: (context, index) {
    return ContentCard(content: items[index]);
  },
)
```

### 3. التحميل المسبق للفيديوهات

```dart
void preloadNextEpisode(Content nextContent) async {
  final controller = VideoPlayerController.network(
    nextContent.streamingUrls.first,
  );
  await controller.initialize();
  // سيتم استخدامه لاحقاً
}
```

---

## الخطوات التالية

1. ✅ **إكمال Firebase Setup** - أضف بيانات اعتماد حقيقية
2. ✅ **إضافة CDN URLs** - استبدل بروابط السيرفرات الحقيقية
3. ✅ **تطبيق DRM** - أضف Widevine للحماية الكاملة
4. ✅ **اختبار SSL Pinning** - تأكد من أمان الاتصالات
5. ✅ **إضافة Analytics** - تتبع سلوك المستخدمين
6. ✅ **تحسين الأداء** - قياس وتحسين السرعة

---

## الدعم والمساعدة

للمزيد من المساعدة:
- 📧 Email: dev@totv.plus
- 📱 WhatsApp: +964-XXX-XXX-XXXX
- 🌐 Website: https://totv.plus

---

**تم بحمد الله** 🚀
**مشروع TOTV+ - تطبيق بث عالمي احترافي**
