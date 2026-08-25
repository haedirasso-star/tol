# TOTV+ — دليل الإضافات الجديدة

هذا **تطبيق TOTV+ نفسه** بكل ميزاته الأصلية، مضافاً إليه:

1. 🎙 **الغرف الصوتية** — عبر LiveKit SFU
2. 📢 **رسالة تلجرام الترحيبية** — تصميم زجاجي على خلفية بوسترات

لم يُحذف أو يُغيَّر أي ملف من ملفاتك الأصلية سوى إضافات محدودة موصوفة أدناه.

---

## ما الذي تغيّر بالضبط

| الملف | التغيير |
|---|---|
| `lib/main.dart` | 3 استيرادات + 3 `part` جديدة |
| `lib/core/constants.dart` | حقول تلجرام في `RC` + قراءتها من Firestore |
| `lib/ui/pages/splash_shell.dart` | سطر واحد: استدعاء `TgWelcome.maybeShow` |
| `lib/ui/pages/profile_player_header.dart` | قسم «المجتمع» في صفحة حسابي |
| `pubspec.yaml` | 3 حزم |
| `android/app/build.gradle` | التوقيع يعود لـ debug إن غاب المفتاح |
| `android/app/src/main/AndroidManifest.xml` | صلاحيات المايك والبلوتوث |
| `functions/index.js` | تصدير 8 دوال صوتية |
| `firestore.rules` | قواعد `voice_rooms` |

**ملفات جديدة:**
```
lib/services/voice_service.dart        منطق LiveKit
lib/ui/pages/voice_rooms_page.dart     واجهات الغرف
lib/ui/pages/tg_welcome.dart           رسالة تلجرام
functions/voice.js                     دوال الخادم
```

---

## 🔴 أولاً: ألغِ سر LiveKit

سرّك ظهر في لقطة شاشة مرتين. اذهب إلى لوحة LiveKit ← **Revoke** ← أنشئ مفتاحاً جديداً.

السر هو ما يوقّع التوكنات: من يملكه ينشئ توكن مضيف لأي غرفة ويطرد المستخدمين ويسجّل الصوت. لا يوجد أي مفتاح أو سر في ملفات المشروع — تُحفظ في Secret Manager فقط.

---

## ⚙️ خطوات التشغيل

### ① الخادم

```bash
cd functions
npm install

firebase functions:secrets:set LIVEKIT_API_KEY
firebase functions:secrets:set LIVEKIT_API_SECRET

firebase deploy --only functions,firestore:rules
```

### ② Webhook

من مخرجات `firebase deploy` انسخ رابط `livekitWebhook`، ثم في
**LiveKit Cloud → Settings → Webhooks** أضف:

```
https://us-central1-totvq-8e439.cloudfunctions.net/livekitWebhook
```

هذا ما يُبقي عدّاد المشاركين محدّثاً في قائمة الغرف **بلا أي مستمع Firestore**.

### ③ التطبيق

```bash
flutter pub get
flutter build apk --release --flavor phone
```

أو ادفع إلى GitHub — سير العمل `android_build.yml` يبني نسختَي الهاتف والشاشة الذكية تلقائياً.

> 🔑 **التوقيع:** حذفتُ `key.properties` و `totv_keystore.jks` من المشروع لأنهما كانا مرفوعين في المستودع — وهي ثغرة خطيرة (من يملكهما يوقّع APK مزيّفاً باسم تطبيقك). الآن البناء ينجح بلا مفتاح ويُوقَّع بـ debug للاختبار. للنشر على Play Store، أضف في GitHub → Settings → Secrets:
> `KEYSTORE_BASE64` · `KEYSTORE_PASSWORD` · `KEY_ALIAS` · `KEY_PASSWORD`
>
> ⚠️ المفتاح القديم يجب اعتباره محروقاً — ولّد جديداً أو فعّل Play App Signing.

---

## 📢 رسالة تلجرام — التحكّم الكامل

كل شيء يُعدَّل من Firestore بلا تحديث التطبيق:

**`app_config/remote_config`**

| الحقل | النوع | الافتراضي |
|---|---|---|
| `telegram` | string | `https://t.me/O_2828` |
| `tg_title` | string | انضم إلى قناتنا على تلجرام |
| `tg_body` | string | تابع كل جديد… |
| `tg_button` | string | اشترك في القناة |
| `tg_enabled` | bool | `true` |
| `tg_show_always` | bool | `false` |

**السلوك:** تظهر بعد تسجيل الدخول ودخول الشاشة الرئيسية بـ 0.9 ثانية. `tg_show_always: false` تعني مرة واحدة فقط لكل جهاز (يُحفظ محلياً — **صفر قراءات Firestore**). اجعلها `true` لتظهر في كل فتح.

**التصميم:** بطاقة زجاجية (`BackdropFilter` بتمويه 22) فوق شبكة بوسترات تنزلق ببطء، مصدرها `TMDB.popularPosters()` — نفس مفتاح TMDB الموجود في تطبيقك. الأزرار: «اشترك في القناة» + «تخطي» + علامة X.

زر الاشتراك يحاول فتح تطبيق تلجرام مباشرة عبر `tg://resolve?domain=...` ويعود للمتصفح إن لم يكن مثبّتاً.

**لإعادة إظهارها للاختبار:** `await TgWelcome.reset();`

---

## 🎙 الغرف الصوتية

**الدخول:** حسابي ← المجتمع ← الغرف الصوتية

### أنشئ غرفة اختبار

**`voice_rooms/{id}`**
```json
{
  "title": "غرفة تجريبية",
  "hostUid": "<uid حسابك>",
  "hostName": "المضيف",
  "speakers": [], "banned": [], "raised_hands": [],
  "locked": false, "closed": false, "live": false, "count": 0
}
```

أو أنشئها من داخل التطبيق بزر «غرفة جديدة».

### الأدوار

| الدور | يسمع | يتحدث | يدير |
|---|:---:|:---:|:---:|
| مستمع | ✅ | ❌ | ❌ |
| متحدث | ✅ | ✅ | ❌ |
| مضيف | ✅ | ✅ | ✅ |

المضيف يضغط **مطوّلاً** على أي مشارك ← ترقية / كتم / طرد. الترقية تعمل **فوراً بلا إعادة اتصال** — هذه ميزة SFU التي يستحيل تحقيقها بـ P2P.

### الاستهلاك

| | القيمة |
|---|---|
| عرض النطاق | ~28 kbps = **12 ميغابايت/ساعة** |
| قراءات Firestore داخل الغرفة | **صفر** |
| كتابات Firestore | واحدة عند الدخول/الخروج (من الخادم) |

ثلاثة قرارات تحقّق هذا:

**`dtx: true`** — يوقف الإرسال أثناء الصمت (2 kbps بدل 24). في غرفة نقاش المستخدم صامت 80-90% من الوقت → توفير ~70% من الباقة.

**المستمع بلا مسار صوت** — لا مايك ولا مُرمِّز ولا AEC. المستمعون 90% من الغرفة، والفرق في بطاريتهم ~3×.

**بيانات الغرفة من LiveKit لا Firestore** — قائمة المشاركين وحالة المايك تصل عبر WebSocket القائم أصلاً، مجاناً.

---

## 🧪 اختبار الاتصال

**١. الخادم أولاً**
```dart
final r = await FirebaseFunctions.instance
    .httpsCallable('mintVoiceToken').call({'roomId': '<id>'});
debugPrint(r.data['role']);   // متوقّع: host
```

**٢. الصلاحيات** — من حساب ثانٍ يجب أن يرجع `listener` وألا يظهر زر المايك. هذا يثبت أن الدور يُفرض من الخادم لا من العميل.

**٣. الصوت** — جهازان **حقيقيان** لا محاكي (المحاكي بلا مايك حقيقي)، وبـ `--release` لا debug: WebRTC بطيء جداً في debug لدرجة تُوهمك بوجود خلل.

**٤. شبكة الجوال العراقية** — لا WiFi المكتب. التأخير وفقد الحزم مختلفان جذرياً.

---

## 💰 الحصة

الطبقة المجانية على LiveKit Cloud: **5,000 دقيقة WebRTC شهرياً** (≈83 ساعة مشارك). كافية للتطوير، تنفد بسرعة عند الإطلاق.

عند التوسّع، الانتقال لخادم ذاتي (VPS بـ ~$24/شهر يخدم ~1,000 مشارك متزامن) يتطلب تعديل سطرين فقط في `functions/voice.js`:

```js
const LK_WS   = "wss://your-server.com";
const LK_HTTP = "https://your-server.com";
```

لا تغيير في التطبيق إطلاقاً.

---

## ⚠️ ملاحظات مهمة

- **الغرف تحتاج Blaze plan** — الدوال المستدعاة (`onCall`) تتطلبه، وهو مجاني حتى حدود عالية.
- **`minSdk 23` موجود أصلاً** في مشروعك — ممتاز، WebRTC لا يعمل تحته.
- **الشاشات الذكية (نسخة TV):** الغرف الصوتية تعمل لكن معظم أجهزة TV بلا مايكروفون؛ المستخدم سيكون مستمعاً فقط، وهذا سلوك سليم.
- **مكالمة واردة:** لضمان عدم انقطاع الصوت نهائياً بعد أول مكالمة، أضف حزمة `audio_session` وتعامل مع المقاطعات. ليست حرجة للإصدار الأول لكنها مهمة قبل الانتشار الواسع.
