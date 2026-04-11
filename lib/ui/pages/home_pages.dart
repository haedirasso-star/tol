part of '../../main.dart';

// ── Play gate: فحص صلاحية التشغيل ────────────────────────────
// يتحقق من: هل المستخدم مسجّل؟ هل له وقت مشاهدة متبقٍ؟
bool _canPlay(BuildContext context) {
  final user = AuthService.currentUser;
  // ضيف بدون حساب → يُظهر نافذة تسجيل الدخول
  if (user == null) {
    showLoginGate(context);
    return false;
  }
  // مشترك مدفوع → مسموح دائماً
  if (SubCompat.isPremium) return true;
  // مسجّل مجاني → يتحقق من الوقت المتبقي
  if (GuestSession.isExpired) {
    showFreeExpired(context);
    return false;
  }
  return true;
}


class HomePage extends StatefulWidget {
  const HomePage();
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  List<_HeroItem> _heroes = [];
  List<Map<String,dynamic>> _featuredActors = [];
  bool _busy  = true;
  int  _hIdx  = 0;

  @override void initState() { super.initState(); _build(); _loadActors(); }

  Future<void> _build() async {
    setState(() => _busy = true);

    // Step 1: ابدأ التحميل فوراً
    if (!AppState.isLoaded) {
      AppState.loadAll().then((_) {
        if (mounted) _buildHeroes();
      }).catchError((_) {
        if (mounted) setState(() => _busy = false);
      });
    }

    // Step 2: أظهر skeleton في الحال
    if (mounted) setState(() => _busy = false);

    // Step 3: انتظر البيانات لمدة قصيرة ثم ابنِ
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted && (AppState.allMovies.isNotEmpty || AppState.allSeries.isNotEmpty ||
        AppState.allLive.isNotEmpty)) {
      await _buildHeroes();
    } else if (mounted) {
      // حاول مرة أخرى بعد تحميل البيانات
      AppState.loadAll(force: true).then((_) {
        if (mounted) _buildHeroes();
      });
    }
  }

  // فلترة المحتوى غير المناسب للـ Hero الرئيسي
  bool _isHeroEligible(dynamic item) {
    final name = (item['name'] ?? '').toString().toLowerCase();
    final cat  = (item['category_name'] ?? '').toString().toLowerCase();
    // استبعاد: أطفال، كرتون، max، disney، adult
    const excluded = ['kids','أطفال','cartoon','baby','children','max ',
                      'disney','adult','xxx','18+','toddler'];
    for (final kw in excluded) {
      if (name.contains(kw) || cat.contains(kw)) return false;
    }
    return true;
  }

  Future<void> _buildHeroes() async {
    if (!mounted) return;
    // فلترة: بدون قنوات أطفال أو max أو كرتون
    final eligibleMovies  = AppState.allMovies.where(_isHeroEligible).take(10).toList();
    final eligibleSeries  = AppState.allSeries.where(_isHeroEligible).take(10).toList();
    final featured = [...eligibleMovies, ...eligibleSeries];
    if (featured.isEmpty) return;
    featured.shuffle();

    // Step 3: أظهر المحتوى فوراً بدون TMDB
    final quickHeroes = <_HeroItem>[];
    for (final item in featured.take(8)) {
      final isTv = AppState.allSeries.contains(item);
      final name = item['name']?.toString() ?? '';
      final icon = item['stream_icon']?.toString() ?? item['cover']?.toString() ?? '';
      quickHeroes.add(_HeroItem(
        item: item, isTv: isTv,
        backdrop: icon, poster: icon,
        title: name, overview: '', rating: '', year: '',
        cast: '', director: '', needsSub: false,
      ));
    }
    if (mounted) setState(() => _heroes = quickHeroes);

    // Step 4: حسّن بـ TMDB في الخلفية (بالتوازي)
    _enrichWithTmdb(featured.take(8).toList());
  }

  Future<void> _loadActors() async {
    // جلب أشهر الممثلين من TMDB
    try {
      final r = await Dio().get('https://api.themoviedb.org/3/person/popular',
          queryParameters: {'api_key': TMDB._defaultKey, 'language': 'ar', 'page': 1});
      final results = (r.data['results'] as List?)?.cast<Map>() ?? [];
      if (!mounted) return;
      setState(() {
        _featuredActors = results.take(15).map((p) => <String,dynamic>{
          'id':    p['id'],
          'name':  p['name'] ?? '',
          'photo': p['profile_path'] != null
              ? 'https://image.tmdb.org/t/p/w185${p['profile_path']}' : '',
          'dept':  p['known_for_department'] ?? '',
          'known_for': (p['known_for'] as List?)?.take(1)
              .map((m) => m['title'] ?? m['name'] ?? '').join('') ?? '',
        }).toList();
      });
    } catch (_) {}
  }

  Widget _buildActorsSection() {
    if (_featuredActors.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(children: [
          Container(width: 3, height: 18, color: C.gold, margin: const EdgeInsets.only(left: 8)),
          Text('نجوم وممثلون', style: TExtra.h2()),
          const Spacer(),
          GestureDetector(onTap: () {},
              child: Text('عرض الكل', style: T.caption(c: C.gold))),
        ]),
      ),
      SizedBox(height: 120, child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemCount: _featuredActors.length,
        itemBuilder: (ctx, i) {
          final a = _featuredActors[i];
          return GestureDetector(
            onTap: () => Navigator.push(ctx, _fade(ActorPage(
                actorId: a['id'] as int, actorName: a['name'].toString(),
                photoUrl: a['photo'].toString()))),
            child: SizedBox(width: 72, child: Column(children: [
              CircleAvatar(radius: 36, backgroundColor: C.surface,
                backgroundImage: (a['photo'] as String).isNotEmpty
                    ? CachedNetworkImageProvider(a['photo'].toString()) : null,
                child: (a['photo'] as String).isEmpty
                    ? const Icon(Icons.person, color: C.dim) : null),
              const SizedBox(height: 5),
              Text(a['name'].toString(), style: T.caption(),
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              if ((a['known_for'] as String).isNotEmpty)
                Text(a['known_for'].toString(), style: T.caption(c: C.dim),
                    maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ])),
          );
        },
      )),
    ]));
  }

    Future<void> _enrichWithTmdb(List items) async {
    // كل الطلبات بالتوازي — لا تسلسل
    final futures = items.map((item) async {
      final isTv = AppState.allSeries.contains(item);
      final name = item['name']?.toString() ?? '';
      final icon = item['stream_icon']?.toString() ?? item['cover']?.toString() ?? '';
      try {
        // Fetch TMDB info + trailer key in parallel
        final results2 = await Future.wait([
          TMDB.search(name, isTv: isTv).timeout(const Duration(seconds: 6), onTimeout: () => <String,String>{}),
          TMDB.getTrailerKeyByName(name, isTv: isTv).timeout(const Duration(seconds: 8), onTimeout: () => null).then((v) => v ?? '').catchError((_) => ''),
        ]);
        final tmdb = results2[0] as Map<String, String>;
        final trailerKey = results2[1] as String;
        final year = tmdb['year'] ?? '';
        return _HeroItem(
          item: item, isTv: isTv,
          backdrop: tmdb['backdrop']?.isNotEmpty == true ? tmdb['backdrop']! : icon,
          poster:   tmdb['poster_sm']?.isNotEmpty == true ? tmdb['poster_sm']! : icon,
          title:    tmdb['title']?.isNotEmpty == true ? tmdb['title']! : name,
          overview: tmdb['overview'] ?? '',
          rating:   tmdb['rating']   ?? '',
          year:     year,
          cast:     tmdb['cast']     ?? '',
          director: tmdb['director'] ?? '',
          needsSub: _isNew(year),
          trailerKey: trailerKey,
        );
      } catch (_) {
        return null;
      }
    }).toList();

    final results = await Future.wait(futures);
    if (!mounted) return;
    final enriched = results.whereType<_HeroItem>().toList();
    if (enriched.isNotEmpty) setState(() => _heroes = enriched);
  }

  // المحتوى الجديد (2025/2026) يحتاج اشتراك

  // ── Skeleton Loading — بدلاً من الشاشة السوداء ────────
  Widget _buildSkeleton() {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(children: [
          // Hero skeleton
          Container(
            height: 220, margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.surface, borderRadius: BorderRadius.circular(16)),
            child: Center(child: _Pulse(label: 'TOTV+')),
          ),
          // Filter chips skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: List.generate(4, (i) => Container(
              margin: const EdgeInsets.only(right: 8),
              width: 70, height: 32,
              decoration: BoxDecoration(
                color: C.surface, borderRadius: BorderRadius.circular(16)),
            ))),
          ),
          const SizedBox(height: 16),
          // Grid skeleton
          Expanded(child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
              childAspectRatio: 0.65),
            itemCount: 12,
            itemBuilder: (_, __) => _SkeletonCard(),
          )),
        ]),
      ),
    );
  }

  bool _isNew(String year) {
    // VIP: never needs subscribe
    if (SubCompat.isPremium) return false; // أي مشترك (Premium أو TOTV) لا يحتاج اشتراك
    if (year.isEmpty) return false;
    final y = int.tryParse(year) ?? 0;
    return y >= 2025;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // بدلاً من شاشة بيضاء/سوداء — أظهر skeleton loading
    if (_busy && _heroes.isEmpty) return _buildSkeleton();

    return Scaffold(
      backgroundColor: C.bg,
      body: RefreshIndicator(color: C.gold, backgroundColor: C.surface, strokeWidth: 1.5,
        onRefresh: () async {
          ListCache.invalidate(); await AppState.loadAll(force: true); await _build();
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          cacheExtent: 1600,
          slivers: [
            // ── Hero Carousel (TOD Style) ──
            if (_heroes.isNotEmpty)
              SliverToBoxAdapter(child: _TODHeroCarousel(
                heroes: _heroes,
                curIdx: _hIdx,
                onChanged: (i) => setState(() => _hIdx = i),
                onPlay: _playHero,
                onInfo: _infoHero,
              )),

            // ── Navigation Categories (TOD horizontal tabs) ──
            SliverToBoxAdapter(child: _CategoryTabs(
              cats: ['الكل', 'أفلام', 'مسلسلات', 'مباشر'],
              onTap: (_) {},
            )),

            // ── تابع ما بدأت (Netflix-style) ──────────────────
            if (Recommendations.continueWatching().isNotEmpty) ...[
              SliverToBoxAdapter(child: _SectionHdr(
                title: 'تابع ما بدأت',
                icon: Icons.play_circle_rounded,
                onMore: () {})),
              SliverToBoxAdapter(child: _ContinueWatchingRow(
                  items: Recommendations.continueWatching(),
                  onTap: _openInfo)),
            ],

            // ── مقترح لك ─────────────────────────────────────────
            if (Recommendations.forYou().isNotEmpty) ...[
              SliverToBoxAdapter(child: _SectionHdr(
                title: 'مقترح لك',
                icon: Icons.auto_awesome_rounded,
                onMore: () {})),
              SliverToBoxAdapter(child: _LandscapeRow(
                  items: Recommendations.forYou(limit: 15),
                  type: 'movie', onTap: _openInfo)),
            ],

            // ── أحدث الأفلام ──────────────────────────────────────
            if (AppState.allMovies.isNotEmpty) ...[
              SliverToBoxAdapter(child: _SectionHdr(title: 'أحدث الأفلام', onMore: () {})),
              SliverToBoxAdapter(child: _LandscapeRow(
                  items: AppState.allMovies.take(15).toList(),
                  type: 'movie', onTap: _openInfo)),
            ],

            // ── أحدث المسلسلات ────────────────────────────────────
            if (AppState.allSeries.isNotEmpty) ...[
              SliverToBoxAdapter(child: _SectionHdr(title: 'أحدث المسلسلات', onMore: () {})),
              SliverToBoxAdapter(child: _PortraitRow(
                  items: AppState.allSeries.take(15).toList(),
                  type: 'series', onTap: _openInfo)),
            ],

            // ── نجوم وممثلون ──────────────────────────────────────
            if (_featuredActors.isNotEmpty)
              _buildActorsSection(),

            // ── البث المباشر ──────────────────────────────────────
            if (AppState.allLive.isNotEmpty) ...[
              SliverToBoxAdapter(child: _SectionHdr(title: 'البث المباشر', onMore: () {})),
              SliverToBoxAdapter(child: _LiveChannelRow(
                  items: AppState.allLive.take(12).toList(),
                  onTap: _openInfo)),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ])));
  }

  void _playHero(_HeroItem h) {
    if (!_canPlay(context)) return;
    Ads.show();
    GuestSession.startPlayback();
    if (h.isTv) { Navigator.push(context, _fade(SeriesDetailPage(series: h.item))); return; }
    Navigator.push(context, _fade(PlayerPage(
        urls: Api.movieUrls(h.item), title: h.title, item: h.item)));
  }

  void _infoHero(_HeroItem h) {
    _showInfo(h.item, h.isTv ? 'series' : 'movie',
        backdrop: h.backdrop, poster: h.poster, title: h.title,
        overview: h.overview, rating: h.rating, year: h.year,
        cast: h.cast, director: h.director, needsSub: h.needsSub);
  }

  void _openInfo(dynamic item, String type) {
    Sound.hapticL();
    _showInfoLazy(item, type);
  }

  // ترشيحات ذكية بناءً على تاريخ المشاهدة
  List<dynamic> _getRecommended() {
    final pool = [...AppState.allMovies, ...AppState.allSeries];
    return WatchHistory.recommend(pool);
  }

  // البحث عن رابط التشغيل من السيرفر إذا لم يتوفر
  Future<List<String>> _resolveUrls(dynamic item, String type) async {
    final id = item['stream_id']?.toString() ?? '';
    if (id.isNotEmpty) {
      if (type == 'live') return Api.liveUrls(item);
      if (type == 'movie') return Api.movieUrls(item);
    }
    // البحث عن ID من السيرفر باسم المحتوى
    try {
      final name = (item['name'] ?? '').toString();
      final action = type == 'series' ? 'get_series' : 'get_vod_streams';
      final list = await Api.getList(action);
      final found = list.firstWhere(
        (e) => (e['name'] ?? '').toString().toLowerCase() == name.toLowerCase(),
        orElse: () => null,
      );
      if (found != null) {
        if (type == 'movie') return Api.movieUrls(found);
        if (type == 'live') return Api.liveUrls(found);
      }
    } catch (_) {}
    return [];
  }

  void _showInfo(dynamic item, String type, {
    String backdrop = '', String poster = '', String title = '',
    String overview = '', String rating = '', String year = '',
    String cast = '', String director = '', bool needsSub = false}) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
        isScrollControlled: true, useSafeArea: true,
        builder: (_) => _TODInfoSheet(
            item: item, type: type, backdrop: backdrop, poster: poster,
            title: title, overview: overview, rating: rating, year: year,
            cast: cast, director: director, needsSub: needsSub));
  }

  void _showInfoLazy(dynamic item, String type) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
        isScrollControlled: true, useSafeArea: true,
        builder: (_) => _InfoSheetLoader(item: item, type: type));
  }

  void _openHistoryItem(Map<String,dynamic> h) {
    Sound.hapticL();
    final item = h['item'] ?? h;
    final type = h['type']?.toString() ?? 'movie';
    _showInfoLazy(item, type);
  }
}


// ══════════════════════════════════════════════════════════════
//  HERO ITEM DATA
// ══════════════════════════════════════════════════════════════
class _HeroItem {
  final dynamic item; final bool isTv;
  final String backdrop, poster, title, overview, rating, year, cast, director;
  final bool needsSub;
  final String trailerKey; // YouTube key for trailer overlay
  const _HeroItem({required this.item, required this.isTv,
      required this.backdrop, required this.poster, required this.title,
      required this.overview, required this.rating, required this.year,
      required this.cast, required this.director, required this.needsSub,
      this.trailerKey = ''});
}

// ══════════════════════════════════════════════════════════════
//  CINEMA HERO CAROUSEL — أحدث تصميم 2025
//  • خلفية تتغير لون مع كل بوستر (Color Bleed Effect)
//  • تدرج سواد ناعم متعدد الطبقات
//  • معلومات شاملة مع Trailer button
//  • Auto-slide مع Parallax Effect
// ══════════════════════════════════════════════════════════════
class _TODHeroCarousel extends StatefulWidget {
  final List<_HeroItem> heroes;
  final int curIdx;
  final void Function(int) onChanged;
  final void Function(_HeroItem) onPlay;
  final void Function(_HeroItem) onInfo;
  const _TODHeroCarousel({
    required this.heroes, required this.curIdx,
    required this.onChanged, required this.onPlay, required this.onInfo,
    super.key,
  });
  @override State<_TODHeroCarousel> createState() => _TODHeroCarouselState();
}

class _TODHeroCarouselState extends State<_TODHeroCarousel>
    with SingleTickerProviderStateMixin {
  late final PageController _pc;
  Timer? _auto;
  // Ambient color extracted from current poster
  Color _ambientColor = const Color(0xFF1A1005);
  final Map<String, Color> _colorCache = {};

  // TV Remote: when D-Pad left/right → change hero
  void _tvLeft()  { if (_pc.hasClients && widget.curIdx > 0) _pc.animateToPage(widget.curIdx - 1, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic); }
  void _tvRight() { if (_pc.hasClients && widget.curIdx < widget.heroes.length - 1) _pc.animateToPage(widget.curIdx + 1, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic); }
  void _tvSelect(){ if (widget.heroes.isNotEmpty) widget.onPlay(widget.heroes[widget.curIdx]); }

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 1.0);
    _startAuto();
    if (widget.heroes.isNotEmpty) _extractColor(widget.heroes[widget.curIdx].backdrop);
  }

  @override
  void dispose() { _auto?.cancel(); _pc.dispose(); super.dispose(); }

  void _startAuto() {
    _auto?.cancel();
    _auto = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || widget.heroes.isEmpty) return;
      final next = (widget.curIdx + 1) % widget.heroes.length;
      _pc.animateToPage(next,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic);
    });
  }

  Future<void> _extractColor(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    if (_colorCache.containsKey(imageUrl)) {
      if (mounted) setState(() => _ambientColor = _colorCache[imageUrl]!);
      return;
    }
    // استخرج اللون الرئيسي من رقمي الـ URL (hash بسيط بدون package)
    // تُحاكي الـ palette extraction باستخدام تجزئة الـ URL
    try {
      final hash = imageUrl.hashCode.abs();
      // ألوان سينمائية دافئة — تتغير مع كل محتوى
      final colors = [
        const Color(0xFF1A0A02), // بني داكن دافئ
        const Color(0xFF020A1A), // أزرق داكن
        const Color(0xFF0A1A02), // أخضر داكن
        const Color(0xFF1A0205), // أحمر داكن
        const Color(0xFF0D0A1A), // بنفسجي داكن
        const Color(0xFF1A1002), // ذهبي داكن
        const Color(0xFF001A10), // فيروزي داكن
        const Color(0xFF1A0A15), // وردي داكن
      ];
      final color = colors[hash % colors.length];
      _colorCache[imageUrl] = color;
      if (mounted) setState(() => _ambientColor = color);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final top  = MediaQuery.of(context).padding.top;
    final size = MediaQuery.of(context).size;
    final h    = size.height * 0.72;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      height: h + top,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            _ambientColor.withOpacity(0.95),
            Colors.black.withOpacity(0.6),
            Colors.black,
          ],
        ),
      ),
      child: Stack(children: [
        // ── Background Images with PageView ────────────────
        PageView.builder(
          controller: _pc,
          itemCount: widget.heroes.length,
          onPageChanged: (i) {
            widget.onChanged(i);
            _startAuto();
            if (i < widget.heroes.length) _extractColor(widget.heroes[i].backdrop);
          },
          itemBuilder: (_, i) => _buildBg(widget.heroes[i]),
        ),

        // ── Multi-layer gradient overlay (cinematic) ───────
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            stops: const [0.0, 0.25, 0.55, 0.75, 1.0],
            colors: [
              Colors.black.withOpacity(0.55),  // top — مساحة للـ header
              Colors.transparent,               // وسط شفاف — يظهر الصورة
              Colors.black.withOpacity(0.3),
              Colors.black.withOpacity(0.75),
              Colors.black,                     // أسفل — ناعم كامل
            ],
          ),
        ))),

        // ── Ambient color bleed at bottom ──────────────────
        Positioned(bottom: 0, left: 0, right: 0, height: 180,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, _ambientColor.withOpacity(0.4), Colors.black],
              ),
            ),
          ),
        ),

        // ── Top header: Logo + Subscribe ──────────────────
        Positioned(top: top + 10, left: 16, right: 16,
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFFFFD740), Color(0xFFF5C518), Color(0xFFFFAB00)],
              ).createShader(b),
              blendMode: BlendMode.srcIn,
              child: Text('TOTV+',
                style: TExtra.cinzel(s: 20, c: Colors.white, w: FontWeight.w900)
                    .copyWith(letterSpacing: 4))),
            const Spacer(),
            // Network quality indicator
            _NetQualityBadge(),
            const SizedBox(width: 10),
            if (!SubCompat.isPremium)
              GestureDetector(
                onTap: () => Navigator.push(
                    context, _fade(const PricingPage())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFFD740), Color(0xFFF5A623)]),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(
                        color: C.gold.withOpacity(0.4), blurRadius: 10, spreadRadius: 1)]),
                  child: Text('اشتراك',
                      style: T.cairo(s: 11, w: FontWeight.w800, c: Colors.black)))),
          ]),
        ),

        // ── Content info overlay ───────────────────────────
        if (widget.curIdx < widget.heroes.length)
          Positioned(bottom: 0, left: 0, right: 0,
            child: _buildInfo(widget.heroes[widget.curIdx], context)),

        // ── Progress dots ──────────────────────────────────
        Positioned(bottom: 16, left: 0, right: 0,
          child: Center(child: Row(mainAxisSize: MainAxisSize.min,
            children: List.generate(math.min(widget.heroes.length, 8), (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: i == widget.curIdx ? 24 : 5,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == widget.curIdx
                      ? C.gold : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ))))),
        ),
      ]),
    );
  }

  void _showTrailerOverlay(BuildContext ctx, String ytKey, String title) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrailerOverlay(ytKey: ytKey, title: title),
    );
  }

  Widget _buildBg(_HeroItem h) {
    final url = _imgUrl(h.backdrop.isNotEmpty ? h.backdrop : h.poster);
    return url.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: url, fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 300),
            memCacheHeight: 900,
            errorWidget: (_, __, ___) => Container(color: C.surface),
          )
        : Container(color: C.surface);
  }

  Widget _buildInfo(_HeroItem h, BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 44),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
        // ── Genre / Category tags ─────────────────────────
        Row(children: [
          if (h.isTv)
            _TypeTag('مسلسل', color: const Color(0xFF9C27B0))
          else
            _TypeTag('فيلم', color: const Color(0xFF1565C0)),
          if (h.needsSub) ...[
            const SizedBox(width: 6),
            _TypeTag('حصري ✦', color: C.gold, textColor: Colors.black),
          ],
        ]),
        const SizedBox(height: 8),

        // ── Title ─────────────────────────────────────────
        Text(h.title,
          style: T.cairo(s: 28, w: FontWeight.w900)
              .copyWith(letterSpacing: -0.5,
                  shadows: [const Shadow(blurRadius: 20, color: Colors.black)]),
          maxLines: 2, overflow: TextOverflow.ellipsis),

        // ── Meta: Rating + Year ───────────────────────────
        const SizedBox(height: 6),
        Row(children: [
          if (h.rating.isNotEmpty && h.rating != '0.0') ...[
            const Icon(Icons.star_rounded, color: Color(0xFFF5C518), size: 14),
            const SizedBox(width: 3),
            Text(h.rating, style: TExtra.mont(s: 12, c: const Color(0xFFF5C518), w: FontWeight.w700)),
            const SizedBox(width: 10),
          ],
          if (h.year.isNotEmpty) ...[
            Text(h.year.length >= 4 ? h.year.substring(0,4) : h.year,
                style: TExtra.mont(s: 12, c: Colors.white54)),
            const SizedBox(width: 10),
          ],
          Container(width: 4, height: 4,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white38)),
          const SizedBox(width: 10),
          Text('HD', style: TExtra.mont(s: 11, c: Colors.white38)),
        ]),

        // ── Overview ──────────────────────────────────────
        if (h.overview.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(h.overview,
            style: T.cairo(s: 12, c: Colors.white60)
                .copyWith(height: 1.5),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ],

        const SizedBox(height: 14),

        // ── Action Buttons ────────────────────────────────
        Row(children: [
          // Play button
          Expanded(child: GestureDetector(
            onTap: () => h.needsSub && !SubCompat.isPremium
                ? Navigator.push(ctx, _fade(const PricingPage()))
                : widget.onPlay(h),
            child: Container(height: 46,
              decoration: BoxDecoration(
                gradient: h.needsSub && !SubCompat.isPremium
                    ? const LinearGradient(colors: [Color(0xFFFFD740), Color(0xFFF5A623)])
                    : const LinearGradient(colors: [Colors.white, Color(0xFFEEEEEE)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 12, spreadRadius: 0)]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  h.needsSub && !SubCompat.isPremium
                      ? Icons.lock_outline_rounded : Icons.play_arrow_rounded,
                  color: Colors.black, size: 22),
                const SizedBox(width: 6),
                Text(
                  h.needsSub && !SubCompat.isPremium ? 'اشتراك' : 'تشغيل',
                  style: T.cairo(s: 14, w: FontWeight.w900, c: Colors.black)),
              ]),
            ),
          )),
          const SizedBox(width: 10),

          // Trailer button — shows when trailerKey available
          if (h.trailerKey.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _showTrailerOverlay(ctx, h.trailerKey, h.title),
              child: Container(width: 46, height: 46,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.5), width: 0.8)),
                child: const Icon(Icons.play_circle_outline_rounded, color: Colors.red, size: 20))),
            const SizedBox(width: 10),
          ],

          // Info button
          GestureDetector(
            onTap: () => widget.onInfo(h),
            child: Container(width: 46, height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.8)),
              child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20))),

          const SizedBox(width: 10),

          // Watchlist button
          GestureDetector(
            onTap: () {
              final inWl = WL.has(h.item);
              WL.toggle(h.item, h.isTv ? 'series' : 'movie');
            },
            child: Container(width: 46, height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.25), width: 0.8)),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22))),
        ]),
      ]),
    );
  }
}

// _MetaChip class is defined elsewhere in file


// ── Meta Chip (used in Info Sheet) ──────────────────────────
class _MetaChip extends StatelessWidget {
  final String text;
  const _MetaChip(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5)),
    child: Text(text, style: TExtra.mont(s: 10, c: C.grey)));
}


// ── Type Tag (for hero carousel) ─────────────────────────────
class _TypeTag extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  const _TypeTag(this.text, {required this.color, this.textColor = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5)),
    child: Text(text, style: TExtra.mont(s: 10, c: textColor, w: FontWeight.w700)));
}

// ── Network Quality Badge ─────────────────────────────────────
class _NetQualityBadge extends StatefulWidget {
  @override State<_NetQualityBadge> createState() => _NetQualityBadgeState();
}
class _NetQualityBadgeState extends State<_NetQualityBadge> {
  String _quality = '';
  Color  _color   = Colors.green;
  Timer? _timer;

  @override void initState() { super.initState(); _check(); _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check()); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _check() async {
    try {
      final sw = Stopwatch()..start();
      await Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)))
          .get('https://api.themoviedb.org/3/configuration?api_key=${TMDB._defaultKey}')
          .timeout(const Duration(seconds: 3));
      sw.stop();
      final ms = sw.elapsedMilliseconds;
      if (!mounted) return;
      setState(() {
        if (ms < 300)       { _quality = 'ممتاز'; _color = const Color(0xFF4CAF50); }
        else if (ms < 800)  { _quality = 'جيد';   _color = const Color(0xFFF5C518); }
        else if (ms < 1500) { _quality = 'بطيء';  _color = const Color(0xFFFF9800); }
        else                { _quality = 'ضعيف';  _color = const Color(0xFFF44336); }
      });
    } catch (_) {
      if (mounted) setState(() { _quality = 'لا إنترنت'; _color = const Color(0xFFF44336); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_quality.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: _color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _color)),
        const SizedBox(width: 4),
        Text(_quality, style: TExtra.mont(s: 9, c: _color, w: FontWeight.w700)),
      ]),
    );
  }
}


// ══════════════════════════════════════════════════════════════
//  TOD INFO SHEET — مثل الصورة تماماً
// ══════════════════════════════════════════════════════════════
class _TODInfoSheet extends StatefulWidget {
  final dynamic item; final String type;
  final String backdrop, poster, title, overview, rating, year, cast, director;
  final bool needsSub;
  final bool isLive;
  _TODInfoSheet({required this.item, required this.type,
      required this.backdrop, required this.poster, required this.title,
      required this.overview, required this.rating, required this.year,
      required this.cast, required this.director, required this.needsSub,
      this.isLive = false});
  @override State<_TODInfoSheet> createState() => _TODInfoSheetState();
}

class _TODInfoSheetState extends State<_TODInfoSheet> {
  bool _inWl = false;
  String _trailerKey = '';
  bool _trailerLoading = false;

  @override void initState() {
    super.initState();
    _inWl = WL.has(widget.item);
    // Auto-load trailer key from poster key (TMDB)
    _fetchTrailerKey();
  }

  Future<void> _fetchTrailerKey() async {
    if (widget.isLive) return;
    setState(() => _trailerLoading = true);
    try {
      final key = await TMDB.getTrailerKeyByName(
        widget.title.isNotEmpty ? widget.title : (widget.item['name']?.toString() ?? ''),
        isTv: widget.type == 'series',
      ).timeout(const Duration(seconds: 10));
      if (mounted && key != null && key.isNotEmpty) {
        setState(() { _trailerKey = key; _trailerLoading = false; });
      } else {
        if (mounted) setState(() => _trailerLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _trailerLoading = false);
    }
  }

  void _showTrailer() {
    if (_trailerKey.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrailerOverlay(ytKey: _trailerKey, title: widget.title),
    );
  }

  void _play() {
    if (!_canPlay(context)) return;
    Navigator.pop(context);
    Ads.show();
    GuestSession.startPlayback();
    WatchHistory.addItem(widget.item, widget.type);
    if (widget.type == 'series') {
      Navigator.push(context, _fade(SeriesDetailPage(series: widget.item)));
      return;
    }
    final urls = widget.type == 'live'
        ? Api.liveUrls(widget.item)
        : Api.movieUrls(widget.item);
    Navigator.push(context, _fade(PlayerPage(urls: urls, title: widget.title,
        isLive: widget.type == 'live', item: widget.item)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF2080808), // شبه شفاف عميق
        borderRadius: const BorderRadius.vertical(top: Radius.circular(S.rXl)),
        border: Border.all(color: CC.glassBdr, width: 0.5)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: C.dim.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2))),

        // ── Backdrop ──────────────────────────────────────
        Stack(children: [
          // زر الإغلاق
          Positioned(top: 12, left: 12, child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(width: 32, height: 32,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.6)),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18)))),

          SizedBox(height: 260, width: double.infinity,
            child: ClipRRect(borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(S.rXl), topRight: Radius.circular(S.rXl)),
              child: widget.backdrop.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.backdrop,
                      fit: BoxFit.cover,
                      memCacheHeight: 700,
                      fadeInDuration: const Duration(milliseconds: 200),
                      errorWidget: (_, __, ___) => widget.poster.isNotEmpty
                          ? CachedNetworkImage(imageUrl: widget.poster, fit: BoxFit.cover)
                          : SmartPoster(item: widget.item, isTv: widget.type == 'series',
                              fit: BoxFit.cover))
                  : SmartPoster(item: widget.item, isTv: widget.type == 'series',
                      fit: BoxFit.cover))),
          Container(height: 220, decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, const Color(0xFF111111).withOpacity(0.98)]))),
        ]),

        // ── Content ───────────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Poster + Title row (TOD style)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Poster/Logo
              if (widget.poster.isNotEmpty)
                ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: SizedBox(width: 90, height: 130,
                    child: CachedNetworkImage(imageUrl: widget.poster, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: C.surface)))),
              if (widget.poster.isNotEmpty) const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: T.cairo(s: 18, w: FontWeight.w900),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                // Meta: year • rating • genre
                Wrap(runSpacing: 6, spacing: 8, children: [
                  if (widget.year.isNotEmpty)
                    _MetaChip(widget.year.length >= 4 ? widget.year.substring(0,4) : widget.year),
                  if (widget.rating.isNotEmpty && widget.rating != '0.0')
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: C.gold, size: 13),
                      const SizedBox(width: 3),
                      Text(widget.rating, style: TExtra.mont(s: 12, c: C.gold, w: FontWeight.w700)),
                    ]),
                  if (widget.type == 'live')
                    _LiveBadge(),
                  _MetaChip('HD'),
                  if (widget.needsSub)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(5)),
                      child: Text('حصري', style: TExtra.mont(s: 9, c: Colors.black, w: FontWeight.w700))),
                ]),
              ])),
            ]),

            // Overview
            if (widget.overview.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(widget.overview, style: TExtra.mont(s: 13, c: C.grey, ls: 0.2),
                  maxLines: 4, overflow: TextOverflow.ellipsis),
            ],

            // Director
            if (widget.director.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('إخراج  ', style: T.cairo(s: 12, c: C.gold, w: FontWeight.w700)),
                Expanded(child: Text(widget.director, style: T.cairo(s: 12, c: C.grey))),
              ]),
            ],
            // Cast
            if (widget.cast.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('بطولة  ', style: T.cairo(s: 12, c: C.gold, w: FontWeight.w700)),
                Expanded(child: Text(widget.cast, style: T.cairo(s: 12, c: C.grey),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ],

            const SizedBox(height: 16),
            // Buttons
            Row(children: [
              // زر الاشتراك أو التشغيل
              Expanded(child: widget.needsSub && !SubCompat.isPremium
                  ? Column(children: [
                      // زر الاشتراك الرئيسي
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, _fade(const ProfilePage()));
                        },
                        child: Container(
                          height: 52, width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF5C518), Color(0xFFFFAB00)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.workspace_premium, color: Colors.black, size: 20),
                            const SizedBox(width: 8),
                            Text(Sub.isFree ? 'اشترك للمشاهدة' : 'ترقية للـ VIP',
                                style: const TextStyle(color: Colors.black,
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // زر شراء خارجي
                      GestureDetector(
                        onTap: () {
                          final url = SubCompat.buyUrl;
                          if (url.isNotEmpty) launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication);
                        },
                        child: Container(
                          height: 40, width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: C.gold.withOpacity(0.5)),
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.shopping_cart_outlined, color: C.gold, size: 16),
                            SizedBox(width: 6),
                            Text('شراء اشتراك', style: TextStyle(color: C.gold, fontSize: 13)),
                          ]),
                        ),
                      ),
                    ])
                  : GestureDetector(
                      onTap: _play,
                      child: Container(
                        height: 52, width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: C.playGrad,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: C.gold.withOpacity(0.4), blurRadius: 14)],
                        ),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.black, size: 26),
                          SizedBox(width: 8),
                          Text('تشغيل الآن', style: TextStyle(color: Colors.black,
                              fontWeight: FontWeight.bold, fontSize: 16)),
                        ]),
                      ),
                    )),
              const SizedBox(width: 10),
              // + قائمتي
              GestureDetector(
                onTap: () async {
                  await WL.toggle(widget.item, widget.type);
                  setState(() => _inWl = !_inWl);
                  Sound.hapticL();
                },
                child: Column(children: [
                  Icon(_inWl ? Icons.check_rounded : Icons.add_rounded,
                      color: _inWl ? C.gold : Colors.white, size: 24),
                  Text('قائمتي', style: T.cairo(s: 9, c: _inWl ? C.gold : C.grey)),
                ])),
              const SizedBox(width: 10),
              // مشاركة
              GestureDetector(
                onTap: () {
                  Sound.hapticL();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('رابط "${widget.title}" تم نسخه',
                        style: const TextStyle(color: Colors.black)),
                    backgroundColor: C.gold, duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
                },
                child: Column(children: [
                  const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                  Text('مشاركة', style: T.cairo(s: 9, c: C.grey)),
                ])),
              // Trailer button
              if (!widget.isLive) ...[const SizedBox(width: 10),
                GestureDetector(
                  onTap: _trailerKey.isNotEmpty ? _showTrailer : null,
                  child: Column(children: [
                    _trailerLoading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.red, strokeWidth: 1.5))
                        : Icon(Icons.video_library_outlined,
                            color: _trailerKey.isNotEmpty ? Colors.red : Colors.white24, size: 22),
                    Text('ترويجي', style: T.cairo(s: 9, c: _trailerKey.isNotEmpty ? Colors.red : C.dim)),
                  ])),
              ],
            ]),
          ])),
      ]));
  }
}

// ── Lazy Info Sheet Loader ─────────────────────────────────
class _InfoSheetLoader extends StatefulWidget {
  final dynamic item; final String type;
  _InfoSheetLoader({required this.item, required this.type});
  @override State<_InfoSheetLoader> createState() => _InfoSheetLoaderState();
}
class _InfoSheetLoaderState extends State<_InfoSheetLoader> {
  Map<String, String> _tmdb = {};
  bool _loading = true;

  @override void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = widget.item['name']?.toString() ?? '';
    final id   = widget.item['stream_id']?.toString() ?? widget.item['series_id']?.toString() ?? '';
    final icon = widget.item['stream_icon']?.toString() ?? widget.item['cover']?.toString() ?? '';
    final isTv = widget.type == 'series';
    final tmdb = id.isNotEmpty
        ? await TMDBFromWorker.fromWorker(id, name, isTv: isTv)
        : await TMDB.search(name, isTv: isTv);
    if (mounted) setState(() {
      _tmdb = tmdb;
      if ((_tmdb['poster'] ?? '').isEmpty && icon.isNotEmpty) _tmdb['poster'] = icon;
      if ((_tmdb['backdrop'] ?? '').isEmpty && icon.isNotEmpty) _tmdb['backdrop'] = icon;
      _loading = false;
    });
  }

  bool _isNew(String year) {
    // VIP: never needs subscribe
    if (SubCompat.isPremium) return false; // أي مشترك (Premium أو TOTV) لا يحتاج اشتراك
    if (year.isEmpty) return false;
    final y = int.tryParse(year) ?? 0;
    return y >= 2025;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Container(
      height: 300, color: const Color(0xFF111111),
      child: const Center(child: CircularProgressIndicator(color: C.gold, strokeWidth: 1.5)));

    final year = _tmdb['year'] ?? '';
    return _TODInfoSheet(
      item: widget.item, type: widget.type,
      backdrop: _tmdb['backdrop'] ?? widget.item['stream_icon'] ?? '',
      poster:   _tmdb['poster']   ?? widget.item['stream_icon'] ?? '',
      title:    _tmdb['title']    ?? widget.item['name'] ?? '',
      overview: _tmdb['overview'] ?? '',
      rating:   _tmdb['rating']   ?? '',
      year:     year,
      cast:     _tmdb['cast']     ?? '',
      director: _tmdb['director'] ?? '',
      needsSub: _isNew(year),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  UI COMPONENTS — TOD Style
// ══════════════════════════════════════════════════════════════

// ── Category Tabs (horizontal scroll) ─────────────────────
class _CategoryTabs extends StatefulWidget {
  final List<String> cats; final ValueChanged<int> onTap;
  _CategoryTabs({required this.cats, required this.onTap});
  @override State<_CategoryTabs> createState() => _CategoryTabsState();
}
class _CategoryTabsState extends State<_CategoryTabs> {
  int _sel = 0;
  @override
  Widget build(BuildContext context) => SizedBox(height: 46,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: widget.cats.length,
      itemBuilder: (_, i) {
        final sel = i == _sel;
        return GestureDetector(
          onTap: () { setState(() => _sel = i); widget.onTap(i); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: sel ? C.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? C.gold : CExtra.border)),
            child: Text(widget.cats[i],
                style: T.cairo(s: 12, c: sel ? Colors.black : C.grey,
                    w: sel ? FontWeight.w700 : FontWeight.w400))));
      }));
}

// ── Section Header ─────────────────────────────────────────
class _SectionHdr extends StatelessWidget {
  final String title;
  final VoidCallback onMore;
  final IconData? icon;
  _SectionHdr({required this.title, required this.onMore, this.icon});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Row(children: [
      if (icon != null) ...[
        Icon(icon!, color: C.gold, size: 16),
        const SizedBox(width: 6),
      ],
      Text(title, style: T.cairo(s: 16, w: FontWeight.w700)),
      const Spacer(),
      GestureDetector(onTap: onMore,
        child: Text('عرض الكل', style: T.cairo(s: 12, c: C.gold))),
    ]));
}

// ── Continue Watching Row (مع progress bar - Netflix style) ──
class _ContinueWatchingRow extends StatelessWidget {
  final List<dynamic> items;
  final void Function(dynamic, String) onTap;
  _ContinueWatchingRow({required this.items, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(height: 140,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length > 15 ? 15 : items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final img  = item['stream_icon']?.toString() ?? item['cover']?.toString() ?? '';
        final type = item['_type']?.toString() ?? 'movie';
        final id   = item['stream_id']?.toString() ?? item['series_id']?.toString() ?? '';
        final progress = WatchHistory.getPercent(id, 3600);
        return GestureDetector(
          onTap: () => onTap(item, type),
          child: Container(
            width: 180, margin: const EdgeInsets.only(right: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(fit: StackFit.expand, children: [
                  img.isNotEmpty
                      ? CachedNetworkImage(imageUrl: _imgUrl(img), fit: BoxFit.cover,
                          memCacheHeight: 250,
                          placeholder: (_, __) => Container(color: C.surface),
                          errorWidget: (_, __, ___) => _NoImg(item['name']?.toString() ?? '' ?? ''))
                      : _NoImg(item['name']?.toString() ?? '' ?? ''),
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)])))),
                  Center(child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.6),
                        border: Border.all(color: C.gold.withOpacity(0.8), width: 1.5)),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20))),
                ]))),
              const SizedBox(height: 3),
              ClipRRect(borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress, minHeight: 3,
                  backgroundColor: C.surface,
                  valueColor: const AlwaysStoppedAnimation(C.gold))),
              const SizedBox(height: 4),
              Text(item['name']?.toString() ?? '',
                  style: T.cairo(s: 10, c: C.grey),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])));
      }));
}

// ── Landscape Row (أفلام — عرضية) ─────────────────────────
class _LandscapeRow extends StatelessWidget {
  final List<dynamic> items; final String type;
  final void Function(dynamic, String) onTap;
  _LandscapeRow({required this.items, required this.type, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(height: 120,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length > 20 ? 20 : items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final img  = item['stream_icon']?.toString() ?? item['cover']?.toString() ?? '';
        return GestureDetector(
          onTap: () => onTap(item, type),
          child: Container(
            width: 180, margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: C.card),
            child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: Stack(fit: StackFit.expand, children: [
                SmartPoster(item: item, fit: BoxFit.cover, memH: 250,
                    radius: BorderRadius.circular(S.rMd)),
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)]))),
                Positioned(bottom: 6, left: 8, right: 8,
                  child: Text(item['name'] ?? '',
                    style: T.caption(c: CC.textPri).copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]))));
      }));
}

// ── Portrait Row (مسلسلات — بورتريه) ──────────────────────
class _PortraitRow extends StatelessWidget {
  final List<dynamic> items; final String type;
  final void Function(dynamic, String) onTap;
  _PortraitRow({required this.items, required this.type, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(height: 168,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length > 20 ? 20 : items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final img  = item['stream_icon']?.toString() ?? item['cover']?.toString() ?? '';
        return GestureDetector(
          onTap: () => onTap(item, type),
          child: Container(
            width: 100, margin: const EdgeInsets.only(right: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8),
                child: img.isNotEmpty
                    ? SmartPoster(item: item, isTv: type == 'series',
                        fit: BoxFit.cover, memH: 300, memW: 100,
                        radius: BorderRadius.circular(S.rMd))
                    : _NoImg(item['name']?.toString() ?? '' ?? '', isTv: type == 'series'))),
              const SizedBox(height: 4),
              Text(item['name'] ?? '', style: T.cairo(s: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])));
      }));
}

// ── Live Channel Row (مع EPG) ──────────────────────────────
class _LiveChannelRow extends StatelessWidget {
  final List<dynamic> items;
  final void Function(dynamic, String) onTap;
  _LiveChannelRow({required this.items, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(height: 88,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length > 20 ? 20 : items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final img  = item['stream_icon']?.toString() ?? '';
        final id   = item['stream_id']?.toString() ?? '';
        final epg  = id.isNotEmpty ? EpgService.currentProgram(id) : null;
        return GestureDetector(
          onTap: () => onTap(item, 'live'),
          child: Container(
            width: 78, margin: const EdgeInsets.only(right: 8),
            child: Column(children: [
              Container(width: 60, height: 60,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: C.surface,
                    border: Border.all(color: CExtra.border, width: 0.5)),
                child: Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: img.isNotEmpty
                        ? CachedNetworkImage(imageUrl: _imgUrl(img), fit: BoxFit.cover, width: 60, height: 60)
                        : const Center(child: Icon(Icons.live_tv_rounded, color: C.dim, size: 24))),
                  // مؤشر LIVE
                  Positioned(bottom: 4, right: 4,
                    child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: CExtra.live))),
                ])),
              const SizedBox(height: 4),
              Text(item['name'] ?? '', style: T.cairo(s: 9, c: C.grey),
                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              // EPG: اسم البرنامج الحالي
              if (epg != null)
                Text(epg ?? "", style: T.cairo(s: 8, c: C.dim),
                    maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ])));
      }));
}

// ── No Image Placeholder ───────────────────────────────────
class _NoImg extends StatelessWidget {
  final String name;
  final bool isTv;
  const _NoImg(this.name, {this.isTv = false});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF1C1C1C), Color(0xFF0D0D0D)])),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(isTv ? Icons.tv_rounded : Icons.movie_rounded, color: C.dim, size: 24),
      const SizedBox(height: 6),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(name, style: T.caption(c: C.dim),
            maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
    ])));
}

class _SkeletonCard extends StatefulWidget {
  @override State<_SkeletonCard> createState() => _SkeletonCardState();
}
class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();
    _anim = Tween(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext _) => AnimatedBuilder(
    animation: _anim,
    builder: (__, ___) => ClipRRect(
      borderRadius: BorderRadius.circular(S.rMd),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (_anim.value - 0.4).clamp(0.0, 1.0),
              _anim.value.clamp(0.0, 1.0),
              (_anim.value + 0.4).clamp(0.0, 1.0),
            ],
            colors: const [
              Color(0xFF141414), Color(0xFF242424), Color(0xFF141414),
            ])),
      ),
    ),
  );
}


// ══════════════════════════════════════════════════════════════
//  SEARCH PAGE — بحث موحّد Netflix-level
// ══════════════════════════════════════════════════════════════
class SearchPage extends StatefulWidget {
  const SearchPage();
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;
  final _ctrl = TextEditingController();
  String _query = '';
  String _filterType = 'all';
  List<dynamic> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override void dispose() { _ctrl.dispose(); _debounce?.cancel(); super.dispose(); }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _query = q);
      _search(q);
    });
  }

  void _search(String q) {
    if (q.trim().isEmpty) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    final lower = q.toLowerCase();
    List<dynamic> pool = [];
    if (_filterType == 'all' || _filterType == 'movie')
      pool.addAll(AppState.allMovies.map((e) => {...Map<String,dynamic>.from(e as Map), '_type': 'movie'}));
    if (_filterType == 'all' || _filterType == 'series')
      pool.addAll(AppState.allSeries.map((e) => {...Map<String,dynamic>.from(e as Map), '_type': 'series'}));
    if (_filterType == 'all' || _filterType == 'live')
      pool.addAll(AppState.allLive.map((e) => {...Map<String,dynamic>.from(e as Map), '_type': 'live'}));
    final starts   = pool.where((e) => (e['name']??'').toString().toLowerCase().startsWith(lower)).toList();
    final contains = pool.where((e) { final n=(e['name']??'').toString().toLowerCase(); return n.contains(lower) && !n.startsWith(lower); }).toList();
    setState(() { _results = [...starts, ...contains].take(100).toList(); _searching = false; });
  }

  void _openItem(dynamic item) {
    Sound.hapticL();
    final type = item['_type']?.toString() ?? 'movie';
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true, useSafeArea: true,
      builder: (_) => _InfoSheetLoader(item: item, type: type));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(backgroundColor: C.bg, body: Column(children: [
      Container(padding: EdgeInsets.fromLTRB(16, top + 12, 16, 12), color: C.bg,
        child: Column(children: [
          Container(height: 46, decoration: BoxDecoration(
            color: C.surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CExtra.border, width: 0.5)),
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, color: C.gold.withOpacity(0.5), size: 20),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: _ctrl, autofocus: false,
                textDirection: TextDirection.rtl,
                style: T.cairo(s: 14),
                decoration: InputDecoration(
                  hintText: 'ابحث عن فيلم، مسلسل، قناة...',
                  hintStyle: T.cairo(s: 13, c: C.dim),
                  border: InputBorder.none, isDense: true),
                onChanged: _onQueryChanged)),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () { _ctrl.clear(); setState(() { _query = ''; _results = []; }); },
                  child: Padding(padding: const EdgeInsets.all(12),
                    child: const Icon(Icons.close_rounded, color: C.dim, size: 16))),
            ])),
          const SizedBox(height: 10),
          SizedBox(height: 32, child: ListView(scrollDirection: Axis.horizontal,
            children: [
              for (final f in [('all','الكل'),('movie','أفلام'),('series','مسلسلات'),('live','مباشر')])
                GestureDetector(
                  onTap: () { setState(() => _filterType = f.$1); _search(_query); },
                  child: AnimatedContainer(duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: _filterType == f.$1 ? C.gold : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _filterType == f.$1 ? C.gold : CExtra.border)),
                    child: Text(f.$2, style: T.cairo(s: 12,
                      c: _filterType == f.$1 ? Colors.black : C.grey,
                      w: _filterType == f.$1 ? FontWeight.w700 : FontWeight.w400)))),
            ])),
        ])),
      Expanded(child: _query.isEmpty ? _buildRecent()
        : _searching ? const Center(child: CircularProgressIndicator(color: C.gold, strokeWidth: 1.5))
        : _results.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.search_off_rounded, color: C.dim, size: 48),
              const SizedBox(height: 12),
              Text('لا نتائج لـ "$_query"', style: T.cairo(s: 13, c: C.grey))]))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 3,
                childAspectRatio: 0.62, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: _results.length,
              itemBuilder: (_, i) => _ContentCard(
                item: _results[i], type: _results[i]['_type']?.toString() ?? 'movie',
                onTap: () => _openItem(_results[i]),
                onFav: () => setState(() {})))),
    ]));
  }

  Widget _buildRecent() {
    final recent = WatchHistory.recent;
    if (recent.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.search_rounded, color: C.dim, size: 48),
      const SizedBox(height: 12),
      Text('ابحث عن محتواك المفضل', style: T.cairo(s: 13, c: C.grey))
    ]));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: recent.length,
      itemBuilder: (_, i) {
        final h = recent[i];
        return ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          leading: ClipRRect(borderRadius: BorderRadius.circular(6),
            child: SizedBox(width: 56, height: 56,
              child: CachedNetworkImage(imageUrl: _imgUrl(h['stream_icon']?.toString() ?? h['icon']?.toString() ?? ''),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: C.surface,
                  child: const Icon(Icons.movie_rounded, color: C.dim, size: 20))))),
          title: Text(h['name']?.toString() ?? '', style: T.cairo(s: 13, w: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(h['_type'] == 'live' ? 'بث مباشر' : h['_type'] == 'series' ? 'مسلسل' : 'فيلم',
            style: T.cairo(s: 11, c: C.grey)),
          trailing: const Icon(Icons.play_circle_outline_rounded, color: C.gold, size: 22),
          onTap: () => _openItem(h));
      });
  }
}

// ══════════════════════════════════════════════════════════════
//  LIVE PAGE — قنوات مباشرة بتصميم شبكي
// ══════════════════════════════════════════════════════════════
class LivePage extends StatefulWidget {
  const LivePage();
  @override State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  List<dynamic> _filtered = [];
  String _selCat = '', _query = '';
  bool _busy = false;
  final _ctrl = TextEditingController();

  @override void initState() { super.initState(); _apply(); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    AppState.allLive    = await Api.getList('get_live_streams', force: true);
    AppState.liveCats   = await Api.getList('get_live_categories', force: true);
    if (mounted) { setState(() => _busy = false); _apply(); }
  }

  void _apply() {
    var b = AppState.allLive;
    if (_selCat.isNotEmpty) b = b.where((c) => c['category_id']?.toString() == _selCat).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      b = b.where((c) => (c['name'] ?? '').toString().toLowerCase().contains(q)).toList();
    }
    _filtered = b;
  }

  void _openChannel(dynamic ch) {
    if (!_canPlay(context)) return;
    Sound.hapticL();
    GuestSession.startPlayback();
    Navigator.push(context, _fade(PlayerPage(
        urls: Api.liveUrls(ch), title: ch['name']?.toString() ?? '', isLive: true)));
  }

  int _cols(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    if (w > 900) return 5; if (w > 600) return 4; return 3;
  }

  // تقسيم القنوات لأقسام منظمة
  Map<String, List<dynamic>> _buildSections(List<dynamic> all) {
    // beIN Sports أولاً — أعلى أولوية
    final bein    = <dynamic>[];
    final sky     = <dynamic>[];
    final mbc     = <dynamic>[];
    final sport   = <dynamic>[];
    final news    = <dynamic>[];
    final kids    = <dynamic>[];
    final movies  = <dynamic>[];
    final series  = <dynamic>[];
    final general = <dynamic>[];

    for (final ch in all) {
      final n = (ch['name'] ?? '').toString().toLowerCase();
      if (n.contains('bein') || n.contains('بين'))       { bein.add(ch);    continue; }
      if (n.contains('sky sport') || n.contains('sky s')) { sky.add(ch);     continue; }
      if (n.contains('mbc'))                              { mbc.add(ch);     continue; }
      if (n.contains('sport') || n.contains('رياضة') ||
          n.contains('arena') || n.contains('eurosport') ||
          n.contains('dazn') || n.contains('match'))     { sport.add(ch);   continue; }
      if (n.contains('news') || n.contains('أخبار') ||
          n.contains('الجزيرة') || n.contains('العربية')||
          n.contains('cnn') || n.contains('bbc'))        { news.add(ch);    continue; }
      if (n.contains('kids') || n.contains('أطفال') ||
          n.contains('cartoon') || n.contains('baby'))   { kids.add(ch);    continue; }
      if (n.contains('movie') || n.contains('أفلام') ||
          n.contains('cinema') || n.contains('سينما'))   { movies.add(ch);  continue; }
      if (n.contains('serie') || n.contains('مسلسل') ||
          n.contains('drama') || n.contains('دراما'))    { series.add(ch);  continue; }
      general.add(ch);
    }

    // ترتيب beIN: 1،2،3... أولاً ثم 4K
    bein.sort((a, b) {
      final an = (a['name'] ?? '').toString().toLowerCase();
      final bn = (b['name'] ?? '').toString().toLowerCase();
      // 4K آخراً
      final a4k = an.contains('4k') ? 1 : 0;
      final b4k = bn.contains('4k') ? 1 : 0;
      if (a4k != b4k) return a4k.compareTo(b4k);
      // استخرج الرقم
      final ar = RegExp(r'(\d+)').firstMatch(an);
      final br = RegExp(r'(\d+)').firstMatch(bn);
      final ai = int.tryParse(ar?.group(1) ?? '999') ?? 999;
      final bi = int.tryParse(br?.group(1) ?? '999') ?? 999;
      return ai.compareTo(bi);
    });

    final sections = <String, List<dynamic>>{};
    if (bein.isNotEmpty)    sections['beIN Sports']    = bein;
    if (sky.isNotEmpty)     sections['Sky Sports']     = sky;
    if (sport.isNotEmpty)   sections['رياضة']           = sport;
    if (mbc.isNotEmpty)     sections['MBC']            = mbc;
    if (news.isNotEmpty)    sections['أخبار']           = news;
    if (movies.isNotEmpty)  sections['أفلام']           = movies;
    if (series.isNotEmpty)  sections['مسلسلات']         = series;
    if (kids.isNotEmpty)    sections['أطفال']           = kids;
    if (general.isNotEmpty) sections['عامة']            = general;
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final top = MediaQuery.of(context).padding.top;
    final pool = _query.isEmpty && _selCat.isEmpty
        ? AppState.allLive
        : _filtered;

    // Hero: beIN 1-3 دائماً أولاً
    final heroList = AppState.allLive.where((c) {
      final n = (c['name'] ?? '').toString().toLowerCase();
      return n.contains('bein') || n.contains('sky') || n.contains('mbc');
    }).take(8).toList();

    final sections = (_query.isEmpty && _selCat.isEmpty)
        ? _buildSections(AppState.allLive)
        : <String, List<dynamic>>{'نتائج البحث': _filtered};

    return Scaffold(backgroundColor: C.bg,
      body: RefreshIndicator(color: C.gold, backgroundColor: C.surface,
        strokeWidth: 1.5, onRefresh: _refresh,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          cacheExtent: 1200,
          slivers: [
            // ── Hero Carousel ──────────────────────────────────
            if (heroList.isNotEmpty && _query.isEmpty && _selCat.isEmpty)
              SliverToBoxAdapter(child: _LiveHeroCarousel(
                  channels: heroList, onTap: _openChannel)),

            // ── Header ─────────────────────────────────────────
            SliverToBoxAdapter(child: _AppHdr(
                top: heroList.isEmpty ? top : 0,
                title: 'مباشر', onRefresh: _refresh)),

            // ── Search ─────────────────────────────────────────
            SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: _SearchBar(ctrl: _ctrl,
                    onChanged: (v) => setState(() { _query = v; _apply(); })))),

            // ── Category Chips ──────────────────────────────────
            if (AppState.liveCats.isNotEmpty)
              SliverToBoxAdapter(child: SizedBox(height: 44, child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                itemCount: AppState.liveCats.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) return _Chip(label: 'الكل', sel: _selCat.isEmpty,
                      onTap: () => setState(() { _selCat = ''; _apply(); }));
                  final cat = AppState.liveCats[i - 1];
                  final id  = cat['category_id']?.toString() ?? '';
                  return _Chip(label: cat['category_name']?.toString() ?? '',
                      sel: _selCat == id,
                      onTap: () => setState(() { _selCat = id; _apply(); }));
                }))),

            // ── أقسام منظمة (beIN أولاً) ───────────────────────
            for (final entry in sections.entries) ...[
              SliverToBoxAdapter(child: _SectionHdr(
                  title: entry.value.length > 0
                      ? '${entry.key}  •  ${entry.value.length}'
                      : entry.key,
                  onMore: () {})),
              SliverToBoxAdapter(child: SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: entry.value.length > 20 ? 20 : entry.value.length,
                  itemBuilder: (_, i) {
                    final ch  = entry.value[i];
                    final nm  = ch['name']?.toString() ?? '';
                    return GestureDetector(
                      onTap: () => _openChannel(ch),
                      child: Container(
                        width: 106, margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: C.card,
                          borderRadius: BorderRadius.circular(S.rMd),
                          border: Border.all(color: CExtra.border, width: 0.4)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(S.rMd),
                          child: Stack(fit: StackFit.expand, children: [
                            SmartPoster(item: ch, fit: BoxFit.contain,
                                radius: BorderRadius.circular(S.rMd)),
                            // تدرج أسفل
                            Positioned(bottom: 0, left: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(6, 16, 6, 5),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)])),
                                child: Text(nm,
                                  style: T.caption(c: CC.textPri).copyWith(
                                      fontSize: 9, fontWeight: FontWeight.w600),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center))),
                            // LIVE badge
                            Positioned(top: 5, left: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: CExtra.live, borderRadius: BorderRadius.circular(3)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(width: 3, height: 3, margin: const EdgeInsets.only(right: 3),
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                                  Text('LIVE', style: TExtra.label(c: Colors.white, s: 7)),
                                ]))),
                          ]))));
                  }))),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ])));
  }
}

// ── Hero Carousel للقنوات المباشرة ──────────────────────────
class _LiveHeroCarousel extends StatefulWidget {
  final List<dynamic> channels;
  final void Function(dynamic) onTap;
  _LiveHeroCarousel({required this.channels, required this.onTap});
  @override State<_LiveHeroCarousel> createState() => _LiveHeroCarouselState();
}
class _LiveHeroCarouselState extends State<_LiveHeroCarousel> {
  int _cur = 0;
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.42;
    final list = widget.channels;
    return SizedBox(height: h, child: Stack(children: [
      _AutoPageView(
        itemCount: list.length,
        interval: const Duration(seconds: 5),
        onPageChanged: (i) => setState(() => _cur = i),
        itemBuilder: (_, i) {
          final ch  = list[i];
          final img = ch['stream_icon']?.toString() ?? '';
          final nm  = ch['name']?.toString() ?? '';
          final cat = ch['category_name']?.toString() ?? 'LIVE';
          return GestureDetector(onTap: () => widget.onTap(ch),
            child: Stack(fit: StackFit.expand, children: [
              // صورة القناة
              img.isNotEmpty
                  ? CachedNetworkImage(imageUrl: _imgUrl(img), fit: BoxFit.cover, memCacheHeight: 600,
                      placeholder: (_, __) => Container(color: C.surface),
                      errorWidget: (_, __, ___) => _liveChannelBg(nm))
                  : _liveChannelBg(nm),
              // Gradient أسفل
              const DecoratedBox(decoration: BoxDecoration(gradient: CExtra.heroGrad)),
              // معلومات
              Positioned(bottom: 50, left: 16, right: 16,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: CExtra.live, borderRadius: BorderRadius.circular(5)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 5, height: 5, margin: const EdgeInsets.only(left: 4),
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                        Text('مباشر', style: TExtra.mont(s: 9, w: FontWeight.w800, c: Colors.white)),
                      ])),
                  ]),
                  const SizedBox(height: 8),
                  Text(nm, style: T.cairo(s: 22, w: FontWeight.w900),
                      maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                  const SizedBox(height: 3),
                  Text(cat, style: TExtra.mont(s: 11, c: C.grey)),
                  const SizedBox(height: 14),
                  // زر تشغيل
                  GestureDetector(onTap: () => widget.onTap(ch),
                    child: Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(gradient: C.playGrad,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [BoxShadow(color: C.gold.withOpacity(0.4), blurRadius: 14)]),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                        const SizedBox(width: 6),
                        Text('مشاهدة الآن', style: T.cairo(s: 14, w: FontWeight.w800, c: Colors.black)),
                      ]))),
                ])),
            ]));
        }),
      // Dots
      Positioned(bottom: 16, left: 0, right: 0,
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(list.length > 8 ? 8 : list.length, (i) =>
            AnimatedContainer(duration: const Duration(milliseconds: 200),
              width: i == _cur ? 20 : 5, height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i == _cur ? C.gold : C.dim,
                borderRadius: BorderRadius.circular(3)))))),
    ]));
  }

  Widget _liveChannelBg(String name) => Container(
    color: C.surface,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.sensors_rounded, color: C.gold, size: 40),
      const SizedBox(height: 8),
      Text(name, style: T.cairo(s: 14, w: FontWeight.w700, c: C.grey),
          maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
    ])));
}

// ══════════════════════════════════════════════════════════════
//  CONTENT PAGE — أفلام / مسلسلات بتصميم TOD
// ══════════════════════════════════════════════════════════════
class ContentPage extends StatefulWidget {
  final String type, label;
  const ContentPage({required this.type, required this.label});
  @override State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> with AutomaticKeepAliveClientMixin {
  @override bool get wantKeepAlive => true;

  List<dynamic> _filtered = [];
  List<_HeroItem> _heroes  = [];
  int    _heroCur  = 0;
  String _selCat   = '', _query = '';
  final _ctrl = TextEditingController();
  String _viewMode = 'portrait';
  bool   _heroLoading = false;

  @override
  void initState() {
    super.initState();
    _apply();
    _loadHeroes();
    // FIX: تحميل إذا فارغ
    if (_source.isEmpty) {
      AppState.loadAll().then((_) {
        if (mounted) { setState(_apply); if (_heroes.isEmpty) _loadHeroes(); }
      });
    }
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  List<dynamic> get _source => widget.type == 'movie' ? AppState.allMovies : AppState.allSeries;
  List<dynamic> get _cats   => widget.type == 'movie' ? AppState.movieCats  : AppState.seriesCats;

  void _apply() {
    // FIX: إذا المصدر فارغ والبيانات لم تُحمَّل، ابدأ التحميل
    if (_source.isEmpty && !AppState.isLoaded) {
      AppState.loadAll().then((_) {
        if (mounted) setState(_apply);
      });
    }
    var b = List<dynamic>.from(_source);
    if (_selCat.isNotEmpty) b = b.where((e) => e['category_id']?.toString() == _selCat).toList();
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      b = b.where((e) => (e['name'] ?? '').toString().toLowerCase().contains(q)).toList();
    }
    b.sort((x, y) {
      final xHas = (x['stream_icon']?.toString() ?? x['cover']?.toString() ?? '').isNotEmpty ? 1 : 0;
      final yHas = (y['stream_icon']?.toString() ?? y['cover']?.toString() ?? '').isNotEmpty ? 1 : 0;
      if (xHas != yHas) return yHas.compareTo(xHas);
      final xCat = x['category_id']?.toString() ?? '';
      final yCat = y['category_id']?.toString() ?? '';
      if (xCat != yCat) return xCat.compareTo(yCat);
      return (x['name'] ?? '').toString().compareTo(y['name'] ?? '');
    });
    _filtered = b;
  }

  Future<void> _loadHeroes() async {
    if (_heroLoading || _heroes.isNotEmpty) return;
    _heroLoading = true;
    final sample = List.from(_source.take(30))..shuffle();
    final heroes = <_HeroItem>[];
    for (final item in sample.take(6)) {
      final isTv  = widget.type == 'series';
      final name  = item['name']?.toString() ?? '';
      final icon  = item['stream_icon']?.toString() ?? item['cover']?.toString() ?? '';
      final tmdb  = await TMDB.search(name, isTv: isTv);
      final year  = tmdb['year'] ?? '';
      heroes.add(_HeroItem(
        item: item, isTv: isTv,
        backdrop: tmdb['backdrop']?.isNotEmpty == true ? tmdb['backdrop']! : icon,
        poster:   tmdb['poster_sm']?.isNotEmpty == true ? tmdb['poster_sm']! : icon,
        title:    tmdb['title'] ?? name,
        overview: tmdb['overview'] ?? '',
        rating:   tmdb['rating'] ?? '',
        year:     year,
        cast:     tmdb['cast'] ?? '',
        director: tmdb['director'] ?? '',
        needsSub: _isNew(year),
      ));
    }
    if (mounted) setState(() { _heroes = heroes; _heroLoading = false; });
  }

  bool _isNew(String year) {
    // VIP: never needs subscribe
    if (SubCompat.isPremium) return false; // أي مشترك (Premium أو TOTV) لا يحتاج اشتراك
    if (year.isEmpty) return false;
    final y = int.tryParse(year) ?? 0;
    return y >= 2025;
  }

  Future<void> _refresh() async {
    final action = widget.type == 'movie' ? 'get_vod_streams' : 'get_series';
    final fresh = await Api.getList(action, force: true);
    if (widget.type == 'movie') AppState.allMovies = fresh;
    else AppState.allSeries = fresh;
    _heroes.clear();
    if (mounted) { setState(_apply); _loadHeroes(); }
  }

  void _openItem(dynamic item) {
    Sound.hapticL();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
        isScrollControlled: true, useSafeArea: true,
        builder: (_) => _InfoSheetLoader(item: item, type: widget.type));
  }

  int get _cols {
    if (_viewMode == 'landscape') return 1;
    final w = MediaQuery.of(context).size.width;
    if (_viewMode == 'grid') return w > 600 ? 4 : 3;
    return w > 900 ? 5 : w > 600 ? 4 : 3; // 3 columns on phone — tidier
  }

  double get _ratio {
    if (_viewMode == 'landscape') return 3.0;
    // Portrait cards: fixed ratio = poster (2:3 = 0.67)
    // This ensures ALL cards same height — no irregular layout
    return 0.62;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(backgroundColor: C.bg,
      body: RefreshIndicator(color: C.gold, backgroundColor: C.surface,
          strokeWidth: 1.5, onRefresh: _refresh,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [

            // ── Hero Carousel كبير في الأعلى ──
            if (_heroes.isNotEmpty)
              SliverToBoxAdapter(child: _TODHeroCarousel(
                heroes: _heroes,
                curIdx: _heroCur,
                onChanged: (i) => setState(() => _heroCur = i),
                onPlay: (h) {
                  if (!_canPlay(context)) return;
                  Ads.show();
                  GuestSession.startPlayback();
                  if (h.isTv) { Navigator.push(context, _fade(SeriesDetailPage(series: h.item))); return; }
                  if (!_canPlay(context)) return;
                  GuestSession.startPlayback();
                  Navigator.push(context, _fade(PlayerPage(urls: Api.movieUrls(h.item), title: h.title)));
                },
                onInfo: (h) {
                  showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
                    isScrollControlled: true, useSafeArea: true,
                    builder: (_) => _TODInfoSheet(
                      item: h.item, type: widget.type,
                      backdrop: h.backdrop, poster: h.poster, title: h.title,
                      overview: h.overview, rating: h.rating, year: h.year,
                      cast: h.cast, director: h.director, needsSub: h.needsSub));
                },
              )),
            if (_heroes.isEmpty && _heroLoading)
              SliverToBoxAdapter(child: Container(
                height: MediaQuery.of(context).size.height * 0.52,
                color: C.surface,
                child: const Center(child: CircularProgressIndicator(color: C.gold, strokeWidth: 1.5)))),

            // ── Header + Search ──
            SliverToBoxAdapter(child: _AppHdr(top: _heroes.isEmpty ? top : 0, title: widget.label, onRefresh: _refresh)),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(14,8,14,0),
              child: _SearchBar(ctrl: _ctrl,
                  onChanged: (v) => setState(() { _query = v; _apply(); })))),

            // ── أقسام التصنيف ──
            if (_cats.isNotEmpty)
              SliverToBoxAdapter(child: SizedBox(height: 46, child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                itemCount: _cats.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) return _Chip(label: 'الكل', sel: _selCat.isEmpty,
                      onTap: () => setState(() { _selCat = ''; _apply(); }));
                  final cat = _cats[i - 1];
                  final id  = cat['category_id']?.toString() ?? '';
                  return _Chip(label: cat['category_name']?.toString() ?? '',
                      sel: _selCat == id,
                      onTap: () => setState(() { _selCat = id; _apply(); }));
                }))),

            // ── Counter + أوضاع العرض ──
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(children: [
                _CounterBar(label: '${_filtered.length} ${widget.type == "series" ? "مسلسل" : "فيلم"}'),
                const Spacer(),
                ...[
                  ['portrait',  Icons.view_column_rounded],
                  ['landscape', Icons.view_list_rounded],
                  ['grid',      Icons.grid_view_rounded],
                ].map((m) {
                  final mode = m[0] as String;
                  final ico  = m[1] as IconData;
                  return GestureDetector(
                    onTap: () => setState(() => _viewMode = mode),
                    child: Padding(padding: const EdgeInsets.only(left: 8),
                      child: Icon(ico, color: _viewMode == mode ? C.gold : C.dim, size: 18)));
                }),
              ]))),

            // ── Grid المحتوى ──
            if (_filtered.isEmpty)
              SliverToBoxAdapter(child: SizedBox(
                height: 280,
                child: Center(child: !AppState.isLoaded
                  ? const CircularProgressIndicator(color: C.gold, strokeWidth: 1.5)
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.movie_filter_rounded, color: C.dim, size: 48),
                      const SizedBox(height: 12),
                      Text('لا يوجد محتوى متاح', style: T.body(c: C.grey)),
                      const SizedBox(height: 16),
                      GestureDetector(onTap: _refresh,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(10)),
                          child: Text('إعادة التحميل', style: T.cairo(s: 12, c: Colors.black, w: FontWeight.w700)))),
                    ])),
              )),
            SliverPadding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _cols, childAspectRatio: _ratio,
                    crossAxisSpacing: 10, mainAxisSpacing: 10),
                delegate: SliverChildBuilderDelegate(
                    (_, i) => _ContentCard(
                        item: _filtered[i], type: widget.type,
                        onTap: () => _openItem(_filtered[i]),
                        onFav: () => setState(() {}),
                        landscape: _viewMode == 'landscape'),
                    childCount: _filtered.length,
                    addRepaintBoundaries: true, addAutomaticKeepAlives: false))),
          ])));
  }
}

// ── Content Card — يدعم portrait + landscape + grid ───────
class _ContentCard extends StatelessWidget {
  final dynamic item; final String type;
  final VoidCallback onTap; final VoidCallback onFav;
  final bool landscape;
  _ContentCard({required this.item, required this.type,
      required this.onTap, required this.onFav, this.landscape = false});

  @override
  Widget build(BuildContext context) {
    final img  = item['stream_icon']?.toString() ?? item['cover']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';

    if (landscape) return _buildLandscape(img, name);
    return _buildPortrait(img, name);
  }

  Widget _buildPortrait(String img, String name) {
    final id  = item['stream_id']?.toString() ?? item['series_id']?.toString() ?? '';
    final pct = id.isNotEmpty ? WatchHistory.getPercent(id, 0) : 0.0;
    final isTv = type == 'series';
    return RepaintBoundary(child: GestureDetector(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Stack(children: [
          // ── Poster ──────────────────────────────────────────
          Positioned.fill(child: ClipRRect(
            borderRadius: BorderRadius.circular(S.rMd),
            child: SmartPoster(
              item: item, isTv: isTv, fit: BoxFit.cover,
              memH: 300, memW: 200,
              radius: BorderRadius.circular(S.rMd)))),
          // ── Bottom fade gradient ─────────────────────────────
          Positioned(bottom: 0, left: 0, right: 0, height: 60,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(S.rMd)),
              child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.75)]))))),
          // ── Progress bar ─────────────────────────────────────
          if (pct > 0.02 && pct < 0.97)
            Positioned(bottom: 0, left: 0, right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(S.rMd)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(height: 3, color: Colors.white.withOpacity(0.15),
                    child: FractionallySizedBox(
                      widthFactor: pct, alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [CC.goldLight, C.gold]))))),
                ]))),
          // ── LIVE badge ────────────────────────────────────────
          if (type == 'live')
            Positioned(top: S.xs, left: S.xs,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CExtra.live, borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 4, height: 4, margin: const EdgeInsets.only(right: 3),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.white)),
                  Text('LIVE', style: TExtra.label(c: Colors.white, s: 8)),
                ]))),
          // ── Bookmark ─────────────────────────────────────────
          Positioned(top: S.xs, right: S.xs,
            child: StatefulBuilder(builder: (_, ss) {
              final fav = WL.has(item);
              return GestureDetector(
                onTap: () async {
                  await WL.toggle(item, type);
                  ss(() {}); onFav();
                  HapticFeedback.lightImpact();
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(S.rMd),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: CC.glass,
                        borderRadius: BorderRadius.circular(S.rMd),
                        border: Border.all(color: CC.glassBdr, width: 0.5)),
                      child: Icon(
                        fav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: fav ? C.gold : CC.textPri,
                        size: 14)))));
            })),
        ])),
        const SizedBox(height: S.xs + 2),
        Text(name,
          style: T.caption(c: CC.textSec).copyWith(fontSize: 11),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      ])));
  }

  Widget _buildLandscape(String img, String name) =>
    RepaintBoundary(child: GestureDetector(onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CExtra.border, width: 0.4)),
        child: Row(children: [
          ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
            child: SizedBox(width: 80, height: double.infinity,
              child: img.isNotEmpty
                  ? CachedNetworkImage(imageUrl: _imgUrl(img), fit: BoxFit.cover, memCacheHeight: 200)
                  : _NoImg(name))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(name, style: T.cairo(s: 12, w: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if (type == 'live') ...[
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: CExtra.live, borderRadius: BorderRadius.circular(3)),
                child: Text('مباشر', style: TExtra.mont(s: 9, c: Colors.white, w: FontWeight.w700))),
            ],
          ])),
          Padding(padding: const EdgeInsets.only(right: 12),
            child: const Icon(Icons.play_circle_outline_rounded, color: C.gold, size: 24)),
        ]))));
}


// ══════════════════════════════════════════════════════════════
//  SERIES DETAIL — حلقات مع صور وتفاصيل TMDB
// ══════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════
//  TRAILER OVERLAY — عرض ترويجي احترافي بـ WebView
//  يُشغَّل تلقائياً من مفتاح البوستر (YouTube trailer key)
// ══════════════════════════════════════════════════════════════
class _TrailerOverlay extends StatefulWidget {
  final String ytKey;
  final String title;
  const _TrailerOverlay({required this.ytKey, required this.title});
  @override State<_TrailerOverlay> createState() => _TrailerOverlayState();
}

class _TrailerOverlayState extends State<_TrailerOverlay> with SingleTickerProviderStateMixin {
  late final WebViewController _wc;
  late final AnimationController _anim;
  late final Animation<double> _fadeIn;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _anim   = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _initPlayer();
  }

  void _initPlayer() {
    // YouTube embed URL — autoplay + مكتوم + controls
    final embedUrl = 'https://www.youtube.com/embed/${widget.ytKey}'
        '?autoplay=1&rel=0&modestbranding=1&playsinline=1&color=white';
    _wc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) { if (mounted) setState(() => _loading = false); },
      ))
      ..loadRequest(Uri.parse(embedUrl));
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          // Handle bar
          Container(margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          // Title bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.5))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.play_circle_rounded, color: Colors.red, size: 12),
                  const SizedBox(width: 4),
                  Text('العرض الترويجي', style: T.caption(c: Colors.red)),
                ])),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.title,
                style: T.cairo(s: 13, w: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ])),
          // Video player area
          Expanded(child: Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: WebViewWidget(controller: _wc)),
            if (_loading)
              Container(color: Colors.black,
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
                  const SizedBox(height: 12),
                  Text('جارٍ تحميل العرض الترويجي...', style: T.caption(c: Colors.white54)),
                ]))),
          ])),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  AUTO TRAILER LAUNCHER — يشغّل الـ trailer تلقائياً
//  عند فتح صفحة التفاصيل لأول مرة (Netflix-style)
// ══════════════════════════════════════════════════════════════
class _AutoTrailerLauncher {
  static final Set<String> _shown = {};

  /// يُظهر الـ trailer تلقائياً مرة واحدة فقط لكل محتوى
  static Future<void> tryLaunch({
    required BuildContext context,
    required String contentId,
    required String contentName,
    required bool isTv,
    Duration delay = const Duration(milliseconds: 1200),
  }) async {
    if (_shown.contains(contentId)) return;
    _shown.add(contentId);

    await Future.delayed(delay);
    if (!context.mounted) return;

    try {
      final key = await TMDB.getTrailerKeyByName(contentName, isTv: isTv)
          .timeout(const Duration(seconds: 8));
      if (key == null || key.isEmpty) return;
      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TrailerOverlay(ytKey: key, title: contentName),
      );
    } catch (_) {}
  }

  /// مسح الـ cache لإعادة العرض
  static void reset(String contentId) => _shown.remove(contentId);
}
