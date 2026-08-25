# TOTV+ Voice Rooms 🎙

غرف صوتية منخفضة الاستهلاك (Flutter + LiveKit SFU + Firebase Cloud Functions)، مبنية على Clean Architecture مع BLoC.

```
28 kbps للمشارك · ~12 ميغابايت/ساعة · صفر مستمعي Firestore داخل الغرفة
```

---

## ما الذي يميّز هذا التصميم

| القرار | الأثر |
|---|---|
| **SFU بدل P2P Mesh** | النطاق ثابت 28 kbps مهما كبرت الغرفة (Mesh ينهار عند 5 مشاركين) |
| **DTX مفعّل** | يوقف الإرسال أثناء الصمت → توفير ~70% من الباقة |
| **المستمع بلا مسار صوت** | لا مايك ولا مُرمِّز ولا AEC → ~3× بطارية أطول لـ 90% من الغرفة |
| **مستويات الصوت في Cubit منفصل** | تجنّب إعادة بناء الشاشة 10 مرات/ثانية |
| **صفر `.snapshots()`** | العدّاد يكتبه Webhook من LiveKit، والقائمة قراءة واحدة |
| **الصلاحيات من الخادم حصراً** | العميل لا يقرّر من يتحدث — لا يمكن تزويره |

---

## هيكل المستودع

```
totv-voice-rooms/
├── firebase.json / firestore.rules / firestore.indexes.json
├── .github/workflows/android.yml   🤖 يبني APK تلقائياً عند كل push
│
├── android_overrides/              📦 إعدادات أندرويد (تُطبَّق فوق flutter create)
│   ├── settings.gradle             + إضافة google-services
│   ├── gradle.properties           ذاكرة كافية لبناء WebRTC
│   └── app/
│       ├── build.gradle            ★ minSdk 23 · com.totv.plus
│       ├── google-services.json    مشروع totvq-8e439
│       ├── proguard-rules.pro
│       └── src/main/
│           ├── AndroidManifest.xml صلاحيات المايك والخدمة الأمامية
│           └── kotlin/com/totv/plus/MainActivity.kt
│
├── functions/                      ☁️ Backend
│   ├── index.js
│   └── src/
│       ├── config.js               🔑 رابط LiveKit + مراجع الأسرار
│       ├── tokens.js               mintVoiceToken — إصدار JWT
│       ├── rooms.js                إنشاء / إغلاق الغرفة
│       ├── moderation.js           ترقية / كتم / طرد / رفع يد
│       └── webhook.js              عدّاد المشاركين
│
└── app/                            📱 Flutter
    ├── pubspec.yaml
    ├── lib/main.dart               تطبيق تجريبي مستقل
    ├── lib/firebase_options.dart   ✅ مضبوط على totvq-8e439
    ├── test/                       اختبارات وحدة (بلا شبكة)
    └── lib/features/voice_room/
        ├── voice_room.dart         ← نقطة الاستيراد الوحيدة
        ├── di.dart
        ├── core/failures.dart
        ├── domain/                 كيانات + عقد + use cases (بلا تبعيات)
        ├── data/                   LiveKit + Firebase
        └── presentation/           BLoC + صفحات + ويدجتس
```

---

## ⚙️ خطوات التشغيل

### ① الأسرار (لا تُكتب في أي ملف)

```bash
cd functions
npm install

firebase functions:secrets:set LIVEKIT_API_KEY
firebase functions:secrets:set LIVEKIT_API_SECRET
```

> ⚠️ **إن ظهر سرّك في لقطة شاشة أو رسالة أو commit — ألغِه فوراً**
> من لوحة LiveKit وأنشئ مفتاحاً جديداً. السرّ يُعرض مرة واحدة فقط،
> ولا سبيل لتدويره إلا بالإلغاء وإعادة الإنشاء.

> ⚠️ سر LiveKit **لا يدخل تطبيق Flutter إطلاقاً**. التطبيق يستلم توكناً موقّعاً جاهزاً من الدالة ولا يعرف كيف يوقّع. من يملك السر يستطيع إنشاء توكن مضيف لأي غرفة.
>
> رابط الـ WebSocket موجود بالفعل في `functions/src/config.js` — عدّله فقط إن انتقلت لخادم ذاتي.

### ② النشر

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```

### ③ Webhook

من `firebase deploy` انسخ رابط `livekitWebhook`، ثم في
**LiveKit Cloud → Settings → Webhooks** أضفه:

```
https://europe-west1-<project-id>.cloudfunctions.net/livekitWebhook
```

### ④ Firebase — جاهز بالفعل

`app/lib/firebase_options.dart` و `android_overrides/app/google-services.json`
مضبوطان على مشروعك `totvq-8e439` وحزمة `com.totv.plus`. لا حاجة لـ
`flutterfire configure` للأندرويد.

فعّل **Anonymous** من Firebase Console → Authentication → Sign-in method
(للتجربة فقط — استبدله بمصادقة TOTV+ الحقيقية لاحقاً).

### ⑤ البناء على GitHub — تلقائي

ادفع المستودع إلى GitHub؛ يعمل `.github/workflows/android.yml` تلقائياً
ويُنتج APK جاهزاً في تبويب **Actions → Artifacts**.

سير العمل يولّد سقالة أندرويد بـ `flutter create` (لأن `gradlew` وملفات
الـ wrapper ثنائية ولا تُرفع)، ثم يطبّق `android_overrides/` فوقها:
`minSdk = 23`، `applicationId = com.totv.plus`، صلاحيات المايك،
وإضافة `google-services`.

### ⑥ البناء محلياً

```bash
cd app
mv lib /tmp/lib_bk && mv pubspec.yaml /tmp/ps_bk
flutter create --platforms=android --org com.totv --project-name totv_voice_rooms .
rm -rf lib pubspec.yaml && mv /tmp/lib_bk lib && mv /tmp/ps_bk pubspec.yaml
rm -rf android/app/src/main/kotlin android/app/src/main/java
cp -r ../android_overrides/. android/

flutter pub get
flutter run --release      # ★ لا debug — WebRTC بطيء جداً في debug
```

> نفّذ كتلة `flutter create` مرة واحدة فقط. بعدها `flutter run` يكفي.

---

## 🧪 اختبار الاتصال

**١. اختبار الخادم أولاً** — أنشئ غرفة يدوياً في Firestore:

```
voice_rooms/test-room
{
  "title": "غرفة تجريبية",
  "hostUid": "<uid حسابك>",
  "speakers": [], "banned": [], "raised_hands": [],
  "locked": false, "closed": false, "live": false, "count": 0
}
```

ثم:

```dart
final r = await FirebaseFunctions.instanceFor(region: 'europe-west1')
    .httpsCallable('mintVoiceToken').call({'roomId': 'test-room'});
debugPrint(r.data['role']);   // متوقّع: host
```

**٢. اختبار الصلاحيات** — جرّب من حساب ثانٍ. يجب أن يرجع `listener` وألا يستطيع فتح المايك. هذا يثبت أن الدور يُفرض من الخادم لا من العميل.

**٣. اختبار الصوت** — جهازان حقيقيان (لا محاكي — المحاكي لا يملك مايكروفوناً حقيقياً). المضيف يضغط مطوّلاً على المستمع → ترقية → يجب أن يظهر زر المايك عنده **فوراً بلا إعادة اتصال**.

**٤. اختبار الشبكة الحقيقية** — على بيانات الجوال لا WiFi. التأخير وفقد الحزم مختلفان جذرياً.

```bash
flutter test          # اختبارات منطق الصلاحيات — بلا شبكة، أجزاء من الثانية
```

---

## 🔌 الدمج في تطبيق TOTV+ الأصلي

انسخ `app/lib/features/voice_room/` إلى `lib/features/` في مشروعك، أضف التبعيات من `pubspec.yaml`، ثم:

```dart
import 'features/voice_room/voice_room.dart';

Navigator.push(ctx, MaterialPageRoute(
  builder: (_) => const RoomsListPage()));
```

لا حاجة لتعديل `main.dart` — الميزة تدير حالتها وتبعياتها بالكامل. ادمج قواعد `voice_rooms` في `firestore.rules` الحالي، وملفات `functions/src/` في مجلد الدوال الموجود.

---

## 💰 التكلفة

الطبقة المجانية على LiveKit Cloud: **5,000 دقيقة WebRTC شهرياً** (≈83 ساعة مشارك) — كافية للتطوير، تنفد بسرعة عند الإطلاق.

عند 900,000 دقيقة/شهر (500 مستخدم × ساعة يومياً):

| الحل | التكلفة/شهر |
|---|---:|
| Agora RTC | ~$891 |
| LiveKit Cloud | ~$425 |
| **LiveKit ذاتي على VPS 4vCPU/8GB** | **~$24** |

الانتقال للخادم الذاتي = تعديل `LK_WS_URL` و `LK_HTTP_URL` في `config.js` فقط. لا تغيير في التطبيق.

> الأسعار تتغيّر — راجع `livekit.com/pricing` قبل أي قرار.

---

## ⚠️ ما تحتاج توفيره بنفسك

هذه غير موجودة في المستودع عمداً (وفي `.gitignore`):

| الملف | كيف تحصل عليه |
|---|---|
| **سر LiveKit** | لوحة LiveKit — يُعرض مرة واحدة فقط عند الإنشاء |
| مفتاح التوقيع للنشر | `keytool -genkey` — **لا تضعه في المستودع أبداً** |
| `GoogleService-Info.plist` | Firebase Console — لـ iOS فقط، غير مطلوب للأندرويد |

كل ما عدا ذلك جاهز: `firebase_options.dart` و `google-services.json`
مضبوطان على مشروعك، وسقالة أندرويد يولّدها CI تلقائياً.

---

## 📋 قائمة تحقّق قبل الإطلاق

- [ ] `audio_session` — تعامل مع المكالمة الواردة، وإلا ينقطع الصوت نهائياً على iOS بعد أول مكالمة
- [ ] Foreground Service فعلي على أندرويد (الصلاحية موجودة، الخدمة تحتاج تنفيذاً)
- [ ] اختبار على شبكة جوال عراقية حقيقية
- [ ] راقب استهلاك الدقائق في لوحة LiveKit أول أسبوع
- [ ] `flutter build apk --release --split-per-abi` — يقلّل حجم APK بنحو 40% مع WebRTC
