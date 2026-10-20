part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════
//  صفحة الفيلم / المسلسل — بأسلوب TOD
//  • أعلى الصفحة: الإعلان الترويجي يعمل فوراً (صامت) فوق البوستر،
//    وإن لم يوجد إعلان يبقى البوستر
//  • غير المشترك: زر «اشتراك» ← خطوات الاشتراك
//  • المشترك: «شاهد الآن» / «الحلقات» + تنزيل + قائمتي
//  • الفيديو الترويجي + «قد يعجبك أيضاً» من نفس القسم في السيرفر
// ════════════════════════════════════════════════════════════════════

/// نقطة الدخول الموحّدة لفتح أي فيلم أو مسلسل
void openDetail(BuildContext context, dynamic item, String type, {Map<String, String>? tmdb}) {
  if (item == null) return;
  if (type == 'live') {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
        isScrollControlled: true, useSafeArea: true,
        builder: (_) => _InfoSheetLoader(item: item, type: type));
    return;
  }
  Sound.hapticL();
  Navigator.push(context, PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => ContentDetailPage(item: item, type: type, tmdb: tmdb),
    transitionsBuilder: (_, a, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child)),
  ));
}

class ContentDetailPage extends StatefulWidget {
  final dynamic item;
  final String type;               // movie | series
  final Map<String, String>? tmdb;
  const ContentDetailPage({super.key, required this.item, required this.type, this.tmdb});
  @override State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  Map<String, String> _tmdb = {};
  TrailerSource? _trailer;
  bool _trailerOn = false, _trailerFailed = false, _expanded = false, _inWl = false;
  late final TrailerGate _gate = TrailerGate(tab: kShellTab.value)..addListener(_onGate);

  bool get _isTv => widget.type == 'series';
  dynamic get _it => widget.item;
  String get _name => _tmdb['title']?.isNotEmpty == true ? _tmdb['title']! : '${_it['name'] ?? ''}';
  String get _icon {
    for (final k in ['stream_icon', 'cover', 'icon']) {
      final v = _it[k]?.toString() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }
  String get _backdrop => _tmdb['backdrop']?.isNotEmpty == true ? _tmdb['backdrop']! : _icon;

  @override
  void initState() {
    super.initState();
    _tmdb = Map.of(widget.tmdb ?? {});
    _inWl = WL.has(_it);
    _load();
  }

  @override
  void didChangeDependencies() { super.didChangeDependencies(); _gate.attach(context); }
  void _onGate() { if (mounted) setState(() {}); }

  @override
  void dispose() { _gate.removeListener(_onGate); _gate.dispose(); super.dispose(); }

  Future<void> _load() async {
    if ((_tmdb['tmdb_id'] ?? '').isEmpty) {
      final name = '${_it['name'] ?? ''}';
      final id = _it['stream_id']?.toString() ?? _it['series_id']?.toString() ?? '';
      try {
        final t = id.isNotEmpty
            ? await TMDBFromWorker.fromWorker(id, name, isTv: _isTv)
            : await TMDB.search(name, isTv: _isTv);
        if (mounted) setState(() => _tmdb = {..._tmdb, ...t});
      } catch (_) {}
    }
    // الإعلان الترويجي يبدأ فوراً
    try {
      final src = await TmdbTrailerService.byTitle(_name, isTv: _isTv,
          tmdbId: int.tryParse(_tmdb['tmdb_id'] ?? ''));
      if (mounted) setState(() { _trailer = src; _trailerFailed = src == null; });
    } catch (_) {
      if (mounted) setState(() => _trailerFailed = true);
    }
  }

  // ── الإجراءات ───────────────────────────────────────────────────
  void _primary() {
    if (!SubCompat.isPremium) { Sound.hapticM(); PayPlansSheet.show(context); return; }
    if (_isTv) {
      Navigator.push(context, _fade(SeriesDetailPage(series: _it)));
      return;
    }
    if (!_canPlay(context)) return;
    Ads.show();
    GuestSession.startPlayback();
    Navigator.push(context, _fade(PlayerPage(urls: Api.movieUrls(_it), title: _name, item: _it)));
  }

  void _openTrailerFull() {
    if (_trailer == null || _trailer!.kind != TrailerKind.youtube) return;
    Sound.hapticL();
    Navigator.push(context, _fade(TrailerFullPage(ytKey: _trailer!.key, title: _name)));
  }

  List<dynamic> get _similar {
    final pool = _isTv ? AppState.allSeries : AppState.allMovies;
    final cat = _it['category_id']?.toString() ?? '';
    final myId = _it['stream_id']?.toString() ?? _it['series_id']?.toString() ?? '';
    final same = pool.where((e) {
      final id = e['stream_id']?.toString() ?? e['series_id']?.toString() ?? '';
      return id != myId && (cat.isEmpty || e['category_id']?.toString() == cat);
    }).take(14).toList();
    return same;
  }

  String get _category {
    final cats = _isTv ? AppState.seriesCats : AppState.movieCats;
    final id = _it['category_id']?.toString() ?? '';
    for (final c in cats) {
      if (c['category_id']?.toString() == id) {
        return (c['category_name']?.toString() ?? '').replaceAll(RegExp(r'^[A-Z]{2,3}\s*[|:\-]\s*'), '').trim();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final w   = MediaQuery.of(context).size.width;
    final top = MediaQuery.of(context).padding.top;
    final mediaH = w * 0.62 + top;
    final premium = SubCompat.isPremium;
    final year = _tmdb['year'] ?? '';
    final rating = _tmdb['rating'] ?? _it['rating']?.toString() ?? '';
    final overview = _tmdb['overview'] ?? _it['plot']?.toString() ?? '';
    final cast = _tmdb['cast'] ?? '';
    final director = _tmdb['director'] ?? '';
    final cat = _category;
    final meta = [
      if (year.isNotEmpty) year,
      if (cat.isNotEmpty) cat,
      if (rating.isNotEmpty && rating != '0.0' && rating != '0') '★ $rating',
      _isTv ? 'مسلسل' : 'فيلم',
    ];
    final isNew = (int.tryParse(year) ?? 0) >= DateTime.now().year - 1;
    final hasYt = _trailer?.kind == TrailerKind.youtube;
    final sim = _similar;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1C1F),
        body: CustomScrollView(physics: const BouncingScrollPhysics(), slivers: [
          // ── الإعلان / البوستر ──────────────────────────────────
          SliverToBoxAdapter(child: SizedBox(
            height: mediaH,
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: Colors.black, child: _backdrop.isNotEmpty
                  ? CachedNetworkImage(imageUrl: _imgUrl(_backdrop), fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox())
                  : const SizedBox()),
              if (_trailer != null && !_trailerFailed)
                Positioned.fill(child: HeroTrailerPlayer(
                  key: ValueKey('detail_${_trailer!.id}'),
                  source: _trailer!,
                  active: _gate.active,
                  onReady: () { if (mounted) setState(() => _trailerOn = true); },
                  onFailed: () {
                    if (!mounted) return;
                    final alt = TmdbTrailerService.alternative(_trailer!);
                    setState(() {
                      if (alt != null) { _trailer = alt; } else { _trailerFailed = true; }
                      _trailerOn = false;
                    });
                  },
                )),
              // تعتيم خفيف أعلى وأسفل
              const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                stops: [0, 0.25, 0.75, 1],
                colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xFF1C1C1F)],
              )))),
              // «تشغيل المقطع الترويجي» حين لا يعمل تلقائياً
              if (!_trailerOn && hasYt)
                Center(child: GestureDetector(
                  onTap: _openTrailerFull,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 74),
                    Text('تشغيل المقطع الترويجي', style: T.cairo(s: FS.lg, w: FontWeight.w700, c: Colors.white)
                        .copyWith(shadows: const [Shadow(color: Colors.black, blurRadius: 12)])),
                  ]),
                )),
              PositionedDirectional(
                top: top + 8, end: 10,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context)),
              ),
              if (_trailerOn)
                PositionedDirectional(bottom: 14, end: 14, child: const TrailerMuteButton()),
              if (_trailerOn && hasYt)
                PositionedDirectional(bottom: 14, start: 14, child: GestureDetector(
                  onTap: _openTrailerFull,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text('ملء الشاشة', style: T.cairo(s: FS.xs, c: Colors.white, w: FontWeight.w700)),
                    ]),
                  ),
                )),
            ]),
          )),

          // ── المعلومات ───────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
            sliver: SliverList(delegate: SliverChildListDelegate([
              Text(_name, style: T.cairo(s: 23, w: FontWeight.w800, c: Colors.white, h: 1.3)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (int i = 0; i < meta.length; i++) ...[
                  Text(meta[i], style: T.cairo(s: FS.md, c: Colors.white, w: FontWeight.w600)),
                  if (i < meta.length - 1) const Text('•', style: TextStyle(color: C.gold, fontSize: 16)),
                ],
              ]),
              const SizedBox(height: 12),
              Row(children: [
                if (isNew) _badge('حصري', C.gold),
                if (isNew) const SizedBox(width: 8),
                _badge('HD', Colors.white60),
              ]),
              const SizedBox(height: 18),

              // زر رئيسي
              SizedBox(
                height: 56, width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: C.gold, foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _primary,
                  icon: premium
                      ? Icon(_isTv ? Icons.video_library_rounded : Icons.play_arrow_rounded, size: 26)
                      : const SizedBox.shrink(),
                  label: Text(!premium ? 'اشتراك' : (_isTv ? 'الحلقات' : 'شاهد الآن'),
                      style: T.cairo(s: 21, w: FontWeight.w900, c: Colors.black)),
                ),
              ),
              if (!premium) ...[
                const SizedBox(height: 8),
                Center(child: Text('اشترك لمشاهدة هذا ${_isTv ? 'المسلسل' : 'الفيلم'} وكل المحتوى بلا حدود',
                    style: T.cairo(s: FS.sm, c: Colors.white60))),
              ],
              const SizedBox(height: 18),

              // القصة
              if (overview.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: _expanded
                      ? Text(overview, style: T.cairo(s: FS.md, c: Colors.white, h: 1.6))
                      : Text.rich(TextSpan(children: [
                          TextSpan(text: overview.length > 130 ? '${overview.substring(0, 130)}…' : overview,
                              style: T.cairo(s: FS.md, c: Colors.white, h: 1.6)),
                          if (overview.length > 130)
                            TextSpan(text: 'المزيد', style: T.cairo(s: FS.md, c: Colors.white54, h: 1.6)),
                        ])),
                ),
              if (director.isNotEmpty || cast.isNotEmpty) const SizedBox(height: 12),
              if (director.isNotEmpty)
                Text('إخراج: $director', style: T.cairo(s: FS.md, c: Colors.white60, h: 1.5)),
              if (cast.isNotEmpty)
                Text('طاقم العمل: $cast', maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: T.cairo(s: FS.md, c: Colors.white60, h: 1.5)),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF3A3A40), height: 1),
              const SizedBox(height: 14),

              // إجراءات
              Row(children: [
                _action(_inWl ? Icons.check_rounded : Icons.add_rounded, 'قائمتي', () async {
                  final v = await WL.toggle(_it, widget.type);
                  if (mounted) setState(() => _inWl = v);
                }),
                if (!_isTv) ...[
                  const SizedBox(width: 26),
                  Column(children: [
                    DownloadButton(
                      dlId: 'm_${_it['stream_id']}', size: 28, color: C.gold,
                      start: () => Downloads.addMovie(_it)),
                    Text('تنزيل', style: T.cairo(s: FS.sm, c: Colors.white, w: FontWeight.w600)),
                  ]),
                ],
                if (hasYt) ...[
                  const SizedBox(width: 26),
                  _action(Icons.movie_filter_outlined, 'الإعلان', _openTrailerFull),
                ],
              ]),
            ])),
          ),

          // ── الفيديو الترويجي ───────────────────────────────────
          if (hasYt) ...[
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 12),
              child: Text('الفيديو الترويجي', style: T.cairo(s: 22, w: FontWeight.w800, c: Colors.white)),
            )),
            SliverToBoxAdapter(child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: GestureDetector(
                  onTap: _openTrailerFull,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(width: w * 0.62, height: w * 0.62 * 9 / 16, child: Stack(fit: StackFit.expand, children: [
                      CachedNetworkImage(
                        imageUrl: 'https://img.youtube.com/vi/${_trailer!.key}/hqdefault.jpg',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => CachedNetworkImage(imageUrl: _imgUrl(_backdrop), fit: BoxFit.cover)),
                      const ColoredBox(color: Color(0x33000000)),
                      const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 46)),
                    ])),
                  ),
                ),
              ),
            )),
          ],

          // ── قد يعجبك أيضاً ─────────────────────────────────────
          if (sim.isNotEmpty) ...[
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 12),
              child: Text('قد يعجبك أيضاً', style: T.cairo(s: 22, w: FontWeight.w800, c: Colors.white)),
            )),
            SliverToBoxAdapter(child: SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: sim.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final s = sim[i];
                  final img = s['stream_icon']?.toString().isNotEmpty == true
                      ? '${s['stream_icon']}' : '${s['cover'] ?? ''}';
                  return GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, _fade(
                        ContentDetailPage(item: s, type: widget.type))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(width: 126, child: img.isNotEmpty
                          ? CachedNetworkImage(imageUrl: _imgUrl(img), fit: BoxFit.cover, memCacheHeight: 380,
                              errorWidget: (_, __, ___) => _NoImg('${s['name'] ?? ''}'))
                          : _NoImg('${s['name'] ?? ''}')),
                    ),
                  );
                },
              ),
            )),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ]),
      ),
    );
  }

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c, width: 1.3)),
    child: Text(t, style: T.cairo(s: FS.md, w: FontWeight.w700, c: c)),
  );

  Widget _action(IconData icon, String label, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () { Sound.hapticL(); onTap(); },
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Column(children: [
        Icon(icon, color: C.gold, size: 30),
        Text(label, style: T.cairo(s: FS.sm, c: Colors.white, w: FontWeight.w600)),
      ]),
    ),
  );
}


/// الإعلان بملء الشاشة وبالصوت — داخل التطبيق
class TrailerFullPage extends StatefulWidget {
  final String ytKey, title;
  const TrailerFullPage({super.key, required this.ytKey, required this.title});
  @override State<TrailerFullPage> createState() => _TrailerFullPageState();
}

class _TrailerFullPageState extends State<TrailerFullPage> {
  late final yt.YoutubePlayerController _c = yt.YoutubePlayerController.fromVideoId(
    videoId: widget.ytKey,
    autoPlay: true,
    params: const yt.YoutubePlayerParams(
      showControls: true,
      showFullscreenButton: false,
      playsInline: true,
      strictRelatedVideos: true,
      // نفس إصلاح Error 152/153
      origin: 'https://www.youtube-nocookie.com',
    ),
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _c.close();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(children: [
      Center(child: yt.YoutubePlayer(controller: _c, aspectRatio: 16 / 9, backgroundColor: Colors.black)),
      Positioned(top: 10, left: 10, child: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
        onPressed: () => Navigator.pop(context))),
    ]),
  );
}


/// «قائمتي» — المحفوظات (بطاقات بوستر)
class MyListPage extends StatefulWidget {
  const MyListPage({super.key});
  @override State<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends State<MyListPage> {
  /// يعيد العنصر الكامل من قوائم السيرفر إن وُجد (لصور ومعلومات صحيحة)
  dynamic _full(Map w) {
    final id = '${w['id'] ?? ''}';
    final isTv = w['type'] == 'series';
    for (final e in (isTv ? AppState.allSeries : AppState.allMovies)) {
      if ('${e['stream_id'] ?? e['series_id'] ?? ''}' == id) return e;
    }
    return {
      isTv ? 'series_id' : 'stream_id': id, 'name': w['name'] ?? '',
      'stream_icon': w['icon'] ?? '', 'cover': w['icon'] ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final items = WL.all;
    final w = MediaQuery.of(context).size.width;
    final cols = w > 600 ? 5 : 3;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black, elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.white),
              onPressed: () => Navigator.pop(context)),
          title: Text('قائمتي', style: T.cairo(s: FS.lg, w: FontWeight.w800, c: Colors.white)),
        ),
        body: items.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bookmark_border_rounded, color: Colors.white24, size: 60),
                const SizedBox(height: 12),
                Text('قائمتك فارغة', style: T.cairo(s: FS.lg, w: FontWeight.w800, c: Colors.white)),
                Text('اضغط «+ قائمتي» في صفحة أي فيلم أو مسلسل',
                    style: T.cairo(s: FS.sm, c: Colors.white60)),
              ]))
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols, childAspectRatio: 0.66, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = _full(items[i]);
                  final type = items[i]['type'] == 'series' ? 'series' : 'movie';
                  final img = '${it['stream_icon'] ?? ''}'.isNotEmpty ? '${it['stream_icon']}' : '${it['cover'] ?? ''}';
                  return GestureDetector(
                    onTap: () async { openDetail(context, it, type); },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: img.isNotEmpty
                          ? CachedNetworkImage(imageUrl: _imgUrl(img), fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _NoImg('${it['name'] ?? ''}'))
                          : _NoImg('${it['name'] ?? ''}'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
