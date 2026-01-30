import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // ستحتاج لإضافة هذه المكتبة
import 'lib/core/app_theme.dart';
import 'lib/core/app_router.dart';
import 'lib/constants.dart';

void main() async {
  // التأكد من تهيئة جميع الخدمات قبل تشغيل التطبيق
  WidgetsFlutterBinding.ensureInitialized();
  
  // تثبيت اتجاه الشاشة (بورتريه فقط) لضمان تناسق الواجهة
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // جعل شريط الحالة شفافاً ليعطي شعوراً سينمائياً
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        // هنا نضع مزودي البيانات (لجلب الأفلام، البث المباشر، والاشتراك)
        // ChangeNotifierProvider(create: (_) => MovieProvider()),
      ],
      child: const GlobalStreamingApp(),
    ),
  );
}

class GlobalStreamingApp extends StatelessWidget {
  const GlobalStreamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOD Professional Clone',
      debugShowCheckedModeBanner: false,
      
      // نظام الألوان المتطور (الأسود العميق والذهبي)
      theme: AppTheme.darkTheme,
      
      // نظام التنقل بين الصفحات (Router)
      initialRoute: AppRouter.splashRoute,
      onGenerateRoute: AppRouter.generateRoute,
      
      // دعم اللغة العربية بشكل كامل
      locale: const Locale('ar', 'IQ'),
    );
  }
}
