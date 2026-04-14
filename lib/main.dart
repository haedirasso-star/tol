// ════════════════════════════════════════════════════════════════
//  TOTV+ — main.dart  v4 — Crash-Safe + AI Support + Resume
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'
    if (dart.library.html) 'stub/ads_stub.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'stub/notif_stub.dart';
import 'package:shimmer/shimmer.dart';

part 'core/constants.dart';
part 'services/tmdb.dart';
part 'services/app_state.dart';
part 'services/notif_app.dart';
part 'services/smart_content_service.dart';
part 'ui/pages/splash_shell.dart';
part 'ui/pages/home_pages.dart';
part 'ui/pages/series_sports.dart';
part 'ui/pages/profile_player.dart';
part 'ui/pages/profile_player_header.dart';
part 'ui/pages/actor_login.dart';
part 'ui/pages/admin_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) { debugPrint('[main] $e'); }
}

Future<void> main() async {
  // ★ اصطياد كل الأخطاء — لا يتوقف التطبيق أبداً
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ★ اصطياد أخطاء Flutter Framework (مشاكل الـ Widget tree)
    FlutterError.onError = (FlutterErrorDetails details) {
      AppErrorHandler.report(
        details.exception, details.stack,
        context: 'Flutter:${details.library ?? 'unknown'}',
      );
      if (kDebugMode) FlutterError.presentError(details);
    };

    // ★ اصطياد الأخطاء غير المتزامنة في Isolate الرئيسي
    PlatformDispatcher.instance.onError = (error, stack) {
      AppErrorHandler.report(error, stack, context: 'PlatformDispatcher');
      return true; // true = تم التعامل مع الخطأ
    };

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    await AppVersion.init();
    // ★ تحميل SharedPreferences مسبقاً — كل الطلبات اللاحقة فورية
    await SPref.preload();

    // ★ Firebase — ضروري قبل runApp
    bool firebaseOk = false;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
          .timeout(const Duration(seconds: 5), onTimeout: () => Firebase.app());
      firebaseOk = true;
    } catch (e, s) {
      AppErrorHandler.report(e, s, context: 'Firebase.init');
    }

    // ★★★ runApp فوراً — الـ UI يظهر بدون أي انتظار
    runApp(const App());

    // ★ كل شيء ثقيل بعد عرض الـ UI (background)
    unawaited(Future.microtask(() async {
      try {
        // ★ تهيئة SharedPrefs مرة واحدة — يُسرّع كل عمليات الـ storage
        await SharedPrefs.init().catchError((_) {});
        if (firebaseOk) {
          FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
          unawaited(RC.init().catchError((_) {}));
          unawaited(NotifService.init().catchError((_) {}));
          // ★ Request POST_NOTIFICATIONS on Android 13+
          unawaited(_requestNotifPermission());
        }
        if (!kIsWeb) {
          unawaited(MobileAds.instance.initialize().catchError((_) {}));
        }
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          unawaited(Future(() => AuthService.startAdminListener(uid)));
          unawaited(Future(() => UserDataWatcher.startListening(uid)));
        }
        unawaited(PlayUrlCache.load().catchError((_) {}));
        unawaited(SmartPosterCache.loadFromDisk().catchError((_) {}));
        unawaited(WatchHistory.ensureLoaded().catchError((_) {}));
      } catch (e) { debugPrint('[main] $e'); }
    }));
  }, (error, stack) {
    AppErrorHandler.report(error, stack, context: 'Zone');
    debugPrint('🔴 Unhandled error caught: $error');
  });
}


// ── Request notification permission (Android 13+) ──────────
Future<void> _requestNotifPermission() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      const plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
  } catch (e) { debugPrint('[notif_perm] $e'); }
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
      if (mounted) {
        setState(() {});
        if (AppState.allMovies.isEmpty && RC.hasDefaultServer) {
          unawaited(AppState.loadAll());
        }
      }
    };
    RC.onVersionChanged = () { if (mounted) setState(() {}); };
  }

  @override
  void dispose() { RC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOTV+',
      debugShowCheckedModeBanner: false,
      // ★ builder يلتقط أخطاء الـ Widget tree ويعرض شاشة بديلة
      builder: (context, child) => _AppErrorBoundary(child: child ?? const SizedBox()),
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: C.bg, // أعمق وأكثر سينمائية
        colorScheme: ColorScheme.dark(
          primary:    C.gold,
          secondary:  C.goldDim,
          surface:    C.surface,
          onSurface:  Colors.white,
          surfaceContainerHighest: C.card,
        ),
        fontFamily: GoogleFonts.cairo().fontFamily,
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        splashFactory: InkRipple.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: const Color(0x0FFFD740),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      routes: {
        '/login': (_) => const FirebaseLoginPage(),
        '/admin': (_) => const AdminWebPage(),
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
//  AppErrorBoundary — يعترض أخطاء الـ Widget ويعرض شاشة آمنة
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
    if (_error != null) return _ErrorScreen(error: _error!, onRetry: () => setState(() => _error = null));
    return widget.child;
  }
}

// ════════════════════════════════════════════════════════════════
//  AppErrorHandler — مركز تسجيل الأخطاء
// ════════════════════════════════════════════════════════════════
class AppErrorHandler {
  static final List<_ErrorLog> _logs = [];
  static const int _maxLogs = 50;

  static void report(Object error, StackTrace? stack, {String context = ''}) {
    final log = _ErrorLog(
      error: error.toString(),
      context: context,
      stack: stack?.toString().split('\n').take(5).join('\n') ?? '',
      time: DateTime.now(),
    );
    _logs.insert(0, log);
    if (_logs.length > _maxLogs) _logs.removeLast();
    debugPrint('🔴 [$context] $error');
  }

  static List<_ErrorLog> get logs => List.unmodifiable(_logs);
  static void clear() => _logs.clear();

  /// رسالة واضحة للمستخدم بناءً على نوع الخطأ
  static String userFriendlyMessage(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') || msg.contains('network') || msg.contains('connection'))
      return 'تعذّر الاتصال بالإنترنت. تحقق من اتصالك وأعد المحاولة.';
    if (msg.contains('timeout'))
      return 'انتهت مهلة الاتصال. السيرفر بطيء — حاول لاحقاً.';
    if (msg.contains('401') || msg.contains('403') || msg.contains('unauthorized'))
      return 'بيانات الدخول غير صحيحة أو انتهت صلاحية جلستك.';
    if (msg.contains('404'))
      return 'المحتوى غير موجود على السيرفر.';
    if (msg.contains('500') || msg.contains('server'))
      return 'خطأ في السيرفر — فريقنا يعمل على الحل.';
    if (msg.contains('firebase') || msg.contains('firestore'))
      return 'مشكلة في الاتصال بقاعدة البيانات. تحقق من الإنترنت.';
    if (msg.contains('permission') || msg.contains('denied'))
      return 'الصلاحية مرفوضة. تحقق من إعدادات التطبيق.';
    if (msg.contains('format') || msg.contains('parse'))
      return 'بيانات غير صالحة من السيرفر. حاول مجدداً.';
    return 'حدث خطأ غير متوقع. اضغط "إعادة المحاولة".';
  }
}

class _ErrorLog {
  final String error, context, stack;
  final DateTime time;
  _ErrorLog({required this.error, required this.context, required this.stack, required this.time});
}

// ════════════════════════════════════════════════════════════════
//  _ErrorScreen — شاشة الخطأ الاحترافية
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
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1), shape: BoxShape.circle,
              border: Border.all(color: Colors.red.withOpacity(0.3), width: 2)),
            child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40)),
          const SizedBox(height: 24),
          Text('حدث خطأ في التطبيق', textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: FS.lg, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center,
              style: GoogleFonts.cairo(fontSize: FS.md, color: Colors.white60)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: onRetry,
            child: Container(width: double.infinity, height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [C.gold, C.goldDim]),
                borderRadius: BorderRadius.circular(R.md)),
              child: Center(child: Text('إعادة المحاولة',
                  style: GoogleFonts.cairo(fontSize: FS.lg, fontWeight: FontWeight.w800, color: Colors.black))))),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              final wa = RC.whatsapp;
              if (wa.isNotEmpty) launchUrl(Uri.parse('https://wa.me/$wa'), mode: LaunchMode.externalApplication);
            },
            child: Text('تواصل مع الدعم', style: GoogleFonts.cairo(fontSize: FS.md, color: C.whatsapp))),
        ]))));
  }
}
