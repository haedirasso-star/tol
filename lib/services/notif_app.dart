part of '../main.dart';

// ════════════════════════════════════════════════════════════════
//  NOTIFICATIONS SERVICE — v1 Clean
// ════════════════════════════════════════════════════════════════
class NotifService {
  static bool _inited = false;
  static final _ln = FlutterLocalNotificationsPlugin();
  static const _chId   = 'totv_main';
  static const _chName = 'TOTV+ Notifications';

  static Future<void> init() async {
    if (_inited) return;
    try {
      if (!kIsWeb) {
        const android = AndroidInitializationSettings('@mipmap/launcher_icon');
        const ios     = DarwinInitializationSettings();
        await _ln.initialize(const InitializationSettings(android: android, iOS: ios));
        await _ln
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(const AndroidNotificationChannel(
              _chId, _chName,
              importance: Importance.high,
              playSound: true,
            ));
      }
      final m = FirebaseMessaging.instance;
      await m.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n != null) show(n.title ?? 'TOTV+', n.body ?? '');
      });
      await m.subscribeToTopic('all_users');
      final token = await m.getToken();
      final user  = FirebaseAuth.instance.currentUser;
      if (token != null && user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'fcm_token':         token,
          'last_token_update': FieldValue.serverTimestamp(),
          'platform':          Plat.name,
        }, SetOptions(merge: true));
      }
      _inited = true;
    } catch (_) {}
  }

  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  static void show(String title, String body, {String? payload}) {
    if (kIsWeb) { debugPrint('📲 $title — $body'); return; }
    Sound.hapticNotif();
    try {
      _ln.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title, body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _chId, _chName,
            importance: Importance.high,
            priority:   Priority.high,
            icon: '@mipmap/launcher_icon',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  static Future<void> subscribeToTopic(String t) async {
    try { await FirebaseMessaging.instance.subscribeToTopic(t); } catch (_) {}
  }
}

// ════════════════════════════════════════════════════════════════
//  GATE PAGES — Maintenance / Lock
// ════════════════════════════════════════════════════════════════
class _LockPage extends StatelessWidget {
  final String msg;
  const _LockPage(this.msg);
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_clock_rounded, color: C.gold, size: 80),
        const SizedBox(height: 20),
        Text('التطبيق مغلق مؤقتاً',
            style: T.cairo(s: 18, w: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(msg.isNotEmpty ? msg : 'يرجى المحاولة لاحقاً',
            style: T.body(c: C.grey), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse(RC.telegram),
              mode: LaunchMode.externalApplication),
          child: Text('تواصل معنا', style: T.caption(c: C.gold)),
        ),
      ]),
    )),
  );
}

class _MaintenancePage extends StatelessWidget {
  final String msg;
  const _MaintenancePage(this.msg);
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: C.gold, strokeWidth: 2),
        const SizedBox(height: 30),
        Text('خاضع للصيانة', style: T.cairo(s: 18, w: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          msg.isNotEmpty ? msg : 'نعمل على تحسين التطبيق، سنعود قريباً',
          style: T.body(c: C.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse(RC.telegram),
              mode: LaunchMode.externalApplication),
          child: Text('تابعنا على تيليجرام', style: T.caption(c: C.gold)),
        ),
      ]),
    )),
  );
}
