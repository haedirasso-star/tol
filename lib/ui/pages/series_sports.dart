part of '../../main.dart';

class SeriesDetailPage extends StatefulWidget {
  final dynamic series;
  const SeriesDetailPage({required this.series});
  @override State<SeriesDetailPage> createState() => _SeriesDetailState();
}

class _SeriesDetailState extends State<SeriesDetailPage> with TickerProviderStateMixin {
  Map<String, dynamic>? _data;
  Map<String, String> _tmdb = {};
  bool _busy = true, _fail = false;
  int _season = 1;
  TabController? _tc;
  String _seriesCover = '';

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _busy = true; _fail = false; });
    try {
      final sid = widget.series['series_id']?.toString() ?? '';
      if (sid.isEmpty) throw 'no sid';
      final results = await Future.wait([
        Api.getSeriesInfo(sid),
        TMDB.search(widget.series['name'] ?? '', isTv: true),
      ]);
      if (!mounted) return;
      final data = results[0] as Map<String, dynamic>;
      final tmdb = results[1] as Map<String, String>;
      _seriesCover = widget.series['cover']?.toString() ?? widget.series['stream_icon']?.toString() ?? '';
      final seas = _seasons(data);
      final old = _tc;
      final tabCount = seas.isNotEmpty ? seas.length : 1;
      _tc = TabController(length: tabCount, vsync: this);
      _tc!.addListener(() {
        if (!_tc!.indexIsChanging) return;
        if (seas.isNotEmpty && _tc!.index < seas.length) {
          setState(() => _season = seas[_tc!.index]);
        }
      });
      old?.dispose();
      if (mounted) setState(() {
        _data = data; _tmdb = tmdb;
        _season = seas.isNotEmpty ? seas.first : 1;
        _busy = false;
      });
    } catch (_) { if (mounted) setState(() { _busy = false; _fail = true; }); }
  }

  List<int> _seasons(Map<String, dynamic> d) {
    final eps = d['episodes'];
    if (eps is! Map) return [];
    return eps.keys.map((k) => int.tryParse(k.toString()) ?? -1)
        .where((v) => v > 0).toList()..sort();
  }

  List<dynamic> _eps(int s) {
    final eps = _data?['episodes'];
    if (eps is! Map) return [];
    final l = eps['$s'];
    return l is List ? l : [];
  }

  void _playEp(dynamic ep) {
    if (!_canPlay(context)) return;
    GuestSession.startPlayback();
    final urls  = Api.episodeUrls(ep);
    final title = '${widget.series['name']} — ${ep['title']?.toString().isNotEmpty == true ? ep['title'] : 'الحلقة ${ep['episode_num']}'}';
    Navigator.push(context, _fade(PlayerPage(urls: urls, title: title, item: ep)));
  }

  @override void dispose() { _tc?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    if (_busy) return Scaffold(backgroundColor: C.bg,
        body: Center(child: _Pulse(label: widget.series['name'] ?? '')));
    if (_fail) return Scaffold(backgroundColor: C.bg,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, color: C.dim, size: 48),
          const SizedBox(height: 14),
          GestureDetector(onTap: _load, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md)),
            child: Text('إعادة المحاولة', style: T.cairo(s: FS.md, c: Colors.black, w: FontWeight.w800)))),
        ])));

    final tc      = _tc;
    if (tc == null) return Scaffold(backgroundColor: C.bg, body: const SizedBox.shrink());
    final info    = (_data?['info'] as Map?)?.cast<String, dynamic>() ?? {};
    final cover   = _tmdb['backdrop'] ?? _tmdb['poster'] ?? info['cover'] ?? _seriesCover;
    final poster  = _tmdb['poster']   ?? info['movie_image'] ?? _seriesCover;
    final plot    = info['plot'] ?? info['description'] ?? _tmdb['overview'] ?? '';
    final rating  = info['rating'] ?? _tmdb['rating'] ?? '';
    final genre   = info['genre'] ?? widget.series['category_name'] ?? '';
    final cast    = _tmdb['cast'] ?? '';
    final director= _tmdb['director'] ?? '';
    final seas    = _seasons(_data!);
    final eps     = _eps(_season);

    return Scaffold(backgroundColor: C.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: Stack(children: [
            // Backdrop
            SizedBox(height: 280 + top, width: double.infinity,
              child: cover.isNotEmpty
                  ? CachedNetworkImage(imageUrl: _imgUrl(cover), fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: C.surface))
                  : Container(color: C.surface)),
            Container(height: 280 + top, decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.97)]))),
            // Close button
            Positioned(top: top + 10, left: 14,
              child: GestureDetector(onTap: () => Navigator.pop(context),
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.6)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: C.textPri, size: 16)))),
            // Poster + Info
            Positioned(bottom: 0, left: 0, right: 0, child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (poster.isNotEmpty)
                  ClipRRect(borderRadius: BorderRadius.circular(R.sm),
                    child: SizedBox(width: 85, height: 120,
                      child: CachedNetworkImage(imageUrl: _imgUrl(poster), fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: C.surface)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, children: [
                  if (genre.isNotEmpty) _TagW(genre),
                  const SizedBox(height: 5),
                  Text(widget.series['name'] ?? '',
                      style: T.cairo(s: FS.lg, w: FontWeight.w900), maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, children: [
                    if (rating.isNotEmpty && rating != '0.0')
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded, color: C.gold, size: 13),
                        const SizedBox(width: 2),
                        Text(rating, style: TExtra.mont(s: FS.sm, c: C.gold)),
                      ]),
                    Text('${seas.length} موسم', style: TExtra.mont(s: FS.sm, c: C.grey)),
                  ]),
                ])),
              ]))),
          ])),
          // Plot
          if (plot.isNotEmpty)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,10,16,0),
              child: Text(plot, style: TExtra.mont(s: FS.sm, c: C.grey), maxLines: 3,
                  overflow: TextOverflow.ellipsis))),
          // Cast
          if (cast.isNotEmpty)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,6,16,0),
              child: RichText(text: TextSpan(children: [
                TextSpan(text: 'طاقم العمل: ', style: T.cairo(s: FS.sm, c: C.gold)),
                TextSpan(text: cast, style: T.cairo(s: FS.sm, c: C.grey)),
              ])))),
          // Season tabs
          if (seas.length > 1)
            SliverToBoxAdapter(child: Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CExtra.border))),
              child: TabBar(controller: tc, isScrollable: true,
                indicatorColor: C.gold, indicatorWeight: 2.5,
                labelColor: C.gold, unselectedLabelColor: C.grey,
                labelStyle: TExtra.mont(s: FS.sm, w: FontWeight.w700),
                unselectedLabelStyle: TExtra.mont(s: FS.sm),
                tabs: seas.map((s) => Tab(text: 'موسم $s')).toList()))),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(14,10,14,4),
            child: _CounterBar(label: '${eps.length} حلقة'))),
        ],
        body: _buildEpisodesList(eps, tc),
      ),
    );
  }

  Widget _buildEpisodesList(List<dynamic> eps, TabController tc) {
    if (_busy) return const Center(child: CircularProgressIndicator(color: C.gold, strokeWidth: 1.5));
    if (eps.isEmpty) {
      // حاول جلب الحلقات مرة أخرى
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.video_library_outlined, color: C.dim, size: 48),
        const SizedBox(height: 12),
        Text('لا توجد حلقات في هذا الموسم', style: T.cairo(s: FS.md, c: C.grey)),
        const SizedBox(height: 16),
        GestureDetector(onTap: _load, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md)),
          child: Text('إعادة التحميل', style: T.cairo(s: FS.sm, c: Colors.black, w: FontWeight.w700)))),
      ]));
    }
    return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: eps.length,
                itemBuilder: (_, i) {
                  final ep    = eps[i];
                  final n     = ep['episode_num']?.toString() ?? '${i+1}';
                  final title = ep['title']?.toString().isNotEmpty == true
                      ? ep['title'] : 'الحلقة $n';
                  final thumb = ep['info']?['movie_image']?.toString()
                      ?? ep['info']?['still_path']?.toString()
                      ?? _seriesCover;
                  final dur   = ep['info']?['duration']?.toString() ?? '';
                  final epPlot= ep['info']?['plot']?.toString() ?? '';
                  return GestureDetector(onTap: () => _playEp(ep),
                    child: Container(margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: C.card,
                          borderRadius: BorderRadius.circular(R.md),
                          border: Border.all(color: CExtra.border, width: 0.5)),
                      child: Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(R.sm),
                          child: SizedBox(width: 112, height: 66,
                            child: Stack(fit: StackFit.expand, children: [
                              thumb.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: _imgUrl(thumb), fit: BoxFit.cover,
                                      memCacheHeight: 200,
                                      errorWidget: (_, __, ___) => Container(color: C.surface))
                                  : Container(color: C.surface),
                              Center(child: Container(width: 30, height: 30,
                                decoration: BoxDecoration(shape: BoxShape.circle,
                                    color: Colors.black.withOpacity(0.6),
                                    border: Border.all(color: C.gold.withOpacity(0.8), width: 1.2)),
                                child: const Icon(Icons.play_arrow_rounded, color: C.gold, size: 18))),
                              Positioned(bottom: 4, right: 4,
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(R.tiny)),
                                  child: Text(n, style: TExtra.mont(s: FS.xs, c: C.textPri, w: FontWeight.w600)))),
                            ]))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: T.cairo(s: FS.sm, w: FontWeight.w700),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (dur.isNotEmpty) ...[const SizedBox(height: 3),
                            Row(children: [const Icon(Icons.access_time_rounded, color: C.dim, size: 11),
                              const SizedBox(width: 3), Text(dur, style: TExtra.mont(s: FS.sm, c: C.grey))])],
                          if (epPlot.isNotEmpty) ...[const SizedBox(height: 3),
                            Text(epPlot, style: TExtra.mont(s: FS.sm, c: C.grey),
                                maxLines: 2, overflow: TextOverflow.ellipsis)],
                        ])),
                        const Icon(Icons.play_circle_outline_rounded, color: C.gold, size: 20),
                      ])));
                },
              );
  }
}

// ══════════════════════════════════════════════════════════════
//  SPORTS DATA ENGINE — Live Scores + Team Logos + Matches
// ══════════════════════════════════════════════════════════════

// ── بيانات المباراة ───────────────────────────────────────────
class MatchData {
  final String id, homeTeam, awayTeam, homeScore, awayScore;
  final String minute, status, league, leagueLogo;
  final String homeLogo, awayLogo;
  final String matchTime; // HH:mm توقيت المباراة
  final String channelHint; // القناة المتوقعة

  const MatchData({
    required this.id, required this.homeTeam, required this.awayTeam,
    required this.homeScore, required this.awayScore,
    required this.minute, required this.status,
    required this.league, this.leagueLogo = '',
    this.homeLogo = '', this.awayLogo = '',
    this.matchTime = '', this.channelHint = '',
  });

  bool get isLive     => status == 'LIVE' || status == '1H' || status == '2H' || status == 'HT';
  bool get isFinished => status == 'FT' || status == 'AET' || status == 'PEN';
  bool get isScheduled=> status == 'NS'  || status == 'TBD' || status == 'SUSP';
  String get scoreDisplay => isScheduled ? matchTime : '$homeScore - $awayScore';
  String get minuteDisplay {
    if (status == 'HT') return 'استراحة';
    if (status == 'FT') return 'انتهت';
    if (isLive && minute.isNotEmpty) return "${minute}'";
    return '';
  }
}

// ── Sports API — TheSportsDB مجاني 100% ───────────────────────
class SportsApi {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));
  static final _cache = HashMap<String, dynamic>();

  // TheSportsDB base URL (مجاني كامل)
  static const _sdb = 'https://www.thesportsdb.com/api/v1/json/3';

  // API-Football via proxy/public endpoint
  static const _matchBase = 'https://api.sofascore.com/api/v1';

  // ── شعار الفريق من TheSportsDB ────────────────────────────────
  static Future<String> teamLogo(String teamName) async {
    if (teamName.isEmpty) return '';
    final key = 'logo_$teamName';
    if (_cache[key] != null) return _cache[key] as String;
    try {
      final r = await _dio.get('$_sdb/searchteams.php',
          queryParameters: {'t': teamName})
          .timeout(const Duration(seconds: 5));
      final teams = r.data['teams'] as List?;
      if (teams != null && teams.isNotEmpty) {
        final logo = teams.first['strTeamBadge']?.toString() ?? '';
        if (logo.isNotEmpty) {
          _cache[key] = logo;
          return logo;
        }
      }
    } catch (e) { debugPrint('[series_sports] $e'); }
    return '';
  }

  // ── مباريات اليوم من AllSports API (مجاني) ───────────────────
  static Future<List<MatchData>> todayMatches() async {
    const key = 'today_matches';
    if (_cache[key] is List<MatchData>) return _cache[key] as List<MatchData>;

    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';

    try {
      // AllSportsAPI — مجاني بدون مفتاح
      final r = await _dio.get(
        'https://allsportsapi.com/api/football/',
        queryParameters: {
          'met': 'Fixtures',
          'APIkey': '9f8c45b2e1d7a3f6c9e0b5d8a2f4c7e1b3d9f2a5',
          'from': date, 'to': date,
        },
      ).timeout(const Duration(seconds: 8));

      final matches = <MatchData>[];
      final result = r.data['result'] as List? ?? [];

      for (final m in result.take(50)) {
        final status = m['event_status']?.toString() ?? 'NS';
        final ht = m['event_home_team']?.toString() ?? '';
        final at = m['event_away_team']?.toString() ?? '';
        final league = m['league_name']?.toString() ?? '';
        final time = m['event_time']?.toString() ?? '';
        final hScore = m['event_final_result']?.toString().split(' - ').first ?? '-';
        final aScore = m['event_final_result']?.toString().split(' - ').last  ?? '-';
        final minute = m['event_clock']?.toString() ?? '';

        // اقتراح القناة بناءً على الدوري
        final channelHint = _guessChannel(league, ht, at);

        matches.add(MatchData(
          id: m['event_key']?.toString() ?? '',
          homeTeam: ht, awayTeam: at,
          homeScore: status == 'NS' ? '' : hScore,
          awayScore: status == 'NS' ? '' : aScore,
          minute: minute, status: _normalizeStatus(status),
          league: league,
          matchTime: time,
          channelHint: channelHint,
        ));
      }

      if (matches.isNotEmpty) {
        _cache[key] = matches;
        // إلغاء الكاش بعد 3 دقائق
        Future.delayed(const Duration(minutes: 3), () => _cache.remove(key));
      }
      return matches;
    } catch (_) {
      // Fallback: بيانات وهمية للتطوير
      return _demoMatches();
    }
  }

  static String _normalizeStatus(String s) {
    final sl = s.toLowerCase();
    if (sl == '1st half' || sl == 'first half' || sl == '1h') return '1H';
    if (sl == '2nd half' || sl == 'second half' || sl == '2h') return '2H';
    if (sl == 'half time' || sl == 'ht') return 'HT';
    if (sl == 'finished' || sl == 'ft') return 'FT';
    if (sl == 'not started' || sl == 'ns') return 'NS';
    if (sl.contains('live') || sl.contains('progress')) return 'LIVE';
    return s.toUpperCase();
  }

  // ── تخمين القناة من اسم الدوري ────────────────────────────
  static String _guessChannel(String league, String home, String away) {
    final l = league.toLowerCase();
    if (l.contains('champions') || l.contains('أبطال')) return 'beIN Sports 3';
    if (l.contains('premier') || l.contains('إنجليزي')) return 'beIN Sports 1';
    if (l.contains('la liga') || l.contains('إسباني')) return 'beIN Sports 2';
    if (l.contains('bundesliga') || l.contains('ألماني')) return 'Sky Sports';
    if (l.contains('serie a') || l.contains('إيطالي')) return 'beIN Sports 4';
    if (l.contains('ligue 1') || l.contains('فرنسي')) return 'beIN Sports 5';
    if (l.contains('euro') || l.contains('uefa')) return 'beIN Sports 1';
    if (l.contains('copa') || l.contains('كأس')) return 'beIN Sports 2';
    return 'beIN Sports';
  }

  // ── بيانات تجريبية للـ fallback ───────────────────────────────
  static List<MatchData> _demoMatches() => [
    const MatchData(id:'1', homeTeam:'ريال مدريد', awayTeam:'برشلونة',
        homeScore:'2', awayScore:'1', minute:'68', status:'2H',
        league:'La Liga', channelHint:'beIN Sports 2'),
    const MatchData(id:'2', homeTeam:'مانشستر سيتي', awayTeam:'ليفربول',
        homeScore:'1', awayScore:'1', minute:'45', status:'HT',
        league:'Premier League', channelHint:'beIN Sports 1'),
    const MatchData(id:'3', homeTeam:'بايرن ميونيخ', awayTeam:'دورتموند',
        homeScore:'', awayScore:'', minute:'', status:'NS',
        league:'Bundesliga', matchTime:'21:30', channelHint:'Sky Sports'),
    const MatchData(id:'4', homeTeam:'يوفنتوس', awayTeam:'ميلان',
        homeScore:'', awayScore:'', minute:'', status:'NS',
        league:'Serie A', matchTime:'22:00', channelHint:'beIN Sports 4'),
    const MatchData(id:'5', homeTeam:'PSG', awayTeam:'مارسيليا',
        homeScore:'3', awayScore:'0', minute:'', status:'FT',
        league:'Ligue 1', channelHint:'beIN Sports 5'),
    const MatchData(id:'6', homeTeam:'الأرسنال', awayTeam:'تشيلسي',
        homeScore:'', awayScore:'', minute:'', status:'NS',
        league:'Premier League', matchTime:'23:00', channelHint:'beIN Sports 1'),
  ];
}



// ══════════════════════════════════════════════════════════════
//  SPORTS PAGE — Full Rebuild v17.0
//  Live Scores + Team Logos + Match Cards + Channel Linking
// ══════════════════════════════════════════════════════════════
class SportsPage extends StatefulWidget {
  const SportsPage();
  @override State<SportsPage> createState() => _SportsPageState();
}

class _SportsPageState extends State<SportsPage>
    with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  // ── حالة الصفحة ─────────────────────────────────────────────
  bool _busy    = true;
  String _status= '';
  int _heroCur  = 0;

  // ── القنوات الرياضية ──────────────────────────────────────────
  List<dynamic> _channels = [];

  // ── كلمات مفتاحية للرياضة ────────────────────────────────────
  // Only: beIN Sports + الثامنة الرياضية + Sky Sports
  static const _sportsKw = [
    'bein', 'beinsport', 'بين', 'bein sport',
    'sky sport', 'sky sports', 'sky',
    'الثامنه', 'الثامنة', 'thaminah', 'al thaminah',
    'sport', 'sports', 'رياضة', 'رياضي',
    'eurosport', 'espn', 'dazn', 'مباشر رياضي',
    'كرة', 'football', 'soccer', 'nba', 'ufc',
  ];

  // أنواع قنوات متعددة
  static const _catDefs = [
    {'key': 'bein',        'label': 'beIN Sports',        'color': 0xFF00A651},
    {'key': 'sky',         'label': 'Sky Sports',         'color': 0xFF1D4ED8},
    {'key': 'الثامنه',     'label': 'الثامنة الرياضية',   'color': 0xFFDC2626},
    {'key': 'eurosport',   'label': 'Eurosport',          'color': 0xFFFF6B00},
    {'key': 'espn',        'label': 'ESPN',               'color': 0xFFCC0000},
    {'key': 'كرة',         'label': 'كرة القدم',          'color': 0xFF7C3AED},
    {'key': 'nba',         'label': 'NBA Basketball',     'color': 0xFF1D428A},
    {'key': 'ufc',         'label': 'UFC / المصارعة',     'color': 0xFF991B1B},
  ];

  List<dynamic> get _heroCh {
    final prio = _channels.where((c) {
      final n = (c['name']??'').toString().toLowerCase();
      return n.contains('bein') || n.contains('بين') || n.contains('sky');
    }).take(10).toList();
    return prio.isNotEmpty ? prio : _channels.take(8).toList();
  }

  List<dynamic> _catCh(String key) {
    final all = _channels.where((c) {
      final n = '${c['name']??''} ${c['category_name']??''}'.toLowerCase();
      return n.contains(key.toLowerCase());
    }).toList();
    if (Sub.isFree)   return all.take(4).toList();
    if (SubCompat.isNormal) return all.take(15).toList();
    return all;
  }

  @override void initState() {
    super.initState();
    _load();
  }

  @override void dispose() {
    super.dispose();
  }

  // ── تحميل القنوات ─────────────────────────────────────────────
  Future<void> _load({bool force = false}) async {
    if (mounted) setState(() { _busy = true; _status = 'جاري التحميل...'; });
    if (AppState.allLive.isNotEmpty && !force) {
      _filterChannels(AppState.allLive);
      if (_channels.isNotEmpty) {
        if (mounted) setState(() { _busy = false; _status = ''; });
        _refreshBg(); return;
      }
    }
    try {
      final live = await Api.getList('get_live_streams', force: force);
      if (live.isNotEmpty) { AppState.allLive = live; _filterChannels(live); }
    } catch (e) { debugPrint('[series_sports] $e'); }
    if (_channels.isEmpty) {
      try {
        final cats = await Api.getList('get_live_categories');
        final sCats = cats.where((c) {
          final n = (c['category_name']??'').toString().toLowerCase();
          return _sportsKw.any((k) => n.contains(k));
        }).toList();
        final chs = <dynamic>[];
        for (final cat in sCats.take(8)) {
          final id = cat['category_id']?.toString() ?? '';
          if (id.isEmpty) continue;
          chs.addAll(await Api.getList('get_live_streams', extra: {'category_id': id}));
        }
        if (chs.isNotEmpty) _filterChannels(chs);
      } catch (e) { debugPrint('[series_sports] $e'); }
    }
    if (mounted) setState(() { _busy = false; _status = ''; });
  }

  void _filterChannels(List<dynamic> all) {
    final f = all.where((ch) {
      final n = '${ch['name']??''} ${ch['category_name']??''}'.toLowerCase();
      // Strictly: beIN Sports + Sky Sports + الثامنة الرياضية ONLY
      final isBein = n.contains('bein') || n.contains('بين') || n.contains('be in') ||
                     n.contains('beinsport');
      final isSky  = n.contains('sky sport') || n.contains('sky sports') ||
                     n.contains('سكاي');
      final is8th  = n.contains('الثامنه') || n.contains('الثامنة') ||
                     n.contains('8 sport') || n.contains('thaminah') ||
                     n.contains('al thaminah');
      return isBein || isSky || is8th;
    }).toList();
    f.sort((a, b) {
      final na = (a['name']??'').toString().toLowerCase();
      final nb = (b['name']??'').toString().toLowerCase();
      if (_chScore(na) != _chScore(nb)) return _chScore(nb).compareTo(_chScore(na));
      final na2 = RegExp(r'\d+').firstMatch(na);
      final nb2 = RegExp(r'\d+').firstMatch(nb);
      final ai = int.tryParse(na2?.group(0)??'999')??999;
      final bi = int.tryParse(nb2?.group(0)??'999')??999;
      return ai.compareTo(bi);
    });
    _channels = f.isNotEmpty ? f : all.take(50).toList();
  }

  int _chScore(String n) {
    if (n.contains('bein') && n.contains('4k')) return 95;
    if (n.contains('bein') || n.contains('بين')) return 100;
    if (n.contains('sky sport')) return 90;
    if (n.contains('eurosport')) return 85;
    if (n.contains('arena'))     return 80;
    if (n.contains('dazn'))      return 75;
    return 60;
  }

  Future<void> _refreshBg() async {
    try {
      final live = await Api.getList('get_live_streams', force: true);
      if (live.isNotEmpty && mounted) {
        AppState.allLive = live; _filterChannels(live);
        if (mounted) setState(() {});
      }
    } catch (e) { debugPrint('[series_sports] $e'); }
  }

  void _play(dynamic ch) {
    if (!_canPlay(context)) return;
    Sound.hapticL();
    GuestSession.startPlayback();
    Navigator.push(context, _fade(PlayerPage(
        urls: Api.liveUrls(ch),
        title: ch['name']?.toString() ?? '', isLive: true, item: ch)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final top = MediaQuery.of(context).padding.top;

    if (_busy && _channels.isEmpty) return _buildLoading(top);

    return Scaffold(backgroundColor: C.bg,
      body: RefreshIndicator(
        color: C.gold, backgroundColor: C.surface, strokeWidth: 1.5,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // ── Header ──────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(top)),
            // ── Hero Carousel ───────────────────────────
            if (_heroCh.isNotEmpty)
              SliverToBoxAdapter(child: _buildHero()),
            // ── القنوات الرياضية مقسمة مع عرض الكل ────
            for (final cat in _catDefs) ...() {
              final list = _catCh(cat['key'] as String);
              if (list.isEmpty) return <Widget>[];
              return [
                SliverToBoxAdapter(child: _SectionHdr(
                    title: '${cat['label']}  •  ${list.length}',
                    onMore: () {
                      // عرض الكل — صفحة شبكية
                      Navigator.push(context, _fade(Scaffold(
                        backgroundColor: C.bg,
                        appBar: AppBar(backgroundColor: C.bg,
                          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                              onPressed: () => Navigator.pop(context)),
                          title: Text(cat['label'] as String, style: TExtra.h2())),
                        body: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _channelCard(list[i])),
                      )));
                    })),
                SliverToBoxAdapter(child: _hRow(list)),
              ];
            }(),
            // ── كل القنوات ──────────────────────────────
            SliverToBoxAdapter(child: _secHdr('كل القنوات', _channels.length)),
            SliverToBoxAdapter(child: _grid2col(_channels)),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Widget _channelCard(dynamic ch) {
    final nm = ch['name']?.toString() ?? '';
    return GestureDetector(
      onTap: () => _play(ch),
      child: Container(
        decoration: BoxDecoration(
          color: C.card, borderRadius: BorderRadius.circular(S.rMd),
          border: Border.all(color: CExtra.border, width: 0.4)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(S.rMd),
          child: Stack(fit: StackFit.expand, children: [
            SmartPoster(item: ch, fit: BoxFit.contain, radius: BorderRadius.circular(S.rMd)),
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)])),
                child: Text(nm, style: T.caption(c: CC.textPri).copyWith(fontSize: FS.xs, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center))),
          ]))));
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(double top) => Container(
    padding: EdgeInsets.fromLTRB(16, top + 12, 16, 8),
    color: C.bg,
    child: Row(children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: CC.goldBg, borderRadius: BorderRadius.circular(R.md)),
        child: const Icon(Icons.sports_soccer_rounded, color: C.gold, size: 20)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('رياضة', style: TExtra.h1()),
      ]),
      const Spacer(),
      GestureDetector(
        onTap: () { _load(force: true); },
        child: Container(width: 34, height: 34,
          decoration: BoxDecoration(color: C.surface,
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: CExtra.border, width: 0.5)),
          child: const Icon(Icons.refresh_rounded, color: C.grey, size: 17))),
    ]));

  // ── Hero Carousel ──────────────────────────────────────────────
  Widget _buildHero() {
    final h   = MediaQuery.of(context).size.height * 0.38;
    final list = _heroCh;
    return SizedBox(height: h, child: Stack(children: [
      _AutoPageView(
        itemCount: list.length,
        interval: const Duration(seconds: 5),
        onPageChanged: (i) => setState(() => _heroCur = i),
        itemBuilder: (_, i) {
          final ch  = list[i];
          final nm  = ch['name']?.toString() ?? '';
          return GestureDetector(onTap: () => _play(ch),
            child: Stack(fit: StackFit.expand, children: [
              SmartPoster(item: ch, fit: BoxFit.cover,
                  radius: BorderRadius.zero),
              DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    stops: const [0.2, 1.0],
                    colors: [Colors.transparent, Colors.black.withOpacity(0.96)]))),
              Positioned(bottom: 60, left: 16, right: 16,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _LiveBadge(),
                  const SizedBox(height: 6),
                  Text(nm, style: TExtra.display(), maxLines: 1,
                      overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                ])),
              Positioned(bottom: 20, left: 16, right: 16,
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  GestureDetector(onTap: () => _play(ch),
                    child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(gradient: C.playGrad,
                          borderRadius: BorderRadius.circular(S.rPill)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 18),
                        const SizedBox(width: 4),
                        Text('مشاهدة', style: TExtra.label(c: Colors.black)),
                      ]))),
                ])),
            ]));
        }),
      Positioned(bottom: 8, left: 0, right: 0,
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(list.length > 8 ? 8 : list.length, (i) =>
            AnimatedContainer(duration: const Duration(milliseconds: 200),
              width: i == _heroCur ? 18 : 4, height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                  color: i == _heroCur ? C.gold : C.dim,
                  borderRadius: BorderRadius.circular(R.tiny)))))),
    ]));
  }

  Widget _buildLoading(double top) => Scaffold(backgroundColor: C.bg,
    body: Column(children: [
      _buildHeader(top),
      Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _Pulse(label: 'الرياضة'), const SizedBox(height: 12),
        Text(_status, style: T.body()),
      ]))),
    ]));

  Widget _buildEmpty(String msg, IconData icon) => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(S.rXl)),
        child: Icon(icon, color: C.dim, size: 36)),
      const SizedBox(height: 16),
      Text(msg, style: TExtra.h2()),
      const SizedBox(height: 24),
      GestureDetector(onTap: () { _load(force: true); },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(S.rLg)),
          child: Text('إعادة المحاولة', style: TExtra.label(c: Colors.black)))),
    ]));

  Widget _secHdr(String label, int count, {Color color = C.gold}) =>
    Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(R.tiny))),
        const SizedBox(width: 10),
        Text(label, style: TExtra.h2()),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(S.rPill)),
          child: Text('$count', style: TExtra.label(c: color, s: FS.sm))),
      ]));

  Widget _sportsBg(String name) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(
        colors: [Color(0xFF0A1628), Color(0xFF1A2840)],
        begin: Alignment.topLeft, end: Alignment.bottomRight)),
    child: Center(child: Icon(Icons.sports_soccer_rounded,
        color: C.gold.withOpacity(0.4), size: 28)));

  Widget _grid2col(List<dynamic> list) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: 4),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 1.6,
        crossAxisSpacing: 10, mainAxisSpacing: 10),
    itemCount: list.length > 60 ? 60 : list.length,
    itemBuilder: (_, i) {
      final ch = list[i]; final nm = ch['name']?.toString() ?? '';
      return GestureDetector(onTap: () => _play(ch),
        child: ClipRRect(borderRadius: BorderRadius.circular(S.rMd),
          child: Stack(fit: StackFit.expand, children: [
            SmartPoster(item: ch, fit: BoxFit.cover, radius: BorderRadius.circular(S.rMd)),
            DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
            Positioned(top: 6, left: 6,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: CExtra.live, borderRadius: BorderRadius.circular(R.tiny)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 4, height: 4, margin: const EdgeInsets.only(right: 3),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: C.textPri)),
                  Text('LIVE', style: TExtra.label(c: C.textPri, s: 7)),
                ]))),
            Positioned(bottom: 6, left: 6, right: 6,
              child: Text(nm, style: T.caption(c: CC.textPri).copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
          ])));
    });

  Widget _hRow(List<dynamic> list) => SizedBox(height: 118,
    child: ListView.builder(scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: list.length > 20 ? 20 : list.length,
      itemBuilder: (_, i) {
        final ch = list[i]; final nm = ch['name']?.toString() ?? '';
        return GestureDetector(onTap: () => _play(ch),
          child: Container(width: 160, margin: const EdgeInsets.only(right: 10),
            child: ClipRRect(borderRadius: BorderRadius.circular(S.rMd),
              child: Stack(fit: StackFit.expand, children: [
                SmartPoster(item: ch, fit: BoxFit.cover, radius: BorderRadius.circular(S.rMd)),
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)]))),
                Positioned(top: 5, left: 5,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: CExtra.live, borderRadius: BorderRadius.circular(R.tiny)),
                    child: Text('LIVE', style: TExtra.label(c: C.textPri, s: 7)))),
                Positioned(bottom: 6, left: 6, right: 6,
                  child: Text(nm, style: T.caption(c: CC.textPri).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
              ]))));
      }));
}

// ── Match Card — بطاقة مباراة احترافية ───────────────────────
class _MatchCard extends StatelessWidget {
  final MatchData match;
  final VoidCallback? onPlay;
  const _MatchCard({required this.match, this.onPlay});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: match.isLive ? onPlay : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(S.rLg),
          border: Border.all(
            color: match.isLive ? CExtra.live.withOpacity(0.3) : CExtra.border,
            width: match.isLive ? 0.8 : 0.4)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // League + status
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: match.isLive ? CExtra.live.withOpacity(0.12)
                      : match.isFinished ? C.surface : CC.goldBg,
                  borderRadius: BorderRadius.circular(S.rPill)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (match.isLive) ...[
                  Container(width: 5, height: 5, margin: const EdgeInsets.only(right: 4),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: CExtra.live)),
                  Text('مباشر', style: TExtra.label(c: CExtra.live, s: FS.sm)),
                ] else if (match.isFinished)
                  Text('انتهت', style: TExtra.label(c: C.grey, s: FS.sm))
                else
                  Text(match.matchTime, style: TExtra.label(c: C.gold, s: FS.sm)),
              ])),
            const SizedBox(width: 8),
            Expanded(child: Text(match.league,
                style: T.caption(), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (match.channelHint.isNotEmpty)
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: CC.goldBg2, borderRadius: BorderRadius.circular(S.rPill),
                    border: Border.all(color: C.gold.withOpacity(0.3), width: 0.5)),
                child: Text(match.channelHint, style: TExtra.label(c: C.gold, s: FS.xs))),
          ]),
          const SizedBox(height: 12),
          // Teams + Score
          Row(children: [
            // فريق المنزل
            Expanded(child: Column(children: [
              _TeamLogo(name: match.homeTeam),
              const SizedBox(height: 6),
              Text(match.homeTeam, style: T.body(c: CC.textPri).copyWith(
                  fontWeight: FontWeight.w700, fontSize: FS.sm),
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ])),
            // النتيجة
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: match.isLive ? Colors.black : C.surface,
                borderRadius: BorderRadius.circular(S.rMd),
                border: Border.all(
                    color: match.isLive ? CExtra.live.withOpacity(0.4) : CExtra.border,
                    width: 0.5)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(match.scoreDisplay,
                  style: TextStyle(
                    color: match.isLive ? Colors.white : CC.textSec,
                    fontSize: match.isScheduled ? 14 : 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace')),
                if (match.minuteDisplay.isNotEmpty)
                  Text(match.minuteDisplay,
                    style: TExtra.label(c: match.status == 'HT' ? C.gold : CExtra.live, s: FS.sm)),
              ])),
            // فريق الضيف
            Expanded(child: Column(children: [
              _TeamLogo(name: match.awayTeam),
              const SizedBox(height: 6),
              Text(match.awayTeam, style: T.body(c: CC.textPri).copyWith(
                  fontWeight: FontWeight.w700, fontSize: FS.sm),
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ])),
          ]),
          // زر مشاهدة (للمباريات الحية فقط)
          if (match.isLive && onPlay != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onPlay,
              child: Container(height: 38, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: C.playGrad, borderRadius: BorderRadius.circular(S.rMd)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 18),
                  const SizedBox(width: 6),
                  Text('شاهد على ${match.channelHint}',
                      style: TExtra.label(c: Colors.black)),
                ]))),
          ],
        ]),
      ),
    );
  }
}

// ── Team Logo Widget ───────────────────────────────────────────
class _TeamLogo extends StatefulWidget {
  final String name;
  const _TeamLogo({required this.name});
  @override State<_TeamLogo> createState() => _TeamLogoState();
}
class _TeamLogoState extends State<_TeamLogo> {
  String _logoUrl = '';
  @override void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final url = await SportsApi.teamLogo(widget.name);
    if (mounted && url.isNotEmpty) setState(() => _logoUrl = url);
  }
  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
        shape: BoxShape.circle, color: C.surface,
        border: Border.all(color: CExtra.border, width: 0.5)),
    child: ClipOval(child: _logoUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: _logoUrl, fit: BoxFit.contain,
            placeholder: (_, __) => const _ShimmerBox(),
            errorWidget: (_, __, ___) => _fallback())
        : _fallback()));

  Widget _fallback() => Center(child: Text(
      widget.name.isNotEmpty ? widget.name[0] : '?',
      style: TExtra.h2(c: C.gold)));
}

// ── Match Hero Banner — يظهر في الـ Hero الكبير ───────────────
class _MatchHeroBanner extends StatelessWidget {
  final MatchData match;
  const _MatchHeroBanner({required this.match});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(S.rLg),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(S.rLg),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5)),
        child: Row(children: [
          Expanded(child: Text(match.homeTeam,
              style: T.body(c: CC.textPri).copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.right, maxLines: 1)),
          Container(margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: CExtra.live.withOpacity(0.15),
                borderRadius: BorderRadius.circular(S.rMd),
                border: Border.all(color: CExtra.live.withOpacity(0.4))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(match.scoreDisplay,
                  style: const TextStyle(color: C.textPri, fontSize: FS.lg,
                      fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              if (match.minuteDisplay.isNotEmpty)
                Text(match.minuteDisplay, style: TExtra.label(c: CExtra.live, s: FS.xs)),
            ])),
          Expanded(child: Text(match.awayTeam,
              style: T.body(c: CC.textPri).copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.left, maxLines: 1)),
        ]))));
}



// ══════════════════════════════════════════════════════════════
//  PROFILE PAGE — بتصميم TOD
// ══════════════════════════════════════════════════════════════
