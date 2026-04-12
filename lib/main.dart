// ════════════════════════════════════════════════════════════════
//  TOTV+ — main.dart  v3 FIXED
// ════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
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
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'stub/notif_stub.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await AppVersion.init();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  unawaited(RC.init());
  unawaited(NotifService.init());
  if (!kIsWeb) unawaited(MobileAds.instance.initialize());

  // ★ إذا كان المستخدم مسجّلاً، ابدأ جميع المستمعات فوراً عند الإقلاع
  // بدون await — لا يُبطئ التطبيق
  final _startUid = FirebaseAuth.instance.currentUser?.uid;
  if (_startUid != null) {
    AuthService.startAdminListener(_startUid);
    // ابدأ المستمع الشامل لبيانات المستخدم (Stream — تحديث حي من Firestore)
    UserDataWatcher.startListening(_startUid);
  }
  // تحميل كاش روابط التشغيل
  unawaited(PlayUrlCache.load());
  // ★ تحميل كاش البوسترات من القرص (يسرّع فتح القوائم)
  unawaited(SmartPosterCache.loadFromDisk());

  runApp(const App());
}

class App extends StatefulWidget {
  const App();
  @override State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    RC.onConfigChanged  = () {
      if (mounted) {
        setState(() {});
        // إذا تغيّر السيرفر الافتراضي وليس هناك محتوى → أعد التحميل
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD740),
          secondary: Color(0xFFFFAB00),
          surface: Color(0xFF141414),
        ),
        fontFamily: GoogleFonts.cairo().fontFamily,
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
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
