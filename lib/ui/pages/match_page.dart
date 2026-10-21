part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════
//  صفحة المباراة بأسلوب TOD
//  بوستر ← الشعاران والعنوان ← عدّاد ← التاريخ • الوقت • الملعب • البطولة
//  ← «منطقة المشجعين» و«اشتراك/شاهد» ← توقّع النتيجة واربح ← الإحصائيات
//  خفيفة: صورة واحدة مخزّنة، وعدّاد يعيد رسم نفسه فقط.
// ════════════════════════════════════════════════════════════════════
class MatchPage extends StatefulWidget {
  final FxMatch match;
  const MatchPage({super.key, required this.match});

  static void open(BuildContext context, FxMatch m) {
    Sound.nav();
    Navigator.push(context, _fade(MatchPage(match: m)));
  }

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  final _scroll = ScrollController();
  final _fansKey = GlobalKey();
  Timer? _phase;           // يعيد الرسم عند فتح/إغلاق التوقع فقط
  int _h = 0, _a = 0;
  (int, int)? _mine;
  PredStats _stats = const PredStats();
  bool _sending = false, _loadingStats = false;
  String _msg = '';

  FxMatch get m => widget.match;

  @override
  void initState() {
    super.initState();
    _init();
    _phase = Timer.periodic(const Duration(seconds: 15), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _phase?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final local = await Predictions.mine(m.id);
    if (!mounted) return;
    if (local != null) setState(() { _mine = local; _h = local.$1; _a = local.$2; });
    // الإحصائيات وتوقعي من القاعدة: فقط حين يكون التوقع مفتوحاً أو أُغلق حديثاً
    if (AuthService.currentUser != null && !Predictions.notYet(m) && m.secsToKick > -6 * 3600) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loadingStats = true);
    try {
      final r = await Predictions.fetch(m);
      if (!mounted) return;
      setState(() {
        _stats = r.stats;
        if (r.mine != null) { _mine = r.mine; _h = r.mine!.$1; _a = r.mine!.$2; }
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingStats = false);
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (AuthService.currentUser == null) {
      Navigator.push(context, _fade(const FirebaseLoginPage()));
      return;
    }
    setState(() { _sending = true; _msg = ''; });
    try {
      final st = await Predictions.submit(m, _h, _a);
      Sound.hapticOk();
      if (!mounted) return;
      setState(() { _mine = (_h, _a); _stats = st; _msg = ''; });
      SportsActions._toast(context, 'تم حفظ توقعك ✅  ${m.h.label} $_h - $_a ${m.a.label}');
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    }
    if (mounted) setState(() => _sending = false);
  }

  void _toFans() {
    final c = _fansKey.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  String get _poster {
    if (m.poster.isNotEmpty) return SportsFeed.url(m.poster);
    for (final p in SportsFeed.promos) { if (p.fixture == m.id) return p.img; }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final lg = SportsFeed.leagues[m.lg];
    final meta = [
      m.dateLabel,
      m.time,
      if (m.venue.isNotEmpty) m.venue,
      if (lg != null && lg.ar.isNotEmpty) lg.ar,
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          ListView(
            controller: _scroll,
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            children: [
              _hero(w),
              const SizedBox(height: 18),
              _teamsTitle(),
              const SizedBox(height: 18),
              Center(child: _MatchClock(match: m)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(meta.join('  •  '), textAlign: TextAlign.center,
                    style: T.cairo(s: 14.5, w: FontWeight.w600, c: Colors.white.withOpacity(0.78), h: 1.6)),
              ),
              const SizedBox(height: 20),
              _actions(),
              const SizedBox(height: 26),
              _divider(),
              KeyedSubtree(key: _fansKey, child: _predictBox()),
              _divider(),
              _statsBox(lg),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
            ],
          ),
          // زر الرجوع
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 8, start: 10,
            child: Material(
              color: Colors.black.withOpacity(0.45), shape: const CircleBorder(),
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── البوستر ─────────────────────────────────────────────────────
  Widget _hero(double w) {
    final url = _poster;
    final h = w * 0.62 + MediaQuery.of(context).padding.top * 0.5;
    final hc = _tone(m.h.color, lo: 0.18, hi: 0.30), ac = _tone(m.a.color, lo: 0.18, hi: 0.30);
    Widget fallback() => DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(
        begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd,
        colors: [hc, _deeper(hc, 0.10), _deeper(ac, 0.10), ac], stops: const [0, .48, .52, 1],
      )),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _NetLogo(url: SportsFeed.url(m.h.logo), size: w * 0.26, fallback: m.h.label),
        Text('VS', style: T.cairo(s: 30, w: FontWeight.w900, c: Colors.white.withOpacity(0.9))),
        _NetLogo(url: SportsFeed.url(m.a.logo), size: w * 0.26, fallback: m.a.label),
      ]),
    );
    return SizedBox(
      height: h,
      child: Stack(fit: StackFit.expand, children: [
        url.isEmpty ? fallback() : CachedNetworkImage(
          imageUrl: url, fit: BoxFit.cover,
          memCacheWidth: (w * MediaQuery.of(context).devicePixelRatio).round().clamp(400, 1600),
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (_, __) => const ColoredBox(color: Color(0xFF111114)),
          errorWidget: (_, __, ___) => fallback(),
        ),
        // تدرّج سفلي ناعم نحو الأسود
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x00000000), Color(0xCC000000), Colors.black],
          stops: [0, .55, .88, 1],
        ))),
        if (m.isLive) const PositionedDirectional(top: 0, end: 14, child: SafeArea(child: Padding(
            padding: EdgeInsets.only(top: 14), child: _LivePill(big: true)))),
      ]),
    );
  }

  // ── الشعاران والعنوان ───────────────────────────────────────────
  Widget _teamsTitle() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      _NetLogo(url: SportsFeed.url(m.h.logo), size: 54, fallback: m.h.label),
      const SizedBox(width: 10),
      Expanded(child: Text('${m.h.label} ضد ${m.a.label}',
          textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: T.cairo(s: 22, w: FontWeight.w900, c: Colors.white, h: 1.35))),
      const SizedBox(width: 10),
      _NetLogo(url: SportsFeed.url(m.a.logo), size: 54, fallback: m.a.label),
    ]),
  );

  // ── الأزرار ──────────────────────────────────────────────────────
  Widget _actions() {
    final paid = SubCompat.isPremium;
    final watch = paid && (m.watchable || m.isLive);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Expanded(child: SizedBox(height: 52, child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _toFans,
          icon: const Icon(Icons.groups_rounded, size: 22),
          label: Text('منطقة المشجعين', style: T.cairo(s: 15.5, w: FontWeight.w800, c: Colors.white)),
        ))),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 52, child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: C.gold, foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            if (paid) { SportsActions.watch(context, m); } else { PayPlansSheet.show(context); }
          },
          icon: Icon(paid ? Icons.play_arrow_rounded : Icons.workspace_premium_rounded, size: 24),
          label: Text(paid ? (watch ? 'شاهد الآن' : 'شاهد') : 'اشتراك',
              style: T.cairo(s: 16, w: FontWeight.w900, c: Colors.black)),
        ))),
      ]),
    );
  }

  Widget _divider() => Container(height: 8, color: const Color(0xFF0D0D10), margin: const EdgeInsets.symmetric(vertical: 4));

  // ── توقّع واربح ─────────────────────────────────────────────────
  Widget _predictBox() {
    final open = Predictions.isOpen(m), notYet = Predictions.notYet(m);
    final closed = !open && !notYet;
    final logged = AuthService.currentUser != null;
    final editable = open && logged;

    String head, sub;
    if (m.isOff) {
      head = 'التوقع غير متاح'; sub = 'المباراة ${m.offLabel}';
    } else if (notYet) {
      head = 'توقّع النتيجة واربح يوماً مجانياً';
      sub = 'يُفتح التوقع قبل انطلاق المباراة بـ 30 دقيقة ويُغلق مع صافرة البداية';
    } else if (open) {
      head = 'توقّع النتيجة الآن';
      sub = 'النتيجة الدقيقة تربحك يوماً مجانياً — يُغلق مع صافرة البداية';
    } else {
      head = 'أُغلق التوقع';
      sub = _mine != null ? 'توقعك محفوظ — يُعلن الفائزون بعد نهاية المباراة' : 'انطلقت المباراة';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 4, height: 22, decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(child: Text(head, style: T.cairo(s: 19, w: FontWeight.w900, c: Colors.white))),
          if (open) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF16351F), borderRadius: BorderRadius.circular(8)),
            child: MatchCountdown(target: m.kick, startedLabel: 'أُغلق',
                style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 13.5, fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ]),
        const SizedBox(height: 6),
        Text(sub, style: T.cairo(s: 13.5, w: FontWeight.w500, c: Colors.white60, h: 1.6)),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _side(m.h, _h, editable, (v) => setState(() => _h = v))),
          Padding(
            padding: const EdgeInsets.only(top: 92),
            child: Text(':', style: T.cairo(s: 30, w: FontWeight.w900, c: Colors.white38)),
          ),
          Expanded(child: _side(m.a, _a, editable, (v) => setState(() => _a = v))),
        ]),
        const SizedBox(height: 18),
        if (_msg.isNotEmpty) Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(_msg, textAlign: TextAlign.center, style: T.cairo(s: 13.5, w: FontWeight.w700, c: C.red)),
        ),
        if (open)
          SizedBox(height: 52, child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.white24,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                : Text(!logged ? 'سجّل الدخول للتوقع' : (_mine == null ? 'أرسل توقعي' : 'تعديل توقعي'),
                    style: T.cairo(s: 16, w: FontWeight.w900, c: Colors.black)),
          ))
        else if (notYet && !m.isOff)
          _note(Icons.lock_clock_rounded, 'يُفتح بعد', MatchCountdown(
            target: m.kick.subtract(Predictions.window), startedLabel: 'الآن',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()])))
        else if (closed && _mine != null)
          _note(Icons.verified_rounded, 'توقعك',
              Text('⁦${m.h.label} ${_mine!.$1} - ${_mine!.$2} ${m.a.label}⁩',
                  style: T.cairo(s: 15, w: FontWeight.w800, c: Colors.white))),
        if (_mine != null && open) Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('توقعك الحالي: ${m.h.label} ${_mine!.$1} - ${_mine!.$2} ${m.a.label}',
              textAlign: TextAlign.center, style: T.cairo(s: 13, w: FontWeight.w600, c: Colors.white60)),
        ),
      ]),
    );
  }

  Widget _note(IconData icon, String label, Widget value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFF111114), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF232328))),
    child: Row(children: [
      Icon(icon, color: C.gold, size: 22),
      const SizedBox(width: 10),
      Text(label, style: T.cairo(s: 14.5, w: FontWeight.w700, c: Colors.white70)),
      const Spacer(),
      Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerEnd, child: value)),
    ]),
  );

  Widget _side(FxTeam t, int v, bool editable, ValueChanged<int> on) => Column(children: [
    _NetLogo(url: SportsFeed.url(t.logo), size: 64, fallback: t.label),
    const SizedBox(height: 8),
    Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
        style: T.cairo(s: 15, w: FontWeight.w800, c: Colors.white)),
    const SizedBox(height: 10),
    Container(
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF111114),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: editable ? Colors.white24 : const Color(0xFF1E1E22)),
      ),
      child: Row(children: [
        _step(Icons.add_rounded, editable && v < 20 ? () { Sound.hapticL(); on(v + 1); } : null),
        Expanded(child: Text('$v', textAlign: TextAlign.center,
            style: TextStyle(color: editable ? Colors.white : Colors.white54, fontSize: 32,
                fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()]))),
        _step(Icons.remove_rounded, editable && v > 0 ? () { Sound.hapticL(); on(v - 1); } : null),
      ]),
    ),
  ]);

  Widget _step(IconData i, VoidCallback? f) => SizedBox(
    width: 46, height: 64,
    child: IconButton(onPressed: f, icon: Icon(i, size: 26, color: f == null ? Colors.white12 : Colors.white)),
  );

  // ── الإحصائيات ──────────────────────────────────────────────────
  Widget _statsBox(FxLeague? lg) {
    final s = _stats;
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Text(k, style: T.cairo(s: 14.5, w: FontWeight.w600, c: Colors.white60)),
        const SizedBox(width: 12),
        Expanded(child: Text(v, textAlign: TextAlign.left, maxLines: 2, overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
            style: T.cairo(s: 14.5, w: FontWeight.w800, c: Colors.white))),
      ]),
    );
    final status = m.isOff ? m.offLabel : m.isLive ? 'تُلعب الآن' : m.isDone ? 'انتهت' : 'لم تبدأ';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('إحصائيات المباراة', style: T.cairo(s: 19, w: FontWeight.w900, c: Colors.white))),
          if (_loadingStats)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
          else if (AuthService.currentUser != null && !Predictions.notYet(m))
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, color: Colors.white70)),
        ]),
        const SizedBox(height: 10),
        if (s.total > 0) ...[
          Text('توقعات المشجعين (${s.total})', style: T.cairo(s: 14, w: FontWeight.w700, c: Colors.white70)),
          const SizedBox(height: 10),
          _bar(s),
          const SizedBox(height: 8),
          Row(children: [
            _legend('فوز ${m.h.label}', s.home, s.total),
            _legend('تعادل', s.draw, s.total),
            _legend('فوز ${m.a.label}', s.away, s.total),
          ]),
          if (s.top.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('النتائج الأكثر توقعاً', style: T.cairo(s: 14, w: FontWeight.w700, c: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in s.top) Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xFF141418), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF26262C))),
                child: Text('⁦${t.$1} - ${t.$2}⁩  ·  ${t.$3}',
                    style: T.cairo(s: 14, w: FontWeight.w800, c: Colors.white)),
              ),
            ]),
          ],
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF0E0E11), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E1E23))),
          child: Column(children: [
            if (lg != null && lg.ar.isNotEmpty) row('البطولة', lg.ar),
            if (m.rd.isNotEmpty) row('الجولة', _round(m.rd)),
            if (m.venue.isNotEmpty) row('الملعب', m.venue),
            row('اليوم', '${m.weekday} ${m.dateLabel}'),
            row('وقت الانطلاق', '⁦${m.time}⁩ بتوقيت جهازك'),
            row('الحالة', status),
          ]),
        ),
      ]),
    );
  }

  static String _round(String r) {
    final n = RegExp(r'(\d+)$').firstMatch(r)?.group(1);
    if (r.startsWith('Regular Season') && n != null) return 'الجولة $n';
    return r;
  }

  Widget _bar(PredStats s) {
    final t = s.total == 0 ? 1 : s.total;
    Widget seg(int v, Color c) => v == 0 ? const SizedBox.shrink()
        : Expanded(flex: (v * 1000 ~/ t).clamp(1, 1000), child: Container(height: 10, color: c));
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Row(children: [seg(s.home, C.gold), seg(s.draw, Colors.white54), seg(s.away, const Color(0xFF4A9EDA))]),
    );
  }

  Widget _legend(String l, int v, int t) => Expanded(child: Column(children: [
    Text('${t == 0 ? 0 : (v * 100 / t).round()}%',
        style: T.cairo(s: 17, w: FontWeight.w900, c: Colors.white)),
    Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
        style: T.cairo(s: 12, w: FontWeight.w600, c: Colors.white60)),
  ]));
}

/// عدّاد بخانات (ساعات · دقائق · ثوانٍ) — يعيد رسم نفسه فقط
class _MatchClock extends StatefulWidget {
  final FxMatch match;
  const _MatchClock({required this.match});
  @override
  State<_MatchClock> createState() => _MatchClockState();
}

class _MatchClockState extends State<_MatchClock> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    if (m.isOff) return Text('المباراة ${m.offLabel}', style: T.cairo(s: 18, w: FontWeight.w800, c: Colors.white70));
    if (m.isLive) return const _LivePill(big: true);
    if (m.isDone) return Text('انتهت المباراة', style: T.cairo(s: 18, w: FontWeight.w800, c: Colors.white70));
    final d = m.kick.difference(DateTime.now());
    Widget cell(int v, String l) => Container(
      width: 74,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: Column(children: [
        Text(v.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white, fontSize: 28,
            fontWeight: FontWeight.w900, height: 1.1, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 2),
        Text(l, style: T.cairo(s: 12.5, w: FontWeight.w700, c: Colors.white60)),
      ]),
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (d.inDays > 0) cell(d.inDays, 'أيام'),
      cell(d.inHours % 24, 'ساعات'),
      cell(d.inMinutes % 60, 'دقائق'),
      cell(d.inSeconds % 60, 'ثواني'),
    ]);
  }
}
