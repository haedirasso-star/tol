import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/voice_room/voice_room.dart';
import 'firebase_options.dart';

/// ═══════════════════════════════════════════════════════════════
///  تطبيق تجريبي مستقل — لاختبار الاتصال قبل الدمج في TOTV+.
///
///  لدمج الميزة في تطبيقك الأصلي، انسخ مجلد
///  lib/features/voice_room/ فقط، ثم:
///      Navigator.push(ctx, MaterialPageRoute(
///          builder: (_) => const RoomsListPage()));
/// ═══════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  Bloc.observer = const _LogObserver();
  runApp(const TotvVoiceApp());
}

class TotvVoiceApp extends StatelessWidget {
  const TotvVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TOTV+ Voice',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E1013),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC107),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // كل الواجهات عربية — RTL
      builder: (ctx, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _AuthGate(),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
///  بوابة المصادقة.
///
///  ⚠️ يستخدم الدخول المجهول (Anonymous) للتجربة السريعة فقط.
///     في تطبيقك الحقيقي استبدله بمصادقة TOTV+ الفعلية —
///     الـ uid هو ما يربط المستخدم بدوره في الغرفة.
///
///  فعّل Anonymous من:
///     Firebase Console → Authentication → Sign-in method
/// ═══════════════════════════════════════════════════════════════
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _signIn();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      // اسم للعرض داخل الغرفة
      final u = FirebaseAuth.instance.currentUser!;
      if ((u.displayName ?? '').isEmpty) {
        await u.updateDisplayName('مستخدم ${u.uid.substring(0, 4)}');
      }
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'فشل تسجيل الدخول: $e';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white24)),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 46),
                const SizedBox(height: 14),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 18),
                FilledButton(
                    onPressed: _signIn, child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
        ),
      );
    }
    return const RoomsListPage();
  }
}

class _LogObserver extends BlocObserver {
  const _LogObserver();
  @override
  void onError(BlocBase bloc, Object error, StackTrace st) {
    debugPrint('[${bloc.runtimeType}] $error');
    super.onError(bloc, error, st);
  }
}
