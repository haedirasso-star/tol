# TOTV+ — سجل التغييرات

الأحدث أولاً. كل الإصدارات في ملف واحد.

---

## TOTV+ v3.4.0+16 — المشغّل الاحترافي الجديد (محرّكان + مميزات نتفليكس/TOD)

```text
جديد:
  lib/ui/player/player_engine.dart   طبقة المحرّكات: السلس (ExoPlayer) + المتقدم (libmpv)
  lib/ui/player/player_prefs.dart    تفضيلات المشغّل + القنوات المفضلة/الأخيرة + علامات تخطي المقدمة
معدّل:
  lib/ui/player/pro_player.dart      المشغّل الاحترافي: نفس التصميم فوق المحرّكين + كل المميزات
  lib/ui/pages/home_pages.dart       قسم القنوات: «القنوات الناقلة» للمباراة + المفضلة + الأخيرة
                                     + ضغطة مطوّلة للمفضلة + تمرير قائمة القسم للمشغّل
  lib/ui/pages/sports_hub.dart       بطاقات المباريات ⇐ قسم القنوات (لا بث مباشر من البطاقة)
  lib/services/sports_feed.dart      SportsFeed.focusMatch
  lib/ui/pages/series_sports.dart    تمرير كل المواسم للمشغّل + قائمة قنوات الرياضة
  lib/core/constants.dart            PlayUrlCache.remove (إبطال الرابط الفاشل كان لا يعمل)
  lib/main.dart                      تسجيل الملفات الجديدة
  android/.../MainActivity.kt        صورة داخل صورة تلقائياً (setAutoPiP + onUserLeaveHint)
  firestore.rules                    skip_markers/{seriesId}: قراءة للجميع · كتابة للأدمن
  pubspec.yaml                       3.4.0+16
المحرك:
  • تلقائي: البث المباشر ⇐ السلس (نفس محرك المتصفح — لا تقطيع على HLS) · الأفلام والمسلسلات ⇐ المتقدم
  • فشل محرك في كل المصادر ⇐ تحويل تلقائي للمحرك الآخر قبل إظهار أي خطأ
  • المستخدم يستطيع الاختيار من الإعدادات (تلقائي / السلس / المتقدم)
  • الإدارة: remote_control.player_engine = pro (تلقائي) | native | mpv | legacy (المشغّل القديم للطوارئ)
  • المتقدم مع HLS: أُزيل reconnect_streamed (كان سبب التعليق) + بداية بهامش 3 مقاطع
التشغيل دائماً من سيرفر اشتراك المستخدم:
  • الروابط الاحتياطية تُبنى من Server.host + بيانات اشتراك المستخدم (لا RC.serverHost العام)
  • الرابط المحفوظ يُستخدم فقط إن كان من نفس سيرفر الاشتراك الحالي
  • بطاقات المباريات لم تعد تشغّل الروابط المثبّتة المباشرة (قناة التطبيق) — تنقل لقسم القنوات
  • قناة TOTV Live تبقى منفصلة ببطاقتها الخاصة فقط
بعد النسخ:
  1) flutter pub get  ثم البناء كالمعتاد
  2) firebase deploy --only firestore:rules   (لقاعدة skip_markers)
  3) بعد رفع النسخة للمتجر: لوحة الإدارة ← الإصدار ← min_version = 16 لإجبار التحديث
نسخة الآيفون (iOS):
  ios/                               مشروع Xcode كامل (قالب Flutter 3.29.3) — com.totv.plus · iOS 14+
  .github/workflows/ios_build.yml    بناء IPA على GitHub: غير موقّع دائماً + موقّع + TestFlight
  ios/ci/*.py                        ضبط Firebase والتوقيع تلقائياً أثناء البناء
  docs/IOS_BUILD_AR.md               الدليل الكامل + ما ينقص + مخاطر مراجعة أبل
  pro_player.dart                    iOS: روابط HLS أولاً للبث المباشر · صورة داخل صورة لأندرويد فقط
  profile_player.dart                iOS: منع تعطّل الدخول بجوجل قبل إعداد Firebase للآيفون
```

---

## TOTV+ v2.6.0+8 — المشغّل الاحترافي الجديد (Pro Player)

```text
جديد:
  lib/ui/player/pro_player.dart   المشغّل الجديد بالكامل على محرك libmpv (media_kit)
معدّل:
  lib/ui/pages/profile_player.dart  المشغّل القديم صار LegacyPlayerPage (احتياط فقط)
  lib/core/constants.dart           مفتاح player_engine (pro/legacy) من remote_control — فوري
  lib/main.dart                     تهيئة المحرك + الاستيرادات
  pubspec.yaml                      media_kit + media_kit_video + media_kit_libs_video
                                    + screen_brightness_platform_interface + volume_controller
بعد النسخ: flutter pub get
تطبيق الإدارة: pages/app_control.dart ← مفتاح «المشغّل الاحترافي الجديد» (للطوارئ)
```

---

## TOTV+ v2.5.0+7 — الملفات المعدّلة (انسخها فوق مشروعك بنفس المسارات)

```text
جديد:
  lib/ui/pages/match_page.dart     صفحة المباراة بأسلوب TOD (بوستر، شعاران، عدّاد، التاريخ والملعب والبطولة،
                                   منطقة المشجعين، اشتراك/شاهد، توقّع واربح، إحصائيات المباراة)
  lib/ui/pages/engage_pages.dart   «الرسائل» (محادثة مع الإدارة أبيض/أسود) + «ادعُ صديقك واربح 16 يوماً»
  lib/services/engage.dart         التوقعات والدعوات والمحادثة عبر دالة push (بلا مفاتيح سرية)
معدّل:
  lib/ui/pages/sports_hub.dart     الضغط على بطاقة المباراة أو إعلانها يفتح صفحة المباراة
  lib/services/notif_app.dart      إشعار الطلب للإدارة: 3 محاولات + لا يحتاج توكن · قناة رسائل لكل مستخدم · فتح المحادثة من الإشعار
  lib/ui/pages/profile_player_header.dart   «الرسائل» مع عدد غير المقروء + «ادعُ صديقك»
  lib/ui/pages/splash_shell.dart   ربط قناة الرسائل بعد الدخول
  lib/main.dart                    تسجيل الملفات الجديدة + عدّاد الرسائل والتطبيق مغلق
  pubspec.yaml                     الإصدار 2.5.0+7 (بلا مكتبات جديدة)
بعد النسخ: flutter pub get
```

---

## TOTV+ v2.4.0+6 — الملفات المعدّلة (انسخها فوق مشروعك بنفس المسارات)

```text
يشمل أيضاً كل ملفات v2.3 (لا ضرر من إعادة نسخها).
جديد:
  lib/ui/pages/content_detail.dart   صفحة الفيلم/المسلسل بأسلوب TOD + الإعلان يعمل فوراً + «قائمتي»
  lib/ui/pages/subscribe_flow.dart   خطوات الاشتراك: الباقة ← الدفع ← الاسم ← التحويل والإيصال ← تتبّع/شكوى
  lib/services/downloads.dart        خدمة التنزيل (استئناف + تنزيلان معاً)
  lib/ui/pages/downloads_page.dart   قائمة التنزيلات + مشغّل بلا إنترنت
معدّل:
  lib/ui/pages/profile_player_header.dart   صفحة «المزيد» بأسلوب TOD
  lib/ui/pages/home_pages.dart       الرئيسية: مباريات + أحدث/أعلى تقييماً + تصنيفات المسلسلات، إصلاح «تابع ما بدأت»
  lib/ui/pages/series_sports.dart    زر تنزيل لكل حلقة + حفظ صورة المسلسل في «تابع ما بدأت»
  lib/ui/pages/payment_sheet.dart    كل أزرار «اشترك» ← الخطوات الجديدة
  lib/core/constants.dart            محتوى العرض لغير المشتركين + إصلاح صور «تابع ما بدأت» + تخفيف كتابات Firestore
  lib/services/smart_content_service.dart   فصل كاش العرض عن كاش المشترك
  lib/services/notif_app.dart        مفتاح تشغيل/إيقاف إشعارات المباريات
  lib/main.dart, pubspec.yaml        path_provider + الملفات الجديدة — الإصدار 2.4.0+6
بعد النسخ: flutter pub get
```

---

## TOTV+ v2.3.0+5 — الملفات المعدّلة فقط (انسخها فوق مشروعك بنفس المسارات)

```text
lib/services/sports_feed.dart        مباريات الأسبوع + ألوان الأندية + إعلانات المباريات + الحالة بالوقت (بلا نتائج)
lib/ui/pages/sports_hub.dart         بطاقات TOD + عدّاد تنازلي + شريط الإعلانات + «تُلعب الآن/اليوم/الغد/الأيام»
lib/ui/pages/home_pages.dart         إعلانات المباريات داخل شريط الإعلانات + «أفضل مباريات الأسبوع» + إصلاح تشغيل الإعلان المتحرّك
lib/ui/widgets/tmdb_hero_video_banner.dart   إصلاح يوتيوب (Error 152/153)
lib/services/notif_app.dart          إصلاح أيقونة الإشعارات + قناة «صافرة البداية»
lib/stub/notif_stub.dart             توافق
pubspec.yaml                         الإصدار 2.3.0+5
android/app/src/main/AndroidManifest.xml          بانر التلفاز
android/app/src/main/res/mipmap-*/                أيقونة التطبيق الجديدة (T)
android/app/src/main/res/drawable/ic_notification.xml   أيقونة الإشعار (T)
android/app/src/main/res/drawable-xhdpi/tv_banner.png   بانر Android TV
android/app/src/main/res/raw/whistle.wav          صوت صافرة الحكم
android/app/src/main/res/raw/keep.xml             منع حذف الأصوات
```

---

## TOTV+ v2.2.0+4

```text
جديد:
  lib/services/sports_feed.dart     (قراءة خلاصة المباريات + مطابقة القناة الناقلة)
  lib/ui/pages/sports_hub.dart      (صفحة رياضة: المباريات + القنوات المباشرة)
  sports_feed/                      (الخادم المجاني: GitHub Actions — ارفعه لمستودع مستقل، انظر README بداخله)
معدّل:
  lib/ui/pages/profile_gate.dart    («من يشاهد الآن؟» أسود/أبيض + مربع تلجرام + زر الدخول)
  lib/ui/pages/splash_shell.dart    (شريط سفلي: الرئيسية/بحث/المزيد + أقسام علوية + زر الرجوع + إصلاح قائمة TV)
  lib/ui/pages/home_pages.dart      (الأقسام العلوية فوق البانر)
  lib/ui/pages/actor_login.dart     (اتجاه عربي صحيح للجمل المختلطة Google / TOTV+ / F1)
  lib/services/notif_app.dart       (اشتراك topic matches + فتح «رياضة» من الإشعار)
  lib/core/constants.dart           (sports_feed في remote_config)
  lib/main.dart, pubspec.yaml       (font_awesome_flutter لشعار تلجرام)
بعد الفك: flutter pub get
```

---

## TOTV+ v2.1.0+3 — الملفات المعدّلة/الجديدة

```text
جديد:
  lib/ui/widgets/tmdb_hero_video_banner.dart   (TmdbTrailerService + TmdbHeroVideoBanner + HeroTrailerPlayer + زر الكتم)
  assets/login/slide_1.jpg  slide_2.jpg  slide_3.jpg   (الشرائح الإعلانية)
  assets/images/brand_t.png                            (شعار T شفاف)
معدّل:
  pubspec.yaml                       (youtube_player_iframe ^5.0.0 + الأصول + الإصدار)
  lib/main.dart                      (import + part + navigatorObservers + إصلاحات v2)
  lib/ui/pages/actor_login.dart      (واجهة الدخول الجديدة)
  lib/ui/pages/home_pages.dart       (تشغيل التريلر في بانر الرئيسية)
  lib/ui/pages/splash_shell.dart     (تتبّع التبويب لإيقاف التريلر)
  lib/services/tmdb.dart             (إصلاح خطأ \$ الذي منع جلب التريلرات)
  lib/core/constants.dart            (SelfHeal + إعادة المحاولة — من v2)
  lib/services/activation.dart       (إعادة محاولة الاستعادة — من v2)
  lib/ui/pages/profile_player.dart   (إصلاح المشغّل — من v2)
بعد الفك:  flutter pub get  ثم  flutter run
ملاحظة: ملف التوقيع totv_keystore.jks و key.properties غير مضمّنين — استخدم نسختك.
```
