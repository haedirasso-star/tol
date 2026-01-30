import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تثبيت اتجاه الشاشة
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  // جعل شريط الحالة سينمائي
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const TOLStreamingApp());
}

class TOLStreamingApp extends StatelessWidget {
  const TOLStreamingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOL Stream',
      debugShowCheckedModeBanner: false,
      
      // تعريف الثيم مباشرة هنا لحل خطأ AppTheme
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFFFD700),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFFFFD700),
        ),
      ),
      
      // تم حذف كلمة const من هنا لحل خطأ "Not a constant expression"
      localizationsDelegates: [
        GlobalCupertinoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'IQ')],
      locale: const Locale('ar', 'IQ'),

      home: const SubscriptionGate(), 
    );
  }
}

class SubscriptionGate extends StatelessWidget {
  const SubscriptionGate({super.key});

  Future<void> _launchTelegram() async {
    final Uri url = Uri.parse('https://t.me/O_2828');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       debugPrint("Could not launch Telegram");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Colors.black],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user, size: 100, color: Color(0xFFFFD700)),
            const SizedBox(height: 30),
            const Text(
              "تطبيق TOL",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFFD700)),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "لمتابعة البث المباشر والحصول على كافة الميزات، يجب الاشتراك في قناة المطور أولاً.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _launchTelegram,
              icon: const Icon(Icons.send_rounded),
              label: const Text("اشترك الآن لتفعيل التطبيق", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {},
              child: const Text("تم الاشتراك؟ اضغط هنا للدخول", style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
