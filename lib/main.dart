import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // لدعم العربية
import 'lib/ui/screens/subscription_gate.dart';
import 'lib/core/app_theme.dart';
import 'lib/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة نظام الإشعارات لاستقبال تنبيهات المباريات
  NotificationService().initialize();
  
  // تثبيت اتجاه الشاشة ومنع التدوير العشوائي
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // إعداد شريط الحالة (سينمائي)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        // هنا سيتم إضافة MovieProvider و AuthProvider لاحقاً
      ],
      child: const TOLStreamingApp(),
    ),
  );
}

class TOLStreamingApp extends StatelessWidget {
  const TOLStreamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOL Stream',
      debugShowCheckedModeBanner: false,
      
      // الهوية البصرية (الأسود والذهبي)
      theme: AppTheme.darkTheme,
      
      // دعم اللغة العربية والاتجاه من اليمين لليسار (RTL)
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'IQ')],
      locale: const Locale('ar', 'IQ'),

      // نقطة الانطلاق: بوابة الاشتراك الإجباري في قناتك t.me/O_2828
      home: const SubscriptionGate(), 
    );
  }
}
