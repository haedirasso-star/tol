part of '../../main.dart';

// ════════════════════════════════════════════════════════════════
//  PROFILE PAGE — Netflix-style redesign
// ════════════════════════════════════════════════════════════════
class ProfilePage extends StatefulWidget {
  const ProfilePage();
  @override State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final user   = AuthService.currentUser;
    final isLog  = user != null;
    final isPaid = SubCompat.isPremium;

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _buildHeroHeader(user, isPaid)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          sliver: SliverList(delegate: SliverChildListDelegate([
            const SizedBox(height: 16),

            // ── كارت الاشتراك الحالي ──
            if (!isLog) ...[ _guestCard(context), const SizedBox(height: 16) ],
            _buildSubscriptionCard(context, user, isPaid),
            const SizedBox(height: 16),

            // ── خطط الاشتراك — تُخفى إذا كان المستخدم مشتركاً ──
            if (!isPaid) ...[ _PurchasePlansButton(buyUrl: RC.buyUrl), const SizedBox(height: 16) ],

            // ── الحساب ──
            if (isLog) ...[ _sectionLabel('الحساب'), const SizedBox(height: 8),
              _menuGroup([
                _menuRow(Icons.email_outlined, 'البريد الإلكتروني', user.email ?? '', () {}),
                _menuRow(Icons.devices_rounded, 'الأجهزة المتصلة', 'إدارة أجهزتك',
                    () => _push(const _DevicesPage())),
              ]),
              const SizedBox(height: 16),
            ],

            // ── الإعدادات ──
            _sectionLabel('الإعدادات'), const SizedBox(height: 8),
            _menuGroup([
              _menuRow(Icons.settings_outlined, 'الإعدادات', 'جودة البث، الإشعارات',
                  () => _push(const _SettingsPage())),
              _menuRow(Icons.security_outlined, 'الأمان', 'كلمة المرور والخصوصية',
                  () => _push(const _SecurityPage())),
            ]),
            const SizedBox(height: 16),

            // ── الدعم ──
            _sectionLabel('الدعم'), const SizedBox(height: 8),
            _menuGroup([
              if (!isPaid) _menuRow(Icons.receipt_long_outlined, 'تتبع طلباتي',
                  'حالة طلبات الاشتراك', () => _push(const OrderTrackingPage())),
              _menuRow(Icons.smart_toy_outlined, 'مساعد TOTV+', 'دعم ذكي فوري',
                  () => _push(const _AISupportPage())),
              _menuRow(Icons.headset_mic_outlined, 'الدعم الفني', 'واتساب وتيليغرام',
                  _openSupport),
              _menuRow(Icons.policy_outlined, 'سياسة الخصوصية', '',
                  () => _push(const _PrivacyPolicyPage())),
            ]),

            const SizedBox(height: 20),
            if (isLog && !isPaid) _freeTimerCard(),
            const SizedBox(height: 20),
            if (isLog) _logoutBtn() else _loginBtn(context),
            const SizedBox(height: 8),
            Center(child: Text('TOTV+ v${AppVersion.version}',
                style: T.caption(c: Colors.white12))),
            const SizedBox(height: 16),
          ])),
        ),
      ]),
    );
  }

  // ── Netflix-style Hero Header ──────────────────────────────
  Widget _buildHeroHeader(user, bool isPaid) {
    final name   = user?.displayName ?? user?.email?.split('@').first ?? 'ضيف';
    final photo  = user?.photoURL ?? '';
    final pColor = isPaid ? C.gold : Colors.white38;
    final posters = <String>[];
    for (final m in AppState.allMovies.take(4)) {
      final u = m['stream_icon']?.toString() ?? m['cover']?.toString() ?? '';
      if (u.isNotEmpty) posters.add(u);
    }

    return Stack(children: [
      // خلفية بوسترات شفافة
      if (posters.isNotEmpty)
        SizedBox(height: 200,
          child: Row(children: posters.map((u) =>
            Expanded(child: CachedNetworkImage(imageUrl: u, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: C.surface),
              placeholder: (_, __) => Container(color: C.surface)))).toList())),
      Container(height: 200, decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.3), C.bg]))),
      // المحتوى
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // صورة المستخدم
          Stack(clipBehavior: Clip.none, children: [
            Container(width: 72, height: 72,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: pColor, width: 2.5),
                boxShadow: [BoxShadow(color: pColor.withOpacity(0.3), blurRadius: 16)]),
              child: ClipOval(child: photo.isNotEmpty
                ? CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover)
                : Container(color: C.surface,
                    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TExtra.mont(s: 28, w: FontWeight.w900, c: pColor)))))),
            if (isPaid)
              Positioned(bottom: -2, right: -2,
                child: Container(width: 22, height: 22,
                  decoration: BoxDecoration(color: C.gold, shape: BoxShape.circle,
                    border: Border.all(color: C.bg, width: 2)),
                  child: const Icon(Icons.workspace_premium_rounded, size: 12, color: Colors.black))),
          ]),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end, children: [
            Text(name, style: T.cairo(s: 18, w: FontWeight.w900),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            _planBadge(isPaid),
          ])),
          if (user != null)
            IconButton(icon: Icon(Icons.notifications_outlined,
                color: Colors.white.withOpacity(0.4)), onPressed: () {}),
        ]),
      ),
    ]);
  }

  Widget _planBadge(bool isPaid) {
    if (isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [C.gold.withOpacity(0.25), C.gold.withOpacity(0.1)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.gold.withOpacity(0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.workspace_premium_rounded, size: 12, color: C.gold),
          const SizedBox(width: 5),
          Text('TOTV+ Premium', style: TExtra.mont(s: 10, c: C.gold, w: FontWeight.w700)),
        ]));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: Text('مجاني', style: TExtra.mont(s: 10, c: Colors.white54, w: FontWeight.w600)));
  }

  Widget _buildSubscriptionCard(BuildContext ctx, user, bool isPaid) {
    if (isPaid) return _paidCard(ctx);
    if (user != null) return _freeCard(ctx);
    return const SizedBox.shrink();
  }

  Widget _paidCard(BuildContext ctx) {
    final expiry    = Sub.expiry;
    final startDate = Sub.activatedAt;
    final daysLeft  = Sub.daysLeft;
    final totalDays = (startDate != null && expiry != null)
        ? expiry.difference(startDate).inDays.clamp(1, 9999) : 30;
    final usedDays  = startDate != null
        ? DateTime.now().difference(startDate).inDays.clamp(0, totalDays) : 0;
    final progress  = daysLeft > 0 ? (1 - usedDays / totalDays).clamp(0.0, 1.0) : 0.0;
    final expiring  = daysLeft <= 7;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1C1400), const Color(0xFF141414)],
          begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.gold.withOpacity(0.35), width: 1.2),
        boxShadow: [BoxShadow(color: C.gold.withOpacity(0.08), blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: C.gold.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('اشتراك TOTV+ نشط', style: T.cairo(s: 13, w: FontWeight.w800, c: C.gold)),
            Text('مشاهدة غير محدودة', style: T.caption(c: CC.textSec)),
          ])),
          if (expiring) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.4))),
            child: Text('ينتهي قريباً', style: T.caption(c: Colors.orange))),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _dateInfo('البداية', _fmtDate(startDate))),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
          Expanded(child: _dateInfo('الانتهاء', _fmtDate(expiry))),
          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
          Expanded(child: _dateInfo('متبقي',
              daysLeft > 0 ? '$daysLeft يوم' : 'منتهي', highlight: true)),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('تقدم الاشتراك', style: T.caption(c: CC.textSec)),
          Text('${(progress * 100).toInt()}%', style: T.caption(c: expiring ? Colors.orange : C.gold)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(expiring ? Colors.orange : C.gold), minHeight: 5)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip('∞ مشاهدة'), _chip('4K جودة'), _chip('كل القنوات'), _chip('بلا إعلانات'),
        ]),
        if (expiring) ...[ const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _openUrl(RC.buyUrl.isNotEmpty ? RC.buyUrl : 'https://payment-totv.vercel.app/'),
            child: Container(width: double.infinity, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange, Colors.orange.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text('تجديد الاشتراك الآن',
                  style: T.cairo(s: 13, w: FontWeight.w800, c: Colors.black))))),
        ],
      ]));
  }

  Widget _freeCard(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.07))),
    child: Column(children: [
      Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
          child: const Icon(Icons.lock_open_rounded, color: Colors.white38, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الباقة المجانية', style: T.cairo(s: 13, w: FontWeight.w700)),
          Text('ساعة مشاهدة يومياً', style: T.caption(c: CC.textSec)),
        ])),
      ]),
      const SizedBox(height: 14),
      _compRow('مدة المشاهدة', '60 دقيقة/يوم', '∞ غير محدودة'),
      _compRow('الجودة', 'HD', 'FHD / 4K'),
      _compRow('القنوات', 'محدودة', 'جميع القنوات'),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: () => _push(const SubscriptionPage()),
        child: Container(width: double.infinity, height: 46,
          decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: C.gold.withOpacity(0.2), blurRadius: 12, offset: const Offset(0,4))]),
          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 16),
            const SizedBox(width: 8),
            Text('ترقية للـ Premium', style: T.cairo(s: 13, w: FontWeight.w900, c: Colors.black)),
          ])))),
    ]));

  Widget _dateInfo(String l, String v, {bool highlight = false}) => Column(children: [
    Text(l, style: T.caption(c: CC.textSec), textAlign: TextAlign.center),
    const SizedBox(height: 3),
    Text(v, style: T.cairo(s: 12, w: FontWeight.w700, c: highlight ? C.gold : Colors.white),
        textAlign: TextAlign.center),
  ]);

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: C.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: C.gold.withOpacity(0.2))),
    child: Text(t, style: T.caption(c: C.gold)));

  Widget _compRow(String l, String free, String paid) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(children: [
      Expanded(flex: 2, child: Text(l, style: T.caption(c: CC.textSec))),
      Expanded(child: Text(free, style: T.caption(c: Colors.white30), textAlign: TextAlign.center)),
      Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_rounded, color: C.gold, size: 11),
        const SizedBox(width: 4),
        Text(paid, style: T.caption(c: C.gold)),
      ])),
    ]));

  Widget _freeTimerCard() => StreamBuilder<int>(
    stream: Stream.periodic(const Duration(seconds: 1), (_) => GuestSession.remainingSecs),
    initialData: GuestSession.remainingSecs,
    builder: (ctx, snap) {
      final frac    = 1.0 - GuestSession.usedFraction;
      final expired = GuestSession.isExpired;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: expired ? Colors.red.withOpacity(0.06) : C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: expired ? Colors.red.withOpacity(0.25) : C.gold.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.timer_outlined, color: expired ? Colors.red : C.gold, size: 16),
            const SizedBox(width: 8),
            Text('وقت المشاهدة اليومي', style: T.cairo(s: 12, w: FontWeight.w700)),
            const Spacer(),
            Text(GuestSession.remainingStr,
                style: TExtra.mont(s: 14, w: FontWeight.w800, c: expired ? Colors.red : C.gold)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: frac.clamp(0.0, 1.0),
              backgroundColor: Colors.white10, color: expired ? Colors.red : C.gold, minHeight: 4)),
          if (expired) ...[ const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _push(const SubscriptionPage()),
              child: Container(height: 36, decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('اشترك للمشاهدة غير المحدودة',
                    style: T.cairo(s: 11, w: FontWeight.w700, c: Colors.black))))),
          ],
        ]));
    });

  Widget _guestCard(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.07))),
    child: Column(children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
        child: const Icon(Icons.person_outline_rounded, size: 28, color: Colors.white24)),
      const SizedBox(height: 12),
      Text('تسجيل الدخول', style: T.cairo(s: 15, w: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('احصل على ساعة مشاهدة مجانية يومياً',
          style: T.caption(c: C.grey), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => Navigator.push(ctx, PageRouteBuilder(
          pageBuilder: (_, __, ___) => const FirebaseLoginPage(),
          transitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (_, a, __, c) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c))),
        child: Container(height: 46, decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text('تسجيل الدخول مجاناً',
              style: T.cairo(s: 13, w: FontWeight.w800, c: Colors.black))))),
    ]));

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(right: 2, bottom: 0),
    child: Row(children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: T.caption(c: Colors.white38).copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700)),
    ]));

  Widget _menuGroup(List<Widget> items) => Container(
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.06))),
    child: Column(children: List.generate(items.length, (i) => Column(children: [
      items[i],
      if (i < items.length - 1) Divider(height: 1, indent: 52, color: Colors.white.withOpacity(0.05)),
    ]))));

  Widget _menuRow(IconData icon, String title, String sub, VoidCallback onTap) =>
    GestureDetector(onTap: () { Sound.hapticL(); onTap(); }, behavior: HitTestBehavior.opaque,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: Icon(icon, size: 17, color: C.gold)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.cairo(s: 13, w: FontWeight.w600)),
            if (sub.isNotEmpty) Text(sub, style: T.caption(c: C.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Icon(Icons.arrow_back_ios_rounded, size: 12, color: Colors.white.withOpacity(0.2)),
        ])));

  Widget _loginBtn(BuildContext ctx) => GestureDetector(
    onTap: () => Navigator.push(ctx, PageRouteBuilder(
      pageBuilder: (_, __, ___) => const FirebaseLoginPage(),
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, a, __, c) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1,0), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c))),
    child: Container(height: 50,
      decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(14)),
      child: Center(child: Text('تسجيل الدخول',
          style: T.cairo(s: 15, w: FontWeight.w800, c: Colors.black)))));

  Widget _logoutBtn() => GestureDetector(
    onTap: () async {
      final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('تسجيل الخروج', style: T.cairo(s: 16, w: FontWeight.w700)),
        content: Text('هل تريد تسجيل الخروج؟', style: T.body()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: T.cairo(s: 13, c: C.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('خروج', style: T.cairo(s: 13, c: Colors.white, w: FontWeight.w700))),
        ]));
      if (ok == true) { await Sub.logout(); GuestSession.reset(); if (mounted) setState(() {}); }
    },
    child: Container(height: 48,
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(0.2))),
      child: Center(child: Text('تسجيل الخروج',
          style: T.cairo(s: 14, w: FontWeight.w600, c: Colors.redAccent)))));

  void _push(Widget p) => Navigator.push(context, PageRouteBuilder(
    pageBuilder: (_, __, ___) => p,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, a, __, c) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1,0), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c)));
  void _openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  void _openSupport() {
    final wa = RC.whatsapp;
    final url = wa.isNotEmpty ? 'https://wa.me/${wa.replaceAll('+','')}' : RC.telegram;
    if (url.isNotEmpty) _openUrl(url);
  }
  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }
}


// ════════════════════════════════════════════════════════════════
//  PURCHASE PLANS BUTTON — زر واحد يفتح sheet الخطط
// ════════════════════════════════════════════════════════════════
class _PurchasePlansButton extends StatelessWidget {
  final String buyUrl;
  const _PurchasePlansButton({required this.buyUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { Sound.hapticM(); _showPlans(context); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [C.gold.withOpacity(0.14), C.gold.withOpacity(0.04)],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.gold.withOpacity(0.4), width: 1.2),
          boxShadow: [BoxShadow(color: C.gold.withOpacity(0.07), blurRadius: 16)]),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.gold.withOpacity(0.2), C.gold.withOpacity(0.08)]),
              shape: BoxShape.circle,
              border: Border.all(color: C.gold.withOpacity(0.3))),
            child: const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('خطط الاشتراك TOTV+', style: T.cairo(s: 14, w: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('شهري • 3 أشهر • سنوي — اضغط لعرض الخطط',
                style: T.caption(c: CC.textSec)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(10)),
            child: Text('اشترك', style: T.cairo(s: 11, w: FontWeight.w800, c: Colors.black))),
        ])));
  }

  void _showPlans(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => _PlansSheet(buyUrl: buyUrl));
  }
}

// ── Plans Sheet ────────────────────────────────────────────────
class _PlansSheet extends StatelessWidget {
  final String buyUrl;
  const _PlansSheet({required this.buyUrl});

  static const _plans = [
    {'id':'monthly',   'title':'شهري',    'price':'5,000',  'priceNum':5000,  'period':'/شهر',    'devices':1, 'badge':'الأكثر شيوعاً', 'accent':0xFFFFD740},
    {'id':'quarterly', 'title':'3 أشهر', 'price':'13,000', 'priceNum':13000, 'period':'/3 أشهر', 'devices':2, 'badge':'وفّر 13%',       'accent':0xFF00D2FF},
    {'id':'yearly',    'title':'سنوي',    'price':'45,000', 'priceNum':45000, 'period':'/سنة',    'devices':2, 'badge':'أفضل قيمة',      'accent':0xFFFF6B35},
  ];

  List<String> _posters() {
    final all = <String>[];
    for (final m in [...AppState.allMovies.take(4), ...AppState.allSeries.take(4)]) {
      final u = m['stream_icon']?.toString() ?? m['cover']?.toString() ?? '';
      if (u.isNotEmpty) all.add(u);
    }
    return all.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final posters = _posters();
    return DraggableScrollableSheet(
      initialChildSize: 0.88, minChildSize: 0.5, maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          // Handle
          Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4, decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
          // Hero بوسترات
          Stack(children: [
            if (posters.isNotEmpty)
              SizedBox(height: 110, child: Row(children: posters.map((u) =>
                Expanded(child: CachedNetworkImage(imageUrl: u, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: C.surface),
                  placeholder: (_, __) => Container(color: C.surface)))).toList())),
            Container(height: 110, decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.5), const Color(0xFF0D0D0D)]))),
            Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: C.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: C.gold.withOpacity(0.4))),
                  child: Text('TOTV+ Premium', style: TExtra.mont(s: 9, c: C.gold, w: FontWeight.w700))),
                const SizedBox(height: 6),
                Text('اختر خطتك', style: T.cairo(s: 20, w: FontWeight.w900)),
              ])),
          ]),
          Expanded(child: ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16,10,16,24),
            children: [
              ..._plans.map((plan) => _PlanCard(
                plan: plan,
                onTap: (p) { Navigator.pop(context); _openPayment(context, p, buyUrl); },
              )),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.06))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('كل الخطط تشمل:', style: T.cairo(s: 12, w: FontWeight.w700, c: C.gold)),
                  const SizedBox(height: 8),
                  for (final f in [
                    'جميع القنوات والأفلام والمسلسلات',
                    'SD / HD / FHD / 4K',
                    'ذكاء اصطناعي لاختيار المحتوى',
                    'بدون إعلانات — دعم فني 24/7',
                  ]) Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [
                    const Icon(Icons.check_circle_rounded, color: C.gold, size: 13),
                    const SizedBox(width: 8),
                    Text(f, style: T.cairo(s: 11, c: Colors.white70)),
                  ])),
                ])),
            ])));
        ]));
  }

  static void _openPayment(BuildContext ctx, Map plan, String buyUrl) {
    showModalBottomSheet(
      context: ctx, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => _PaymentSheet(plan: plan, buyUrl: buyUrl));
  }
}

// ── Plan Card ──────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final Map plan;
  final void Function(Map) onTap;
  const _PlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color   = Color(plan['accent'] as int);
    final popular = plan['id'] == 'monthly';
    return GestureDetector(
      onTap: () { Sound.hapticM(); onTap(plan); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: popular ? color.withOpacity(0.07) : C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(popular ? 0.5 : 0.2), width: popular ? 1.5 : 1),
          boxShadow: popular ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 16)] : null),
        child: Row(children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(plan['title'] as String,
              style: T.cairo(s: 11, w: FontWeight.w900, c: color), textAlign: TextAlign.center))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('اشتراك ${plan['title']}', style: T.cairo(s: 13, w: FontWeight.w700)),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3))),
                child: Text(plan['badge'] as String, style: TExtra.mont(s: 8, c: color, w: FontWeight.w700))),
            ]),
            const SizedBox(height: 2),
            Text('${plan['devices']} ${plan['devices']==1?"جهاز":"جهازان"} • كل الأجهزة',
                style: T.caption(c: CC.textSec)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ShaderMask(shaderCallback: (r) => LinearGradient(colors: [color, color.withOpacity(0.7)]).createShader(r),
              child: Text(plan['price'] as String, style: TExtra.mont(s: 18, w: FontWeight.w900, c: Colors.white))),
            Text('د.ع${plan['period']}', style: TExtra.mont(s: 9, c: color.withOpacity(0.8))),
          ]),
        ])));
  }
}

// ════════════════════════════════════════════════════════════════
//  PAYMENT SHEET — نظام الدفع المتقدم + Telegram Bot
// ════════════════════════════════════════════════════════════════
class _PaymentSheet extends StatefulWidget {
  final Map plan;
  final String buyUrl;
  const _PaymentSheet({required this.plan, required this.buyUrl});
  @override State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  int     _step    = 0;   // 0=اختيار  1=تفاصيل  2=نجاح
  String? _method;

  static const _fibNum  = '07714415816';
  static const _fibName = 'حيدر عصام';
  static const _keyNum  = '7065169257';

  // Telegram Bot
  static const _tgBotToken = '7929309914:AAGsv_xZFX1I-KvFQUd8_xtGAeubH2YiReE';
  static const _tgChatId   = '1418184484';

  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool  _busy = false;
  String _err = '';

  @override void initState() { super.initState(); }
  @override void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Color get _ac => Color(widget.plan['accent'] as int);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _step == 2 ? 0.7 : 0.82, minChildSize: 0.4, maxChildSize: 0.95,
      builder: (_, sc) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 2),
            width: 36, height: 4, decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
          _buildHeader(),
          Expanded(child: SingleChildScrollView(controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: _step == 0 ? _buildStep0()
                 : _step == 1 ? _buildStep1()
                 : _buildStep2())),
        ])));
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    child: Row(children: [
      GestureDetector(
        onTap: () { if (_step > 0 && _step < 2) setState(() { _step--; _method = null; _err = ''; })
                    else Navigator.pop(context); },
        child: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: C.surface, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.white54))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إتمام الشراء', style: T.cairo(s: 15, w: FontWeight.w800)),
        Text('${widget.plan['title']} — ${widget.plan['price']} د.ع', style: T.caption(c: _ac)),
      ])),
      // step indicator
      Row(children: List.generate(3, (i) => Container(
        width: i == _step ? 20 : 6, height: 6, margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: i == _step ? _ac : i < _step ? _ac.withOpacity(0.4) : Colors.white12,
          borderRadius: BorderRadius.circular(3))))),
    ]));

  // ── Step 0: اختيار طريقة الدفع ──────────────────────────────
  Widget _buildStep0() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('اختر طريقة الدفع', style: T.cairo(s: 17, w: FontWeight.w900)),
    const SizedBox(height: 4),
    Text('ادفع وأرسل لنا إيصال التحويل', style: T.caption(c: CC.textSec)),
    const SizedBox(height: 18),
    _mCard('fib',     '🏦', 'FIB',           'تحويل بنكي — الأسرع', 'الأسرع', const Color(0xFF00D2FF)),
    const SizedBox(height: 10),
    _mCard('superapp','📱', 'سوبر كي',       'Super App — محفظة إلكترونية', 'شائع', C.gold),
    const SizedBox(height: 10),
    _mCard('key',     '🔑', 'كي',            'Key — تحويل إلكتروني', null, Colors.transparent),
    const SizedBox(height: 16),
    Divider(color: Colors.white.withOpacity(0.07)),
    const SizedBox(height: 12),
    _mCard('website', '🌐', 'موقعنا الإلكتروني', 'اشترِ عبر موقعنا الرسمي', 'آمن 🔒', const Color(0xFF4CAF50)),
  ]);

  Widget _mCard(String id, String icon, String title, String sub, String? badge, Color bc) =>
    GestureDetector(
      onTap: () {
        Sound.hapticL();
        if (id == 'website') {
          Navigator.pop(context);
          launchUrl(Uri.parse(widget.buyUrl.isNotEmpty
              ? '${widget.buyUrl}?plan=${widget.plan['id']}'
              : 'https://payment-totv.vercel.app/?plan=${widget.plan['id']}'),
            mode: LaunchMode.externalApplication);
          return;
        }
        setState(() { _method = id; _step = 1; });
      },
      child: Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: T.cairo(s: 13, w: FontWeight.w700)),
              if (badge != null) ...[ const SizedBox(width: 7),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: bc.withOpacity(0.15), borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: bc.withOpacity(0.4))),
                  child: Text(badge, style: TExtra.mont(s: 8, c: bc, w: FontWeight.w700))),
              ],
            ]),
            Text(sub, style: T.caption(c: CC.textSec)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white.withOpacity(0.25)),
        ])));

  // ── Step 1: تفاصيل الدفع ────────────────────────────────────
  Widget _buildStep1() {
    final isKey  = _method == 'key';
    final num    = isKey ? _keyNum : _fibNum;
    final label  = _method == 'fib' ? 'FIB' : _method == 'superapp' ? 'سوبر كي' : 'كي';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // بطاقة التحويل
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_ac.withOpacity(0.1), Colors.transparent],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _ac.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: T.cairo(s: 13, w: FontWeight.w700, c: _ac)),
            const Spacer(),
            ShaderMask(shaderCallback: (r) => LinearGradient(colors: [_ac, _ac.withOpacity(0.7)]).createShader(r),
              child: Text('${widget.plan['price']} د.ع',
                  style: TExtra.mont(s: 16, w: FontWeight.w900, c: Colors.white))),
          ]),
          const SizedBox(height: 12),
          _infoTile('رقم الحساب', num, copy: true),
          if (!isKey) _infoTile('اسم المستلم', _fibName),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 13),
              const SizedBox(width: 8),
              Expanded(child: Text('حوّل المبلغ كاملاً ثم أرسل بياناتك أدناه',
                  style: T.cairo(s: 11, c: Colors.orange.withOpacity(0.9)))),
            ])),
        ])),
      const SizedBox(height: 18),
      Text('بياناتك', style: T.cairo(s: 15, w: FontWeight.w800)),
      const SizedBox(height: 10),
      _tf(_nameCtrl,  'اسمك الكامل',    Icons.person_outline_rounded),
      const SizedBox(height: 8),
      _tf(_phoneCtrl, 'رقم هاتفك',      Icons.phone_outlined, type: TextInputType.phone),
      const SizedBox(height: 8),
      // نوع الخطة (readonly)
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 17),
          const SizedBox(width: 10),
          Text('اشتراك ${widget.plan['title']} — ${widget.plan['price']} د.ع',
              style: T.cairo(s: 12, w: FontWeight.w600)),
        ])),
      if (_err.isNotEmpty) ...[ const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.25))),
          child: Text(_err, style: T.cairo(s: 11, c: Colors.redAccent))),
      ],
      const SizedBox(height: 18),
      GestureDetector(
        onTap: _busy ? null : _submit,
        child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: _busy ? null : LinearGradient(colors: [_ac, _ac.withOpacity(0.7)]),
            color: _busy ? C.surface : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _busy ? null : [BoxShadow(color: _ac.withOpacity(0.3), blurRadius: 14, offset: const Offset(0,4))]),
          child: Center(child: _busy
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: C.gold, strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                const SizedBox(width: 8),
                Text('إرسال الطلب', style: T.cairo(s: 15, w: FontWeight.w900, c: Colors.black)),
              ])))),
    ]);
  }

  Widget _infoTile(String label, String value, {bool copy = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text('$label: ', style: T.caption(c: CC.textSec)),
      Expanded(child: Text(value, style: T.cairo(s: 13, w: FontWeight.w700))),
      if (copy) GestureDetector(
        onTap: () { Clipboard.setData(ClipboardData(text: value)); Sound.hapticL();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تم النسخ ✓', style: T.cairo(s: 12)),
            duration: const Duration(seconds: 1), backgroundColor: C.surface,
            behavior: SnackBarBehavior.floating)); },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: C.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text('نسخ', style: T.cairo(s: 10, c: C.gold)))),
    ]));

  Widget _tf(TextEditingController c, String hint, IconData icon, {TextInputType? type}) =>
    TextField(controller: c, keyboardType: type, textDirection: TextDirection.rtl,
      style: T.cairo(s: 13, c: Colors.white),
      decoration: InputDecoration(
        hintText: hint, hintStyle: T.cairo(s: 12, c: Colors.white30),
        prefixIcon: Icon(icon, size: 17, color: Colors.white30),
        filled: true, fillColor: C.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E1E1E))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E1E1E))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _ac, width: 1.2))));

  // ── إرسال الطلب إلى Telegram Bot + Firestore ────────────────
  Future<void> _submit() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _err = 'يرجى إدخال الاسم ورقم الهاتف'); return;
    }
    setState(() { _busy = true; _err = ''; });

    final user     = FirebaseAuth.instance.currentUser;
    final methodLb = _method == 'fib' ? 'FIB' : _method == 'superapp' ? 'سوبر كي' : 'كي';
    final orderId  = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

    // ① حفظ في Firestore
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'order_id': orderId, 'uid': user?.uid ?? 'guest',
        'email': user?.email ?? '', 'name': name, 'phone': phone,
        'plan': widget.plan['id'], 'plan_title': widget.plan['title'],
        'price': widget.plan['price'], 'method': methodLb,
        'status': 'pending', 'created': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    // ② إرسال إلى Telegram Bot
    final msg = '🔔 *طلب اشتراك جديد*\n\n'
      '🆔 `$orderId`\n'
      '👤 الاسم: $name\n'
      '📞 الهاتف: $phone\n'
      '📦 الخطة: اشتراك ${widget.plan['title']}\n'
      '💰 المبلغ: ${widget.plan['price']} د.ع\n'
      '💳 طريقة الدفع: $methodLb\n'
      '📧 البريد: ${user?.email ?? 'ضيف'}\n'
      '⏰ الوقت: ${DateTime.now().toLocal().toString().substring(0,16)}\n\n'
      '✅ *لتفعيل الاشتراك:* ابحث عن المستخدم في Firebase وفعّل اشتراكه';
    try {
      await Dio().post(
        'https://api.telegram.org/bot$_tgBotToken/sendMessage',
        data: {'chat_id': _tgChatId, 'text': msg, 'parse_mode': 'Markdown'},
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    await Sound.hapticOk();
    if (mounted) setState(() { _busy = false; _step = 2; });
  }

  // ── Step 2: نجاح الإرسال ────────────────────────────────────
  Widget _buildStep2() => Column(children: [
    const SizedBox(height: 10),
    Container(width: 72, height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5), width: 2)),
      child: const Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 38)),
    const SizedBox(height: 14),
    Text('تم إرسال طلبك!', style: T.cairo(s: 20, w: FontWeight.w900), textAlign: TextAlign.center),
    const SizedBox(height: 6),
    Text('سيتم تفعيل اشتراكك خلال دقائق بعد التحقق',
        style: T.body(c: CC.textSec), textAlign: TextAlign.center),
    const SizedBox(height: 20),
    Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(children: [
        _cRow('الخطة', 'اشتراك ${widget.plan['title']}'),
        _cRow('المبلغ', '${widget.plan['price']} د.ع'),
        _cRow('طريقة الدفع', _method == 'fib' ? 'FIB' : _method == 'superapp' ? 'سوبر كي' : 'كي'),
        _cRow('الحالة', '⏳ قيد المراجعة'),
      ])),
    const SizedBox(height: 16),
    // تفعيل يدوي
    Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.gold.withOpacity(0.06), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.gold.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.vpn_key_rounded, color: C.gold, size: 15),
          const SizedBox(width: 8),
          Text('هل لديك كود تفعيل؟', style: T.cairo(s: 12, w: FontWeight.w700, c: C.gold)),
        ]),
        const SizedBox(height: 5),
        Text('إذا أرسل لك الدعم كوداً، فعّل اشتراكك مباشرة',
            style: T.caption(c: CC.textSec)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () { Navigator.pop(context);
            Navigator.push(context, PageRouteBuilder(
              pageBuilder: (_, __, ___) => const SubscriptionPage(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (_, a, __, c) => SlideTransition(
                position: Tween<Offset>(begin: const Offset(0,1), end: Offset.zero)
                    .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c))); },
          child: Container(height: 40,
            decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text('تفعيل الاشتراك',
                style: T.cairo(s: 13, w: FontWeight.w800, c: Colors.black))))),
      ])),
    const SizedBox(height: 12),
    // واتساب
    GestureDetector(
      onTap: () {
        final wa  = RC.whatsapp;
        final msg = Uri.encodeComponent(
          'مرحباً، أرسلت طلب اشتراك ${widget.plan['title']}\n'
          'الاسم: ${_nameCtrl.text.trim()}\n'
          'الهاتف: ${_phoneCtrl.text.trim()}');
        final url = wa.isNotEmpty
          ? 'https://wa.me/${wa.replaceAll('+','')}?text=$msg'
          : RC.telegram;
        if (url.isNotEmpty) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Container(height: 44,
        decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF25D366).withOpacity(0.25))),
        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.support_agent_rounded, color: Color(0xFF25D366), size: 16),
          const SizedBox(width: 8),
          Text('تواصل مع الدعم', style: T.cairo(s: 13, c: const Color(0xFF25D366), w: FontWeight.w700)),
        ])))),
    const SizedBox(height: 8),
    TextButton(onPressed: () => Navigator.pop(context),
      child: Text('إغلاق', style: T.cairo(s: 13, c: Colors.white38))),
  ]);

  Widget _cRow(String k, String v) => Padding(padding: const EdgeInsets.only(bottom: 7),
    child: Row(children: [
      Text(k, style: T.caption(c: CC.textSec)), const Spacer(),
      Text(v, style: T.cairo(s: 12, w: FontWeight.w700)),
    ]));
}

class _PrivacyPolicyPage extends StatelessWidget {
  const _PrivacyPolicyPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: Text('سياسة الخصوصية', style: TExtra.h2()),
        elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [C.gold.withOpacity(0.15), Colors.transparent],
                begin: Alignment.topRight, end: Alignment.bottomLeft),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.gold.withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: C.gold.withOpacity(0.15)),
                  child: const Icon(Icons.shield_outlined, color: C.gold, size: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('سياسة الخصوصية', style: T.cairo(s: 16, w: FontWeight.w800)),
                  Text('آخر تحديث: يناير 2025', style: T.caption(c: CC.textSec)),
                ])),
              ]),
              const SizedBox(height: 14),
              Text(
                'نحن في TOTV+ نولي خصوصيتك أهمية قصوى. تصف هذه السياسة كيفية جمع بياناتك واستخدامها وحمايتها عند استخدام تطبيقنا.',
                style: T.body(c: CC.textSec), textDirection: TextDirection.rtl),
            ])),

          const SizedBox(height: 24),
          _section('1. المعلومات التي نجمعها', Icons.data_usage_rounded, [
            _bullet('معلومات الحساب', 'عند التسجيل نجمع: البريد الإلكتروني، الاسم، صورة الملف الشخصي (اختياري).'),
            _bullet('بيانات الاستخدام', 'نجمع معلومات عن المحتوى الذي تشاهده، مدة المشاهدة، وتفضيلاتك لتحسين تجربتك.'),
            _bullet('معلومات الجهاز', 'نوع الجهاز، نظام التشغيل، معرّف الجهاز — لأغراض الأمان وتحديد الأجهزة المصرح بها.'),
            _bullet('بيانات الاتصال', 'عنوان IP والبلد لضمان توافق المحتوى وأداء الخدمة.'),
          ]),

          _section('2. كيف نستخدم بياناتك', Icons.settings_applications_rounded, [
            _bullet('تقديم الخدمة', 'تشغيل المحتوى المرئي، إدارة اشتراكك، وحفظ تقدم المشاهدة.'),
            _bullet('تخصيص التجربة', 'تقديم توصيات بناءً على ما تشاهد، وتذكر تفضيلاتك.'),
            _bullet('الأمان', 'الكشف عن النشاط المشبوه، ومنع الاستخدام غير المصرح به.'),
            _bullet('التواصل', 'إرسال إشعارات مهمة عن اشتراكك أو تحديثات التطبيق.'),
          ]),

          _section('3. مشاركة البيانات', Icons.share_rounded, [
            _bullet('لا نبيع بياناتك', 'لا نقوم أبدًا ببيع بياناتك الشخصية لأطراف ثالثة.'),
            _bullet('خدمات Firebase', 'نستخدم Google Firebase لتخزين البيانات والمصادقة — وفق معايير أمان عالية.'),
            _bullet('TMDB', 'نستخدم The Movie Database API لجلب بيانات المحتوى (أوصاف، صور، تقييمات).'),
            _bullet('الالتزام القانوني', 'قد نُفصح عن البيانات إذا طُلب ذلك بموجب القانون أو أمر قضائي.'),
          ]),

          _section('4. حماية البيانات', Icons.lock_outline_rounded, [
            _bullet('التشفير', 'جميع البيانات المنقولة مشفرة بـ TLS/HTTPS.'),
            _bullet('Firebase Security Rules', 'قواعد صارمة تضمن أن كل مستخدم يصل فقط لبياناته الخاصة.'),
            _bullet('كلمات المرور', 'كلمات مرور Firebase مشفرة ولا يمكن لأحد الاطلاع عليها بما فينا نحن.'),
            _bullet('بيانات الاشتراك', 'بيانات Xtream server محفوظة محلياً على جهازك ومشفرة.'),
          ]),

          _section('5. حقوقك', Icons.verified_user_outlined, [
            _bullet('حق الوصول', 'يمكنك طلب نسخة من بياناتك في أي وقت.'),
            _bullet('حق التصحيح', 'تعديل معلومات حسابك من صفحة الملف الشخصي.'),
            _bullet('حق الحذف', 'يمكنك حذف حسابك وجميع بياناته من إعدادات التطبيق.'),
            _bullet('حق الرفض', 'إيقاف الإشعارات من إعدادات الجهاز أو التطبيق.'),
          ]),

          _section('6. الاحتفاظ بالبيانات', Icons.storage_rounded, [
            _bullet('مدة الحفظ', 'نحتفظ ببياناتك طالما حسابك نشط. عند حذف الحساب تُحذف البيانات خلال 30 يوماً.'),
            _bullet('سجل المشاهدة', 'يُحفظ محلياً على جهازك ويمكنك مسحه من إعدادات التطبيق.'),
          ]),

          _section('7. الكوكيز والتتبع', Icons.track_changes_rounded, [
            _bullet('لا كوكيز خارجية', 'لا نستخدم كوكيز تتبع إعلانية.'),
            _bullet('Firebase Analytics', 'نستخدم تحليلات مجهولة لفهم كيف يُستخدم التطبيق وتحسينه.'),
          ]),

          _section('8. الأطفال', Icons.child_care_rounded, [
            _bullet('العمر المسموح', 'التطبيق موجّه للمستخدمين الذين يبلغون 13 عاماً أو أكثر.'),
            _bullet('الحماية', 'لا نجمع بيانات الأطفال دون الـ 13 عمداً.'),
          ]),

          _section('9. تغييرات السياسة', Icons.update_rounded, [
            _bullet('الإشعار', 'سيتم إخطارك بأي تغييرات جوهرية عبر إشعار داخل التطبيق.'),
            _bullet('الاستمرار', 'استمرار استخدامك للتطبيق بعد التحديث يعني موافقتك على السياسة الجديدة.'),
          ]),

          const SizedBox(height: 24),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CExtra.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تواصل معنا', style: T.cairo(s: 14, w: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('إذا كان لديك أي استفسار عن سياسة الخصوصية:', style: T.body(c: CC.textSec)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  final wa = RC.whatsapp;
                  if (wa.isNotEmpty) launchUrl(Uri.parse('https://wa.me/$wa'), mode: LaunchMode.externalApplication);
                },
                child: Row(children: [
                  const Icon(Icons.support_agent_rounded, color: Color(0xFF25D366), size: 18),
                  const SizedBox(width: 8),
                  Text('تواصل عبر واتساب', style: T.cairo(s: 13, c: const Color(0xFF25D366))),
                ])),
            ])),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: C.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: C.gold, size: 16)),
        const SizedBox(width: 10),
        Text(title, style: T.cairo(s: 14, w: FontWeight.w700)),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CExtra.border, width: 0.5)),
        child: Column(children: children)),
      const SizedBox(height: 16),
    ]);

  Widget _bullet(String title, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(color: C.gold, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: T.cairo(s: 12, w: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(desc, style: T.body(c: CC.textSec, s: 11), textDirection: TextDirection.rtl),
      ])),
    ]));
}

// ════════════════════════════════════════════════════════════════
//  DEVICES PAGE
// ════════════════════════════════════════════════════════════════
class _DevicesPage extends StatefulWidget {
  const _DevicesPage();
  @override State<_DevicesPage> createState() => _DevicesPageState();
}
class _DevicesPageState extends State<_DevicesPage> {
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final devs = (doc.data()?['devices'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() { _devices = devs; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _removeDevice(String deviceId) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    setState(() => _devices.removeWhere((d) => d['device_id'] == deviceId));
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'devices': _devices,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text('الأجهزة المتصلة', style: TExtra.h2())),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.gold))
          : _devices.isEmpty
              ? Center(child: Text('لا توجد أجهزة مسجّلة', style: T.body(c: CC.textSec)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: _devices.length,
                  itemBuilder: (ctx, i) {
                    final d = _devices[i];
                    final isThis = d['device_id'] == 'current';
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isThis ? C.gold.withOpacity(0.3) : CExtra.border)),
                      child: Row(children: [
                        Icon(d['platform'] == 'ios' ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
                            color: C.gold, size: 28),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d['model']?.toString() ?? 'جهاز غير معروف', style: T.cairo(s: 13, w: FontWeight.w600)),
                          Text(d['platform']?.toString() ?? '', style: T.caption(c: CC.textSec)),
                          if (isThis) Text('الجهاز الحالي', style: T.caption(c: C.gold)),
                        ])),
                        if (!isThis)
                          GestureDetector(
                            onTap: () => _removeDevice(d['device_id']?.toString() ?? ''),
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3))),
                              child: Text('إزالة', style: T.caption(c: Colors.redAccent)))),
                      ]));
                  }),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  ProfileEditPage
// ════════════════════════════════════════════════════════════════
class _ProfileEditPage extends StatefulWidget {
  const _ProfileEditPage();
  @override State<_ProfileEditPage> createState() => _ProfileEditPageState();
}
class _ProfileEditPageState extends State<_ProfileEditPage> {
  final _nameCtrl  = TextEditingController();
  final _photoCtrl = TextEditingController();
  bool _busy = false;
  @override void initState() {
    super.initState();
    _nameCtrl.text  = AuthService.currentUser?.displayName ?? '';
    _photoCtrl.text = AuthService.currentUser?.photoURL ?? '';
  }
  @override void dispose() { _nameCtrl.dispose(); _photoCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await AuthService.currentUser?.updateDisplayName(_nameCtrl.text.trim());
      if (_photoCtrl.text.trim().isNotEmpty) {
        await AuthService.currentUser?.updatePhotoURL(_photoCtrl.text.trim());
      }
      // Sync to Firestore
      final uid = AuthService.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'display_name': _nameCtrl.text.trim(),
          'photo_url': _photoCtrl.text.trim(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ ✓', style: T.cairo(s: 13, c: Colors.black)), backgroundColor: C.gold, behavior: SnackBarBehavior.floating)); Navigator.pop(context); }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: T.cairo(s: 12)), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = AuthService.currentUser?.photoURL ?? '';
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text('تعديل الملف الشخصي', style: TExtra.h2()),
        actions: [TextButton(onPressed: _busy ? null : _save, child: Text('حفظ', style: T.cairo(s: 14, c: C.gold, w: FontWeight.w700)))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        Center(child: CircleAvatar(radius: 50, backgroundColor: C.surface,
          backgroundImage: photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null,
          child: photo.isEmpty ? const Icon(Icons.person_rounded, size: 50, color: Colors.white24) : null)),
        const SizedBox(height: 24),
        _label('الاسم الكامل'),
        const SizedBox(height: 8),
        _field(_nameCtrl, 'أدخل اسمك'),
        const SizedBox(height: 16),
        _label('رابط صورة البروفايل (URL)'),
        const SizedBox(height: 8),
        _field(_photoCtrl, 'https://example.com/photo.jpg', type: TextInputType.url),
        const SizedBox(height: 28),
        if (_busy) const Center(child: CircularProgressIndicator(color: C.gold)),
      ])));
  }

  Widget _label(String t) => Align(alignment: Alignment.centerRight, child: Text(t, style: T.cairo(s: 13, c: CC.textSec)));
  Widget _field(TextEditingController c, String hint, {TextInputType? type}) => TextField(
    controller: c, keyboardType: type,
    style: T.cairo(s: 14),
    decoration: InputDecoration(hintText: hint, hintStyle: T.cairo(s: 13, c: Colors.white38),
      filled: true, fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CExtra.border, width: 0.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CExtra.border, width: 0.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.gold, width: 1))));
}

// ════════════════════════════════════════════════════════════════
//  SETTINGS PAGE
// ════════════════════════════════════════════════════════════════
class _SettingsPage extends StatefulWidget {
  const _SettingsPage();
  @override State<_SettingsPage> createState() => _SettingsPageState();
}
class _SettingsPageState extends State<_SettingsPage> {
  bool _notifs  = true;
  bool _autoPlay= true;
  String _quality = 'auto';
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() {
        _notifs   = p.getBool('pref_notifs') ?? true;
        _autoPlay = p.getBool('pref_autoplay') ?? true;
        _quality  = p.getString('pref_quality') ?? 'auto';
      });
    });
  }
  void _save(String key, dynamic value) {
    SharedPreferences.getInstance().then((p) {
      if (value is bool) p.setBool(key, value);
      if (value is String) p.setString(key, value);
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text('الإعدادات', style: TExtra.h2())),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _sTitle('المشاهدة'),
        _toggle('التشغيل التلقائي', 'تشغيل العنصر التالي تلقائياً', _autoPlay, (v) {
          setState(() => _autoPlay = v); _save('pref_autoplay', v);
        }),
        _divider(),
        _selectRow('جودة البث الافتراضية', _quality, ['auto','sd','hd','fhd'],
            ['تلقائي','SD (480p)','HD (720p)','FHD (1080p)'], (v) {
          setState(() => _quality = v); _save('pref_quality', v);
        }),
        const SizedBox(height: 20),
        _sTitle('الإشعارات'),
        _toggle('إشعارات التطبيق', 'تلقي إشعارات الاشتراك والتحديثات', _notifs, (v) {
          setState(() => _notifs = v); _save('pref_notifs', v);
        }),
        const SizedBox(height: 20),
        _sTitle('التخزين'),
        _actionRow('مسح ذاكرة التخزين المؤقت', Icons.cleaning_services_rounded, C.gold, () async {
          final p = await SharedPreferences.getInstance();
          await p.remove('wh_history_v1'); await p.remove('wh_progress_v1');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم المسح ✓', style: T.cairo(s: 12, c: Colors.black)), backgroundColor: C.gold, behavior: SnackBarBehavior.floating));
        }),
        _divider(),
        _actionRow('مسح قائمة المشاهدة', Icons.playlist_remove_rounded, Colors.orange, () async {
          final p = await SharedPreferences.getInstance();
          await p.remove('wl_items_v1');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم المسح ✓', style: T.cairo(s: 12, c: Colors.black)), backgroundColor: C.gold, behavior: SnackBarBehavior.floating));
        }),
      ]));
  }
  Widget _sTitle(String t) => Padding(padding: const EdgeInsets.fromLTRB(4,0,4,10),
    child: Text(t, style: T.caption(c: Colors.white38).copyWith(letterSpacing: 1.0, fontWeight: FontWeight.w600)));
  Widget _divider() => Divider(height: 1, color: CExtra.border.withOpacity(0.5), indent: 16, endIndent: 16);
  Widget _toggle(String title, String sub, bool val, Function(bool) onChange) =>
    Container(color: C.surface, child: SwitchListTile(
      title: Text(title, style: T.cairo(s: 13, w: FontWeight.w600)),
      subtitle: Text(sub, style: T.caption(c: CC.textSec)),
      value: val, onChanged: onChange,
      activeColor: C.gold, inactiveThumbColor: C.dim, inactiveTrackColor: C.surface));
  Widget _selectRow(String title, String current, List<String> vals, List<String> labels, Function(String) onSelect) =>
    Container(color: C.surface, child: ListTile(
      title: Text(title, style: T.cairo(s: 13, w: FontWeight.w600)),
      trailing: DropdownButton<String>(value: current, dropdownColor: C.surface, underline: const SizedBox(),
        style: T.cairo(s: 12, c: C.gold),
        items: List.generate(vals.length, (i) => DropdownMenuItem(value: vals[i], child: Text(labels[i]))),
        onChanged: (v) { if (v != null) onSelect(v); })));
  Widget _actionRow(String title, IconData icon, Color color, VoidCallback onTap) =>
    ListTile(tileColor: C.surface, leading: Icon(icon, color: color, size: 20),
      title: Text(title, style: T.cairo(s: 13, w: FontWeight.w600, c: color)), onTap: onTap);
}

// ════════════════════════════════════════════════════════════════
//  SECURITY PAGE
// ════════════════════════════════════════════════════════════════
class _SecurityPage extends StatelessWidget {
  const _SecurityPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text('الأمان والخصوصية', style: TExtra.h2())),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _item(context, Icons.lock_reset_rounded, 'تغيير كلمة المرور', 'أرسل رابط إعادة تعيين', Colors.blueAccent, () async {
          final email = AuthService.currentUser?.email;
          if (email == null) return;
          try {
            await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال رابط التغيير إلى $email', style: T.cairo(s: 12, c: Colors.black)), backgroundColor: C.gold, behavior: SnackBarBehavior.floating));
          } catch (_) {}
        }),
        const SizedBox(height: 10),
        _item(context, Icons.delete_outline_rounded, 'حذف الحساب', 'حذف جميع البيانات نهائياً', Colors.red, () async {
          final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
            backgroundColor: C.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('حذف الحساب', style: T.cairo(s: 16, w: FontWeight.w700, c: Colors.red)),
            content: Text('سيتم حذف حسابك وجميع بياناتك بشكل نهائي. هذا الإجراء لا يمكن التراجع عنه.', style: T.body()),
            actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: T.cairo(s: 13, c: C.grey))),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: Text('حذف نهائياً', style: T.cairo(s: 13, c: Colors.white)))]));
          if (ok == true) {
            try {
              final uid = AuthService.currentUser?.uid;
              if (uid != null) await FirebaseFirestore.instance.collection('users').doc(uid).delete();
              await AuthService.currentUser?.delete();
              if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            } catch (_) {}
          }
        }),
      ]));
  }
  Widget _item(BuildContext ctx, IconData icon, String title, String sub, Color color, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.cairo(s: 13, w: FontWeight.w600, c: color)),
          Text(sub, style: T.caption(c: CC.textSec)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withOpacity(0.5)),
      ])));
}

// ════════════════════════════════════════════════════════════════
//  TOTV SERVER PAGE stub — kept from original
// ════════════════════════════════════════════════════════════════
class _TOTVServerPage extends StatefulWidget {
  const _TOTVServerPage();
  @override State<_TOTVServerPage> createState() => _TOTVServerPageState();
}
class _TOTVServerPageState extends State<_TOTVServerPage> {
  final _hostCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false, _ok = false;
  String _msg = '';

  @override void initState() {
    super.initState();
    _hostCtrl.text = RC.serverHost;
    _userCtrl.text = Sub.username;
    _passCtrl.text = Sub.password;
  }
  @override void dispose() { _hostCtrl.dispose(); _userCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _connect() async {
    setState(() { _busy = true; _msg = ''; });
    final res = await Sub.activate(username: _userCtrl.text.trim(), password: _passCtrl.text.trim());
    if (!mounted) return;
    setState(() { _busy = false; _ok = res.ok; _msg = res.msg; });
    if (res.ok) AppState.loadAll(force: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text('سيرفر Xtream', style: TExtra.h2())),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        _f(_userCtrl, 'اسم المستخدم'),
        const SizedBox(height: 12),
        _f(_passCtrl, 'كلمة المرور', ob: true),
        const SizedBox(height: 24),
        GestureDetector(onTap: _busy ? null : _connect,
          child: Container(height: 50, decoration: BoxDecoration(gradient: _busy ? null : C.playGrad, color: _busy ? C.surface : null, borderRadius: BorderRadius.circular(12)),
            child: Center(child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: C.gold, strokeWidth: 2)) : Text('اتصال', style: T.cairo(s: 15, c: Colors.black, w: FontWeight.w800))))),
        if (_msg.isNotEmpty) ...[const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _ok ? CC.success.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _ok ? CC.success.withOpacity(0.3) : Colors.red.withOpacity(0.3))),
            child: Text(_msg, style: T.body(c: _ok ? CC.success : Colors.redAccent)))],
      ])));
  }
  Widget _f(TextEditingController c, String hint, {bool ob = false}) => TextField(controller: c, obscureText: ob,
    style: T.cairo(s: 14), decoration: InputDecoration(hintText: hint, hintStyle: T.cairo(s: 13, c: Colors.white38), filled: true, fillColor: C.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CExtra.border, width: 0.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CExtra.border, width: 0.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.gold, width: 1))));
}

// ════════════════════════════════════════════════════════════════
//  AI SUPPORT PAGE stub
// ════════════════════════════════════════════════════════════════
class _AISupportPage extends StatelessWidget {
  const _AISupportPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => Navigator.pop(context)),
        title: Text('مساعد TOTV+', style: TExtra.h2())),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, gradient: CC.goldGrad),
          child: const Icon(Icons.smart_toy_rounded, color: Colors.black, size: 40)),
        const SizedBox(height: 20),
        Text('مساعد TOTV+ الذكي', style: T.cairo(s: 18, w: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('قريباً — سيتوفر الدعم الذكي قريباً', style: T.body(c: CC.textSec)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            final wa = RC.whatsapp;
            if (wa.isNotEmpty) launchUrl(Uri.parse('https://wa.me/$wa'), mode: LaunchMode.externalApplication);
          },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(12)),
            child: Text('تواصل مع الدعم البشري', style: T.cairo(s: 14, c: Colors.black, w: FontWeight.w700)))),
      ])));
  }
}

// BannedPage defined in splash_shell.dart
