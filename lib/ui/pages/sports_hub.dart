part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════
//  SPORTS HUB — صفحة «رياضة» (v4 — بطاقات بأسلوب TOD)
//  • إعلانات المباريات (صور يومية يرفعها المشرف) مع عدّاد تنازلي
//  • مباريات الأسبوع: تُلعب الآن · اليوم · غداً · بقية الأيام
//  • بطاقة المباراة: شريط البطولة (وقت + تاريخ + شعار) ثم شريط لكل
//    نادٍ بلون شعاره — بلا نتائج (انطلاق المباراة فقط)
//  • «شاهد» يفتح القناة الناقلة، أو القنوات المحتملة، أو «القنوات المباشرة»
// ════════════════════════════════════════════════════════════════════

// ── أدوات مشتركة ────────────────────────────────────────────────────
Color _tone(Color? c, {double lo = 0.20, double hi = 0.34, Color fallback = const Color(0xFF24242C)}) {
  if (c == null) return fallback;
  final h = HSLColor.fromColor(c);
  if (h.saturation < 0.18) {
    // أبيض/أسود/رمادي (ريال مدريد، يوفنتوس…) ⇐ فحمي أنيق بدل الرمادي الباهت
    return HSLColor.fromAHSL(1, h.hue, 0.10, (lo + hi) / 2 - 0.06).toColor();
  }
  return h
      .withSaturation(math.min(h.saturation, 0.82))
      .withLightness(h.lightness.clamp(lo, hi))
      .toColor();
}

Color _deeper(Color c, [double by = 0.07]) {
  final h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - by).clamp(0.04, 1.0)).toColor();
}

String _countdownText(Duration d) {
  if (d.isNegative) return '00:00:00';
  final days = d.inDays;
  final hh = (d.inHours % 24).toString().padLeft(2, '0');
  final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
  final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
  return days > 0 ? '$days يوم  \u2066$hh:$mm:$ss\u2069' : '$hh:$mm:$ss';
}

/// عدّاد تنازلي محلي — يعتمد على ساعة الجهاز ووقت الانطلاق فقط
class MatchCountdown extends StatefulWidget {
  final DateTime target;
  final TextStyle style;
  final String startedLabel;
  const MatchCountdown({super.key, required this.target, required this.style,
      this.startedLabel = 'انطلقت المباراة'});
  @override State<MatchCountdown> createState() => _MatchCountdownState();
}

class _MatchCountdownState extends State<MatchCountdown> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }
  @override void dispose() { _t?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final d = widget.target.difference(DateTime.now());
    return Text(d.isNegative ? widget.startedLabel : _countdownText(d),
        textDirection: (d.isNegative || d.inDays > 0) ? TextDirection.rtl : TextDirection.ltr,
        style: widget.style);
  }
}

// ── الإجراءات: المشاهدة وفتح الإعلان ───────────────────────────────
class SportsActions {
  static Future<void> watch(BuildContext context, FxMatch m) async {
    if (!m.watchable) {
      final d = m.kick.difference(DateTime.now());
      _toast(context, m.isOff
          ? 'المباراة ${m.offLabel}'
          : 'تبدأ المباراة بعد ${_countdownText(d)} — يُفتح البث قبل الانطلاق بـ 30 دقيقة');
      return;
    }
    if (!_canPlay(context)) return;
    Sound.hapticM();
    if (AppState.allLive.isEmpty) {
      try { AppState.allLive = await Api.getList('get_live_streams'); } catch (_) {}
    }
    if (!context.mounted) return;
    final r = SportsFeed.channelsFor(m);
    if (r.list.isEmpty) {
      ShellNav.go(3);
      SportsFeed.openChannels.value++;
      _toast(context, 'لا توجد قناة ناقلة مؤكدة لهذه المباراة في باقتك — اختر من القنوات المباشرة');
      return;
    }
    if (r.list.length == 1 || r.exact) { _play(context, r.list.first); return; }
    _pick(context, m, r.list);
  }

  static void openPromo(BuildContext context, MatchPromo p) {
    final m = p.match;
    if (m != null) { MatchPage.open(context, m); return; }
    Sound.nav();
    ShellNav.go(3);
  }

  static void _play(BuildContext context, dynamic ch) {
    Sound.hapticL();
    GuestSession.startPlayback();
    Navigator.push(context, _fade(PlayerPage(
        urls: Api.liveUrls(ch), title: ch['name']?.toString() ?? '', isLive: true, item: ch)));
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1C21),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        content: Text(msg, textDirection: TextDirection.rtl,
            style: T.cairo(s: FS.sm, c: Colors.white, w: FontWeight.w600)),
      ));
  }

  static void _pick(BuildContext context, FxMatch m, List<dynamic> list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E11),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                child: Text('${m.h.label} × ${m.a.label}',
                    textAlign: TextAlign.center,
                    style: T.cairo(s: FS.lg, w: FontWeight.w800, c: Colors.white)),
              ),
              Text('اختر القناة الناقلة', style: T.cairo(s: FS.sm, c: Colors.white60)),
              const SizedBox(height: 10),
              Flexible(child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final ch = list[i];
                  return Material(
                    color: const Color(0xFF17171B),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () { Navigator.pop(ctx); _play(context, ch); },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(children: [
                          SizedBox(width: 64, height: 40, child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SmartPoster(item: ch, fit: BoxFit.contain,
                                radius: BorderRadius.circular(8)))),
                          const SizedBox(width: 12),
                          Expanded(child: Text('${ch['name'] ?? ''}',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr, textAlign: TextAlign.right,
                              style: T.cairo(s: FS.md, w: FontWeight.w700, c: Colors.white))),
                          const SizedBox(width: 8),
                          const Icon(Icons.play_circle_fill_rounded, color: C.gold, size: 28),
                        ]),
                      ),
                    ),
                  );
                },
              )),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ShellNav.go(3);
                  SportsFeed.openChannels.value++;
                },
                child: Text('كل القنوات المباشرة',
                    style: T.cairo(s: FS.sm, c: Colors.white70, w: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  بطاقة المباراة بأسلوب TOD
// ════════════════════════════════════════════════════════════════════
class TodMatchCard extends StatelessWidget {
  final FxMatch match;
  final double width;
  const TodMatchCard({super.key, required this.match, this.width = 340});

  static const double height = 262;

  @override
  Widget build(BuildContext context) {
    final m  = match;
    final lg = SportsFeed.leagues[m.lg];
    final lgC = _tone(lg?.color, lo: 0.13, hi: 0.22, fallback: const Color(0xFF15151B));
    final hC  = _tone(m.h.color);
    final aC  = _tone(m.a.color, lo: 0.22, hi: 0.38);
    final today = DateUtils.isSameDay(m.kick, DateTime.now());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        width: width, height: height,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => MatchPage.open(context, m),
            child: Column(children: [
              // ── شريط البطولة ──
              Container(
                height: 78,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd,
                  colors: [lgC, _deeper(lgC, 0.05)],
                )),
                child: Row(children: [
                  Expanded(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.time, textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.white, fontSize: 19,
                              fontWeight: FontWeight.w900, height: 1.1)),
                      const SizedBox(height: 3),
                      if (m.isLive)
                        _LivePill()
                      else if (today && m.upcoming)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          MatchCountdown(target: m.kick, style: const TextStyle(
                              color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()])),
                        ])
                      else
                        Text(m.isOff ? m.offLabel : m.dateLabel,
                            style: T.cairo(s: 14, w: FontWeight.w600, c: Colors.white.withOpacity(0.92))),
                    ],
                  )),
                  _NetLogo(url: SportsFeed.url(lg?.logo ?? ''), size: 40, round: false,
                      tint: Colors.white),
                ]),
              ),
              // ── المستضيف ──
              Expanded(child: _band(m.h, hC, m.watchable ? Icons.play_circle_fill_rounded : null)),
              // ── الضيف ──
              Expanded(child: _band(m.a, aC, null)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _band(FxTeam t, Color c, IconData? action) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd,
      colors: [c, _deeper(c, 0.08)],
    )),
    child: Row(children: [
      _NetLogo(url: SportsFeed.url(t.logo), size: 46, fallback: t.label),
      const SizedBox(width: 14),
      Expanded(child: Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: T.cairo(s: 19, w: FontWeight.w800, c: Colors.white)
              .copyWith(shadows: const [Shadow(color: Colors.black38, blurRadius: 6)]))),
      if (action != null) Icon(action, color: Colors.white, size: 34),
    ]),
  );
}

/// صف أفقي من بطاقات المباريات بعنوان (يُستخدم في الرياضة والرئيسية)
class MatchCardsRow extends StatelessWidget {
  final String title;
  final List<FxMatch> matches;
  final VoidCallback? onMore;
  const MatchCardsRow({super.key, required this.title, required this.matches, this.onMore});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    final w = math.min(MediaQuery.of(context).size.width * 0.86, 380.0);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(children: [
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: T.cairo(s: 21, w: FontWeight.w800, c: Colors.white))),
            if (onMore != null)
              GestureDetector(onTap: onMore,
                child: Text('عرض الكل', style: T.cairo(s: FS.sm, w: FontWeight.w700, c: C.gold))),
          ]),
        ),
        SizedBox(
          height: TodMatchCard.height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => TodMatchCard(match: matches[i], width: w),
          ),
        ),
      ]),
    );
  }
}

/// «أهم مباريات الأسبوع» في الرئيسية
class HomeMatchesRow extends StatefulWidget {
  const HomeMatchesRow({super.key});
  @override State<HomeMatchesRow> createState() => _HomeMatchesRowState();
}

class _HomeMatchesRowState extends State<HomeMatchesRow> {
  @override
  void initState() { super.initState(); SportsFeed.rev.addListener(_r); SportsFeed.load(); }
  @override
  void dispose() { SportsFeed.rev.removeListener(_r); super.dispose(); }
  void _r() { if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) {
    final act = SportsFeed.active;
    final live = act.where((m) => m.isLive).toList();
    var top = act.where((m) => m.imp && !m.isLive).toList();
    if (top.length < 3) top = act.where((m) => !m.isLive).take(8).toList();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (live.isNotEmpty)
        MatchCardsRow(title: 'تُلعب الآن', matches: live, onMore: () => ShellNav.go(3)),
      MatchCardsRow(title: 'أفضل مباريات كرة القدم هذا الأسبوع',
          matches: top.take(10).toList(), onMore: () => ShellNav.go(3)),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
//  معلومات شريحة «إعلان مباراة» داخل بانر الرئيسية
// ════════════════════════════════════════════════════════════════════
class PromoHeroInfo extends StatelessWidget {
  final MatchPromo promo;
  const PromoHeroInfo({super.key, required this.promo});

  @override
  Widget build(BuildContext context) {
    final m = promo.match;
    final kick = promo.kick ?? m?.kick;
    final title = promo.title.isNotEmpty ? promo.title
        : (m != null ? '${m.h.label} × ${m.a.label}' : '');
    final lg = m != null ? SportsFeed.leagues[m.lg] : null;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 44),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(6)),
              child: Text('مباراة مرتقبة', style: T.cairo(s: FS.xs, w: FontWeight.w900, c: Colors.black)),
            ),
            if (lg != null) ...[
              const SizedBox(width: 8),
              Text(lg.ar, style: T.cairo(s: FS.sm, w: FontWeight.w700, c: Colors.white70)),
            ],
          ]),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: T.cairo(s: 26, w: FontWeight.w900, c: Colors.white)
                    .copyWith(shadows: const [Shadow(blurRadius: 16, color: Colors.black)])),
          ],
          if (kick != null) ...[
            const SizedBox(height: 10),
            _BigCountdown(target: kick),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 46, width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: (m?.watchable ?? false) ? C.gold : Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => (m?.watchable ?? false)
                  ? SportsActions.watch(context, m!) : SportsActions.openPromo(context, promo),
              icon: Icon((m?.watchable ?? false) ? Icons.play_arrow_rounded : Icons.sports_soccer_rounded, size: 22),
              label: Text((m?.watchable ?? false) ? 'شاهد الآن' : (m != null ? 'تفاصيل المباراة' : 'جدول المباريات'),
                  style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// عدّاد كبير بخانات: أيام · ساعات · دقائق · ثوانٍ
class _BigCountdown extends StatefulWidget {
  final DateTime target;
  const _BigCountdown({required this.target});
  @override State<_BigCountdown> createState() => _BigCountdownState();
}

class _BigCountdownState extends State<_BigCountdown> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }
  @override void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.target.difference(DateTime.now());
    if (d.isNegative) {
      return d.inMinutes > -115 ? _LivePill(big: true)
          : Text('انتهت المباراة', style: T.cairo(s: FS.md, c: Colors.white70, w: FontWeight.w700));
    }
    Widget cell(int v, String l) => Container(
      width: 58, padding: const EdgeInsets.symmetric(vertical: 6),
      margin: const EdgeInsetsDirectional.only(end: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(children: [
        Text(v.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white,
            fontSize: 22, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
        Text(l, style: T.cairo(s: 10.5, c: Colors.white70, w: FontWeight.w700)),
      ]),
    );
    return Row(children: [
      if (d.inDays > 0) cell(d.inDays, 'يوم'),
      cell(d.inHours % 24, 'ساعة'),
      cell(d.inMinutes % 60, 'دقيقة'),
      cell(d.inSeconds % 60, 'ثانية'),
    ]);
  }
}

/// شريط إعلانات المباريات أعلى صفحة الرياضة
class _PromoStrip extends StatefulWidget {
  final List<MatchPromo> promos;
  const _PromoStrip({required this.promos});
  @override State<_PromoStrip> createState() => _PromoStripState();
}

class _PromoStripState extends State<_PromoStrip> {
  final _pc = PageController(viewportFraction: 0.92);
  Timer? _auto;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_pc.hasClients || widget.promos.length < 2) return;
      _pc.animateToPage((_i + 1) % widget.promos.length,
          duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
    });
  }
  @override void dispose() { _auto?.cancel(); _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Column(children: [
      SizedBox(
        height: w * 0.92 * 9 / 16 + 8,
        child: PageView.builder(
          controller: _pc,
          itemCount: widget.promos.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) {
            final p = widget.promos[i];
            final k = p.kick ?? p.match?.kick;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: GestureDetector(
                onTap: () => SportsActions.openPromo(context, p),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(fit: StackFit.expand, children: [
                    CachedNetworkImage(imageUrl: p.img, fit: BoxFit.cover,
                        placeholder: (_, __) => const ColoredBox(color: Color(0xFF141418)),
                        errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF141418))),
                    if (k != null)
                      PositionedDirectional(
                        start: 10, bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.timer_outlined, size: 15, color: C.gold),
                            const SizedBox(width: 5),
                            MatchCountdown(target: k, startedLabel: 'تُلعب الآن',
                                style: const TextStyle(color: Colors.white, fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: [FontFeature.tabularFigures()])),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      if (widget.promos.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < widget.promos.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == _i ? 20 : 6, height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                    color: i == _i ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
          ]),
        ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
//  الصفحة
// ════════════════════════════════════════════════════════════════════
class SportsHubPage extends StatefulWidget {
  const SportsHubPage({super.key});
  @override State<SportsHubPage> createState() => _SportsHubPageState();
}

class _SportsHubPageState extends State<SportsHubPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override bool get wantKeepAlive => true;

  int    _seg = 0;          // 0 المباريات · 1 القنوات المباشرة
  int    _league = 0;       // 0 = الكل
  Timer? _tick;

  static String _dKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SportsFeed.rev.addListener(_onFeed);
    SportsFeed.openChannels.addListener(_onOpenChannels);
    kShellTab.addListener(_onTab);
    SportsFeed.load();
    // إعادة ترتيب الأقسام كل دقيقة (مباراة بدأت ⇐ «تُلعب الآن»)
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && kShellTab.value == 3) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    SportsFeed.rev.removeListener(_onFeed);
    SportsFeed.openChannels.removeListener(_onOpenChannels);
    kShellTab.removeListener(_onTab);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && kShellTab.value == 3) SportsFeed.load();
  }

  void _onTab() { if (kShellTab.value == 3) SportsFeed.load(); }
  void _onFeed() { if (mounted) setState(() {}); }
  void _onOpenChannels() { if (mounted) setState(() => _seg = 1); }

  String _dayTitle(String key, FxMatch first) {
    final now = DateTime.now();
    if (key == _dKey(now)) return 'مباريات اليوم';
    if (key == _dKey(now.add(const Duration(days: 1)))) return 'مباريات الغد';
    return '${first.weekday} • ${first.kick.day}/${first.kick.month}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(children: [
          const SectionTopBar(current: 3),
          _segments(),
          Expanded(child: IndexedStack(index: _seg, children: [
            _matchesView(),
            // صفحة المباشر الحالية بأقسامها — بلا هامش علوي مكرّر
            MediaQuery.removePadding(
              context: context, removeTop: true,
              child: const Directionality(textDirection: TextDirection.ltr, child: LivePage())),
          ])),
        ]),
      ),
    );
  }

  Widget _segments() {
    Widget seg(int i, String label, IconData icon) {
      final on = _seg == i;
      return Expanded(child: GestureDetector(
        onTap: () { if (_seg != i) { Sound.nav(); setState(() => _seg = i); } },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 40,
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 17, color: on ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(label, style: T.cairo(s: FS.md, w: FontWeight.w800,
                c: on ? Colors.black : Colors.white70)),
          ]),
        ),
      ));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF222228)),
      ),
      child: Row(children: [
        seg(0, 'المباريات', Icons.sports_soccer_rounded),
        const SizedBox(width: 4),
        seg(1, 'القنوات المباشرة', Icons.live_tv_rounded),
      ]),
    );
  }

  Widget _matchesView() {
    if (!SportsFeed.configured) {
      return _empty(Icons.link_off_rounded, 'جدول المباريات غير مفعّل بعد',
          'يمكنك المشاهدة الآن من القنوات المباشرة');
    }
    if (SportsFeed.matches.isEmpty) {
      if (SportsFeed.loading || SportsFeed.error.isEmpty) return _skeleton();
      return _empty(Icons.wifi_off_rounded, 'تعذّر تحميل المباريات',
          'تحقّق من الاتصال ثم اسحب للتحديث', retry: true);
    }

    final all = SportsFeed.active;
    final lgIds = all.map((m) => m.lg).toSet().toList()
      ..sort((a, b) => (SportsFeed.leagues[a]?.order ?? 99).compareTo(SportsFeed.leagues[b]?.order ?? 99));
    final list  = _league == 0 ? all : all.where((m) => m.lg == _league).toList();
    final live  = list.where((m) => m.isLive).toList();
    final byDay = <String, List<FxMatch>>{};
    for (final m in list.where((m) => !m.isLive)) {
      byDay.putIfAbsent(_dKey(m.kick), () => []).add(m);
    }
    final days = byDay.keys.toList()..sort();
    final promos = SportsFeed.activePromos;

    return RefreshIndicator(
      color: C.gold, backgroundColor: const Color(0xFF141418),
      onRefresh: () => SportsFeed.load(force: true),
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          if (promos.isNotEmpty) ...[
            const SizedBox(height: 4),
            _PromoStrip(promos: promos),
            const SizedBox(height: 6),
          ],

          if (lgIds.length > 1) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: lgIds.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final id = i == 0 ? 0 : lgIds[i - 1];
                  final on = _league == id;
                  final lg = SportsFeed.leagues[id];
                  return GestureDetector(
                    onTap: () { Sound.nav(); setState(() => _league = id); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: on ? Colors.white : const Color(0xFF141418),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: on ? Colors.white : const Color(0xFF26262C)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (id != 0) ...[
                          _NetLogo(url: SportsFeed.url(lg?.logo ?? ''), size: 18, round: false),
                          const SizedBox(width: 6),
                        ],
                        Text(id == 0 ? 'الكل' : (lg?.ar ?? ''), style: T.cairo(s: FS.sm,
                            w: FontWeight.w800, c: on ? Colors.black : Colors.white70)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],

          if (live.isNotEmpty) MatchCardsRow(title: 'تُلعب الآن', matches: live),
          for (final d in days)
            MatchCardsRow(title: _dayTitle(d, byDay[d]!.first), matches: byDay[d]!),

          if (live.isEmpty && days.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(children: [
                const Icon(Icons.event_busy_rounded, color: Colors.white24, size: 46),
                const SizedBox(height: 10),
                Text('لا توجد مباريات قادمة هذا الأسبوع',
                    textAlign: TextAlign.center,
                    style: T.cairo(s: FS.md, c: Colors.white60, w: FontWeight.w600)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _skeleton() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
    children: [
      _SkelBox(height: 190, radius: 16),
      const SizedBox(height: 18),
      _SkelBox(height: 24, radius: 6),
      const SizedBox(height: 10),
      _SkelBox(height: TodMatchCard.height, radius: 18),
      const SizedBox(height: 18),
      _SkelBox(height: TodMatchCard.height, radius: 18),
    ],
  );

  Widget _empty(IconData icon, String title, String sub, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 100),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white24, size: 54),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center,
            style: T.cairo(s: FS.lg, w: FontWeight.w800, c: Colors.white)),
        const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center, style: T.cairo(s: FS.sm, c: Colors.white60)),
        const SizedBox(height: 20),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (retry) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => SportsFeed.load(force: true),
              child: Text('إعادة المحاولة', style: T.cairo(s: FS.sm, c: Colors.white, w: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
          ],
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => setState(() => _seg = 1),
            child: Text('القنوات المباشرة', style: T.cairo(s: FS.sm, c: Colors.black, w: FontWeight.w800)),
          ),
        ]),
      ]),
    ),
  );
}

class _LivePill extends StatelessWidget {
  final bool big;
  const _LivePill({this.big = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: big ? 12 : 8, vertical: big ? 5 : 2),
    decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: big ? 7 : 5, height: big ? 7 : 5,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      SizedBox(width: big ? 6 : 4),
      Text('تُلعب الآن', textDirection: TextDirection.rtl,
          style: T.cairo(s: big ? FS.md : FS.xs, w: FontWeight.w800, c: Colors.white)),
    ]),
  );
}

/// شعار من الخلاصة مع بديل أنيق (أول حرف) إن غاب
class _NetLogo extends StatelessWidget {
  final String url;
  final double size;
  final bool round;
  final String fallback;
  final Color? tint;     // لشعارات البطولات: أبيض موحّد فوق الشريط الملوّن
  const _NetLogo({required this.url, required this.size, this.round = true,
      this.fallback = '', this.tint});

  @override
  Widget build(BuildContext context) {
    Widget fb() => fallback.isEmpty
        ? SizedBox(width: size, height: size)
        : Container(
            width: size, height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
            child: Text(fallback.characters.first,
                style: T.cairo(s: size * 0.42, w: FontWeight.w800, c: Colors.white)),
          );
    if (url.isEmpty) return fb();
    return SizedBox(
      width: size, height: size,
      child: CachedNetworkImage(
        imageUrl: url, fit: BoxFit.contain,
        color: tint, colorBlendMode: tint != null ? BlendMode.srcIn : null,
        memCacheWidth: (size * 3).round(),
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => SizedBox(width: size, height: size),
        errorWidget: (_, __, ___) => fb(),
      ),
    );
  }
}

class _SkelBox extends StatelessWidget {
  final double height, radius;
  const _SkelBox({required this.height, required this.radius});
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFF131317),
    highlightColor: const Color(0xFF1F1F25),
    child: Container(height: height, decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(radius))),
  );
}
