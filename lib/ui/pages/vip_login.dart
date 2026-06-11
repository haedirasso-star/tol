part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — اشتراك VIP (سيرفر خاص)
//  يُدخل المستخدم host + username + password ويتصل بسيرفره مباشرة.
//  تُحفظ البيانات محلياً (بلا Firebase). التركيب: part 'ui/pages/vip_login.dart';
// ════════════════════════════════════════════════════════════════════════

class VipLoginSheet extends StatefulWidget {
  const VipLoginSheet({super.key});

  static void show(BuildContext ctx) => showModalBottomSheet(
    context: ctx, isScrollControlled: true,
    backgroundColor: Colors.transparent, useSafeArea: true,
    builder: (_) => const VipLoginSheet());

  @override State<VipLoginSheet> createState() => _VipLoginSheetState();
}

class _VipLoginSheetState extends State<VipLoginSheet> {
  final _host = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() { _host.dispose(); _user.dispose(); _pass.dispose(); super.dispose(); }

  Future<void> _connect() async {
    setState(() { _busy = true; _err = null; });
    final res = await Sub.activateVip(
      host: _host.text, username: _user.text, password: _pass.text);
    if (!mounted) return;
    if (res.ok) {
      // ★ امسح محتوى أي سيرفر سابق وحمّل من سيرفر المستخدم الجديد فوراً
      AppState.clearAll();
      ListCache.clear();
      SmartContentLoader.cancelAll();
      unawaited(AppState.loadAll(force: true).then((_) {
        AppState.onPartialLoad?.call();
      }));
      Sound.hapticOk();
      setState(() => _busy = false);
      Navigator.of(context).pop(true); // أغلق الورقة
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${res.msg} — يتم تحميل محتوى سيرفرك الآن',
          style: T.cairo(s: FS.sm, c: Colors.black)),
        backgroundColor: C.gold, behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3)));
    } else {
      setState(() { _busy = false; _err = res.msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: pad),
      child: Container(
        decoration: const BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: C.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(3)))),
          // العنوان
          Row(children: [
            Container(width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFFFFD740), C.gold]),
                borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 26)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('اشتراك VIP', style: T.cairo(s: FS.lg, w: FontWeight.w900)),
              Text('اتصل بسيرفرك الخاص مباشرةً', style: T.caption(c: C.textSec)),
            ])),
          ]),
          const SizedBox(height: 22),
          _field(_host, 'رابط السيرفر', 'http://server.com:8080', Icons.dns_rounded),
          const SizedBox(height: 12),
          _field(_user, 'اسم المستخدم', 'username', Icons.person_rounded),
          const SizedBox(height: 12),
          _field(_pass, 'كلمة المرور', 'password', Icons.lock_rounded),
          if (_err != null) ...[
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: C.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(R.md), border: Border.all(color: C.red.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: C.red, size: 18),
                const SizedBox(width: 9),
                Expanded(child: Text(_err!, style: T.cairo(s: FS.sm, c: C.red))),
              ])),
          ],
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _busy ? null : _connect,
            child: Container(height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFFFFD740), C.gold]),
                borderRadius: BorderRadius.circular(R.md),
                boxShadow: [BoxShadow(color: C.gold.withOpacity(0.3), blurRadius: 16)]),
              child: Center(child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                : Text('اتصال', style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black)))),
          ),
          const SizedBox(height: 10),
          Text('تُحفظ بياناتك على جهازك فقط — لا تُرسل لأحد.',
            textAlign: TextAlign.center, style: T.caption(c: C.dim)),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, IconData icon) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: T.cairo(s: FS.sm, w: FontWeight.w700, c: C.textSec)),
      const SizedBox(height: 7),
      Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          controller: c,
          style: T.cairo(s: FS.md, c: C.textPri),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: T.cairo(s: FS.sm, c: C.dim),
            prefixIcon: Icon(icon, color: C.gold, size: 19),
            filled: true, fillColor: Colors.white.withOpacity(0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.md),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(R.md),
              borderSide: const BorderSide(color: C.gold, width: 1.5)),
          ),
        ),
      ),
    ]);
}
