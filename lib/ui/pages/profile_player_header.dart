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
    final pColor = isPaid ? C.gold : C.textDim;
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
                boxShadow: [BoxShadow(color: pColor.withOpacity(0.3), blurRadius: FS.lg)]),
              child: ClipOval(child: photo.isNotEmpty
                ? CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover)
                : Container(color: C.surface,
                    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TExtra.mont(s: FS.x2l, w: FontWeight.w900, c: pColor)))))),
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
            Text(name, style: T.cairo(s: FS.lg, w: FontWeight.w900),
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
          borderRadius: BorderRadius.circular(R.xl),
          border: Border.all(color: C.gold.withOpacity(0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.workspace_premium_rounded, size: 12, color: C.gold),
          const SizedBox(width: 5),
          Text('TOTV+ Premium', style: TExtra.mont(s: FS.sm, c: C.gold, w: FontWeight.w700)),
        ]));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(R.xl),
        border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: Text('مجاني', style: TExtra.mont(s: FS.sm, c: Colors.white54, w: FontWeight.w600)));
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
          colors: [C.goldBg, C.surface],
          begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(R.xl),
        border: Border.all(color: C.gold.withOpacity(0.35), width: 1.2),
        boxShadow: [BoxShadow(color: C.gold.withOpacity(0.08), blurRadius: FS.xl)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: C.gold.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('اشتراك TOTV+ نشط', style: T.cairo(s: FS.md, w: FontWeight.w800, c: C.gold)),
            Text('مشاهدة غير محدودة', style: T.caption(c: CC.textSec)),
          ])),
          if (expiring) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(R.xl),
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
        ClipRRect(borderRadius: BorderRadius.circular(R.tiny),
          child: LinearProgressIndicator(value: progress, backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(expiring ? Colors.orange : C.gold), minHeight: 5)),
        const SizedBox(height: 14),
        // ★ معلومات السيرفر
        FutureBuilder<Map<String, String>>(
          future: Sub.getServerInfo(),
          builder: (_, snap) {
            final info = snap.data ?? {};
            if (info.isEmpty) return const SizedBox.shrink();
            final maxConn    = info['max_connections'] ?? '1';
            final activeConn = info['active_connections'] ?? '0';
            final status     = info['status'] ?? 'Active';
            final isTrial    = info['is_trial'] == '1';
            return Column(children: [
              Divider(color: Colors.white.withOpacity(0.07)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.dns_rounded, color: Colors.white30, size: 14),
                const SizedBox(width: 6),
                Text('معلومات السيرفر', style: T.caption(c: CC.textSec)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _serverChip('الحالة', status, C.green),
                const SizedBox(width: 8),
                _serverChip('الأجهزة', '$activeConn/$maxConn', C.gold),
                if (isTrial) ...[const SizedBox(width: 8),
                  _serverChip('تجريبي', '⏱', Colors.orange)],
              ]),
              const SizedBox(height: 8),
            ]);
          }),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip('∞ مشاهدة'), _chip('4K جودة'), _chip('كل القنوات'), _chip('بلا إعلانات'),
        ]),
        if (expiring) ...[ const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _openUrl(RC.buyUrl.isNotEmpty ? RC.buyUrl : AppUrls.payment),
            child: Container(width: double.infinity, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange, Colors.orange.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(R.md)),
              child: Center(child: Text('تجديد الاشتراك الآن',
                  style: T.cairo(s: FS.md, w: FontWeight.w800, c: Colors.black))))),
        ],
      ]));
  }

  Widget _serverChip(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(R.xl),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: T.caption(c: CC.textSec)),
      const SizedBox(width: 4),
      Text(value, style: T.cairo(s: FS.sm, w: FontWeight.w700, c: color)),
    ]));

  Widget _freeCard(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
      border: Border.all(color: Colors.white.withOpacity(0.07))),
    child: Column(children: [
      Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
          child: const Icon(Icons.lock_open_rounded, color: C.textDim, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الباقة المجانية', style: T.cairo(s: FS.md, w: FontWeight.w700)),
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
          decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md),
            boxShadow: [BoxShadow(color: C.gold.withOpacity(0.2), blurRadius: FS.sm, offset: const Offset(0,4))]),
          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 16),
            const SizedBox(width: 8),
            Text('ترقية للـ Premium', style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black)),
          ])))),
    ]));

  Widget _dateInfo(String l, String v, {bool highlight = false}) => Column(children: [
    Text(l, style: T.caption(c: CC.textSec), textAlign: TextAlign.center),
    const SizedBox(height: 3),
    Text(v, style: T.cairo(s: FS.sm, w: FontWeight.w700, c: highlight ? C.gold : Colors.white),
        textAlign: TextAlign.center),
  ]);

  Widget _chip(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: C.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(R.xl),
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
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: expired ? Colors.red.withOpacity(0.25) : C.gold.withOpacity(0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.timer_outlined, color: expired ? Colors.red : C.gold, size: 16),
            const SizedBox(width: 8),
            Text('وقت المشاهدة اليومي', style: T.cairo(s: FS.sm, w: FontWeight.w700)),
            const Spacer(),
            Text(GuestSession.remainingStr,
                style: TExtra.mont(s: FS.md, w: FontWeight.w800, c: expired ? Colors.red : C.gold)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(R.tiny),
            child: LinearProgressIndicator(value: frac.clamp(0.0, 1.0),
              backgroundColor: Colors.white10, color: expired ? Colors.red : C.gold, minHeight: 4)),
          if (expired) ...[ const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _push(const SubscriptionPage()),
              child: Container(height: 36, decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.sm)),
                child: Center(child: Text('اشترك للمشاهدة غير المحدودة',
                    style: T.cairo(s: FS.sm, w: FontWeight.w700, c: Colors.black))))),
          ],
        ]));
    });

  Widget _guestCard(BuildContext ctx) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
      border: Border.all(color: Colors.white.withOpacity(0.07))),
    child: Column(children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle),
        child: const Icon(Icons.person_outline_rounded, size: 28, color: C.textDim.withOpacity(0.24))),
      const SizedBox(height: 12),
      Text('تسجيل الدخول', style: T.cairo(s: FS.lg, w: FontWeight.w700)),
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
        child: Container(height: 46, decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md)),
          child: Center(child: Text('تسجيل الدخول مجاناً',
              style: T.cairo(s: FS.md, w: FontWeight.w800, c: Colors.black))))),
    ]));

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(right: 2, bottom: 0),
    child: Row(children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(R.tiny))),
      const SizedBox(width: 8),
      Text(t, style: T.caption(c: C.textDim).copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700)),
    ]));

  Widget _menuGroup(List<Widget> items) => Container(
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
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
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: Icon(icon, size: 17, color: C.gold)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.cairo(s: FS.md, w: FontWeight.w600)),
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
      decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md)),
      child: Center(child: Text('تسجيل الدخول',
          style: T.cairo(s: FS.lg, w: FontWeight.w800, c: Colors.black)))));

  Widget _logoutBtn() => GestureDetector(
    onTap: () async {
      final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
        title: Text('تسجيل الخروج', style: T.cairo(s: FS.lg, w: FontWeight.w700)),
        content: Text('هل تريد تسجيل الخروج؟', style: T.body()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: T.cairo(s: FS.md, c: C.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.sm))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('خروج', style: T.cairo(s: FS.md, c: C.textPri, w: FontWeight.w700))),
        ]));
      if (ok == true) { await Sub.logout(); GuestSession.reset(); if (mounted) setState(() {}); }
    },
    child: Container(height: 48,
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: Colors.red.withOpacity(0.2))),
      child: Center(child: Text('تسجيل الخروج',
          style: T.cairo(s: FS.md, w: FontWeight.w600, c: Colors.redAccent)))));

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
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: C.gold.withOpacity(0.4), width: 1.2),
          boxShadow: [BoxShadow(color: C.gold.withOpacity(0.07), blurRadius: FS.lg)]),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.gold.withOpacity(0.2), C.gold.withOpacity(0.08)]),
              shape: BoxShape.circle,
              border: Border.all(color: C.gold.withOpacity(0.3))),
            child: const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('خطط الاشتراك TOTV+', style: T.cairo(s: FS.md, w: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('شهري • 3 أشهر • سنوي — اضغط لعرض الخطط',
                style: T.caption(c: CC.textSec)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md)),
            child: Text('اشترك', style: T.cairo(s: FS.sm, w: FontWeight.w800, c: Colors.black))),
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
          color: C.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          // Handle
          Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4, decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(R.tiny)))),
          // Hero بوسترات
          Stack(children: [
            if (posters.isNotEmpty)
              SizedBox(height: 110, child: Row(children: posters.map((u) =>
                Expanded(child: CachedNetworkImage(imageUrl: u, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: C.surface),
                  placeholder: (_, __) => Container(color: C.surface)))).toList())),
            Container(height: 110, decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.5), C.bg]))),
            Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: C.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(R.xl),
                    border: Border.all(color: C.gold.withOpacity(0.4))),
                  child: Text('TOTV+ Premium', style: TExtra.mont(s: FS.xs, c: C.gold, w: FontWeight.w700))),
                const SizedBox(height: 6),
                Text('اختر خطتك', style: T.cairo(s: FS.xl, w: FontWeight.w900)),
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
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
                  border: Border.all(color: Colors.white.withOpacity(0.06))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('كل الخطط تشمل:', style: T.cairo(s: FS.sm, w: FontWeight.w700, c: C.gold)),
                  const SizedBox(height: 8),
                  ...[
                    'جميع القنوات والأفلام والمسلسلات',
                    'SD / HD / FHD / 4K',
                    'ذكاء اصطناعي لاختيار المحتوى',
                    'بدون إعلانات — دعم فني 24/7',
                  ].map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, color: C.gold, size: 13),
                      const SizedBox(width: 8),
                      Text(f, style: T.cairo(s: FS.sm, c: Colors.white70)),
                    ]),
                  )),
                ])),
            ]),
          ),
        ]),
      ),
    );
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
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: color.withOpacity(popular ? 0.5 : 0.2), width: popular ? 1.5 : 1),
          boxShadow: popular ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: FS.lg)] : null),
        child: Row(children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(R.md)),
            child: Center(child: Text(plan['title'] as String,
              style: T.cairo(s: FS.sm, w: FontWeight.w900, c: color), textAlign: TextAlign.center))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('اشتراك ${plan['title']}', style: T.cairo(s: FS.md, w: FontWeight.w700)),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(R.sm),
                  border: Border.all(color: color.withOpacity(0.3))),
                child: Text(plan['badge'] as String, style: TExtra.mont(s: 8, c: color, w: FontWeight.w700))),
            ]),
            const SizedBox(height: 2),
            Text('${plan['devices']} ${plan['devices']==1?"جهاز":"جهازان"} • كل الأجهزة',
                style: T.caption(c: CC.textSec)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ShaderMask(shaderCallback: (r) => LinearGradient(colors: [color, color.withOpacity(0.7)]).createShader(r),
              child: Text(plan['price'] as String, style: TExtra.mont(s: FS.lg, w: FontWeight.w900, c: C.textPri))),
            Text('د.ع${plan['period']}', style: TExtra.mont(s: FS.xs, c: color.withOpacity(0.8))),
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
          color: C.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 2),
            width: 36, height: 4, decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(R.tiny)))),
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
        onTap: () {
          if (_step > 0 && _step < 2) {
            setState(() { _step--; _method = null; _err = ''; });
          } else {
            Navigator.pop(context);
          }
        },
        child: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: C.surface, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.white54))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إتمام الشراء', style: T.cairo(s: FS.lg, w: FontWeight.w800)),
        Text('${widget.plan['title']} — ${widget.plan['price']} د.ع', style: T.caption(c: _ac)),
      ])),
      // step indicator
      Row(children: List.generate(3, (i) => Container(
        width: i == _step ? 20 : 6, height: 6, margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: i == _step ? _ac : i < _step ? _ac.withOpacity(0.4) : Colors.white12,
          borderRadius: BorderRadius.circular(R.tiny))))),
    ]));

  // ── Step 0: اختيار طريقة الدفع ──────────────────────────────
  Widget _buildStep0() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('اختر طريقة الدفع', style: T.cairo(s: FS.lg, w: FontWeight.w900)),
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
    _mCard('website', '🌐', 'موقعنا الإلكتروني', 'اشترِ عبر موقعنا الرسمي', 'آمن 🔒', C.green),
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
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: FS.xl)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: T.cairo(s: FS.md, w: FontWeight.w700)),
              if (badge != null) ...[ const SizedBox(width: 7),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: bc.withOpacity(0.15), borderRadius: BorderRadius.circular(R.sm),
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
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: _ac.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: T.cairo(s: FS.md, w: FontWeight.w700, c: _ac)),
            const Spacer(),
            ShaderMask(shaderCallback: (r) => LinearGradient(colors: [_ac, _ac.withOpacity(0.7)]).createShader(r),
              child: Text('${widget.plan['price']} د.ع',
                  style: TExtra.mont(s: FS.lg, w: FontWeight.w900, c: C.textPri))),
          ]),
          const SizedBox(height: 12),
          _infoTile('رقم الحساب', num, copy: true),
          if (!isKey) _infoTile('اسم المستلم', _fibName),
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.07),
              borderRadius: BorderRadius.circular(R.sm),
              border: Border.all(color: Colors.orange.withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 13),
              const SizedBox(width: 8),
              Expanded(child: Text('حوّل المبلغ كاملاً ثم أرسل بياناتك أدناه',
                  style: T.cairo(s: FS.sm, c: Colors.orange.withOpacity(0.9)))),
            ])),
        ])),
      const SizedBox(height: 18),
      Text('بياناتك', style: T.cairo(s: FS.lg, w: FontWeight.w800)),
      const SizedBox(height: 10),
      _tf(_nameCtrl,  'اسمك الكامل',    Icons.person_outline_rounded),
      const SizedBox(height: 8),
      _tf(_phoneCtrl, 'رقم هاتفك',      Icons.phone_outlined, type: TextInputType.phone),
      const SizedBox(height: 8),
      // نوع الخطة (readonly)
      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 17),
          const SizedBox(width: 10),
          Text('اشتراك ${widget.plan['title']} — ${widget.plan['price']} د.ع',
              style: T.cairo(s: FS.sm, w: FontWeight.w600)),
        ])),
      if (_err.isNotEmpty) ...[ const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.07),
            borderRadius: BorderRadius.circular(R.sm),
            border: Border.all(color: Colors.red.withOpacity(0.25))),
          child: Text(_err, style: T.cairo(s: FS.sm, c: Colors.redAccent))),
      ],
      const SizedBox(height: 18),
      GestureDetector(
        onTap: _busy ? null : _submit,
        child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: _busy ? null : LinearGradient(colors: [_ac, _ac.withOpacity(0.7)]),
            color: _busy ? C.surface : null,
            borderRadius: BorderRadius.circular(R.md),
            boxShadow: _busy ? null : [BoxShadow(color: _ac.withOpacity(0.3), blurRadius: FS.md, offset: const Offset(0,4))]),
          child: Center(child: _busy
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: C.gold, strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                const SizedBox(width: 8),
                Text('إرسال الطلب', style: T.cairo(s: FS.lg, w: FontWeight.w900, c: Colors.black)),
              ])))),
    ]);
  }

  Widget _infoTile(String label, String value, {bool copy = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text('$label: ', style: T.caption(c: CC.textSec)),
      Expanded(child: Text(value, style: T.cairo(s: FS.md, w: FontWeight.w700))),
      if (copy) GestureDetector(
        onTap: () { Clipboard.setData(ClipboardData(text: value)); Sound.hapticL();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تم النسخ ✓', style: T.cairo(s: FS.sm)),
            duration: const Duration(seconds: 1), backgroundColor: C.surface,
            behavior: SnackBarBehavior.floating)); },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: C.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(R.sm)),
          child: Text('نسخ', style: T.cairo(s: FS.sm, c: C.gold)))),
    ]));

  Widget _tf(TextEditingController c, String hint, IconData icon, {TextInputType? type}) =>
    TextField(controller: c, keyboardType: type, textDirection: TextDirection.rtl,
      style: T.cairo(s: FS.md, c: C.textPri),
      decoration: InputDecoration(
        hintText: hint, hintStyle: T.cairo(s: FS.sm, c: Colors.white30),
        prefixIcon: Icon(icon, size: 17, color: Colors.white30),
        filled: true, fillColor: C.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md),
          borderSide: const BorderSide(color: C.card)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md),
          borderSide: const BorderSide(color: C.card)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md),
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
    } catch (e) { debugPrint('[profile_player_header] $e'); }

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
      await DioClient.telegram.post(
        'https://api.telegram.org/bot$_tgBotToken/sendMessage',
        data: {'chat_id': _tgChatId, 'text': msg, 'parse_mode': 'Markdown'},
      ).timeout(const Duration(seconds: 8));
    } catch (e) { debugPrint('[profile_player_header] $e'); }

    await Sound.hapticOk();
    if (mounted) setState(() { _busy = false; _step = 2; });
  }

  // ── Step 2: نجاح الإرسال ────────────────────────────────────
  Widget _buildStep2() => Column(children: [
    const SizedBox(height: 10),
    Container(width: 72, height: 72,
      decoration: BoxDecoration(
        color: C.green.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: C.green.withOpacity(0.5), width: 2)),
      child: const Icon(Icons.check_rounded, color: C.green, size: 38)),
    const SizedBox(height: 14),
    Text('تم إرسال طلبك!', style: T.cairo(s: FS.xl, w: FontWeight.w900), textAlign: TextAlign.center),
    const SizedBox(height: 6),
    Text('سيتم تفعيل اشتراكك خلال دقائق بعد التحقق',
        style: T.body(c: CC.textSec), textAlign: TextAlign.center),
    const SizedBox(height: 20),
    Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
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
      decoration: BoxDecoration(color: C.gold.withOpacity(0.06), borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: C.gold.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.vpn_key_rounded, color: C.gold, size: 15),
          const SizedBox(width: 8),
          Text('هل لديك كود تفعيل؟', style: T.cairo(s: FS.sm, w: FontWeight.w700, c: C.gold)),
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
            decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md)),
            child: Center(child: Text('تفعيل الاشتراك',
                style: T.cairo(s: FS.md, w: FontWeight.w800, c: Colors.black))))),
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
        decoration: BoxDecoration(color: C.whatsapp.withOpacity(0.07),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: C.whatsapp.withOpacity(0.25))),
        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.support_agent_rounded, color: C.whatsapp, size: 16),
          const SizedBox(width: 8),
          Text('تواصل مع الدعم', style: T.cairo(s: FS.md, c: C.whatsapp, w: FontWeight.w700)),
        ])))),
    const SizedBox(height: 8),
    TextButton(onPressed: () => Navigator.pop(context),
      child: Text('إغلاق', style: T.cairo(s: FS.md, c: C.textDim))),
  ]);

  Widget _cRow(String k, String v) => Padding(padding: const EdgeInsets.only(bottom: 7),
    child: Row(children: [
      Text(k, style: T.caption(c: CC.textSec)), const Spacer(),
      Text(v, style: T.cairo(s: FS.sm, w: FontWeight.w700)),
    ]));
}

class _PrivacyPolicyPage extends StatelessWidget {
  const _PrivacyPolicyPage();

  @override
  Widget build(BuildContext context) {
    final posters = <String>[];
    for (final m in AppState.allMovies.take(3)) {
      final u = m['stream_icon']?.toString() ?? '';
      if (u.isNotEmpty) posters.add(u);
    }
    final poster = posters.isNotEmpty ? posters.first : '';

    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(children: [
        // خلفية زجاجية من بوسترات الأفلام
        if (poster.isNotEmpty)
          Positioned.fill(child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover))),
        Positioned.fill(child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.85),
                Colors.black.withOpacity(0.95),
                Colors.black,
              ])))),
        SafeArea(child: Column(children: [
          // Header
          Padding(padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: C.textPri),
                onPressed: () => Navigator.pop(context)),
              Expanded(child: Text('سياسة الخصوصية',
                  style: T.cairo(s: FS.lg, w: FontWeight.w800))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: C.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(R.xl),
                  border: Border.all(color: C.gold.withOpacity(0.35))),
                child: Text('TOTV+', style: TExtra.mont(s: FS.xs, c: C.gold, w: FontWeight.w700))),
            ])),
          Divider(height: 1, color: Colors.white.withOpacity(0.07)),
          // Content
          Expanded(child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              _hero(context),
              const SizedBox(height: 28),
              _block('نظرة عامة',
                Icons.shield_outlined,
                'TOTV+ ملتزم بحماية خصوصيتك بالكامل. هذه الوثيقة توضح ما نجمعه ولماذا وكيف نستخدمه — بلغة واضحة وبسيطة.'),
              _block('ما نجمعه',
                Icons.folder_open_rounded,
                'نجمع معلوماتك عند إنشاء حساب: البريد الإلكتروني، اسم المستخدم، وصورة الملف الشخصي الاختيارية. بيانات الاستخدام مجهولة الهوية ومجمّعة فقط لتحسين الأداء.'),
              _block('كيف نستخدم بياناتك',
                Icons.tune_rounded,
                'نستخدم بياناتك لإدارة حسابك، تخصيص المحتوى المقترح، إرسال إشعارات الخدمة، ومنع الاحتيال. لا نستخدم بياناتك لأي أغراض إعلانية.'),
              _block('مشاركة البيانات',
                Icons.share_rounded,
                'لا نبيع أو نشارك معلوماتك الشخصية مع أطراف خارجية. نشارك فقط ما يلزم مع مزودي الخدمة الذين يساعدوننا في تشغيل المنصة، وجميعهم ملزمون باتفاقيات سرية صارمة.'),
              _block('الاحتفاظ بالبيانات',
                Icons.history_rounded,
                'نحتفظ ببياناتك طالما حسابك نشط. يمكنك طلب حذف حسابك وجميع بياناتك في أي وقت من خلال صفحة الإعدادات أو بمراسلة فريق الدعم.'),
              _block('الأمان',
                Icons.lock_outline_rounded,
                'نستخدم تشفير TLS لجميع البيانات المنقولة، ونطبق معايير أمنية عالية لحماية بياناتك المخزنة. تخضع أنظمتنا لمراجعات أمنية دورية.'),
              _block('ملفات تعريف الارتباط',
                Icons.cookie_outlined,
                'نستخدم ملفات تعريف ارتباط وظيفية ضرورية فقط لتشغيل التطبيق (مثل الجلسات وتفضيلات اللغة). لا نستخدم ملفات تتبع إعلانية.'),
              _block('حقوقك',
                Icons.person_pin_rounded,
                'لديك الحق في الوصول لبياناتك، تصحيحها، حذفها، أو تصديرها. للاستفسار عن أي من هذه الحقوق تواصل معنا عبر قسم الدعم في التطبيق.'),
              _block('التحديثات',
                Icons.update_rounded,
                'قد نحدّث هذه السياسة من وقت لآخر. سنخطرك بأي تغييرات جوهرية عبر البريد الإلكتروني أو إشعار داخل التطبيق قبل 30 يوماً من سريانها.'),
              const SizedBox(height: 8),
              // Contact
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(R.md),
                  border: Border.all(color: Colors.white.withOpacity(0.08))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.mail_outline_rounded, color: C.gold, size: 16),
                    const SizedBox(width: 8),
                    Text('تواصل مع فريق الخصوصية', style: T.cairo(s: FS.md, w: FontWeight.w700, c: C.gold)),
                  ]),
                  const SizedBox(height: 8),
                  Text('لأي استفسار متعلق بخصوصيتك، تواصل معنا عبر قسم الدعم الفني في التطبيق وسنرد خلال 48 ساعة.',
                      style: T.caption(c: CC.textSec)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      final wa = RC.whatsapp;
                      if (wa.isNotEmpty) launchUrl(Uri.parse('https://wa.me/${wa.replaceAll("+","")}'),
                          mode: LaunchMode.externalApplication);
                    },
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: C.whatsapp.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(R.md),
                        border: Border.all(color: C.whatsapp.withOpacity(0.3))),
                      child: Center(child: Text('تواصل معنا',
                          style: T.cairo(s: FS.md, c: C.whatsapp, w: FontWeight.w700))))),
                ])),
              const SizedBox(height: 12),
              Center(child: Text('آخر تحديث: أبريل 2026  •  TOTV+ v${AppVersion.version}',
                  style: T.caption(c: Colors.white.withOpacity(0.12)))),
            ])),
        ])),
      ]));
  }

  Widget _hero(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 52, height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [C.gold.withOpacity(0.2), C.gold.withOpacity(0.05)]),
        shape: BoxShape.circle,
        border: Border.all(color: C.gold.withOpacity(0.3))),
      child: const Icon(Icons.shield_rounded, color: C.gold, size: 24)),
    const SizedBox(height: 14),
    Text('خصوصيتك تعني لنا', style: T.cairo(s: FS.xl, w: FontWeight.w900)),
    const SizedBox(height: 6),
    Text('نحن لا نبيع بياناتك. أبداً.',
        style: T.cairo(s: FS.md, c: C.gold, w: FontWeight.w700)),
    const SizedBox(height: 8),
    Text('TOTV+ تؤمن بأن خصوصيتك حق أساسي، وليس خياراً.',
        style: T.body(c: CC.textSec)),
  ]);

  Widget _block(String title, IconData icon, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 38, height: 38, margin: const EdgeInsets.only(left: 14, top: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Icon(icon, color: C.gold, size: 18)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: T.cairo(s: FS.md, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(body, style: T.body(c: CC.textSec).copyWith(height: 1.6)),
      ])),
    ]));
}
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
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
                        border: Border.all(color: isThis ? C.gold.withOpacity(0.3) : CExtra.border)),
                      child: Row(children: [
                        Icon(d['platform'] == 'ios' ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
                            color: C.gold, size: 28),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d['model']?.toString() ?? 'جهاز غير معروف', style: T.cairo(s: FS.md, w: FontWeight.w600)),
                          Text(d['platform']?.toString() ?? '', style: T.caption(c: CC.textSec)),
                          if (isThis) Text('الجهاز الحالي', style: T.caption(c: C.gold)),
                        ])),
                        if (!isThis)
                          GestureDetector(
                            onTap: () => _removeDevice(d['device_id']?.toString() ?? ''),
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(R.sm),
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
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحفظ ✓', style: T.cairo(s: FS.md, c: Colors.black)), backgroundColor: C.gold, behavior: SnackBarBehavior.floating)); Navigator.pop(context); }
    } catch (e) {
      setState(() => _busy = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: T.cairo(s: FS.sm)), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
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
        actions: [TextButton(onPressed: _busy ? null : _save, child: Text('حفظ', style: T.cairo(s: FS.md, c: C.gold, w: FontWeight.w700)))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        Center(child: CircleAvatar(radius: 50, backgroundColor: C.surface,
          backgroundImage: photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null,
          child: photo.isEmpty ? const Icon(Icons.person_rounded, size: 50, color: C.textDim.withOpacity(0.24)) : null)),
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

  Widget _label(String t) => Align(alignment: Alignment.centerRight, child: Text(t, style: T.cairo(s: FS.md, c: CC.textSec)));
  Widget _field(TextEditingController c, String hint, {TextInputType? type}) => TextField(
    controller: c, keyboardType: type,
    style: T.cairo(s: FS.md),
    decoration: InputDecoration(hintText: hint, hintStyle: T.cairo(s: FS.md, c: C.textDim),
      filled: true, fillColor: C.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: const BorderSide(color: CExtra.border, width: 0.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: const BorderSide(color: CExtra.border, width: 0.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: const BorderSide(color: C.gold, width: 1))));
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
    SPref.i.then((p) {
      if (mounted) setState(() {
        _notifs   = p.getBool('pref_notifs') ?? true;
        _autoPlay = p.getBool('pref_autoplay') ?? true;
        _quality  = p.getString('pref_quality') ?? 'auto';
      });
    });
  }
  void _save(String key, dynamic value) {
    SPref.i.then((p) {
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
          final p = await SPref.i;
          await p.remove('wh_history_v1'); await p.remove('wh_progress_v1');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم المسح ✓', style: T.cairo(s: FS.sm, c: Colors.black)), backgroundColor: C.gold, behavior: SnackBarBehavior.floating));
        }),
        _divider(),
        _actionRow('مسح قائمة المشاهدة', Icons.playlist_remove_rounded, Colors.orange, () async {
          final p = await SPref.i;
          await p.remove('wl_items_v1');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم المسح ✓', style: T.cairo(s: FS.sm, c: Colors.black)), backgroundColor: C.gold, behavior: SnackBarBehavior.floating));
        }),
      ]));
  }
  Widget _sTitle(String t) => Padding(padding: const EdgeInsets.fromLTRB(4,0,4,10),
    child: Text(t, style: T.caption(c: C.textDim).copyWith(letterSpacing: 1.0, fontWeight: FontWeight.w600)));
  Widget _divider() => Divider(height: 1, color: CExtra.border.withOpacity(0.5), indent: 16, endIndent: 16);
  Widget _toggle(String title, String sub, bool val, Function(bool) onChange) =>
    Container(color: C.surface, child: SwitchListTile(
      title: Text(title, style: T.cairo(s: FS.md, w: FontWeight.w600)),
      subtitle: Text(sub, style: T.caption(c: CC.textSec)),
      value: val, onChanged: onChange,
      activeColor: C.gold, inactiveThumbColor: C.dim, inactiveTrackColor: C.surface));
  Widget _selectRow(String title, String current, List<String> vals, List<String> labels, Function(String) onSelect) =>
    Container(color: C.surface, child: ListTile(
      title: Text(title, style: T.cairo(s: FS.md, w: FontWeight.w600)),
      trailing: DropdownButton<String>(value: current, dropdownColor: C.surface, underline: const SizedBox(),
        style: T.cairo(s: FS.sm, c: C.gold),
        items: List.generate(vals.length, (i) => DropdownMenuItem(value: vals[i], child: Text(labels[i]))),
        onChanged: (v) { if (v != null) onSelect(v); })));
  Widget _actionRow(String title, IconData icon, Color color, VoidCallback onTap) =>
    ListTile(tileColor: C.surface, leading: Icon(icon, color: color, size: 20),
      title: Text(title, style: T.cairo(s: FS.md, w: FontWeight.w600, c: color)), onTap: onTap);
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
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال رابط التغيير إلى $email', style: T.cairo(s: FS.sm, c: Colors.black)), backgroundColor: C.gold, behavior: SnackBarBehavior.floating));
          } catch (e) { debugPrint('[profile_player_header] $e'); }
        }),
        const SizedBox(height: 10),
        _item(context, Icons.delete_outline_rounded, 'حذف الحساب', 'حذف جميع البيانات نهائياً', Colors.red, () async {
          final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
            backgroundColor: C.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
            title: Text('حذف الحساب', style: T.cairo(s: FS.lg, w: FontWeight.w700, c: Colors.red)),
            content: Text('سيتم حذف حسابك وجميع بياناتك بشكل نهائي. هذا الإجراء لا يمكن التراجع عنه.', style: T.body()),
            actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: T.cairo(s: FS.md, c: C.grey))),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: Text('حذف نهائياً', style: T.cairo(s: FS.md, c: C.textPri)))]));
          if (ok == true) {
            try {
              final uid = AuthService.currentUser?.uid;
              if (uid != null) await FirebaseFirestore.instance.collection('users').doc(uid).delete();
              await AuthService.currentUser?.delete();
              if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            } catch (e) { debugPrint('[profile_player_header] $e'); }
          }
        }),
      ]));
  }
  Widget _item(BuildContext ctx, IconData icon, String title, String sub, Color color, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.cairo(s: FS.md, w: FontWeight.w600, c: color)),
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
          child: Container(height: 50, decoration: BoxDecoration(gradient: _busy ? null : C.playGrad, color: _busy ? C.surface : null, borderRadius: BorderRadius.circular(R.md)),
            child: Center(child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: C.gold, strokeWidth: 2)) : Text('اتصال', style: T.cairo(s: FS.lg, c: Colors.black, w: FontWeight.w800))))),
        if (_msg.isNotEmpty) ...[const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _ok ? CC.success.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(R.md), border: Border.all(color: _ok ? CC.success.withOpacity(0.3) : Colors.red.withOpacity(0.3))),
            child: Text(_msg, style: T.body(c: _ok ? CC.success : Colors.redAccent)))],
      ])));
  }
  Widget _f(TextEditingController c, String hint, {bool ob = false}) => TextField(controller: c, obscureText: ob,
    style: T.cairo(s: FS.md), decoration: InputDecoration(hintText: hint, hintStyle: T.cairo(s: FS.md, c: C.textDim), filled: true, fillColor: C.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: const BorderSide(color: CExtra.border, width: 0.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: const BorderSide(color: CExtra.border, width: 0.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: const BorderSide(color: C.gold, width: 1))));
}

// ════════════════════════════════════════════════════════════════
//  AI SUPPORT PAGE stub
// ════════════════════════════════════════════════════════════════
class _AISupportPage extends StatefulWidget {
  const _AISupportPage();
  @override State<_AISupportPage> createState() => _AISupportPageState();
}

class _AISupportPageState extends State<_AISupportPage> {
  final _scroll = ScrollController();
  final _input  = TextEditingController();
  final List<_Msg> _msgs = [];
  bool _typing = false;

  static const _tgBot  = '7929309914:AAGsv_xZFX1I-KvFQUd8_xtGAeubH2YiReE';
  static const _tgChat = '1418184484';

  static const _system = '''أنت مساعد TOTV+ الذكي والمتعاطف. قواعدك:
1. رد دائماً بالعربية بأسلوب واضح ومحترم
2. ردود موجزة (3-5 أسطر) إلا إذا طُلب شرح مفصّل
3. المعلومات الثابتة:
   - الأسعار: شهري 5,000 د.ع | 3 أشهر 13,000 | سنوي 45,000
   - FIB وسوبر كي: رقم 07714415816 (حيدر عصام)
   - كي: رقم 7065169257
4. للمشاكل التقنية: اقترح إعادة التشغيل أولاً ثم تغيير الجودة
5. إذا لم تعرف الجواب: وجّه للدعم البشري عبر واتساب
6. تعامل مع الأسئلة الغريبة أو المبهمة بطلب توضيح
7. لا تختلق معلومات غير موجودة عن التطبيق
8. إذا غضب المستخدم: تعاطف معه أولاً ثم ساعده
9. اللهجة العراقية مقبولة ومرحب بها''';

  @override
  void initState() {
    super.initState();
    _addBot('مرحبا! انا مساعد TOTV+ الذكي\n\nاستطيع مساعدتك في:\n- مشاكل الاشتراك والدفع\n- مشاكل البث التقنية\n- تفعيل الاشتراك\n- اي سؤال عن التطبيق\n\nاكتب سؤالك!');
  }

  @override
  void dispose() { _scroll.dispose(); _input.dispose(); super.dispose(); }

  void _addBot(String text) {
    setState(() => _msgs.add(_Msg(text: text, isUser: false)));
    _scrollDown();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  String? _localReply(String q) {
    final s = q.toLowerCase().trim();
    // تجاهل الرسائل الفارغة جداً أو غير المفهومة
    if (s.length < 2) return 'لم أفهم سؤالك، ممكن توضح أكثر؟ 😊';

    // ── تحيات ─────────────────────────────────────────
    if (_has(s, ['مرحبا','هلو','هاي','السلام','اهلا','هاي','hi','hello','hey']))
      return 'أهلاً وسهلاً! 👋\nأنا مساعد TOTV+ الذكي.\nكيف يمكنني مساعدتك اليوم؟';

    // ── أسعار واشتراك ─────────────────────────────────
    if (_has(s, ['سعر','بكم','بكم','كم سعر','كم يكلف','اشتراك','باقة','باقه','اسعار']))
      return 'أسعار TOTV+ 💰\n• شهري: 5,000 د.ع — جهاز واحد\n• 3 أشهر: 13,000 د.ع — جهازان\n• سنوي: 45,000 د.ع — جهازان\nجميع الجودات + بلا إعلانات ✅';

    // ── طرق الدفع ─────────────────────────────────────
    if (_has(s, ['fib','فيب','فب','دفع','ادفع','كيف ادفع','طريقة الدفع']))
      return 'الدفع عبر FIB 🏦\n1️⃣ حوّل المبلغ لـ: 07714415816\n   الاسم: حيدر عصام\n2️⃣ أرسل إيصال التحويل من صفحة الاشتراك\n✅ يتم التفعيل خلال دقائق';

    if (_has(s, ['سوبر كي','super','سوبر']))
      return 'الدفع عبر سوبر كي 📱\n• الرقم: 07714415816\n• الاسم: حيدر عصام\nبعد التحويل أرسل الإيصال وسيتم التفعيل فوراً ✅';

    if (_has(s, ['زين كاش','كاش','zcash']))
      return 'الدفع عبر زين كاش:\n• الرقم: 07714415816\n• الاسم: حيدر عصام\nأرسل الإيصال بعد التحويل ✅';

    if (s.contains('كي') && _has(s, ['كي','key cash','كاش']) && !_has(s, ['سوبر','super']))
      return 'الدفع عبر كي 🔑\n• الرقم: 7065169257\nبعد التحويل أرسل الإيصال من صفحة الاشتراك ✅';

    // ── تفعيل الاشتراك ────────────────────────────────
    if (_has(s, ['تفعيل','فعّل','فعل','اشترك','username','يوزر','كود التفعيل','تفعيل الاشتراك']))
      return 'تفعيل الاشتراك 🔐\n1️⃣ اذهب لـ حسابي\n2️⃣ اضغط "تفعيل الاشتراك"\n3️⃣ أدخل username و password\n4️⃣ اضغط "تفعيل اشتراكي"\n✅ يتفعل فوراً!';

    // ── مشاكل البث ───────────────────────────────────
    if (_has(s, ['توقف','يتوقف','بطيء','تقطع','تقطيع','لا يعمل','مو شغال','ما يشتغل','مشكلة','مشكله','بث','يبث']))
      return 'حل مشاكل البث 📺\n1️⃣ تحقق من سرعة الإنترنت (يحتاج 5Mbps+)\n2️⃣ خفّض جودة البث (SD أو HD)\n3️⃣ أغلق التطبيق وأعد فتحه\n4️⃣ تحقق من انتهاء اشتراكك\nإذا استمر → تواصل مع الدعم 🛠';

    // ── مشاكل تسجيل الدخول ───────────────────────────
    if (_has(s, ['ما يدخل','لا يدخل','تسجيل دخول','دخول','لوجن','login','ما تقبل']))
      return 'مشكلة تسجيل الدخول 🔑\n• تأكد من صحة البريد وكلمة المرور\n• جرب "نسيت كلمة المرور"\n• إذا لم تتذكر بريدك → تواصل مع الدعم 📞';

    // ── نسيان كلمة المرور ────────────────────────────
    if (_has(s, ['نسيت','نسيت كلمة','كلمة مرور','password','باسورد']))
      return 'استعادة كلمة المرور 🔄\n1️⃣ اضغط "تسجيل الدخول"\n2️⃣ اضغط "نسيت كلمة المرور"\n3️⃣ أدخل بريدك الإلكتروني\n4️⃣ افتح الرابط في بريدك ✅';

    // ── جودة البث ────────────────────────────────────
    if (_has(s, ['جودة','hd','4k','sd','fhd','كيفية تغيير الجودة']))
      return 'جودات البث المتاحة 🎬\n• SD — للإنترنت البطيء (2Mbps)\n• HD 720p — (5Mbps)\n• FHD 1080p — (10Mbps)\n• 4K — للمشتركين فقط (25Mbps)\nغيّر الجودة من ⚙️ أثناء التشغيل';

    // ── الأجهزة المدعومة ─────────────────────────────
    if (_has(s, ['جهاز','اجهزة','موبايل','تلفزيون','تي في','tv','ايفون','iphone','android','ios']))
      return 'الأجهزة المدعومة 📱\n• Android 5.0+\n• iOS 12+\n• Android TV / Google TV\n• Amazon Fire Stick\n\nالباقة الشهرية: جهاز واحد\nالبقية: جهازان';

    // ── الحساب ───────────────────────────────────────
    if (_has(s, ['حساب','اكونت','account','بروفايل','profile']))
      return 'لإدارة حسابك 👤\nاذهب لـ صفحة "حسابي" في التطبيق حيث يمكنك:\n• عرض معلومات اشتراكك\n• تغيير الإعدادات\n• التواصل مع الدعم';

    // ── الإلغاء والاسترداد ───────────────────────────
    if (_has(s, ['الغ','الغاء','استرداد','refund','ارجاع','استرجاع']))
      return 'الإلغاء والاسترداد 📋\nللإلغاء أو استرداد المبلغ تواصل مع الدعم خلال 24 ساعة من الاشتراك.\nسنعالج طلبك في أقرب وقت 🤝';

    // ── شكر ومجاملات ─────────────────────────────────
    if (_has(s, ['شكرا','شكراً','ممتاز','رائع','حلو','تمام','يسلمو','thanks','thank']))
      return 'العفو! سعيد بمساعدتك 😊\nإذا احتجت أي شيء آخر، أنا هنا دائماً!';

    // ── استفسارات غير مفهومة ─────────────────────────
    if (s.length < 5 || _has(s, ['؟','?','..','لا افهم','ايش']))
      return 'ممكن توضح سؤالك أكثر؟ 🤔\nمثلاً: "كيف أدفع؟" أو "سعر الاشتراك؟" أو "مشكلة في البث"';

    return null; // ذهب للـ API
  }

  bool _has(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _typing) return;
    _input.clear();
    Sound.hapticL();

    setState(() { _msgs.add(_Msg(text: text, isUser: true)); _typing = true; });
    _scrollDown();

    // 1. Local smart reply
    final local = _localReply(text);
    if (local != null) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() { _typing = false; _msgs.add(_Msg(text: local, isUser: false)); });
      _scrollDown();
      unawaited(_forwardTg(text, local));
      return;
    }

    // 2. Claude AI API
    try {
      final history = _msgs.length > 10 ? _msgs.sublist(_msgs.length - 10) : _msgs;
      final msgs = history.map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}).toList();
      msgs.add({'role': 'user', 'content': text});

      final res = await DioClient.instance.post(
        'https://api.anthropic.com/v1/messages',
        options: Options(headers: {
          'x-api-key': RC.aiKey.isNotEmpty ? RC.aiKey : '',
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        }),
        data: {'model': 'claude-haiku-4-5-20251001', 'max_tokens': 250, 'system': _system, 'messages': msgs},
      ).timeout(const Duration(seconds: 6));

      final blocks = res.data['content'] as List? ?? [];
      final reply  = blocks.firstWhere((b) => b['type'] == 'text', orElse: () => null)?['text']?.toString() ?? '';
      if (reply.isNotEmpty && mounted) {
        setState(() { _typing = false; _msgs.add(_Msg(text: reply, isUser: false)); });
        _scrollDown();
        unawaited(_forwardTg(text, reply));
        return;
      }
    } catch (e) { debugPrint('[profile_player_header] $e'); }

    // 3. Fallback
    final fb = 'شكرا على سؤالك!\nللمساعدة الفورية تواصل مع الدعم عبر الزر ادناه.';
    if (mounted) setState(() { _typing = false; _msgs.add(_Msg(text: fb, isUser: false)); });
    _scrollDown();
    unawaited(_forwardTg(text, fb));
  }

  Future<void> _forwardTg(String q, String a) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await DioClient.telegram.post(
        'https://api.telegram.org/bot$_tgBot/sendMessage',
        data: {
          'chat_id': _tgChat,
          'text': 'مساعد TOTV+\n'
            'المستخدم: ${user?.email ?? 'غير مسجل'}\n'
            'السؤال: $q\n'
            'الرد: $a\n'
            'الوقت: ${DateTime.now().toLocal().toString().substring(0,16)}',
        }).timeout(const Duration(seconds: 5));
    } catch (e) { debugPrint('[profile_player_header] $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final poster = AppState.allMovies.isNotEmpty
        ? (AppState.allMovies.first['stream_icon']?.toString() ?? '') : '';

    return Scaffold(
      backgroundColor: C.bg,
      body: Stack(children: [
        // Glassmorphism background
        if (poster.isNotEmpty)
          Positioned.fill(child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: C.bg)))),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.90))),

        SafeArea(child: Column(children: [
          // Header
          _buildHeader(context),
          Divider(height: 1, color: Colors.white.withOpacity(0.06), indent: 16, endIndent: 16),
          // Quick suggestions
          _buildChips(),
          // Chat
          Expanded(child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _msgs.length + (_typing ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _msgs.length) return const _TypingBubble();
              return _ChatBubble(msg: _msgs[i]);
            })),
          _buildInput(),
        ])),
      ]));
  }

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_rounded, size: 14, color: C.textPri))),
      const SizedBox(width: 12),
      Container(width: 36, height: 36,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: C.playGrad,
          boxShadow: [BoxShadow(color: C.gold.withOpacity(0.3), blurRadius: 8)]),
        child: const Icon(Icons.smart_toy_rounded, color: Colors.black, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مساعد TOTV+', style: T.cairo(s: FS.md, w: FontWeight.w800)),
        Row(children: [
          Container(width: 6, height: 6, margin: const EdgeInsets.only(left: 4),
            decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle)),
          Text('متصل', style: T.caption(c: C.green)),
        ]),
      ])),
      GestureDetector(
        onTap: () {
          // ★ يعمل دائماً — fallback لرقم الدعم الثابت
          final wa = RC.whatsapp.isNotEmpty
              ? RC.whatsapp.replaceAll('+', '')
              : '9647714415816'; // رقم الدعم الافتراضي
          final msg = Uri.encodeComponent('مرحباً، أحتاج مساعدة في تطبيق TOTV+');
          launchUrl(
            Uri.parse('https://wa.me/$wa?text=$msg'),
            mode: LaunchMode.externalApplication);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: C.whatsapp.withOpacity(0.1),
            borderRadius: BorderRadius.circular(R.xl),
            border: Border.all(color: C.whatsapp.withOpacity(0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.support_agent_rounded, color: C.whatsapp, size: 14),
            const SizedBox(width: 4),
            Text('بشري', style: T.cairo(s: FS.sm, c: C.whatsapp, w: FontWeight.w700)),
          ]))),
    ]));

  Widget _buildChips() => SizedBox(height: 36,
    child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
      children: ['الاسعار', 'مشكلة بث', 'الدفع', 'التفعيل', 'الاجهزة'].map((chip) =>
        GestureDetector(
          onTap: () { _input.text = chip; _send(); },
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(R.xl),
              border: Border.all(color: Colors.white.withOpacity(0.12))),
            child: Text(chip, style: T.cairo(s: FS.sm, c: Colors.white70))))).toList()));

  Widget _buildInput() => Container(
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(R.xl),
      border: Border.all(color: Colors.white.withOpacity(0.1))),
    child: Row(children: [
      Expanded(child: TextField(
        controller: _input,
        textDirection: TextDirection.rtl,
        style: T.cairo(s: FS.md, c: C.textPri),
        decoration: InputDecoration(
          hintText: 'اكتب سؤالك...',
          hintStyle: T.cairo(s: FS.sm, c: Colors.white30),
          border: InputBorder.none, isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8)),
        onSubmitted: (_) => _send())),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _send,
        child: Container(width: 34, height: 34,
          decoration: BoxDecoration(gradient: C.playGrad, shape: BoxShape.circle),
          child: const Icon(Icons.send_rounded, color: Colors.black, size: 16))),
    ]));
}

class _Msg {
  final String text;
  final bool isUser;
  const _Msg({required this.text, required this.isUser});
}

class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      mainAxisAlignment: msg.isUser ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!msg.isUser) ...[
          Container(width: 26, height: 26, margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: C.playGrad),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.black, size: 13)),
        ],
        Flexible(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: msg.isUser ? C.gold.withOpacity(0.15) : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
              bottomRight: Radius.circular(msg.isUser ? 4 : 16)),
            border: Border.all(
              color: msg.isUser ? C.gold.withOpacity(0.25) : Colors.white.withOpacity(0.07))),
          child: Text(msg.text,
            style: T.cairo(s: FS.sm, c: Colors.white.withOpacity(0.9)),
            textDirection: TextDirection.rtl))),
        if (msg.isUser) ...[
          const SizedBox(width: 6),
          Container(width: 26, height: 26,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, color: Colors.white30, size: 13)),
        ],
      ]));
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override State<_TypingBubble> createState() => _TypingBubbleState();
}
class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override void initState() { super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Container(width: 26, height: 26, margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: C.playGrad),
        child: const Icon(Icons.smart_toy_rounded, color: Colors.black, size: 13)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
        child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) =>
          AnimatedBuilder(animation: _c, builder: (_, __) => Container(
            width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: C.gold.withOpacity(0.3 + 0.7 * ((_c.value + i * 0.33) % 1.0)))))))),
    ]));
}


// BannedPage defined in splash_shell.dart