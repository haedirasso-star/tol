part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — تفاصيل المستخدم + إدارة المشرفين
//  • صفحة تفاصيل كاملة: الاشتراك، طريقة الدفع، مصدر التفعيل، السيرفر، المشاكل.
//  • تغيير سيرفر المستخدم يدوياً أو من الرصيد.
//  • إضافة/حذف إيميل مشرف (admins/{email}) — يفعّل ويضيف سيرفرات.
//  التركيب:  part 'ui/pages/admin_user_detail.dart';
// ════════════════════════════════════════════════════════════════════════

class _UserDetailPage extends StatelessWidget {
  final String uid;
  const _UserDetailPage({required this.uid});

  static void open(BuildContext ctx, String uid) => Navigator.of(ctx).push(
    MaterialPageRoute(builder: (_) => _UserDetailPage(uid: uid)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AC.bg,
      body: SafeArea(child: StreamBuilder<DocumentSnapshot>(
        stream: _AC.db.collection('users').doc(uid).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _AC.gold));
          final m = (snap.data!.data() as Map<String,dynamic>?) ?? {};
          final sub = (m['subscription'] as Map<String,dynamic>?) ?? {};
          final name = m['display_name']?.toString() ?? '—';
          final email = m['email']?.toString() ?? uid;
          final plan = sub['plan']?.toString() ?? 'free';
          final exp = (sub['expiry_date'] as Timestamp?)?.toDate();
          final left = exp == null ? null : exp.difference(DateTime.now()).inDays;
          final banned = m['status']?.toString() == 'banned';
          final online = m['is_online'] == true;

          return ListView(padding: const EdgeInsets.all(16), children: [
            // header
            Row(children: [
              GestureDetector(onTap: () => Navigator.pop(context),
                child: Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: _AC.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _AC.bdr)),
                  child: const Icon(Icons.arrow_back_ios_rounded, size: 15, color: _AC.t2))),
              const SizedBox(width: 12),
              Container(width: 52, height: 52,
                decoration: BoxDecoration(color: _AC.gold.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: _AC.t(s: 22, w: FontWeight.w800, c: _AC.gold)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: _AC.t(s: 16, w: FontWeight.w800)),
                Text(email, style: _AC.mono(s: 10, c: _AC.t2), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(
                    color: online ? _AC.grn : _AC.t3, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(online ? 'متصل الآن' : 'غير متصل', style: _AC.t(s: 10, c: online ? _AC.grn : _AC.t3)),
                ]),
              ])),
            ]),
            const SizedBox(height: 18),

            // ── الاشتراك ──
            _detailCard('💎 الاشتراك', [
              _kv('الخطة', plan == 'premium' ? 'بريميوم 💎' : plan == 'trial' ? 'تجريبي 🔵' : 'مجاني ⏱',
                  vc: plan == 'premium' ? _AC.gold : plan == 'trial' ? _AC.cyn : _AC.t2),
              if (exp != null) _kv('تاريخ الانتهاء', _fmt(exp)),
              if (left != null) _kv('المتبقّي', left < 0 ? 'منتهي منذ ${-left} يوم' : '$left يوم',
                  vc: left < 0 ? _AC.red : left <= 7 ? _AC.org : _AC.grn),
              if (sub['activated_at'] != null)
                _kv('فُعّل في', _fmt((sub['activated_at'] as Timestamp).toDate())),
              if (sub['activated_by'] != null) _kv('فعّله', sub['activated_by'].toString()),
              if (sub['note'] != null) _kv('ملاحظة', sub['note'].toString()),
            ]),
            const SizedBox(height: 12),

            // ── السيرفر ──
            _detailCard('🖥 السيرفر', [
              _kv('الهوست', sub['host']?.toString() ?? sub['server_host']?.toString() ?? '— لا يوجد', mono: true),
              _kv('المستخدم', sub['username']?.toString() ?? '—', mono: true),
              _kv('كلمة المرور', sub['password']?.toString() ?? '—', mono: true),
              if (sub['server_id'] != null) _kv('معرّف الرصيد', sub['server_id'].toString(), mono: true),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _actBtn('🔄 تغيير السيرفر (من الرصيد)', _AC.prp,
                  () => _changeServerFromCredit(context))),
            ]),
            const SizedBox(height: 8),
            _actBtn('✏️ تغيير السيرفر يدوياً', _AC.blu, () => _manualServerSheet(context, sub)),
            const SizedBox(height: 8),
            // ★ شحن الرصيد — لصق بيانات الاشتراك وتفعيل بضغطة
            _actBtn('📋 شحن الرصيد (لصق البيانات)', _AC.gold, () => _pasteCredsSheet(context, sub)),
            const SizedBox(height: 12),

            // ── طريقة الدفع / آخر طلب ──
            _UserLastOrder(uid: uid, email: email),
            const SizedBox(height: 12),

            // ── إجراءات ──
            _detailCard('⚙️ إجراءات', [
              _actBtn('⚡ تفعيل / تجديد', _AC.gold, () => _ActivateSheet.show(context,
                  uid: uid, email: email, name: name, presetDays: 30)),
              const SizedBox(height: 8),
              // ★ إرسال رسالة مباشرة للمستخدم (تظهر داخل تطبيقه فوراً)
              _actBtn('📨 إرسال رسالة للمستخدم', _AC.cyn, () => _sendMessageSheet(context)),
              const SizedBox(height: 8),
              _actBtn(banned ? '✅ رفع الحظر' : '🚫 حظر المستخدم', banned ? _AC.grn : _AC.red, () async {
                await _AC.db.collection('users').doc(uid).update({
                  'status': banned ? 'active' : 'banned', 'updated_at': FieldValue.serverTimestamp()});
                if (context.mounted) _toast(context, banned ? 'رُفع الحظر' : 'حُظر المستخدم');
              }),
              const SizedBox(height: 8),
              _actBtn('⏸ إيقاف الاشتراك', _AC.org, () async {
                await _AC.db.collection('users').doc(uid).update({
                  'subscription.plan': 'free', 'updated_at': FieldValue.serverTimestamp()});
                if (context.mounted) _toast(context, 'أُوقف الاشتراك');
              }),
            ]),
            const SizedBox(height: 30),
          ]);
        },
      )),
    );
  }

  // ★ شحن الرصيد بلصق نص الاشتراك (Host/Username/Password) وتفعيله بضغطة
  void _pasteCredsSheet(BuildContext ctx, Map<String,dynamic> sub) {
    const kDefaultHost = 'http://max.m950.org:2052';
    final raw = TextEditingController();
    String host = '', user = '', pass = '';

    ({String host, String user, String pass}) parse(String t) {
      String h = '', u = '', p = '';
      for (var line in t.split(RegExp(r'[\n\r]+'))) {
        final l = line.trim();
        final m = RegExp(r'^\s*(host|server|url|رابط|هوست|username|user|اليوزر|يوزر|اسم المستخدم|password|pass|الباس|باسورد|كلمة المرور)\s*[:=]\s*(.+)$',
            caseSensitive: false).firstMatch(l);
        if (m != null) {
          final key = m.group(1)!.toLowerCase();
          final val = m.group(2)!.trim();
          if (key.contains('host') || key.contains('server') || key.contains('url') || key.contains('رابط') || key.contains('هوست')) h = val;
          else if (key.contains('user') || key.contains('يوزر') || key.contains('اسم')) u = val;
          else if (key.contains('pass') || key.contains('باس') || key.contains('كلمة')) p = val;
        }
      }
      return (host: h, user: u, pass: p);
    }

    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (c, setS) {
        final parsed = parse(raw.text);
        host = parsed.host.isNotEmpty ? parsed.host : kDefaultHost;
        user = parsed.user; pass = parsed.pass;
        final ready = user.isNotEmpty && pass.isNotEmpty;
        return Container(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(color: _AC.bg2,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)), border: Border(top: BorderSide(color: _AC.bdr))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: _AC.bdr2, borderRadius: BorderRadius.circular(3)))),
            Text('📋 شحن الرصيد — لصق البيانات', style: _AC.t(s: 15, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('الصق رسالة الاشتراك كما هي (Host / Username / Password)', style: _AC.t(s: 11, c: _AC.t2)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: _AC.bg3, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _AC.bdr)),
              child: TextField(
                controller: raw, maxLines: 5,
                onChanged: (_) => setS(() {}),
                textDirection: TextDirection.ltr,
                style: _AC.t(s: 13).copyWith(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'Host: http://max.m950.org:2052\nUsername: Hwiuhehgy\nPassword: 48033650916376',
                  hintStyle: TextStyle(color: _AC.t3, fontSize: 12),
                  contentPadding: EdgeInsets.all(12), border: InputBorder.none))),
            const SizedBox(height: 12),
            // معاينة ما تم استخراجه
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _AC.card, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ready ? _AC.grn.withOpacity(0.4) : _AC.bdr)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _previewRow('Host', host),
                _previewRow('Username', user.isEmpty ? '—' : user),
                _previewRow('Password', pass.isEmpty ? '—' : pass),
              ])),
            const SizedBox(height: 14),
            Opacity(opacity: ready ? 1 : 0.5, child: _goldBtn('⚡ تفعيل بهذه البيانات', () async {
              if (!ready) { _toast(ctx, '⚠ لم يتم استخراج اليوزر/الباسوورد — تحقق من النص'); return; }
              final curExp = (sub['expiry_date'] as Timestamp?)?.toDate();
              final exp = (curExp != null && curExp.isAfter(DateTime.now()))
                  ? curExp : DateTime.now().add(const Duration(days: 365));
              await _AC.db.collection('users').doc(uid).update({
                'subscription.host': host, 'subscription.server_host': host,
                'subscription.username': user, 'subscription.password': pass,
                'subscription.plan': 'premium',
                'subscription.expiry_date': Timestamp.fromDate(exp),
                'subscription.activated_by': _AC.adminEmail,
                'subscription.activated_at': FieldValue.serverTimestamp(),
                'updated_at': FieldValue.serverTimestamp()});
              if (c.mounted) { Navigator.pop(c); _toast(ctx, '✅ تم التفعيل من البيانات الملصقة'); }
            })),
          ]),
        );
      }));
  }

  Widget _previewRow(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      SizedBox(width: 78, child: Text(k, style: _AC.t(s: 11, c: _AC.t2))),
      Expanded(child: Directionality(textDirection: TextDirection.ltr,
        child: Text(v, style: _AC.t(s: 12, w: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis))),
    ]));

  // ★ إرسال رسالة مباشرة تظهر داخل تطبيق المستخدم فوراً
  void _sendMessageSheet(BuildContext ctx) {
    final title = TextEditingController(text: 'رسالة من الإدارة');
    final body = TextEditingController();
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: _AC.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)), border: Border(top: BorderSide(color: _AC.bdr))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: _AC.bdr2, borderRadius: BorderRadius.circular(3)))),
          Text('📨 رسالة للمستخدم', style: _AC.t(s: 15, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('تظهر داخل تطبيقه فوراً كإشعار.', style: _AC.t(s: 11, c: _AC.t2)),
          const SizedBox(height: 12),
          _ConsoleField(controller: title, hint: 'العنوان'), const SizedBox(height: 10),
          Container(decoration: BoxDecoration(color: _AC.bg3, borderRadius: BorderRadius.circular(12), border: Border.all(color: _AC.bdr)),
            child: TextField(controller: body, maxLines: 4, style: _AC.t(s: 13),
              decoration: const InputDecoration(hintText: 'نص الرسالة…', hintStyle: TextStyle(color: _AC.t3),
                contentPadding: EdgeInsets.all(12), border: InputBorder.none))),
          const SizedBox(height: 16),
          _goldBtn('📤 إرسال', () async {
            if (body.text.trim().isEmpty) { _toast(ctx, '⚠ اكتب نص الرسالة'); return; }
            await _AC.db.collection('users').doc(uid).update({
              'admin_message': {
                'title': title.text.trim().isEmpty ? 'رسالة من الإدارة' : title.text.trim(),
                'body': body.text.trim(),
                'at': FieldValue.serverTimestamp(),
              },
              'updated_at': FieldValue.serverTimestamp(),
            });
            if (ctx.mounted) { Navigator.pop(ctx); _toast(ctx, '✅ أُرسلت الرسالة'); }
          }),
        ]),
      ));
  }

  Future<void> _changeServerFromCredit(BuildContext ctx) async {
    try {
      final email = (await _AC.db.collection('users').doc(uid).get()).data()?['email']?.toString() ?? '';
      final alloc = await _CreditEngine.allocate(uid: uid, email: email);
      await _AC.db.collection('users').doc(uid).update({
        'subscription.host': alloc['host'], 'subscription.server_host': alloc['host'],
        'subscription.username': alloc['username'], 'subscription.password': alloc['password'],
        'subscription.server_id': alloc['server_id'], 'updated_at': FieldValue.serverTimestamp()});
      if (ctx.mounted) _toast(ctx, '✅ سيرفر جديد: ${alloc['server_name']}');
    } catch (e) { if (ctx.mounted) _toast(ctx, '⚠ $e'); }
  }

  void _manualServerSheet(BuildContext ctx, Map<String,dynamic> sub) {
    // ★ الهوست تلقائي — الأدمن يضيف اليوزر والباسوورد فقط
    const kDefaultHost = 'http://max.m950.org:2052';
    final curHost = (sub['host']?.toString() ?? sub['server_host']?.toString() ?? '').trim();
    final host = TextEditingController(text: curHost.isNotEmpty ? curHost : kDefaultHost);
    final user = TextEditingController(text: sub['username']?.toString() ?? '');
    final pass = TextEditingController(text: sub['password']?.toString() ?? '');
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(color: _AC.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)), border: Border(top: BorderSide(color: _AC.bdr))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 38, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: _AC.bdr2, borderRadius: BorderRadius.circular(3)))),
          Text('🔑 تفعيل سيرفر المستخدم', style: _AC.t(s: 15, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('الهوست تلقائي — أضف اسم المستخدم وكلمة المرور للتفعيل',
              style: _AC.t(s: 11, c: _AC.t2)),
          const SizedBox(height: 14),
          Text('السيرفر (تلقائي)', style: _AC.t(s: 11, c: _AC.t2)), const SizedBox(height: 5),
          _ConsoleField(controller: host, hint: kDefaultHost, ltr: true), const SizedBox(height: 10),
          Text('اسم المستخدم', style: _AC.t(s: 11, c: _AC.t2)), const SizedBox(height: 5),
          _ConsoleField(controller: user, hint: 'username', ltr: true), const SizedBox(height: 10),
          Text('كلمة المرور', style: _AC.t(s: 11, c: _AC.t2)), const SizedBox(height: 5),
          _ConsoleField(controller: pass, hint: 'password', ltr: true), const SizedBox(height: 16),
          _goldBtn('💾 حفظ وتفعيل', () async {
            final h = host.text.trim().isEmpty ? kDefaultHost : host.text.trim();
            final u = user.text.trim();
            final pw = pass.text.trim();
            if (u.isEmpty || pw.isEmpty) {
              _toast(ctx, '⚠ أضف اسم المستخدم وكلمة المرور'); return;
            }
            // الحفاظ على تاريخ الانتهاء الحالي أو منح سنة افتراضياً
            final curExp = (sub['expiry_date'] as Timestamp?)?.toDate();
            final exp = (curExp != null && curExp.isAfter(DateTime.now()))
                ? curExp : DateTime.now().add(const Duration(days: 365));
            await _AC.db.collection('users').doc(uid).update({
              'subscription.host': h, 'subscription.server_host': h,
              'subscription.username': u, 'subscription.password': pw,
              // ★ تفعيل تلقائي حتى يتحوّل محتوى المستخدم للسيرفر الجديد فوراً
              'subscription.plan': 'premium',
              'subscription.expiry_date': Timestamp.fromDate(exp),
              'subscription.activated_by': _AC.adminEmail,
              'subscription.activated_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp()});
            // ★ مستند تفعيل في activations
            try {
              await _AC.db.collection('activations').add({
                'uid': uid, 'username': u, 'host': h, 'plan': 'premium',
                'source': 'admin', 'activated_by': _AC.adminEmail,
                'expiry_date': Timestamp.fromDate(exp),
                'created_at': FieldValue.serverTimestamp(),
              });
            } catch (_) {}
            if (ctx.mounted) { Navigator.pop(ctx); _toast(ctx, '✅ حُفظ السيرفر وفُعّل'); }
          }),
        ]),
      ));
  }

  Widget _detailCard(String title, List<Widget> rows) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: _AC.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: _AC.t(s: 13, w: FontWeight.w700, c: _AC.gold)),
      const SizedBox(height: 12), ...rows,
    ]));

  Widget _kv(String k, String v, {Color? vc, bool mono = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 95, child: Text(k, style: _AC.t(s: 11.5, c: _AC.t2))),
      Expanded(child: Text(v, style: mono ? _AC.mono(s: 11, c: vc ?? _AC.tx) : _AC.t(s: 12, w: FontWeight.w600, c: vc ?? _AC.tx))),
    ]));

  Widget _actBtn(String t, Color c, VoidCallback onTap) => GestureDetector(
    onTap: () { Sound.hapticM(); onTap(); },
    child: Container(width: double.infinity, height: 46, alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(.3))),
      child: Text(t, style: _AC.t(s: 12.5, w: FontWeight.w700, c: c))));

  static String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2,"0")}/${d.month.toString().padLeft(2,"0")}/${d.year}';
}

// آخر طلب للمستخدم (طريقة الدفع + الحالة)
class _UserLastOrder extends StatelessWidget {
  final String uid, email;
  const _UserLastOrder({required this.uid, required this.email});
  @override
  Widget build(BuildContext context) => FutureBuilder<QuerySnapshot>(
    future: _AC.db.collection('orders').where('uid', isEqualTo: uid).limit(20).get(),
    builder: (_, snap) {
      final docs = snap.data?.docs ?? [];
      if (docs.isEmpty) {
        return Container(padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: _AC.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _AC.bdr)),
          child: Row(children: [const Text('💳 ', style: TextStyle(fontSize: 14)),
            Text('لا طلبات دفع لهذا المستخدم', style: _AC.t(s: 11.5, c: _AC.t2))]));
      }
      // رتّب محلياً بالأحدث
      docs.sort((a, b) {
        final ta = (a.data() as Map)['created'] as Timestamp?;
        final tb = (b.data() as Map)['created'] as Timestamp?;
        return (tb?.compareTo(ta ?? Timestamp(0,0)) ?? 0);
      });
      return Container(padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: _AC.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _AC.bdr)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('💳 سجل الطلبات (${docs.length})', style: _AC.t(s: 13, w: FontWeight.w700, c: _AC.gold)),
          const SizedBox(height: 12),
          ...docs.take(5).map((d) {
            final m = d.data() as Map<String,dynamic>;
            final st = m['status']?.toString() ?? 'pending';
            final (sc, stt) = switch (st) {
              'active' => (_AC.grn, 'مُفعّل'), 'rejected' => (_AC.red, 'مرفوض'), _ => (_AC.org, 'بانتظار')};
            return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['plan_title'] ?? m['plan'] ?? '—'} · ${m['method'] ?? '—'}', style: _AC.t(s: 11.5, w: FontWeight.w600)),
                if (m['price'] != null) Text('${m['price']} د.ع', style: _AC.t(s: 10, c: _AC.t2)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: sc.withOpacity(.13), borderRadius: BorderRadius.circular(7)),
                child: Text(stt, style: _AC.t(s: 9.5, w: FontWeight.w700, c: sc))),
            ]));
          }),
        ]));
    });
}

// ════════════════════════════════════════════════════════════════════════
//  إدارة المشرفين — admins/{email}
// ════════════════════════════════════════════════════════════════════════
class _AdminsTab extends StatefulWidget { const _AdminsTab(); @override State<_AdminsTab> createState()=>_AdminsTabState(); }
class _AdminsTabState extends State<_AdminsTab> {
  final _email = TextEditingController();
  @override void dispose(){_email.dispose();super.dispose();}
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(14), children: [
    _acCard('➕ إضافة مشرف', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('المشرف يمكنه تفعيل الاشتراكات وإضافة السيرفرات.', style: _AC.t(s: 10.5, c: _AC.t2)),
      const SizedBox(height: 10),
      _ConsoleField(controller: _email, hint: 'admin@example.com', ltr: true),
      const SizedBox(height: 12),
      _goldBtn('➕ إضافة مشرف', () async {
        final e = _email.text.trim().toLowerCase();
        if (!e.contains('@')) { _toast(context, '⚠ إيميل غير صالح'); return; }
        await _AC.db.collection('admins').doc(e).set({
          'email': e, 'added_by': _AC.adminEmail, 'added_at': FieldValue.serverTimestamp()});
        // ابحث عن وثيقة المستخدم بهذا الإيميل وفعّل is_admin (ليعمل في القواعد)
        try {
          final q = await _AC.db.collection('users').where('email', isEqualTo: e).limit(1).get();
          if (q.docs.isNotEmpty) {
            await q.docs.first.reference.update({'is_admin': true, 'role': 'admin'});
          }
        } catch (_) {}
        _AC.tg('👮 مشرف جديد: $e');
        _email.clear();
        if (context.mounted) _toast(context, '✅ أُضيف المشرف');
      }),
    ])),
    const SizedBox(height: 14),
    _acSec('المشرفون'),
    StreamBuilder<QuerySnapshot>(stream: _AC.db.collection('admins').snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        // الأدمن الأساسي ثابت دائماً
        return Column(children: [
          _adminRow('haedirasso@gmail.com', isPrimary: true, id: null),
          ...docs.where((d) => d.id != 'haedirasso@gmail.com').map((d) {
            final m = d.data() as Map<String,dynamic>;
            return _adminRow(m['email']?.toString() ?? d.id, id: d.id);
          }),
        ]);
      }),
  ]);

  Widget _adminRow(String email, {bool isPrimary = false, String? id}) => Container(
    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _AC.card, borderRadius: BorderRadius.circular(11),
      border: Border.all(color: isPrimary ? _AC.gold.withOpacity(.3) : _AC.bdr)),
    child: Row(children: [
      Icon(isPrimary ? Icons.shield_rounded : Icons.shield_outlined, color: _AC.gold, size: 20),
      const SizedBox(width: 11),
      Expanded(child: Text(email, style: _AC.mono(s: 11, c: _AC.tx), overflow: TextOverflow.ellipsis)),
      if (isPrimary)
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _AC.gold.withOpacity(.13), borderRadius: BorderRadius.circular(7)),
          child: Text('أساسي', style: _AC.t(s: 9.5, w: FontWeight.w700, c: _AC.gold)))
      else
        GestureDetector(onTap: () async {
          await _AC.db.collection('admins').doc(id).delete();
          if (context.mounted) _toast(context, '🗑 حُذف المشرف');
        }, child: const Icon(Icons.delete_outline_rounded, color: _AC.red, size: 19)),
    ]));
}
