// ════════════════════════════════════════════════════════════════
//  TOTV+ — main.dart  v5 — Zero-Crash Startup
//
//  ترتيب التهيئة الصحيح (يمنع Crash + ANR):
//  1. WidgetsFlutterBinding      ← يجب أن يكون السطر الأول
//  2. Error Handlers             ← يلتقط أي خطأ لاحق
//  3. SystemChrome               ← مظهر شريط الحالة
//  4. SharedPreferences          ← cache محلي سريع
//  5. AppVersion                 ← قراءة إصدار التطبيق
//  6. (لا إعلانات — نظام اشتراكات فقط)
//  7. Firebase.initializeApp()   ← قبل runApp لمنع Firestore crash
//  8. runApp()                   ← الـ UI يظهر فوراً
//  9. Background services        ← كل شيء ثقيل بعد الـ UI
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io' as io;
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, defaultTargetPlatform, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
// ★ المشغّل الاحترافي: libmpv (بادئة mk/mkv لتجنّب تعارض الأسماء مع audioplayers وغيرها)
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart' show ScreenBrightnessPlatform;
import 'package:volume_controller/volume_controller.dart' show VolumeController;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'stub/notif_stub.dart';
import 'package:shimmer/shimmer.dart';
// ★ الإعلان المتحرّك (YouTube IFrame الرسمي) — بادئة yt لتفادي تعارض PlayerState مع audioplayers
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'core/supa_config.dart';
part 'core/constants.dart';
part 'services/tmdb.dart';
part 'services/app_state.dart';
part 'services/notif_app.dart';
part 'services/smart_content_service.dart';
part 'services/supa.dart';
part 'services/activation.dart';
part 'services/sports_feed.dart';
part 'services/engage.dart';
part 'services/downloads.dart';
part 'ui/widgets/tmdb_hero_video_banner.dart';
part 'ui/pages/splash_shell.dart';
part 'ui/pages/home_pages.dart';
part 'ui/pages/series_sports.dart';
part 'ui/pages/sports_hub.dart';
part 'ui/pages/match_page.dart';
part 'ui/pages/engage_pages.dart';
part 'ui/player/pro_player.dart';
part 'ui/pages/content_detail.dart';
part 'ui/pages/subscribe_flow.dart';
part 'ui/pages/downloads_page.dart';
part 'ui/pages/profile_player.dart';
part 'ui/pages/profile_player_header.dart';
part 'ui/pages/actor_login.dart';
part 'ui/pages/admin_page.dart';
part 'ui/pages/admin_console.dart';
part 'ui/pages/admin_credit.dart';
part 'ui/pages/admin_user_detail.dart';
part 'ui/pages/payment_sheet.dart';
part 'ui/pages/vip_login.dart';
part 'ui/pages/redeem_code.dart';
part 'ui/pages/profile_gate.dart';

// ════════════════════════════════════════════════════════════════
//  Firebase background message handler
//  @pragma vm:entry-point — ضروري لمنع tree-shaking
// ════════════════════════════════════════════════════════════════
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) { debugPrint('[bg_msg] $e'); }
  // رسالة جديدة من الإدارة والتطبيق مغلق ⇐ نقطة «غير مقروء» على «الرسائل»
  if (message.data['type'] == 'chat') {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(ChatInbox.kUnread, (p.getInt(ChatInbox.kUnread) ?? 0) + 1);
    } catch (_) {}
  }
}

// ════════════════════════════════════════════════════════════════
//  main() — Zero-Crash Startup
// ════════════════════════════════════════════════════════════════
Future<void> main() async {

  // ══ 1. WidgetsBinding — يجب أن يكون أول سطر قابل للتنفيذ ══════
  WidgetsFlutterBinding.ensureInitialized();

  // ══ المشغّل الاحترافي (libmpv) — إن فشل يعمل المشغّل القديم تلقائياً ══
  try { mk.MediaKit.ensureInitialized(); } catch (e) { ProPlayer.engineFailed = true; debugPrint('[media_kit] $e'); }

  // ══ تحسين الأداء: حدّ ذاكرة الصور (أخف على المعالج والذاكرة) ══
  // بدون هذا الحدّ قد تمتلئ الذاكرة بآلاف البوسترات فيبطئ التطبيق.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 80 * 1024 * 1024; // 80MB
  PaintingBinding.instance.imageCache.maximumSize = 150; // عدد الصور المخزّنة


  // ══ 2. Error Handlers ══════════════════════════════════════════
  // يلتقط أخطاء Flutter framework (مشاكل الـ Widget tree)
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[Flutter] ${details.exception}\n${details.stack}');
    // ★ v2: سجّل الخطأ في طبقة التعافي، وحاول إصلاحاً ذاتياً عند تكراره
    try {
      SelfHeal.report(details.exception, where: 'framework');
      if (SelfHeal.isStruggling) unawaited(SelfHeal.repair());
    } catch (_) {}
    if (kDebugMode) FlutterError.presentError(details);
  };

  // يلتقط الأخطاء غير المتزامنة في الـ Isolate الرئيسي
  // يمنع crash في Android 12+ عند خطأ GPU أو Platform Thread
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[Platform] $error');
    try {
      SelfHeal.report(error, where: 'platform');
      if (SelfHeal.isStruggling) unawaited(SelfHeal.repair());
    } catch (_) {}
    return true; // true = الخطأ تمت معالجته، لا crash
  };

  // يُخصص واجهة مخصصة عند حدوث خطأ في الـ Widget tree
  // ★ v2: شاشة خطأ تُصلح نفسها فعلاً.
  //   القديمة كانت تكتب «اضغط للإعادة» بلا أي زر يعمل — نص ميّت.
  ErrorWidget.builder = (FlutterErrorDetails details) =>
      const _RecoverableError();

  // ══ 3. SystemChrome ════════════════════════════════════════════
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                   Colors.transparent,
    statusBarIconBrightness:          Brightness.light,
    systemNavigationBarColor:         Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // ══ 4. SharedPreferences ══════════════════════════════════════
  try { await SPref.preload(); }
  catch (e) { debugPrint('[main] SPref: $e'); }

  // ★ تحميل الهوست العام المحفوظ محلياً (يعمل حتى لو Firebase معطّل)
  try { await GlobalHost.load(); }
  catch (e) { debugPrint('[main] GlobalHost: $e'); }

  // ══ 5. AppVersion ══════════════════════════════════════════════
  try { await AppVersion.init(); }
  catch (e) { debugPrint('[main] AppVersion: $e'); }

  // ══ 6. (أُزيلت الإعلانات — يعتمد التطبيق على الاشتراكات فقط) ═══════

  // ══ 7. Firebase ════════════════════════════════════════════════
  bool firebaseOk = false;
  try {
    // محاولة استخدام instance موجود أولاً (أسرع)
    Firebase.app();
    firebaseOk = true;
  } catch (_) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10));
      firebaseOk = true;
    } catch (e) { debugPrint('[main] Firebase (non-fatal): $e'); }
  }

  // ══ كشف TV قبل بناء الواجهة (ليعمل تخطيط التلفاز من أول إطار) ══
  try { await TVLayout.detect(); } catch (_) {}

  // ══ 8. runApp — الـ UI يظهر فوراً ════════════════════════════
  runApp(const App());

  // ══ 9. Background services — بعد أول frame ════════════════════
  // scheduleMicrotask يضمن اكتمال بناء الـ Widget tree أولاً
  scheduleMicrotask(() => _initBackgroundServices(firebaseOk));
}

/// تهيئة الخدمات الثقيلة في الخلفية بعد ظهور الـ UI
void _initBackgroundServices(bool firebaseOk) {
  Future.microtask(() async {

    // SharedPrefs singleton — للقراءة السريعة لاحقاً
    try { await SharedPrefs.init(); } catch (_) {}

    if (firebaseOk) {
      // FCM background handler
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (_) {}

      // ★ Remote Config — delay 500ms to let UI fully render first
    // Prevents Firestore WebSocket connections from competing with UI rendering
    Future.delayed(const Duration(milliseconds: 500), () {
      unawaited(RC.init().catchError((e) => debugPrint('[RC] $e')));
    });

      // الإشعارات المحلية
      unawaited(NotifService.init().catchError((e) => debugPrint('[Notif] $e')));

      // إذن الإشعارات على Android 13+
      unawaited(_requestNotifPermission());

      // خدمات المستخدم المسجَّل
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          unawaited(Future(() => AuthService.startAdminListener(uid)));
          unawaited(Future(() => UserDataWatcher.startListening(uid)));
          // ★ استعادة الاشتراك من Supabase (استدعاء واحد بدل 5 قراءات Firestore)
          unawaited(ActivationService.restoreFromCloud(uid: uid)
              .catchError((e) { debugPrint('[supa restore] $e'); return false; }));
        }
      } catch (_) {}
    }

    // كاش محلي
    unawaited(PlayUrlCache.load().catchError((_) {}));
    unawaited(SmartPosterCache.loadFromDisk().catchError((_) {}));
    unawaited(WatchHistory.ensureLoaded().catchError((_) {}));
  });
}

/// طلب إذن الإشعارات على Android 13+ (API 33)
Future<void> _requestNotifPermission() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  } catch (e) { debugPrint('[notif_perm] $e'); }
}

// ════════════════════════════════════════════════════════════════
//  App Widget
// ════════════════════════════════════════════════════════════════
// ★ مفتاح تنقّل عام — لعرض حوارات من أي مكان (إشعار التفعيل داخل التطبيق)
final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();

// ★ حوار "تم تفعيل اشتراكك" مع تعليمات إعادة التشغيل
void showActivationDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF0E0E13),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: C.gold.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 92, height: 92,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.gold.withOpacity(0.18), C.gold.withOpacity(0.04)]),
              shape: BoxShape.circle,
              border: Border.all(color: C.gold.withOpacity(0.5), width: 2),
              boxShadow: [BoxShadow(color: C.gold.withOpacity(0.3), blurRadius: 26, spreadRadius: 1)]),
            child: Padding(padding: const EdgeInsets.all(18),
              child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 36))))),
          const SizedBox(height: 16),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_rounded, color: C.green, size: 20),
            const SizedBox(width: 7),
            Text('تم تفعيل اشتراكك', style: T.cairo(s: FS.xl, w: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          Text('اشتراكك فعّال الآن في TOTV+ 🎉\n\n'
               'لتحميل القنوات والأفلام: أطفئ الهاتف وأعد تشغيله، '
               'ثم افتح التطبيق مرة أخرى.\n\n'
               'إن لم يظهر المحتوى، قدّم شكوى من صفحة الشكاوى.',
              textAlign: TextAlign.center,
              style: T.cairo(s: FS.sm, c: C.textSec, h: 1.7)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Container(height: 50, width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFE27A), C.gold]),
                borderRadius: BorderRadius.circular(R.md)),
              child: Center(child: Text('حسناً، فهمت',
                  style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black))))),
          const SizedBox(height: 9),
          GestureDetector(
            onTap: () { Navigator.of(ctx).pop(); ComplaintSheet.show(context); },
            child: Text('لم يظهر المحتوى؟ قدّم شكوى',
                style: T.cairo(s: FS.sm, c: C.gold, w: FontWeight.w700))),
        ]),
      ),
    ),
  );
}

// ★ حوار رسالة من الإدارة
void showAdminMessageDialog(BuildContext context, String title, String body) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: const Color(0xFF0E0E13),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: C.gold.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(
              color: C.gold.withOpacity(0.12), shape: BoxShape.circle,
              border: Border.all(color: C.gold.withOpacity(0.4))),
            child: const Icon(Icons.campaign_rounded, color: C.gold, size: 28)),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center,
              style: T.cairo(s: FS.lg, w: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(body, textAlign: TextAlign.center,
              style: T.cairo(s: FS.sm, c: C.textSec, h: 1.6)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Container(height: 48, width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFE27A), C.gold]),
                borderRadius: BorderRadius.circular(R.md)),
              child: Center(child: Text('حسناً',
                  style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black))))),
        ]),
      ),
    ),
  );
}

class App extends StatefulWidget {
  const App();
  @override State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    RC.onConfigChanged = () {
      if (!mounted) return;
      setState(() {});
      // النظام الجديد: حمّل من سيرفر المستخدم الخاص فقط
      if (AppState.allMovies.isEmpty && Sub.hasServer) {
        unawaited(AppState.loadAll());
      }
    };
    RC.onVersionChanged = () { if (mounted) setState(() {}); };
    // ★ إشعار التفعيل داخل التطبيق عند تحويل الأدمن لبريميوم
    UserDataWatcher.setOnActivated(() {
      Sound.check(); // ★ صوت علامة الصح عند التفعيل
      // تحديث كل الأقسام تلقائياً فور التفعيل (يمنع مشاكل التفعيل/تحميل المحتوى)
      try {
        ListCache.invalidate();
        if (Sub.hasServer) {
          unawaited(AppState.loadAll(force: true).then((_) {
            if (mounted) setState(() {});
          }).catchError((_) {}));
        }
      } catch (_) {}
      if (mounted) setState(() {});
      final ctx = rootNavKey.currentContext;
      if (ctx != null) showActivationDialog(ctx);
    });
    // ★ رسالة مباشرة من الأدمن → حوار داخل التطبيق
    UserDataWatcher.setOnAdminMessage((title, body) {
      final ctx = rootNavKey.currentContext;
      if (ctx != null) showAdminMessageDialog(ctx, title, body);
    });
  }

  @override
  void dispose() { RC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                   'TOTV+',
      navigatorKey:            rootNavKey,
      navigatorObservers:      [kRouteObserver],   // ★ يوقف الإعلان عند فتح صفحة فوقه
      debugShowCheckedModeBanner: false,
      // ★ يلتقط أخطاء الـ Widget tree ويعرض شاشة آمنة
      builder: (ctx, child) => _AppErrorBoundary(child: child ?? const SizedBox()),
      theme: ThemeData(
        brightness:              Brightness.dark,
        useMaterial3:            true,
        scaffoldBackgroundColor: C.bg,
        colorScheme: ColorScheme.dark(
          primary:                 C.gold,
          secondary:               C.goldDim,
          surface:                 C.surface,
          onSurface:               Colors.white,
          surfaceContainerHighest: C.card,
        ),
        fontFamily:       GoogleFonts.cairo().fontFamily,
        textTheme:        GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        splashFactory:    InkRipple.splashFactory,
        highlightColor:   Colors.transparent,
        splashColor:      const Color(0x0FFFD740),
        appBarTheme: const AppBarTheme(
          backgroundColor:        Colors.transparent,
          elevation:               0,
          scrolledUnderElevation:  0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor:           Colors.transparent,
            statusBarIconBrightness:  Brightness.light,
            systemNavigationBarColor: Colors.transparent,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      routes: {
        '/login': (_) => const FirebaseLoginPage(),
        '/admin': (_) => const AdminWebPage(),
        '/ops': (_) => const AdminConsolePage(),
      },
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (RC.needsUpdate)  return _UpdateGatePage();
    if (RC.locked)       return _LockPage(RC.lockMsg);
    if (RC.maintenance)  return _MaintenancePage(RC.maintMsg);
    return const Splash();
  }
}

// ════════════════════════════════════════════════════════════════
//  AppErrorBoundary — يعترض أخطاء الـ Widget tree
// ════════════════════════════════════════════════════════════════
class _AppErrorBoundary extends StatefulWidget {
  final Widget child;
  const _AppErrorBoundary({required this.child});
  @override State<_AppErrorBoundary> createState() => _AppErrorBoundaryState();
}

class _AppErrorBoundaryState extends State<_AppErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorScreen(
        error:   _error!,
        onRetry: () => setState(() => _error = null),
      );
    }
    return widget.child;
  }
}

// ════════════════════════════════════════════════════════════════
//  AppErrorHandler
// ════════════════════════════════════════════════════════════════
class AppErrorHandler {
  static final List<_ErrorLog> _logs = [];
  static const int _maxLogs = 50;

  static void report(Object error, StackTrace? stack, {String context = ''}) {
    _logs.insert(0, _ErrorLog(
      error:   error.toString(),
      context: context,
      stack:   stack?.toString().split('\n').take(5).join('\n') ?? '',
      time:    DateTime.now(),
    ));
    if (_logs.length > _maxLogs) _logs.removeLast();
    debugPrint('[ERR][$context] $error');
  }

  static List<_ErrorLog> get logs => List.unmodifiable(_logs);
  static void clear() => _logs.clear();

  static String userFriendlyMessage(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') || msg.contains('network'))
      return 'تعذّر الاتصال بالإنترنت. تحقق من اتصالك وأعد المحاولة.';
    if (msg.contains('timeout'))
      return 'انتهت مهلة الاتصال. السيرفر بطيء — حاول لاحقاً.';
    if (msg.contains('401') || msg.contains('unauthorized'))
      return 'بيانات الدخول غير صحيحة.';
    if (msg.contains('firebase') || msg.contains('firestore'))
      return 'مشكلة في الاتصال بقاعدة البيانات.';
    return 'حدث خطأ غير متوقع. اضغط "إعادة المحاولة".';
  }
}

class _ErrorLog {
  final String error, context, stack;
  final DateTime time;
  const _ErrorLog({
    required this.error, required this.context,
    required this.stack, required this.time,
  });
}

// ════════════════════════════════════════════════════════════════
//  _ErrorScreen — شاشة الخطأ الاحترافية (Gold & Black)
// ════════════════════════════════════════════════════════════════
class _ErrorScreen extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final msg = AppErrorHandler.userFriendlyMessage(error);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color:  const Color(0x1AE05252),
                  shape:  BoxShape.circle,
                  border: Border.all(color: const Color(0x4DE05252), width: 2),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFE05252), size: 40),
              ),
              const SizedBox(height: 24),
              Text('حدث خطأ في التطبيق',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 12),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                      fontSize: 13, color: Colors.white60)),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFF5A623), Color(0xFFB07A18)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('إعادة المحاولة',
                        style: GoogleFonts.cairo(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: Colors.black)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  final wa = RC.whatsapp;
                  if (wa.isNotEmpty) {
                    launchUrl(Uri.parse('https://wa.me/$wa'),
                        mode: LaunchMode.externalApplication);
                  }
                },
                child: Text('تواصل مع الدعم',
                    style: GoogleFonts.cairo(
                        fontSize: 13, color: const Color(0xFF25D366))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  ★ v2 — شاشة الخطأ القابلة للتعافي
//  تحاول الإصلاح تلقائياً أولاً، فإن فشلت تعرض أزراراً تعمل فعلاً.
// ════════════════════════════════════════════════════════════════
class _RecoverableError extends StatefulWidget {
  const _RecoverableError();
  @override State<_RecoverableError> createState() => _RecoverableErrorState();
}

class _RecoverableErrorState extends State<_RecoverableError> {
  bool _trying = true;
  int  _secs   = 3;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    // محاولة إصلاح ذاتي فور ظهور الشاشة
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secs--);
      if (_secs <= 0) { t.cancel(); _heal(); }
    });
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  Future<void> _heal() async {
    if (!mounted) return;
    setState(() => _trying = true);
    await SelfHeal.repair();
    if (!mounted) return;
    setState(() => _trying = false);
    _restart();
  }

  void _restart() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Splash()), (r) => false);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/intro_mark.png',
              width: 74, height: 74,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.refresh_rounded, color: Color(0xFFF5A623), size: 52)),
          const SizedBox(height: 22),
          const Text('لحظة من فضلك',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFF5F5F7),
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            _trying
                ? (_secs > 0
                    ? 'نُصلح المشكلة تلقائياً خلال $_secs…'
                    : 'جارٍ الإصلاح…')
                : 'تعذّر الإصلاح التلقائي — جرّب أحد الخيارين',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9B9BA1), fontSize: 13, height: 1.7),
          ),
          const SizedBox(height: 26),
          if (_trying)
            const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Color(0xFFF5A623)))
          else ...[
            _btn('إعادة المحاولة', true, _heal),
            const SizedBox(height: 10),
            _btn('إعادة تشغيل التطبيق', false, _restart),
          ],
        ]),
      ),
    ),
  );

  Widget _btn(String label, bool primary, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, height: 50,
      decoration: BoxDecoration(
        color: primary ? const Color(0xFFF5A623) : const Color(0xFF141416),
        borderRadius: BorderRadius.circular(13),
        border: primary ? null : Border.all(color: const Color(0xFF232326)),
      ),
      child: Center(child: Text(label,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: primary ? Colors.black : const Color(0xFFF5F5F7)))),
    ),
  );
}
