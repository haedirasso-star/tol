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
  bool _obscure = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    // ★ املأ الهوست تلقائياً بالهوست العام المحفوظ (المستخدم غالباً يكتب user+pass فقط)
    _host.text = GlobalHost.value;
  }

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
        AppState.notifyContent();
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
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(color: C.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(3)))),
          // ── هيرو فاخر ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [C.gold.withOpacity(0.16), C.gold.withOpacity(0.02)]),
              borderRadius: BorderRadius.circular(R.xl),
              border: Border.all(color: C.gold.withOpacity(0.22))),
            child: Column(children: [
              Container(width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE27A), C.gold]),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: C.gold.withOpacity(0.45), blurRadius: 22, spreadRadius: 1)]),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 34)),
              const SizedBox(height: 12),
              Text('تفعيل اشتراكي', style: T.cairo(s: FS.xl, w: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('أدخل اسم المستخدم وكلمة المرور — والباقي علينا',
                  textAlign: TextAlign.center, style: T.caption(c: C.textSec)),
            ]),
          ),
          // ★ الهوست تلقائي ومقفل — المستخدم يكتب اليوزر والباسوورد فقط
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: C.gold.withOpacity(0.06),
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: C.gold.withOpacity(0.25))),
            child: Row(children: [
              const Icon(Icons.dns_rounded, color: C.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('السيرفر (تلقائي)', style: T.cairo(s: FS.xs, c: C.textSec)),
                Directionality(textDirection: TextDirection.ltr,
                  child: Text(GlobalHost.value,
                    style: T.cairo(s: FS.sm, w: FontWeight.w700, c: C.gold),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ])),
              const Icon(Icons.lock_rounded, color: C.dim, size: 15),
            ]),
          ),
          const SizedBox(height: 12),
          _field(_user, 'اسم المستخدم', 'username', Icons.person_rounded),
          const SizedBox(height: 12),
          _field(_pass, 'كلمة المرور', 'password', Icons.lock_rounded,
              obscure: _obscure,
              suffix: GestureDetector(
                onTap: () => setState(() => _obscure = !_obscure),
                child: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: C.dim, size: 19))),
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
            child: Container(height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFE27A), C.gold]),
                borderRadius: BorderRadius.circular(R.md),
                boxShadow: [BoxShadow(color: C.gold.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 4))]),
              child: Center(child: _busy
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black)),
                    const SizedBox(width: 11),
                    Text('جارٍ الاتصال وتحميل المحتوى…', style: T.cairo(s: FS.sm, w: FontWeight.w800, c: Colors.black)),
                  ])
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.bolt_rounded, color: Colors.black, size: 21),
                    const SizedBox(width: 7),
                    Text('تفعيل الآن', style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black)),
                  ]))),
          ),
          const SizedBox(height: 11),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_rounded, size: 12, color: C.dim),
            const SizedBox(width: 5),
            Text('تُحفظ بياناتك على جهازك فقط — لا تُرسل لأحد.',
              textAlign: TextAlign.center, style: T.caption(c: C.dim)),
          ]),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, IconData icon,
      {bool obscure = false, Widget? suffix}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: T.cairo(s: FS.sm, w: FontWeight.w700, c: C.textSec)),
      const SizedBox(height: 7),
      Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          controller: c,
          obscureText: obscure,
          style: T.cairo(s: FS.md, c: C.textPri),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: T.cairo(s: FS.sm, c: C.dim),
            prefixIcon: Icon(icon, color: C.gold, size: 19),
            suffixIcon: suffix == null ? null : Padding(
                padding: const EdgeInsetsDirectional.only(end: 12), child: suffix),
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
