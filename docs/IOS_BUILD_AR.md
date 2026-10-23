# TOTV+ — بناء نسخة الآيفون عبر GitHub

## ما الذي أُضيف للمشروع

| الملف | الوظيفة |
|---|---|
| `ios/` | مشروع Xcode كامل (من قالب Flutter 3.29.3 الرسمي) — المعرّف `com.totv.plus`، iOS 14+، الأيقونات، شاشة البداية السوداء |
| `ios/Runner/Info.plist` | السماح بروابط http (سيرفرات IPTV) · أذونات الصور والكاميرا · الإشعارات · واتساب/تلغرام |
| `ios/Runner/Runner.entitlements` | الإشعارات (Push) |
| `ios/ci/configure_firebase.py` | يضبط Firebase وتسجيل الدخول بجوجل تلقائياً من `GoogleService-Info.plist` |
| `ios/ci/set_signing.py` | التوقيع اليدوي أثناء البناء |
| `.github/workflows/ios_build.yml` | البناء على GitHub (جهاز Mac سحابي) |

---

## 1) أول بناء — بدون أي إعداد (نسخة تجربة غير موقّعة)

1. ارفع المشروع إلى مستودع GitHub.
2. افتح **Actions** ← **TOTV+ Build — iOS (IPA)** ← **Run workflow**.
3. بعد انتهاء البناء (حوالي 20–30 دقيقة) حمّل **TOTV-iOS-unsigned** من أسفل صفحة التشغيل.

### تثبيت النسخة غير الموقّعة على آيفونك للتجربة
- حمّل برنامج **Sideloadly** على ويندوز أو ماك، ووصّل الآيفون بالكابل.
- اسحب ملف `TOTV-iOS-unsigned.ipa` إليه وسجّل بحساب Apple ID (حتى المجاني).
- على الآيفون: الإعدادات ← عام ← VPN وإدارة الجهاز ← ثق بالمطوّر.
- بالحساب المجاني: تعمل النسخة **7 أيام** ثم تعيد التثبيت. الإشعارات لا تعمل في هذه الطريقة.
- بديل: أي «شهادة خاصة» (شهادة مطوّر مدفوعة) يمكنها توقيع نفس الملف.

> ⚠️ دقائق أجهزة macOS على GitHub تُحتسب ×10 للمستودعات الخاصة. البناء لا يعمل إلا يدوياً
> (أو عند وسم `ios-v*`) كي لا يستهلك رصيدك.

---

## 2) ما ينقص لإكمال نسخة المتجر / TestFlight

### أ) حساب Apple Developer (إلزامي — 99$ سنوياً)
سجّل من developer.apple.com/programs. بدونه لا يمكن الرفع للمتجر ولا TestFlight.

### ب) معرّف التطبيق App ID
developer.apple.com ← Certificates, IDs & Profiles ← Identifiers ← **+** ← App IDs:
- Bundle ID: **`com.totv.plus`** (Explicit)
- فعّل **Push Notifications**

### ج) شهادة التوزيع (Apple Distribution) — بدون جهاز Mac
على أي جهاز فيه OpenSSL (لينكس، أو Git Bash على ويندوز):
```bash
openssl genrsa -out totv.key 2048
openssl req -new -key totv.key -out totv.csr -subj "/emailAddress=haedirasso@gmail.com/CN=TOTV Plus/C=IQ"
```
ارفع `totv.csr` في: Certificates ← **+** ← **Apple Distribution**، ثم حمّل `distribution.cer` وحوّله:
```bash
openssl x509 -in distribution.cer -inform DER -out distribution.pem -outform PEM
openssl pkcs12 -export -legacy -inkey totv.key -in distribution.pem -out totv_dist.p12
```
(اختر كلمة مرور — ستحتاجها. خيار `-legacy` ضروري كي يقبله ماك.)
**احتفظ بـ `totv.key` و`totv_dist.p12` في مكان آمن.**

### د) ملف التوفير (Provisioning Profile)
Profiles ← **+** ← **App Store Connect** (للمتجر وTestFlight) أو **Ad Hoc** (لأجهزة محددة بأرقامها UDID)
← اختر App ID `com.totv.plus` ← الشهادة ← حمّل ملف `.mobileprovision`.

### هـ) Firebase للآيفون (لتسجيل الدخول بجوجل والإشعارات)
1. Firebase Console ← مشروع `totvq-8e439` ← Add app ← **iOS** ← Bundle ID: `com.totv.plus`.
2. حمّل **`GoogleService-Info.plist`** (البناء يضبط كل شيء منه تلقائياً).
3. Authentication ← Sign-in method ← تأكد أن Google مفعّل، ثم أعد تحميل الملف إن تغيّر.
4. للإشعارات: Apple Developer ← Keys ← **+** ← Apple Push Notifications service (APNs) ← حمّل ملف `.p8`،
   ثم Firebase ← Project settings ← Cloud Messaging ← iOS app ← ارفع مفتاح APNs (مع Key ID وTeam ID).

> بدون هذا الملف: التطبيق يعمل، لكن زر «الدخول بجوجل» يعرض رسالة «غير مفعّل بعد في نسخة الآيفون»
> (بدلاً من أن يتعطّل التطبيق)، والإشعارات لا تصل.

### و) App Store Connect
1. appstoreconnect.apple.com ← Apps ← **+** ← New App ← Bundle ID `com.totv.plus`، الاسم TOTV+.
2. للرفع التلقائي إلى TestFlight: Users and Access ← Integrations ← App Store Connect API ← **+** (صلاحية App Manager)
   ← حمّل `AuthKey_XXXX.p8` واحفظ **Key ID** و**Issuer ID**.

### ز) أسرار GitHub (Settings ← Secrets and variables ← Actions ← New repository secret)

| الاسم | القيمة |
|---|---|
| `IOS_DIST_CERT_P12_BASE64` | محتوى `totv_dist.p12` بصيغة base64 |
| `IOS_DIST_CERT_PASSWORD` | كلمة مرور ملف p12 |
| `IOS_PROVISION_PROFILE_BASE64` | محتوى `.mobileprovision` بصيغة base64 |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | محتوى `GoogleService-Info.plist` بصيغة base64 |
| `APPSTORE_API_KEY_ID` | Key ID (للرفع إلى TestFlight) |
| `APPSTORE_API_ISSUER_ID` | Issuer ID |
| `APPSTORE_API_PRIVATE_KEY` | نص ملف `AuthKey_XXXX.p8` كاملاً (كما هو، ليس base64) |

**تحويل ملف إلى base64:**
- ماك/لينكس: `base64 -i totv_dist.p12 | tr -d '\n'`
- ويندوز PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("totv_dist.p12"))`

### ح) التشغيل
Actions ← iOS ← Run workflow ← اختر `app-store` وفعّل **upload_testflight** ← يظهر البناء في TestFlight بعد معالجة أبل (15–30 دقيقة).
**رقم البناء يجب أن يزيد مع كل رفع** — اكتبه في خانة `build_number` (مثلاً 17، 18…) أو ارفع الرقم في pubspec.

### ط) صفحة المتجر
لقطات شاشة (6.7 إنش و5.5 إنش، وiPad إن دعمته)، وصف، **رابط سياسة الخصوصية** (إلزامي)، تصنيف العمر،
وحساب تجربة يعمل للمراجِع (اسم مستخدم وكلمة مرور فيهما اشتراك فعّال).

---

## 3) ⚠️ مخاطر مراجعة أبل — اقرأها قبل الرفع

أبل أشد بكثير من Google Play. هذه أسباب رفض متوقعة لتطبيقكم كما هو الآن:

1. **الدفع خارج المتجر (البند 3.1.1):** بيع الاشتراكات داخل التطبيق عبر زين كاش / آسيا سيل / FIB / كي كارد
   ممنوع للمحتوى الرقمي — أبل تشترط **In-App Purchase** (بعمولة 15–30%). الحلول: إخفاء صفحات الدفع والشراء
   في نسخة iOS وجعلها «تسجيل دخول فقط» لمن اشترك خارج التطبيق (نموذج «Reader app»)، أو إضافة In-App Purchase.
2. **حقوق المحتوى (البند 5.2):** تطبيقات IPTV التي تعرض قنوات مثل beIN بدون إثبات ترخيص تُرفض غالباً،
   وقد يُطلب منك إثبات حقوق البث. TestFlight الخارجي يمرّ بمراجعة أخف لكنها موجودة أيضاً.
3. **تسجيل الدخول (البند 4.8):** وجود «الدخول بجوجل» قد يجعل أبل تطلب **Sign in with Apple** أيضاً.
4. **الروابط http:** مسموحة، لكن أبل قد تسأل عن السبب — الجواب: «سيرفرات البث لدى مزوّدي IPTV لا تدعم HTTPS».

**للتجربة الداخلية:** TestFlight الداخلي (حتى 100 شخص من فريقك في App Store Connect) **لا يحتاج مراجعة** —
مناسب جداً لتجربة التطبيق قبل التفكير في النشر العام. والنسخة غير الموقّعة عبر Sideloadly لا تحتاج أي شيء.

---

## 4) ملاحظات تقنية عن نسخة الآيفون
- **البث المباشر** يعمل بمشغّل أبل الأصلي، والتطبيق يقدّم روابط HLS (m3u8) تلقائياً لأن أبل لا يشغّل بث TS المستمر.
- **الأفلام والمسلسلات** (MKV وغيرها) تعمل بالمحرك المتقدم (mpv) كما في أندرويد.
- **صورة داخل صورة** غير متاحة في الآيفون حالياً (أزرارها مخفية هناك).
- **أصوات الإشعارات الخاصة** (صافرة المباراة) تعمل في أندرويد؛ في الآيفون يُستخدم صوت الإشعار الافتراضي.
- لا يمكن تجربة البناء محلياً دون جهاز Mac — GitHub Actions هو جهاز الماك هنا.
