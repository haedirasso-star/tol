import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/splash_screen.dart';
import 'core/config/app_theme.dart';
import 'core/services/firebase_remote_config_service.dart';
import 'core/services/force_update_service.dart';
import 'data/repositories/content_repository_impl.dart';
import 'domain/usecases/get_trending_content.dart';
import 'presentation/bloc/home/home_bloc.dart';
import 'presentation/bloc/home/home_event.dart';
import 'package:flutter/foundation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool needsUpdate = false;
  try {
    await Firebase.initializeApp();
    final remoteConfig = FirebaseRemoteConfigService();
    await remoteConfig.initialize();
    needsUpdate = await ForceUpdateService().checkForUpdate();
  } catch (e) {
    // يعمل التطبيق بدون Firebase للمعاينة (Chrome/محاكي) إذا لم يكن Firebase مُعداً
    debugPrint('Firebase/Remote Config غير مُعد أو فشل التهيئة: $e');
  }

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI overlay style (status bar & navigation bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(TOTVPlusApp(needsUpdate: needsUpdate));
}

class TOTVPlusApp extends StatelessWidget {
  final bool needsUpdate;

  const TOTVPlusApp({Key? key, required this.needsUpdate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => HomeBloc(
            getTrendingContent: GetTrendingContent(
              ContentRepositoryImpl(),
            ),
          )..add(LoadHomeContent()),
        ),
      ],
      child: MaterialApp(
        title: 'TOTV+',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: needsUpdate
            ? const ForceUpdateScreen()
            : const SplashScreen(),
        routes: {
          '/home': (context) => const HomePage(),
        },
      ),
    );
  }
}

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.system_update_alt,
                size: 80,
                color: Color(0xFFFF6B00),
              ),
              const SizedBox(height: 24),
              const Text(
                'تحديث مطلوب',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'يرجى تحديث التطبيق للحصول على أحدث الميزات والمحتوى',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Open app store/play store
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'تحديث الآن',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
