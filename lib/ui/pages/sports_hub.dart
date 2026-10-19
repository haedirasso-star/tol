part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════
//  SPORTS HUB — صفحة «رياضة» (v3)
//  • المباريات: بوستر مباراة اليوم + أيام + دوريات + بطاقات المباريات
//  • زر «شاهد» يفتح القناة الناقلة من السيرفر مباشرة، أو يعرض القنوات
//    المحتملة، أو ينقل إلى «القنوات المباشرة» إن لم توجد قناة مصرّح بها
//  • القنوات المباشرة: صفحة المباشر الحالية بأقسامها داخل نفس القسم
// ════════════════════════════════════════════════════════════════════

class SportsHubPage extends StatefulWidget {
  const SportsHubPage({super.key});
  @override State<SportsHubPage> createState() => _SportsHubPageState();
}

class _SportsHubPageState extends State<SportsHubPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override bool get wantKeepAlive => true;

  int    _seg = 0;          // 0 المباريات · 1 القنوات المباشرة
  String _day = '';         // yyyy-MM-dd
  int    _league = 0;       // 0 = الكل
  Timer? _poll;
  bool   _fg = true;

  static String _dKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SportsFeed.rev.addListener(_onFeed);
    kShellTab.addListener(_onTab);
    SportsFeed.load();
    // يتحدّث فقط حين تكون الصفحة ظاهرة والتطبيق في المقدّمة
    _poll = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_fg && kShellTab.value == 3 && _seg == 0) SportsFeed.load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    SportsFeed.rev.removeListener(_onFeed);
    kShellTab.removeListener(_onTab);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _fg = s == AppLifecycleState.resumed;
    if (_fg && kShellTab.value == 3) SportsFeed.load();
  }

  void _onTab() { if (kShellTab.value == 3) SportsFeed.load(); }
  void _onFeed() { if (mounted) setState(() {}); }

  // ── الأيام المتاحة ─────────────────────────────────────────────
  List<String> get _days {
    final s = SportsFeed.matches.map((m) => _dKey(m.kick)).toSet().toList()..sort();
    return s;
  }

  String get _selDay {
    final days = _days;
    if (days.contains(_day)) return _day;
    final today = _dKey(DateTime.now());
    if (days.contains(today)) return today;
    return days.firstWhere((d) => d.compareTo(today) > 0, orElse: () => days.isEmpty ? today : days.last);
  }

  String _dayLabel(String d) {
    final now = DateTime.now();
    if (d == _dKey(now)) return 'اليوم';
    if (d == _dKey(now.add(const Duration(days: 1)))) return 'غداً';
    if (d == _dKey(now.subtract(const Duration(days: 1)))) return 'أمس';
    final p = d.split('-');
    const wd = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final dt = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    return '${wd[dt.weekday - 1]} ${dt.day}/${dt.month}';
  }

  List<FxMatch> get _dayMatches =>
      SportsFeed.matches.where((m) => _dKey(m.kick) == _selDay).toList();

  FxMatch? _featured(List<FxMatch> list) {
    if (list.isEmpty) return null;
    final live = list.where((m) => m.isLive).toList()
      ..sort((a, b) => (b.imp ? 1 : 0) - (a.imp ? 1 : 0));
    if (live.isNotEmpty) return live.first;
    final next = list.where((m) => !m.isDone && !m.isOff).toList();
    final imp  = next.where((m) => m.imp).toList();
    if (imp.isNotEmpty) return imp.first;
    if (next.isNotEmpty) return next.first;
    return list.firstWhere((m) => m.imp, orElse: () => list.first);
  }

  // ── «شاهد» — القناة الناقلة ───────────────────────────────────
  Future<void> _watch(FxMatch m) async {
    if (!_canPlay(context)) return;
    Sound.hapticM();
    if (AppState.allLive.isEmpty) {
      try { AppState.allLive = await Api.getList('get_live_streams'); } catch (_) {}
    }
    if (!mounted) return;
    final r = SportsFeed.channelsFor(m);
    if (r.list.isEmpty) {
      setState(() => _seg = 1);
      _toast('لا توجد قناة ناقلة مؤكدة لهذه المباراة في باقتك — اختر من القنوات المباشرة');
      return;
    }
    if (r.list.length == 1 || r.exact) { _play(r.list.first); return; }
    _pickChannel(m, r.list);
  }

  void _play(dynamic ch) {
    Sound.hapticL();
    GuestSession.startPlayback();
    Navigator.push(context, _fade(PlayerPage(
        urls: Api.liveUrls(ch), title: ch['name']?.toString() ?? '', isLive: true, item: ch)));
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1C21),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        content: Text(msg, textDirection: TextDirection.rtl,
            style: T.cairo(s: FS.sm, c: Colors.white, w: FontWeight.w600)),
      ));
  }

  void _pickChannel(FxMatch m, List<dynamic> list) {
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
                      onTap: () { Navigator.pop(ctx); _play(ch); },
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
                onPressed: () { Navigator.pop(ctx); setState(() => _seg = 1); },
                child: Text('كل القنوات المباشرة',
                    style: T.cairo(s: FS.sm, c: Colors.white70, w: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
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

  // ── المباريات ──────────────────────────────────────────────────
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

    final all    = _dayMatches;
    final list   = _league == 0 ? all : all.where((m) => m.lg == _league).toList();
    final feat   = _featured(all);
    final lgIds  = all.map((m) => m.lg).toSet().toList()
      ..sort((a, b) => (SportsFeed.leagues[a]?.order ?? 99).compareTo(SportsFeed.leagues[b]?.order ?? 99));
    final groups = <int, List<FxMatch>>{};
    for (final m in list) { groups.putIfAbsent(m.lg, () => []).add(m); }
    final gIds = groups.keys.toList()
      ..sort((a, b) => (SportsFeed.leagues[a]?.order ?? 99).compareTo(SportsFeed.leagues[b]?.order ?? 99));
    for (final g in groups.values) {
      g.sort((a, b) {
        int rank(FxMatch m) => m.isLive ? 0 : (m.isDone || m.isOff) ? 2 : 1;
        final r = rank(a) - rank(b);
        return r != 0 ? r : a.ts.compareTo(b.ts);
      });
    }

    return RefreshIndicator(
      color: C.gold, backgroundColor: const Color(0xFF141418),
      onRefresh: () => SportsFeed.load(force: true),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          if (feat != null)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: _MatchPoster(match: feat, onWatch: () => _watch(feat)),
            )),

          // الأيام
          SliverToBoxAdapter(child: _chips<String>(
            items: _days, selected: _selDay,
            label: _dayLabel,
            onTap: (d) => setState(() { _day = d; _league = 0; }),
          )),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // الدوريات
          if (lgIds.length > 1)
            SliverToBoxAdapter(child: _chips<int>(
              items: [0, ...lgIds], selected: _league,
              label: (id) => id == 0 ? 'الكل' : (SportsFeed.leagues[id]?.ar ?? ''),
              logo: (id) => id == 0 ? '' : SportsFeed.url(SportsFeed.leagues[id]?.logo ?? ''),
              onTap: (id) => setState(() => _league = id),
            )),

          if (list.isEmpty)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Column(children: [
                const Icon(Icons.event_busy_rounded, color: Colors.white24, size: 46),
                const SizedBox(height: 10),
                Text('لا توجد مباريات في هذا اليوم',
                    style: T.cairo(s: FS.md, c: Colors.white60, w: FontWeight.w600)),
              ]),
            )),

          for (final id in gIds) ...[
            SliverToBoxAdapter(child: _leagueHeader(id, groups[id]!.length)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MatchCard2(match: groups[id]![i], onWatch: () => _watch(groups[id]![i])),
                ),
                childCount: groups[id]!.length,
              )),
            ),
          ],

          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
            child: Text(_updatedLabel, textAlign: TextAlign.center,
                style: T.cairo(s: FS.xs, c: Colors.white38)),
          )),
        ],
      ),
    );
  }

  String get _updatedLabel {
    if (SportsFeed.updated == 0) return '';
    final mins = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(SportsFeed.updated * 1000)).inMinutes;
    if (mins < 1) return 'آخر تحديث: الآن';
    if (mins < 60) return 'آخر تحديث: قبل $mins د';
    return 'آخر تحديث: قبل ${mins ~/ 60} س';
  }

  Widget _leagueHeader(int id, int count) {
    final l = SportsFeed.leagues[id];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(children: [
        _NetLogo(url: SportsFeed.url(l?.logo ?? ''), size: 24, round: false),
        const SizedBox(width: 9),
        Expanded(child: Text(l?.ar ?? '', style: T.cairo(s: FS.lg, w: FontWeight.w800, c: Colors.white))),
        Text('$count', style: T.cairo(s: FS.sm, c: Colors.white38, w: FontWeight.w700)),
      ]),
    );
  }

  Widget _chips<V>({required List<V> items, required V selected, required String Function(V) label,
      String Function(V)? logo, required void Function(V) onTap}) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final v = items[i];
          final on = v == selected;
          final lg = logo?.call(v) ?? '';
          return GestureDetector(
            onTap: () { Sound.nav(); onTap(v); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: on ? Colors.white : const Color(0xFF141418),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? Colors.white : const Color(0xFF26262C)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (lg.isNotEmpty) ...[
                  _NetLogo(url: lg, size: 18, round: false),
                  const SizedBox(width: 6),
                ],
                Text(label(v), style: T.cairo(s: FS.sm, w: FontWeight.w800,
                    c: on ? Colors.black : Colors.white70)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _skeleton() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
    children: [
      _SkelBox(height: 210, radius: 18),
      const SizedBox(height: 16),
      for (int i = 0; i < 5; i++) ...[
        _SkelBox(height: 92, radius: 14),
        const SizedBox(height: 10),
      ],
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

// ════════════════════════════════════════════════════════════════════
//  بوستر مباراة اليوم — شعارا الفريقين كبيران + الوقت/النتيجة + شاهد
// ════════════════════════════════════════════════════════════════════
class _MatchPoster extends StatelessWidget {
  final FxMatch match;
  final VoidCallback onWatch;
  const _MatchPoster({required this.match, required this.onWatch});

  @override
  Widget build(BuildContext context) {
    final m  = match;
    final lg = SportsFeed.leagues[m.lg];
    return Container(
      height: 214,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft,
          colors: [Color(0xFF1B1B22), Color(0xFF0C0C0F)],
        ),
        border: Border.all(color: m.isLive ? const Color(0x66E50914) : const Color(0xFF24242A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // شعار البطولة خافت في الخلفية
        PositionedDirectional(
          end: -30, top: -20,
          child: Opacity(opacity: 0.07,
              child: _NetLogo(url: SportsFeed.url(lg?.logo ?? ''), size: 190, round: false)),
        ),
        // شعارا الفريقين كخلفية ضبابية خفيفة
        Positioned.fill(child: Row(children: [
          Expanded(child: Opacity(opacity: 0.06,
              child: _NetLogo(url: SportsFeed.url(m.h.logo), size: 220, round: false))),
          Expanded(child: Opacity(opacity: 0.06,
              child: _NetLogo(url: SportsFeed.url(m.a.logo), size: 220, round: false))),
        ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(children: [
            Row(children: [
              _NetLogo(url: SportsFeed.url(lg?.logo ?? ''), size: 20, round: false),
              const SizedBox(width: 7),
              Expanded(child: Text(lg?.ar ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: T.cairo(s: FS.sm, w: FontWeight.w700, c: Colors.white70))),
              if (m.imp) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    border: Border.all(color: C.gold.withOpacity(0.7)),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('مباراة اليوم', style: T.cairo(s: FS.xs, w: FontWeight.w800, c: C.gold)),
              ),
            ]),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: _side(m.h)),
              _center(m),
              Expanded(child: _side(m.a)),
            ]),
            const Spacer(),
            SizedBox(
              height: 42, width: double.infinity,
              child: m.watchable
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: C.gold, foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: onWatch,
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text('شاهد الآن', style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black)),
                    )
                  : Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A20),
                        borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        m.isDone || m.isOff ? m.offLabel
                            : 'تبدأ ${_relative(m)} • البث يُفتح قبل الانطلاق بـ 30 دقيقة',
                        style: T.cairo(s: FS.sm, w: FontWeight.w700, c: Colors.white70)),
                    ),
            ),
          ]),
        ),
      ]),
    );
  }

  static String _relative(FxMatch m) {
    final d = m.minsToKick;
    if (d < 60) return 'بعد $d د';
    if (d < 24 * 60) return 'بعد ${d ~/ 60} س';
    return 'الساعة ${m.time}';
  }

  Widget _side(FxTeam t) => Column(mainAxisSize: MainAxisSize.min, children: [
    _NetLogo(url: SportsFeed.url(t.logo), size: 62, fallback: t.label),
    const SizedBox(height: 8),
    Text(t.label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
        style: T.cairo(s: FS.md, w: FontWeight.w800, c: Colors.white, h: 1.25)),
  ]);

  Widget _center(FxMatch m) => SizedBox(
    width: 96,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (m.isLive || m.isDone)
        Text(m.score, textDirection: TextDirection.ltr,
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900))
      else
        Text(m.time, textDirection: TextDirection.ltr,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      if (m.isLive) _LivePill(label: m.liveLabel)
      else Text(m.isDone || m.isOff ? m.offLabel : 'بتوقيتك',
          style: T.cairo(s: FS.xs, c: Colors.white54, w: FontWeight.w600)),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════
//  بطاقة مباراة
// ════════════════════════════════════════════════════════════════════
class _MatchCard2 extends StatelessWidget {
  final FxMatch match;
  final VoidCallback onWatch;
  const _MatchCard2({required this.match, required this.onWatch});

  @override
  Widget build(BuildContext context) {
    final m = match;
    return Material(
      color: const Color(0xFF111114),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: m.watchable ? onWatch : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: m.isLive ? const Color(0x55E50914) : const Color(0xFF1E1E24)),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(child: _team(m.h)),
              SizedBox(
                width: 88,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(m.isLive || m.isDone ? m.score : m.time,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: m.isDone ? Colors.white70 : Colors.white,
                          fontSize: m.isLive || m.isDone ? 22 : 19,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  if (m.isLive) _LivePill(label: m.liveLabel)
                  else Text(m.isDone || m.isOff ? m.offLabel : _soon(m),
                      style: T.cairo(s: FS.xs, c: Colors.white54, w: FontWeight.w600)),
                ]),
              ),
              Expanded(child: _team(m.a)),
            ]),
            if (m.watchable) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 36, width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: m.isLive ? C.gold : Colors.white,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                  onPressed: onWatch,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text('شاهد', style: T.cairo(s: FS.sm, w: FontWeight.w900, c: Colors.black)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  static String _soon(FxMatch m) {
    final d = m.minsToKick;
    if (d <= 0) return 'تنطلق الآن';
    if (d < 60) return 'بعد $d د';
    return '';
  }

  Widget _team(FxTeam t) => Column(mainAxisSize: MainAxisSize.min, children: [
    _NetLogo(url: SportsFeed.url(t.logo), size: 38, fallback: t.label),
    const SizedBox(height: 6),
    Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
        style: T.cairo(s: FS.sm, w: FontWeight.w700, c: Colors.white)),
  ]);
}

class _LivePill extends StatelessWidget {
  final String label;
  const _LivePill({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, textDirection: TextDirection.rtl,
          style: T.cairo(s: FS.xs, w: FontWeight.w800, c: Colors.white)),
    ]),
  );
}

/// شعار من الخلاصة مع بديل أنيق (أول حرف) إن غاب
class _NetLogo extends StatelessWidget {
  final String url;
  final double size;
  final bool round;
  final String fallback;
  const _NetLogo({required this.url, required this.size, this.round = true, this.fallback = ''});

  @override
  Widget build(BuildContext context) {
    Widget fb() => fallback.isEmpty
        ? SizedBox(width: size, height: size)
        : Container(
            width: size, height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFF22222A), shape: BoxShape.circle),
            child: Text(fallback.characters.first,
                style: T.cairo(s: size * 0.42, w: FontWeight.w800, c: Colors.white70)),
          );
    if (url.isEmpty) return fb();
    return SizedBox(
      width: size, height: size,
      child: CachedNetworkImage(
        imageUrl: url, fit: BoxFit.contain,
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
