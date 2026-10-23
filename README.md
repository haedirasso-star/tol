# TOTV+ — تطبيق البث (Flutter)

**الإصدار:** 3.4.0+16 · أندرويد (هاتف + تلفاز) · آيفون (iOS 14+)

## بنية المشروع

```text
lib/
  main.dart                 نقطة البداية + قائمة كل ملفات المكتبة (part)
  firebase_options.dart     إعدادات Firebase لكل منصة
  core/                     الثوابت والإعدادات العامة (constants, supa_config)
  services/                 المنطق بدون واجهة: الحساب، الاشتراك، الرياضة، الإشعارات، التحميلات…
  ui/
    widgets/                عناصر مشتركة (common) + بانر الفيديو
    player/                 المشغّل: المحرّكات، التفضيلات، المشغّل الاحترافي، المشغّل القديم (طوارئ)
    pages/                  صفحات المستخدم
    admin/                  صفحات الإدارة
  stub/                     بديل الإشعارات لنسخة الويب
assets/                     الصور والأصوات والفيديو (مُعلنة كمجلدات في pubspec)
android/  ios/              مشروعا المنصتين
.github/workflows/          البناء الآلي: أندرويد · آيفون · تطبيق الإدارة · دالة الإشعارات
firestore.rules  storage.rules  firestore.indexes.json  firebase.json
functions/                  دوال Firebase
supabase/                   قاعدة Supabase (SQL + دالة push)
sports_feed/                خادم جدول المباريات (مستودع مستقل)
store/                      أيقونات وصور المتجر
tools/admin.html            لوحة الإدارة على الويب (صفحة مستقلة تُفتح في المتصفح)
docs/                       التوثيق
```

## التوثيق (`docs/`)
| الملف | المحتوى |
|---|---|
| `CHANGELOG.md` | سجل كل الإصدارات |
| `IOS_BUILD_AR.md` | بناء نسخة الآيفون وما ينقصها |
| `INTEGRATION_AR.md` | دليل الدمج العام |
| `SUPABASE_SETUP_AR.md` | إعداد Supabase |
| `FIRESTORE_SCHEMA.md` | بنية قاعدة Firestore |

## البناء
- **أندرويد:** يُبنى تلقائياً عند الدفع إلى `main` (Actions ← TOTV+ Build — Release APK).
- **آيفون:** يدوياً من Actions ← TOTV+ Build — iOS (IPA). التفاصيل في `docs/IOS_BUILD_AR.md`.
- محلياً: `flutter pub get` ثم `flutter build apk --flavor phone` (أو `--flavor tv`).
