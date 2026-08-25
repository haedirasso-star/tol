# TOTV+ — دليل البناء والتعديلات

تم دمج التطويرات داخل المشروع مباشرةً. هذا الملف يلخّص ما تغيّر وكيف تبني.

## ✅ ما تم دمجه

### ملفات جديدة (lib/ui/pages/)
- **payment_sheet.dart** — شاشة دفع محسّنة (باقات + طرق دفع + تتبّع طلب). الدخول: `BuyPremiumButton()` أو `PayPlansSheet.show(context)`.
- **admin_console.dart** — مركز عمليات الأدمن الكامل (11 قسم): Dashboard, المستخدمون, تفعيل, الاشتراكات, الطلبات, الرصيد, تحكم, الإصدارات, الإشعارات, المحظورون, الإعدادات.
- **admin_credit.dart** — نظام الرصيد: كل سيرفر = نقطتان، كل تفعيل = نقطة، التخصيص داخل transaction.

### تعديلات main.dart
- أضيفت أسطر `part` للملفات الثلاثة (أسطر 60–62).
- أضيف مسار `'/ops': (_) => const AdminConsolePage()` (سطر 283).

### تعديلات الأمان
- **firestore.rules**: أضيفت قواعد `orders` و`servers` (سيرفرات للأدمن فقط لأنها تحوي كلمات مرور)، وشُدّد تعديل `subscription` ليكون من الأدمن فقط.
- **storage.rules**: جديد — رفع الإيصالات تحت `receipts/{uid}/` (صور ≤ 5MB).

## 🔌 خطوة يدوية مطلوبة منك
أضِف زر دخول مركز العمليات في صفحة الحساب (يظهر للأدمن فقط)، مثال:
```dart
if ((FirebaseAuth.instance.currentUser?.email ?? '') == 'haedirasso@gmail.com')
  ListTile(
    leading: const Icon(Icons.shield_rounded),
    title: const Text('مركز العمليات'),
    onTap: () => Navigator.pushNamed(context, '/ops'),
  ),
```
ولاستبدال زر الشراء القديم بالشاشة الجديدة، استخدم `const BuyPremiumButton()`.

## ⚙️ ميزة اختيارية: رفع الإيصال داخل التطبيق
في `payment_sheet.dart` الميزة تعمل افتراضياً عبر واتساب. لتفعيل الرفع داخل التطبيق:
1. أضِف إلى pubspec.yaml:
   ```yaml
   image_picker: ^1.1.2
   firebase_storage: ^13.0.5
   ```
2. أضِف الـ imports في main.dart.
3. بدّل `kReceiptUploadInApp = true` وأزِل التعليق عن جسم `_pickReceipt()`.

## 🏗 البناء
```bash
flutter pub get
flutter analyze        # شغّله وأصلح أي تحذير قبل البناء
flutter run            # للتجربة
flutter build apk --release   # أو appbundle للنشر
```

## 🚀 نشر القواعد
```bash
firebase deploy --only firestore:rules,storage
```

## 🔐 ملاحظات أمنية مهمة
- توكن تلجرام لم يعد في الكود — يُحفظ في `app_config/settings` من قسم الإعدادات.
- ملفات التوقيع (key.properties, *.jks) يجب ألا تُرفع في أي مستودع عام.
- شغّل `flutter analyze` قبل البناء؛ لم يكن بالإمكان تشغيله أثناء التجهيز.
