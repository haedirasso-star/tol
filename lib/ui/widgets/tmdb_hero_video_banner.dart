part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — الإعلان المتحرّك في الواجهة (Trailer Hero) بأسلوب Netflix / TOD
//  ──────────────────────────────────────────────────────────────────────
//  1) TmdbTrailerService  : يجلب الإعلان الرسمي من TMDB (YouTube أو MP4)
//  2) HeroTrailerPlayer   : مشغّل خفيف يملأ المساحة (cover) — صامت، تلقائي، يتكرّر
//  3) TmdbHeroVideoBanner : بانر كامل: صورة ⇐ فيديو + عنوان + شارات + زر + كتم/صوت
//
//  ★ الأداء والذاكرة:
//   • مشغّل واحد فقط في كل وقت، يبدأ بعد ثانيتين من استقرار الشريحة
//   • يتوقف عند مغادرة التبويب، فتح صفحة أخرى، أو خروج التطبيق للخلفية
//   • dispose() يغلق المشغّل كلياً — لا صوت ولا فيديو في الخلفية
//   • إن رفض YouTube التضمين أو فشل التحميل ⇐ تبقى الصورة بهدوء بلا أي خطأ
// ════════════════════════════════════════════════════════════════════════

/// مراقب الصفحات — يوقف الإعلان عند فتح صفحة فوقه (مثل المشغّل أو التفاصيل)
final RouteObserver<ModalRoute<void>> kRouteObserver = RouteObserver<ModalRoute<void>>();

/// التبويب الظاهر حالياً في الواجهة الرئيسية (0 = الرئيسية)
final ValueNotifier<int> kShellTab = ValueNotifier<int>(0);

/// كتم/صوت مشترك — اختيار المستخدم يبقى بين الشرائح (يبدأ صامتاً دائماً)
final ValueNotifier<bool> kTrailerMuted = ValueNotifier<bool>(true);

// ════════════════════════════════════════════════════════════════════════
//  1) خدمة الإعلانات من TMDB
// ════════════════════════════════════════════════════════════════════════
enum TrailerKind { youtube, mp4 }

class TrailerSource {
  final TrailerKind kind;
  final String key;   // YouTube video id
  final String url;   // رابط MP4 مباشر
  const TrailerSource.youtube(this.key) : kind = TrailerKind.youtube, url = '';
  const TrailerSource.mp4(this.url)     : kind = TrailerKind.mp4,     key = '';
  String get id => kind == TrailerKind.youtube ? 'yt:$key' : 'mp4:$url';
}

class TmdbBannerItem {
  final int id;
  final bool isTv;
  final String title, overview, backdrop, year;
  final double rating;
  final List<String> genres;
  const TmdbBannerItem({required this.id, required this.isTv, required this.title,
      required this.overview, required this.backdrop, required this.year,
      required this.rating, required this.genres});
}

class TmdbTrailerService {
  TmdbTrailerService._();
  static const _base = 'https://api.themoviedb.org/3';
  static final Map<String, TrailerSource?> _cache = {};

  /// الإعلان من رقم TMDB مباشرة.
  /// الأولوية: Trailer رسمي ⇐ Trailer ⇐ Teaser ⇐ أي فيديو YouTube.
  static Future<TrailerSource?> byId(int tmdbId, {bool isTv = false}) async {
    final ck = '${isTv ? 'tv' : 'mv'}_$tmdbId';
    if (_cache.containsKey(ck)) return _cache[ck];
    TrailerSource? out;
    try {
      final r = await DioClient.tmdb.get(
        '$_base/${isTv ? 'tv' : 'movie'}/$tmdbId/videos',
        queryParameters: {
          'api_key': TMDB._key,
          // عربي أولاً ثم إنجليزي ثم بلا لغة — في طلب واحد
          'include_video_language': 'ar,en,null',
        },
      ).timeout(const Duration(seconds: 8));
      final list = ((r.data['results'] as List?) ?? const [])
          .whereType<Map>()
          .where((v) => (v['key']?.toString() ?? '').isNotEmpty)
          .toList();
      int score(Map v) {
        final site = v['site']?.toString() ?? '';
        final type = v['type']?.toString() ?? '';
        final lang = v['iso_639_1']?.toString() ?? '';
        var s = 0;
        if (site == 'YouTube') s += 100;
        if (type == 'Trailer') s += 40; else if (type == 'Teaser') s += 20;
        if (v['official'] == true) s += 15;
        if (lang == 'ar') s += 8; else if (lang == 'en') s += 4;
        return s;
      }
      list.sort((a, b) => score(b).compareTo(score(a)));
      for (final v in list) {
        final site = v['site']?.toString() ?? '';
        final key  = v['key'].toString();
        if (site == 'YouTube') { out = TrailerSource.youtube(key); break; }
        if (key.startsWith('http') && key.toLowerCase().contains('.mp4')) {
          out = TrailerSource.mp4(key); break;
        }
      }
    } catch (e) { debugPrint('[trailer] byId $tmdbId: $e'); }
    _cache[ck] = out;
    return out;
  }

  /// الإعلان من اسم المحتوى (لمحتوى السيرفر الذي لا يحمل رقم TMDB).
  static Future<TrailerSource?> byTitle(String title, {bool isTv = false, int? tmdbId}) async {
    if (tmdbId != null && tmdbId > 0) return byId(tmdbId, isTv: isTv);
    final ck = 't_${isTv ? 'tv' : 'mv'}_$title';
    if (_cache.containsKey(ck)) return _cache[ck];
    TrailerSource? out;
    try {
      final info = await TMDB.search(title, isTv: isTv).timeout(const Duration(seconds: 6));
      final id = int.tryParse(info['tmdb_id']?.toString() ?? '');
      if (id != null) out = await byId(id, isTv: isTv);
    } catch (e) { debugPrint('[trailer] byTitle "$title": $e'); }
    _cache[ck] = out;
    return out;
  }

  /// الرائج هذا الأسبوع — لبانر لا يعتمد على سيرفر المستخدم.
  static Future<List<TmdbBannerItem>> trending({bool isTv = false, int take = 8}) async {
    try {
      final r = await DioClient.tmdb.get(
        '$_base/trending/${isTv ? 'tv' : 'movie'}/week',
        queryParameters: {'api_key': TMDB._key, 'language': 'ar'},
      ).timeout(const Duration(seconds: 8));
      const g = {28:'أكشن',12:'مغامرة',16:'أنيميشن',35:'كوميدي',80:'جريمة',18:'دراما',
        14:'فانتازيا',27:'رعب',9648:'غموض',10749:'رومانسي',878:'خيال علمي',53:'إثارة',
        10759:'أكشن ومغامرة',10765:'خيال علمي',10768:'حرب',37:'غربي',10751:'عائلي'};
      return ((r.data['results'] as List?) ?? const [])
          .whereType<Map>()
          .where((m) => (m['backdrop_path'] ?? '').toString().isNotEmpty)
          .take(take)
          .map((m) => TmdbBannerItem(
                id: (m['id'] as num).toInt(),
                isTv: isTv,
                title: (m['title'] ?? m['name'] ?? '').toString(),
                overview: (m['overview'] ?? '').toString(),
                backdrop: 'https://image.tmdb.org/t/p/w1280${m['backdrop_path']}',
                year: ((m['release_date'] ?? m['first_air_date'] ?? '').toString()).split('-').first,
                rating: ((m['vote_average'] ?? 0) as num).toDouble(),
                genres: ((m['genre_ids'] as List?) ?? const [])
                    .map((x) => g[x] ?? '').where((x) => x.isNotEmpty).take(2).cast<String>().toList(),
              ))
          .toList();
    } catch (e) { debugPrint('[trailer] trending: $e'); return const []; }
  }
}

// ════════════════════════════════════════════════════════════════════════
//  2) المشغّل — يملأ المساحة كخلفية (cover)، صامت تلقائياً، يتكرّر
// ════════════════════════════════════════════════════════════════════════
class HeroTrailerPlayer extends StatefulWidget {
  final TrailerSource source;
  final bool active;            // false ⇐ إيقاف مؤقت (تبويب آخر / صفحة فوقه)
  final VoidCallback? onReady;  // أول إطار فعلي ظهر
  final VoidCallback? onFailed; // التضمين مرفوض / خطأ ⇐ نُبقي الصورة
  final VoidCallback? onEnded;
  const HeroTrailerPlayer({super.key, required this.source, this.active = true,
      this.onReady, this.onFailed, this.onEnded});
  @override State<HeroTrailerPlayer> createState() => _HeroTrailerPlayerState();
}

class _HeroTrailerPlayerState extends State<HeroTrailerPlayer> {
  yt.YoutubePlayerController? _yt;
  StreamSubscription<yt.YoutubePlayerValue>? _ytSub;
  VideoPlayerController? _vc;
  bool _ready = false, _failed = false, _disposed = false;
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    kTrailerMuted.addListener(_applyMute);
    _start();
    // إن لم يبدأ خلال 12 ثانية (شبكة ضعيفة) ⇐ تخلَّ عنه بهدوء
    _watchdog = Timer(const Duration(seconds: 12), () { if (!_ready) _fail('timeout'); });
  }

  void _start() {
    final s = widget.source;
    if (s.kind == TrailerKind.youtube) {
      _yt = yt.YoutubePlayerController.fromVideoId(
        videoId: s.key,
        autoPlay: true,
        params: const yt.YoutubePlayerParams(
          mute: true,                 // يبدأ صامتاً ⇐ تشغيل تلقائي فوري بلا منع من المتصفح
          showControls: false,
          showFullscreenButton: false,
          loop: true,
          enableCaption: false,
          showVideoAnnotations: false,
          strictRelatedVideos: true,
          playsInline: true,
        ),
      );
      _ytSub = _yt!.listen((v) {
        if (_disposed) return;
        if (v.error != yt.YoutubeError.none) { _fail('yt ${v.error}'); return; }
        if (v.playerState == yt.PlayerState.playing && !_ready) {
          // مهلة قصيرة تُخفي شعار YouTube الذي يظهر أول نصف ثانية
          Future.delayed(const Duration(milliseconds: 700), _markReady);
          _applyMute();
        }
        if (v.playerState == yt.PlayerState.ended) {
          widget.onEnded?.call();
          _yt?.seekTo(seconds: 0, allowSeekAhead: true);
          _yt?.playVideo();
        }
      });
    } else {
      _vc = VideoPlayerController.networkUrl(Uri.parse(s.url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _vc!.initialize().then((_) async {
        if (_disposed) return;
        await _vc!.setLooping(true);
        await _vc!.setVolume(kTrailerMuted.value ? 0.0 : 1.0);
        if (widget.active) await _vc!.play();
        _markReady();
      }).catchError((e) => _fail('mp4 $e'));
      _vc!.addListener(() { if (_vc!.value.hasError) _fail('mp4 ${_vc!.value.errorDescription}'); });
    }
  }

  void _markReady() {
    if (_disposed || _ready || _failed) return;
    _watchdog?.cancel();
    setState(() => _ready = true);
    widget.onReady?.call();
  }

  void _fail(String why) {
    if (_disposed || _failed) return;
    debugPrint('[trailer] fallback to image: $why');
    _watchdog?.cancel();
    setState(() => _failed = true);
    widget.onFailed?.call();
  }

  /// كتم/صوت فوري بلا إيقاف التشغيل
  void _applyMute() {
    final m = kTrailerMuted.value;
    if (_yt != null) { m ? _yt!.mute() : _yt!.unMute(); if (!m) _yt!.setVolume(100); }
    _vc?.setVolume(m ? 0.0 : 1.0);
  }

  @override
  void didUpdateWidget(covariant HeroTrailerPlayer old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      if (widget.active) { _yt?.playVideo(); _vc?.play(); }
      else               { _yt?.pauseVideo(); _vc?.pause(); }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    kTrailerMuted.removeListener(_applyMute);
    _ytSub?.cancel();
    _yt?.close();          // يغلق WebView ⇐ لا صوت في الخلفية
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final Widget video;
    double ar = 16 / 9;
    if (_yt != null) {
      video = yt.YoutubePlayer(controller: _yt!, aspectRatio: 16 / 9,
          backgroundColor: Colors.black);
    } else if (_vc != null && _vc!.value.isInitialized) {
      ar = _vc!.value.aspectRatio;
      video = VideoPlayer(_vc!);
    } else {
      video = const SizedBox.shrink();
    }
    // cover: نكبّر الفيديو حتى يملأ البانر مهما كان شكله، ونقصّ الزائد
    return AnimatedOpacity(
      opacity: _ready ? 1 : 0,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      child: IgnorePointer(            // اللمس يذهب للبانر لا لـ YouTube
        child: LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth, h = c.maxHeight;
          var vw = w, vh = w / ar;
          if (vh < h) { vh = h; vw = h * ar; }
          // تكبير طفيف يقصّ إطار YouTube وشريط العنوان
          vw *= 1.12; vh *= 1.12;
          return ClipRect(child: OverflowBox(
            maxWidth: vw, maxHeight: vh, minWidth: vw, minHeight: vh,
            child: SizedBox(width: vw, height: vh, child: video),
          ));
        }),
      ),
    );
  }
}

/// زر الكتم/الصوت — زجاجي دائري
class TrailerMuteButton extends StatelessWidget {
  final double size;
  const TrailerMuteButton({super.key, this.size = 38});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: kTrailerMuted,
    builder: (_, muted, __) => Semantics(
      button: true,
      label: muted ? 'تشغيل الصوت' : 'كتم الصوت',
      child: GestureDetector(
        onTap: () { Sound.nav(); kTrailerMuted.value = !muted; },
        child: ClipOval(child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: size, height: size,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.2)),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  key: ValueKey(muted), color: Colors.white, size: size * 0.5),
            ),
          ),
        )),
      ),
    ),
  );
}

/// بوابة الظهور: هل يجب أن يعمل الإعلان الآن؟
/// التبويب ظاهر + لا توجد صفحة فوقه + التطبيق في المقدمة.
class TrailerGate extends ChangeNotifier with WidgetsBindingObserver implements RouteAware {
  final int tab;
  bool _routeTop = true, _appFg = true, _subscribed = false;
  TrailerGate({this.tab = 0}) {
    WidgetsBinding.instance.addObserver(this);
    kShellTab.addListener(notifyListeners);
  }
  bool get active => _routeTop && _appFg && kShellTab.value == tab;

  void attach(BuildContext context) {
    if (_subscribed) return;
    final r = ModalRoute.of(context);
    if (r != null) { kRouteObserver.subscribe(this, r); _subscribed = true; }
  }

  @override void didPushNext() { _routeTop = false; notifyListeners(); }
  @override void didPopNext()  { _routeTop = true;  notifyListeners(); }
  @override void didPush() {}
  @override void didPop()  {}
  @override void didChangeAppLifecycleState(AppLifecycleState s) {
    _appFg = s == AppLifecycleState.resumed; notifyListeners();
  }

  @override
  void dispose() {
    if (_subscribed) kRouteObserver.unsubscribe(this);
    kShellTab.removeListener(notifyListeners);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════
//  3) البانر الكامل (مستقل — يُستخدم في أي صفحة)
// ════════════════════════════════════════════════════════════════════════
class TmdbHeroVideoBanner extends StatefulWidget {
  final int? tmdbId;            // أو
  final String title;           // يُبحث بالاسم إن لم يتوفر الرقم
  final bool isTv;
  final String backdropUrl;     // يظهر فوراً حتى يجهز الفيديو
  final List<String> badges;    // مثل: «فيلم» «أكشن» «2025»
  final String ctaLabel;        // «شاهد الآن» / «اشترك»
  final VoidCallback? onCta;
  final double? height;
  final int tab;                // رقم التبويب الذي يعيش فيه البانر
  const TmdbHeroVideoBanner({super.key, this.tmdbId, required this.title,
      this.isTv = false, this.backdropUrl = '', this.badges = const [],
      this.ctaLabel = 'شاهد الآن', this.onCta, this.height, this.tab = 0});
  @override State<TmdbHeroVideoBanner> createState() => _TmdbHeroVideoBannerState();
}

class _TmdbHeroVideoBannerState extends State<TmdbHeroVideoBanner> {
  TrailerSource? _src;
  bool _videoOn = false;
  Timer? _delay;
  late final TrailerGate _gate = TrailerGate(tab: widget.tab)..addListener(_onGate);
  void _onGate() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    _delay = Timer(const Duration(milliseconds: 1200), _load);
  }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _gate.attach(context); }

  Future<void> _load() async {
    final s = await TmdbTrailerService.byTitle(widget.title, isTv: widget.isTv, tmdbId: widget.tmdbId);
    if (mounted && s != null) setState(() => _src = s);
  }

  @override
  void dispose() { _delay?.cancel(); _gate.removeListener(_onGate); _gate.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? MediaQuery.of(context).size.height * 0.58;
    return SizedBox(
      height: h, width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        // الصورة — تظهر فوراً
        if (widget.backdropUrl.isNotEmpty)
          CachedNetworkImage(imageUrl: widget.backdropUrl, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black))
        else const ColoredBox(color: Colors.black),
        // الفيديو فوقها حين يجهز
        if (_src != null)
          HeroTrailerPlayer(
            key: ValueKey(_src!.id), source: _src!, active: _gate.active,
            onReady: () => setState(() => _videoOn = true),
            onFailed: () => setState(() { _videoOn = false; _src = null; }),
          ),
        // تدرّج سينمائي
        const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          stops: [0.0, 0.3, 0.7, 1.0],
          colors: [Color(0x88000000), Color(0x00000000), Color(0x99000000), Colors.black])))),
        // زر الصوت — الزاوية العلوية
        if (_videoOn)
          Positioned(top: MediaQuery.of(context).padding.top + 12, left: 14,
              child: const TrailerMuteButton()),
        // العنوان + الشارات + الزر
        Positioned(left: 18, right: 18, bottom: 22, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.badges.isNotEmpty) Wrap(spacing: 6, runSpacing: 6,
              children: widget.badges.map((b) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24)),
                child: Text(b, style: T.cairo(s: FS.xs, w: FontWeight.w700)),
              )).toList()),
            const SizedBox(height: 8),
            Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: T.cairo(s: 26, w: FontWeight.w900).copyWith(
                    shadows: const [Shadow(blurRadius: 18, color: Colors.black)])),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: widget.onCta,
              child: Container(
                height: 46, padding: const EdgeInsets.symmetric(horizontal: 26),
                decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 26),
                  const SizedBox(width: 6),
                  Text(widget.ctaLabel, style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black)),
                ]),
              ),
            ),
          ],
        )),
      ]),
    );
  }
}
