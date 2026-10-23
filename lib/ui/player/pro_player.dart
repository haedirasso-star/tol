part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════
//  TOTV+ Pro Player v3.4
//  ─────────────────────────────────────────────────────────────────
//  نفس التصميم الأبيض/الأسود الفخم — فوق محرّكين (player_engine.dart):
//   • البث المباشر ⇐ المحرك السلس (ExoPlayer) — ثابت مثل المتصفح
//   • الأفلام والمسلسلات ⇐ المحرك المتقدم (libmpv) — كل الصيغ والمسارات
//   • فشل محرك في كل المصادر ⇐ تحويل تلقائي للمحرك الآخر
//
//  البث المباشر (أسلوب TOD):
//   • شارة «مباشر» ذكية + زر «العودة للمباشر» عند التأخر عن البث
//   • شريط قنوات سفلي + القناة السابقة + المفضلة + الأخيرة + أرقام القنوات
//   • مؤشر جودة الاتصال + إعادة اتصال صامتة + تسمية المصادر
//   • زاب فوري: تبقى آخر صورة ظاهرة حتى تجهز القناة الجديدة
//
//  الأفلام والمسلسلات (أسلوب نتفليكس):
//   • شاشة الإيقاف المؤقت (العنوان والقصة) · تخطي المقدمة بعلامات حقيقية
//   • الحلقة التالية عند الشارة + الانتقال للموسم التالي · «هل ما زلت تشاهد؟»
//   • قائمة الحلقات بالمواسم · الصوت والترجمة وحجمها · استكمال بلا نوافذ مزعجة
//
//  الراحة: الإيماءات كاملة · صورة داخل صورة تلقائياً · حفظ التفضيلات ·
//  وضع عمودي مريح · توفير البيانات · ريموت التلفاز · مؤقت نوم بتلاشي الصوت.
//
//  الاحتياط: RC.playerEngine == 'legacy' يعيد المشغّل القديم فوراً من الإدارة.
// ════════════════════════════════════════════════════════════════════

class PlayerPage extends StatelessWidget {
  final List<String> urls;
  final String title;
  final bool isLive;
  final dynamic item;
  final List<dynamic> episodes;
  final int episodeIndex;
  final void Function(int)? onEpisodeChanged;
  /// كل مواسم المسلسل (رقم الموسم ⇐ حلقاته) — لقائمة المواسم والانتقال للموسم التالي
  final Map<int, List<dynamic>> seasons;
  final int season;
  /// قائمة القنوات التي جاء منها المستخدم (للتنقّل بين القنوات داخل المشغّل)
  final List<dynamic> channels;
  const PlayerPage({super.key, required this.urls, required this.title, this.isLive = false, this.item,
      this.episodes = const [], this.episodeIndex = 0, this.onEpisodeChanged,
      this.seasons = const {}, this.season = 0, this.channels = const []});

  static bool get useLegacy => RC.playerEngine == 'legacy';

  @override
  Widget build(BuildContext context) => useLegacy
      ? LegacyPlayerPage(urls: urls, title: title, isLive: isLive, item: item,
          episodes: episodes, episodeIndex: episodeIndex, onEpisodeChanged: onEpisodeChanged)
      : ProPlayer(urls: urls, title: title, isLive: isLive, item: item,
          episodes: episodes, episodeIndex: episodeIndex, onEpisodeChanged: onEpisodeChanged,
          seasons: seasons, season: season, channels: channels);
}

class ProPlayer extends StatefulWidget {
  final List<String> urls;
  final String title;
  final bool isLive;
  final dynamic item;
  final List<dynamic> episodes;
  final int episodeIndex;
  final void Function(int)? onEpisodeChanged;
  final Map<int, List<dynamic>> seasons;
  final int season;
  final List<dynamic> channels;
  const ProPlayer({super.key, required this.urls, required this.title, this.isLive = false, this.item,
      this.episodes = const [], this.episodeIndex = 0, this.onEpisodeChanged,
      this.seasons = const {}, this.season = 0, this.channels = const []});

  /// يُضبط في main() إن فشل تحميل libmpv ⇐ المحرك السلس لكل شيء
  static bool engineFailed = false;

  @override
  State<ProPlayer> createState() => _ProPlayerState();
}

enum _Panel { none, episodes, channels, settings }
enum _Drag { none, seek, bright, vol, zoom }

// ── ألوان وخطوط المشغّل: أبيض/أسود فخم ─────────────────────────────
const _pWhite = Colors.white;
const _pDim = Color(0xB3FFFFFF);
const _pFaint = Color(0x33FFFFFF);
const _pGlass = Color(0x8C0B0B0D);
const _pStroke = Color(0x26FFFFFF);
const _pRed = Color(0xFFE50914);
TextStyle _pt(double s, {FontWeight w = FontWeight.w600, Color c = _pWhite, double? h}) =>
    T.cairo(s: s, w: w, c: c, h: h).copyWith(shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8)]);

String _clock(Duration d) {
  final neg = d.isNegative;
  final x = neg ? -d : d;
  final h = x.inHours, m = x.inMinutes.remainder(60), s = x.inSeconds.remainder(60);
  final t = h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return neg ? '-$t' : t;
}

class _ProPlayerState extends State<ProPlayer> with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── المحرك ─────────────────────────────────────────────────────
  PlayerEngine? _e;
  EngineKind _kind = EngineKind.native;
  bool _engineSwitched = false;
  final _pos = ValueNotifier<Duration>(Duration.zero);
  final _dur = ValueNotifier<Duration>(Duration.zero);
  final _buf = ValueNotifier<Duration>(Duration.zero);
  bool _playing = false, _buffering = true, _started = false, _startedThis = false, _ended = false;
  bool _userPaused = false;       // إيقاف بقرار المستخدم (لا يتأثر بالتحميل)
  bool _error = false, _failing = false;
  String _err = '', _hint = '';

  // ── المصادر ────────────────────────────────────────────────────
  List<String> _queue = [];
  int _qi = 0, _soft = 0, _stalls = 0;
  String _openedUrl = '';
  final List<DateTime> _stallLog = [];
  Timer? _watchdog, _stallT, _progT, _guardT, _hideT, _wmT, _sleepT, _sleepFadeT, _resumeT, _tapT, _hudT,
      _pauseT, _digT;

  // ── المحتوى الحالي (يتغيّر عند تبديل الحلقة/القناة) ──────────────
  late int _ep = widget.episodeIndex;
  late int _season = widget.season;
  late List<dynamic> _eps = widget.episodes;
  late dynamic _item = widget.item;
  late String _title = widget.title;
  List<dynamic> _channels = [];
  dynamic _prevCh;
  SkipMarkers? _marks;

  // ── الواجهة ────────────────────────────────────────────────────
  bool _ui = true, _locked = false, _pip = false, _landscape = true, _showRemain = false;
  _Panel _panel = _Panel.none;
  int _chTab = 0;                 // 0 الكل · 1 المفضلة · 2 الأخيرة
  BoxFit _fit = BoxFit.contain;
  double _zoom = 1, _rate = 1, _bright = .5, _vol = .7, _engVol = 1;
  bool _boost = false;            // ضغطة مطوّلة ×2
  int _wm = 0, _sleepMin = 0;
  Duration? _resumedFrom;
  bool _introSkipped = false;
  String _toast = '', _digits = '';

  // ── البث المباشر ───────────────────────────────────────────────
  DateTime? _pausedAt;
  bool _behind = false;           // متأخر عن حافة البث (بعد إيقاف مؤقت)

  // ── نتفليكس: شاشة الإيقاف + هل ما زلت تشاهد ─────────────────────
  bool _pauseInfo = false;
  int _autoChain = 0;             // حلقات انتقلت تلقائياً بلا أي لمس
  (int, int)? _askStill;          // الحلقة المنتظرة حتى يؤكّد المستخدم

  // ── الإيماءات ──────────────────────────────────────────────────
  _Drag _drag = _Drag.none;
  Offset _dragStart = Offset.zero, _dragAcc = Offset.zero;
  Duration _scrubFrom = Duration.zero, _scrubTo = Duration.zero;
  int _tapSide = 0, _tapSecs = 0;
  Offset _lastDoubleTap = Offset.zero;
  bool _seeking = false;
  Duration _seekPreview = Duration.zero;

  // ── الحلقة التالية ──────────────────────────────────────────────
  bool _nextShown = false, _nextDismissed = false;
  late final AnimationController _nextAc = AnimationController(vsync: this, duration: const Duration(seconds: 10))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) { final n = _next; if (n != null) _goEpisode(n.$1, n.$2, auto: true); }
    });

  final _chQ = TextEditingController();
  final _strip = ScrollController();

  static const _pipCh = MethodChannel('totv_pip');
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
  static const _stripW = 92.0;

  String get _cid {
    final it = _item;
    if (it == null) return '';
    return '${it['stream_id'] ?? it['id'] ?? it['series_id'] ?? ''}';
  }

  Map get _root => widget.item is Map ? widget.item as Map : const {};
  String get _seriesId => '${_root['_series_id'] ?? _root['series_id'] ?? ''}';
  String get _seriesName {
    final n = '${_root['_series_name'] ?? ''}'.trim();
    if (n.isNotEmpty) return n;
    return widget.title.split(' — ').first.trim();
  }

  bool get _isSeries => _eps.isNotEmpty;
  bool get _paused => _userPaused || _ended;

  /// الحلقة التالية (نفس الموسم أو أول حلقة في الموسم التالي)
  (int, int)? get _next {
    if (widget.isLive || _eps.isEmpty) return null;
    if (_ep + 1 < _eps.length) return (_season, _ep + 1);
    if (widget.seasons.isEmpty) return null;
    final ks = widget.seasons.keys.toList()..sort();
    final i = ks.indexOf(_season);
    if (i >= 0 && i + 1 < ks.length && (widget.seasons[ks[i + 1]] ?? const []).isNotEmpty) return (ks[i + 1], 0);
    return null;
  }

  bool get _hasNext => _next != null;

  List<dynamic> _epsOf(int season) => season == _season ? _eps : (widget.seasons[season] ?? const []);

  // ══════════════════════════════════════════════════════════════
  //  دورة الحياة
  // ══════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fit = const [BoxFit.contain, BoxFit.cover, BoxFit.fill][PlayerPrefs.fit.clamp(0, 2)];
    _setLandscape(true);
    if (!kIsWeb) WakelockPlus.enable();   // الشاشة لا تنطفئ أثناء المشاهدة (لكلا المحرّكين)
    SecurityLayer.enableScreenRecord();
    if (!kIsWeb) {
      _pipCh.setMethodCallHandler((call) async {
        if (call.method == 'pipStatusChanged' && mounted) setState(() => _pip = call.arguments == true);
      });
    }
    _wmT = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() => _wm = (_wm + 1) % 4); });
    _initSystemLevels();
    _boot();
  }

  Future<void> _initSystemLevels() async {
    try { _bright = (await ScreenBrightnessPlatform.instance.application).clamp(0.0, 1.0); } catch (_) {}
    try {
      VolumeController.instance.showSystemUI = false;
      _vol = (await VolumeController.instance.getVolume()).clamp(0.0, 1.0);
    } catch (_) {}
  }

  Future<void> _boot() async {
    await PlayerPrefs.load();
    if (!mounted) return;
    _fit = const [BoxFit.contain, BoxFit.cover, BoxFit.fill][PlayerPrefs.fit.clamp(0, 2)];
    if (!SubCompat.isPremium) {
      try { await WatchTimer.load(); } catch (_) {}
      _guardT = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && !SubCompat.isPremium && WatchTimer.isExpired) _paywall();
      });
    }
    WatchTimer.startPlayback();
    if (widget.isLive) _loadChannels();
    _queue = _buildQueue(widget.urls);
    if (_queue.isEmpty) {
      setState(() { _error = true; _err = 'لم يُعثر على رابط تشغيل — تأكد من تفعيل اشتراكك'; });
      return;
    }
    try {
      await _attachEngine(_pickKind());
    } catch (e) {
      debugPrint('[pro_player] engine: $e');
      if (mounted) setState(() { _error = true; _err = 'تعذّر تشغيل المشغّل على هذا الجهاز'; });
      return;
    }
    if (!mounted) return;
    _open(_queue.first, start: _resumePos());
    if (_isSeries) _loadMarkers();
    _setAutoPip(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveProgress(force: true);
    for (final t in [_watchdog, _stallT, _progT, _guardT, _hideT, _wmT, _sleepT, _sleepFadeT, _resumeT, _tapT,
        _hudT, _pauseT, _digT]) { t?.cancel(); }
    _nextAc.dispose();
    _chQ.dispose();
    _strip.dispose();
    _e?.dispose();
    _pos.dispose(); _dur.dispose(); _buf.dispose();
    WatchTimer.stopPlayback();
    final uid = AuthService.currentUser?.uid;
    if (uid != null) unawaited(GuestSession.stopPlayback(uid));
    if (!kIsWeb) {
      _setAutoPip(false);
      _pipCh.setMethodCallHandler(null);
    }
    try { ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness(); } catch (_) {}
    if (!kIsWeb) WakelockPlus.disable();
    SecurityLayer.disableScreenRecord();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused && !_pip) {
      _e?.pause();
      _userPaused = true;
      if (widget.isLive) _pausedAt ??= DateTime.now();
      _saveProgress(force: true);
    }
  }

  void _refresh() { if (mounted) setState(() {}); }

  void _setLandscape(bool on) {
    _landscape = on;
    SystemChrome.setPreferredOrientations(on
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
  }

  void _setAutoPip(bool on) {
    if (!Plat.isAndroid) return;   // القناة الأصلية موجودة في أندرويد فقط
    _pipCh.invokeMethod('setAutoPiP', {'enable': on && PlayerPrefs.autoPip}).catchError((_) => null);
  }

  // ══════════════════════════════════════════════════════════════
  //  المحرك
  // ══════════════════════════════════════════════════════════════
  EngineKind _pickKind() {
    if (ProPlayer.engineFailed) return EngineKind.native;
    final rc = RC.playerEngine;
    if (rc == 'native') return EngineKind.native;
    if (rc == 'mpv') return EngineKind.mpv;
    if (PlayerPrefs.engine == 'native') return EngineKind.native;
    if (PlayerPrefs.engine == 'mpv') return EngineKind.mpv;
    // تلقائي: المباشر ⇐ السلس · الأفلام والمسلسلات ⇐ المتقدم (كل الصيغ والمسارات)
    return widget.isLive ? EngineKind.native : EngineKind.mpv;
  }

  Future<void> _attachEngine(EngineKind k) async {
    var kind = (k == EngineKind.mpv && ProPlayer.engineFailed) ? EngineKind.native : k;
    var e = PlayerEngine.create(kind, title: _title, live: widget.isLive);
    try {
      await e.init();
    } catch (err) {
      debugPrint('[pro_player] ${kind.name} init: $err');
      if (kind != EngineKind.mpv) rethrow;
      ProPlayer.engineFailed = true;
      try { await e.dispose(); } catch (_) {}
      kind = EngineKind.native;
      e = NativeEngine();
      await e.init();
    }
    e
      ..onPlaying = _onPlaying
      ..onBuffering = _onBuffering
      ..onPosition = _onTick
      ..onDuration = ((v) => _dur.value = v)
      ..onBuffer = ((v) => _buf.value = v)
      ..onCompleted = _onCompleted
      ..onError = _onError
      ..onFirstFrame = _onStarted
      ..onTracks = _refresh
      ..onSurface = _refresh;
    final old = _e;
    _e = e;
    _kind = kind;
    if (old != null) unawaited(old.dispose());
    if (_engVol != 1) unawaited(e.setVolume(_engVol));
    _refresh();
  }

  Future<void> _switchEngine(EngineKind k) async {
    if (k == _kind) return;
    final at = widget.isLive ? null : _pos.value;
    setState(() { _panel = _Panel.none; _hint = 'تبديل المحرك…'; });
    try { await _attachEngine(k); } catch (_) { _flash('تعذّر تبديل المحرك'); return; }
    if (!mounted) return;
    _flash(_kind == EngineKind.native ? 'المحرك السلس' : 'المحرك المتقدم');
    _open(_queue.isEmpty ? _openedUrl : _queue[_qi], start: at);
  }

  // ══════════════════════════════════════════════════════════════
  //  المصادر والتشغيل — دائماً من سيرفر اشتراك المستخدم نفسه
  // ══════════════════════════════════════════════════════════════
  List<String> _buildQueue(List<String> urls) {
    final out = <String>[];
    void add(String u) { if (u.trim().isNotEmpty && !out.contains(u)) out.add(u); }
    final host = Server.host;
    final cached = _cid.isEmpty ? null : PlayUrlCache.get(_cid);
    // الرابط الناجح السابق — فقط إن كان من نفس سيرفر الاشتراك الحالي
    if (cached != null && cached.isNotEmpty && host.isNotEmpty && cached.startsWith(host)) add(cached);
    if (widget.isLive && urls.length > 1) add(LiveLoadBalancer.pickBest(urls));
    for (final u in urls) { add(u); }
    for (final u in _candidates()) { add(u); }
    // ★ iOS: مشغّل أبل لا يشغّل بث TS المستمر ⇐ روابط HLS (m3u8) أولاً للمباشر
    if (Plat.isIOS && widget.isLive) {
      final hls = out.where((u) => u.toLowerCase().contains('.m3u8')).toList();
      return [...hls, ...out.where((u) => !hls.contains(u))];
    }
    return out;
  }

  /// روابط احتياطية من سيرفر اشتراك المستخدم (لا من سيرفر التطبيق العام)
  List<String> _candidates() {
    final it = _item;
    final id = '${it?['stream_id'] ?? it?['id'] ?? ''}';
    if (id.isEmpty) return const [];
    final base = Server.host.replaceAll(RegExp(r'/+$'), '');
    final user = Sub.username, pass = Sub.password;
    if (base.isEmpty || user.isEmpty || pass.isEmpty) return const [];
    if (widget.isLive) {
      return ['$base/live/$user/$pass/$id.ts', '$base/live/$user/$pass/$id.m3u8', '$base/$user/$pass/$id'];
    }
    final isSeries = it?['series_id'] != null || it?['episode_num'] != null || _isSeries;
    final dir = isSeries ? 'series' : 'movie';
    final declared = '${it?['container_extension'] ?? ''}';
    final exts = <String>{if (declared.isNotEmpty) declared, 'mkv', 'mp4', 'm3u8', 'ts', 'avi'};
    return [for (final e in exts) '$base/$dir/$user/$pass/$id.$e'];
  }

  Duration? _resumePos() {
    if (widget.isLive || _cid.isEmpty) return null;
    final ms = WatchHistory.getProgressMs(_cid);
    if (ms <= 10000 || WatchHistory.isCompleted(_cid)) return null;
    return Duration(milliseconds: ms);
  }

  Future<void> _open(String url, {Duration? start}) async {
    final e = _e;
    if (e == null || !mounted) return;
    _openedUrl = url;
    _startedThis = false;
    _failing = false;
    _stallT?.cancel();
    setState(() {
      _error = false; _buffering = true; _ended = false; _userPaused = false; _pauseInfo = false;
      if (widget.isLive) { _behind = false; _pausedAt = null; }   // إعادة الفتح = حافة البث
    });
    _watchdog?.cancel();
    _watchdog = Timer(Duration(seconds: widget.isLive ? 16 : 25), () {
      if (mounted && !_startedThis) _fail('timeout');
    });
    try {
      await e.open(url, start: start, live: widget.isLive, dataSaver: PlayerPrefs.dataSaver);
      if (!mounted || _e != e) return;
      if (_rate != 1 && !widget.isLive) await e.setRate(_rate);
      if (start != null && !_started) {
        _resumedFrom = start;
        _resumeT?.cancel();
        _resumeT = Timer(const Duration(seconds: 8), () { if (mounted) setState(() => _resumedFrom = null); });
      }
    } catch (err) {
      _fail('$err');
    }
  }

  void _onStarted() {
    if (_startedThis || !mounted) return;
    _startedThis = true;
    _watchdog?.cancel();
    _soft = 0; _hint = '';
    if (_cid.isNotEmpty && _openedUrl.isNotEmpty) PlayUrlCache.put(_cid, _openedUrl);
    try { LiveLoadBalancer.markSuccess(Uri.parse(_openedUrl).host); } catch (_) {}
    if (!_started) {
      _started = true;
      HapticFeedback.lightImpact();
    }
    if (_item != null) {
      WatchHistory.addItem(_item, widget.isLive ? 'live' : 'movie');
      if (widget.isLive) PlayerPrefs.addRecent(_item);
    }
    _progT?.cancel();
    _progT = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
    _schedHide();
    _refresh();
  }

  void _onPlaying(bool v) {
    _playing = v;
    if (v) {
      _ended = false;
      if (_userPaused && _startedThis) _userPaused = false;   // تشغيل من خارج المشغّل (سماعة/إشعار)
      _schedHide();
    }
    _refresh();
  }

  void _onError(String e) {
    debugPrint('[pro_player] ${_kind.name}: $e');
    if (!_startedThis) { _fail(e); return; }
    // المحرك السلس يتوقف نهائياً عند الخطأ ⇐ نتعافى بصمت من نفس الموضع
    if (_kind == EngineKind.native) _recover('runtime');
  }

  void _onBuffering(bool v) {
    _buffering = v;
    _stallT?.cancel();
    if (v && _startedThis && !_userPaused) {
      _stallLog.add(DateTime.now());
      // تقطيع طويل ⇐ إعادة فتح نفس المصدر من نفس الموضع، ثم مصدر بديل
      _stallT = Timer(Duration(seconds: widget.isLive ? 14 : 22), () {
        if (mounted && _buffering) _recover('stall');
      });
    }
    _refresh();
  }

  void _recover(String why) {
    _stalls++;
    if (_stalls >= 3 && _qi + 1 < _queue.length) {
      _qi++;
      _stalls = 0;
      _hint = 'تبديل إلى مصدر أسرع…';
    } else {
      _hint = 'إعادة الاتصال…';
    }
    _open(_queue.isEmpty ? _openedUrl : _queue[_qi], start: widget.isLive ? null : _pos.value);
  }

  bool _transient(String r) {
    final l = r.toLowerCase();
    return l.contains('timeout') || l.contains('socket') || l.contains('connection') || l.contains('reset') ||
        l.contains('502') || l.contains('503') || l.contains('504') || l.contains('network') || l.contains('source error');
  }

  Future<void> _fail(String r) async {
    if (!mounted || _failing) return;
    _failing = true;
    _watchdog?.cancel();
    try { LiveLoadBalancer.markFail(Uri.parse(_openedUrl).host); } catch (_) {}
    if (_cid.isNotEmpty && PlayUrlCache.get(_cid) == _openedUrl) PlayUrlCache.remove(_cid);
    final at = widget.isLive ? null : (_started && _pos.value > Duration.zero ? _pos.value : _resumePos());
    if (_qi + 1 < _queue.length) {
      _qi++;
      _hint = 'تجربة مصدر آخر (${_qi + 1}/${_queue.length})…';
      _open(_queue[_qi], start: at);
      return;
    }
    if (_soft < 2 && _transient(r)) {
      _soft++;
      _hint = 'انقطاع مؤقت — إعادة المحاولة…';
      _refresh();
      Timer(Duration(milliseconds: 1500 * _soft), () {
        if (!mounted) return;
        _qi = 0;
        _open(_queue[0], start: at);
      });
      return;
    }
    // ★ كل المصادر فشلت بهذا المحرك ⇐ نجرّب المحرك الآخر مرة واحدة
    final other = _kind == EngineKind.native ? EngineKind.mpv : EngineKind.native;
    if (!_engineSwitched && !(other == EngineKind.mpv && ProPlayer.engineFailed)) {
      _engineSwitched = true;
      _hint = 'تجربة المحرك البديل…';
      _refresh();
      try {
        await _attachEngine(other);
        if (!mounted) return;
        _qi = 0; _soft = 0;
        _open(_queue[0], start: at);
        return;
      } catch (_) {}
    }
    if (!SubCompat.isPremium && WatchTimer.isExpired) { _paywall(); return; }
    final l = r.toLowerCase();
    String msg;
    if (!Sub.hasServer && Sub.password.isEmpty) {
      msg = 'لم تُفعَّل بيانات الاشتراك بعد — فعّل اشتراكك أولاً';
    } else if (r.contains('403') || r.contains('401')) {
      msg = 'هذا المحتوى ليس ضمن اشتراكك أو انتهت صلاحيته';
    } else if (r.contains('404')) {
      msg = 'هذا المحتوى غير متوفر حالياً على السيرفر';
    } else if (l.contains('timeout') || l.contains('connection') || l.contains('network')) {
      msg = 'السيرفر لا يستجيب — تحقق من الإنترنت وحاول مجدداً';
    } else {
      msg = 'تعذّر تشغيل هذا المحتوى';
    }
    setState(() { _error = true; _err = msg; _hint = ''; _buffering = false; });
    // ★ تقرير للأدمن: أي قناة مباشرة فشلت كل مصادرها (يظهر في «أعطال القنوات»)
    if (widget.isLive && Sub.hasServer) ChannelReport.add(_title, _cid, r);
  }

  void _retry() {
    _qi = 0; _soft = 0; _stalls = 0; _engineSwitched = false;
    if (_queue.isEmpty) _queue = _buildQueue(widget.urls);
    if (_queue.isEmpty) return;
    _open(_queue.first, start: widget.isLive ? null : (_pos.value > Duration.zero ? _pos.value : _resumePos()));
  }

  void _onTick(Duration pos) {
    _pos.value = pos;
    if (widget.isLive || !_startedThis) return;
    final dur = _dur.value;
    // الحلقة التالية: عند بداية الشارة (من علامات الأدمن) أو قبل النهاية بـ 25 ثانية
    final lead = (_marks?.creditsLeft ?? 0) > 0 ? _marks!.creditsLeft : 25;
    if (_hasNext && !_nextShown && !_nextDismissed && dur.inSeconds > 90 && (dur - pos).inSeconds <= lead) {
      _nextShown = true;
      _nextAc.forward(from: 0);
      _refresh();
    }
  }

  void _onCompleted() {
    _saveProgress(force: true);
    final n = _next;
    if (n != null && !_nextDismissed) { _goEpisode(n.$1, n.$2, auto: true); return; }
    setState(() { _ended = true; _ui = true; _pauseInfo = false; });
  }

  void _saveProgress({bool force = false}) {
    if (widget.isLive || _cid.isEmpty || !_started) return;
    final pos = _pos.value.inSeconds, dur = _dur.value.inSeconds;
    if (dur <= 0 || (!force && !_playing)) return;
    if (pos > 5) WatchHistory.saveProgress(_cid, pos, dur);
  }

  // ══════════════════════════════════════════════════════════════
  //  الحلقات والمواسم
  // ══════════════════════════════════════════════════════════════
  String _epNum(dynamic ep, int i) => '${(ep is Map ? ep['episode_num'] : null) ?? (i + 1)}';
  String _epLabel(int i, [int? season]) {
    final list = _epsOf(season ?? _season);
    if (i < 0 || i >= list.length) return 'الحلقة ${i + 1}';
    return 'الحلقة ${_epNum(list[i], i)}';
  }

  String _epTitle(int i, [int? season]) {
    final list = _epsOf(season ?? _season);
    if (i < 0 || i >= list.length) return _epLabel(i, season);
    final t = '${list[i]['title'] ?? ''}'.trim();
    // أسماء تقنية مثل «Show.S01.E01» لا تُعرض
    if (t.isEmpty || RegExp(r'S\d+\s*[._\- ]?\s*E\d+', caseSensitive: false).hasMatch(t)) return _epLabel(i, season);
    return t;
  }

  String _epImage(int i, [int? season]) {
    final list = _epsOf(season ?? _season);
    if (i >= 0 && i < list.length) {
      final info = list[i]['info'];
      final img = info is Map ? '${info['movie_image'] ?? info['cover_big'] ?? ''}' : '';
      if (img.isNotEmpty) return img;
    }
    return '${_root['_series_cover'] ?? _root['cover'] ?? _root['stream_icon'] ?? _root['movie_image'] ?? ''}';
  }

  String _plot() {
    final it = _item is Map ? _item as Map : const {};
    final info = it['info'];
    for (final v in [it['plot'], info is Map ? info['plot'] : null, it['description'], it['overview'],
        _root['plot'], _root['overview']]) {
      final s = '${v ?? ''}'.trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return '';
  }

  Future<void> _loadMarkers() async {
    final m = await SkipMarkers.fetch(_seriesId);
    if (mounted && m != null) setState(() => _marks = m);
  }

  Future<void> _goEpisode(int season, int i, {bool auto = false}) async {
    final list = _epsOf(season);
    if (i < 0 || i >= list.length) return;
    if (auto) {
      _autoChain++;
      if (_autoChain >= 3) {
        // ★ «هل ما زلت تشاهد؟» بعد 3 حلقات متتالية بلا أي لمس
        _nextAc.stop();
        _e?.pause();
        setState(() { _askStill = (season, i); _userPaused = true; _nextShown = false; });
        return;
      }
    }
    _saveProgress(force: true);
    _nextAc.stop();
    final ep = list[i];
    List<String> urls = const [];
    try { urls = Api.episodeUrls(ep); } catch (_) {}
    final m = Map<String, dynamic>.from(ep as Map);
    if (_seriesName.isNotEmpty) {
      m['name'] = '$_seriesName — الحلقة ${_epNum(ep, i)}';
      m['_series_id'] = _seriesId;
      m['_series_name'] = _seriesName;
      if ('${_root['_series_cover'] ?? ''}'.isNotEmpty) m['_series_cover'] = _root['_series_cover'];
    }
    setState(() {
      _season = season;
      _eps = list;
      _ep = i;
      _item = m;
      _title = _epTitle(i, season);
      _nextShown = false; _nextDismissed = false; _introSkipped = false;
      _started = false; _resumedFrom = null; _panel = _Panel.none; _ended = false; _askStill = null;
    });
    widget.onEpisodeChanged?.call(i);
    _pos.value = Duration.zero; _dur.value = Duration.zero;
    _qi = 0; _soft = 0; _stalls = 0; _engineSwitched = false;
    _queue = _buildQueue(urls);
    if (_queue.isEmpty) { setState(() { _error = true; _err = 'لم يُعثر على رابط هذه الحلقة'; }); return; }
    _open(_queue.first, start: _resumePos());
  }

  // ══════════════════════════════════════════════════════════════
  //  القنوات (تبديل داخل نفس المشغّل)
  // ══════════════════════════════════════════════════════════════
  void _loadChannels() {
    final src = widget.channels.isNotEmpty ? widget.channels : AppState.allLive;
    _channels = src.where((c) => Sub.liveAllowed('${c['name'] ?? ''}')).toList();
  }

  int get _chIdx {
    final id = '${_item?['stream_id'] ?? ''}';
    if (id.isEmpty) return -1;
    return _channels.indexWhere((c) => '${c['stream_id'] ?? ''}' == id);
  }

  void _goChannel(dynamic ch) {
    if (ch == null) return;
    if ('${ch['stream_id'] ?? ''}' == '${_item?['stream_id'] ?? '-'}') { setState(() => _panel = _Panel.none); return; }
    final urls = Api.liveUrls(ch);
    _prevCh = _item;
    setState(() {
      _item = ch; _title = '${ch['name'] ?? ''}'; _panel = _Panel.none;
      _behind = false; _pausedAt = null; _error = false;
    });
    _qi = 0; _soft = 0; _stalls = 0; _engineSwitched = false; _stallLog.clear();
    _queue = _buildQueue(urls);
    if (_queue.isEmpty) { setState(() { _error = true; _err = 'تعذّر بناء رابط هذه القناة'; }); return; }
    HapticFeedback.selectionClick();
    final n = _chIdx;
    _flash(n >= 0 ? '${n + 1}  ·  $_title' : _title);
    _open(_queue.first);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerStrip());
  }

  void _stepChannel(int d) {
    if (_channels.isEmpty) return;
    final i = _chIdx;
    final n = ((i < 0 ? 0 : i) + d) % _channels.length;
    _goChannel(_channels[n < 0 ? n + _channels.length : n]);
  }

  void _centerStrip() {
    if (!_strip.hasClients) return;
    final i = _chIdx;
    if (i < 0) return;
    final vw = _strip.position.viewportDimension;
    final target = (i * _stripW - vw / 2 + _stripW / 2).clamp(0.0, _strip.position.maxScrollExtent);
    _strip.jumpTo(target);
  }

  void _goLive() {
    HapticFeedback.selectionClick();
    setState(() { _behind = false; _pausedAt = null; });
    _open(_queue.isEmpty ? _openedUrl : _queue[_qi]);
    _flash('عدت إلى البث المباشر');
  }

  /// جودة الاتصال: 3 ممتازة · 2 متوسطة · 1 ضعيفة
  int get _health {
    final now = DateTime.now();
    _stallLog.removeWhere((t) => now.difference(t).inSeconds > 90);
    var h = _stallLog.isEmpty ? 3 : (_stallLog.length == 1 ? 2 : 1);
    if (_buffering && _startedThis && !_userPaused) h = math.min(h, 1);
    return h;
  }

  // ══════════════════════════════════════════════════════════════
  //  التحكم
  // ══════════════════════════════════════════════════════════════
  void _schedHide() {
    _hideT?.cancel();
    if (_paused || _panel != _Panel.none || _seeking) return;
    _hideT = Timer(const Duration(milliseconds: 3800), () {
      if (mounted && !_paused && _panel == _Panel.none && !_seeking) setState(() => _ui = false);
    });
  }

  void _showUi() {
    if (!_ui) setState(() => _ui = true);
    if (widget.isLive) WidgetsBinding.instance.addPostFrameCallback((_) => _centerStrip());
    _schedHide();
  }

  void _toggleUi() {
    setState(() => _ui = !_ui);
    if (_ui) _showUi();
  }

  void _openPanel(_Panel p) {
    _hideT?.cancel();
    setState(() { _panel = p; _pauseInfo = false; });
  }

  void _closePanel() { setState(() => _panel = _Panel.none); _schedHide(); }

  void _pause() {
    _e?.pause();
    _userPaused = true;
    _setAutoPip(false);   // متوقف ⇐ لا صورة داخل صورة عند الخروج
    if (widget.isLive) _pausedAt ??= DateTime.now();
    _pauseT?.cancel();
    // ★ شاشة الإيقاف (أسلوب نتفليكس) بعد 6 ثوانٍ
    _pauseT = Timer(const Duration(seconds: 6), () {
      if (mounted && _userPaused && _started && !_ended && !_error && !_locked && _panel == _Panel.none && !_seeking) {
        setState(() { _pauseInfo = true; _ui = false; });
      }
    });
  }

  void _resume() {
    _pauseT?.cancel();
    if (widget.isLive && _pausedAt != null) {
      if (DateTime.now().difference(_pausedAt!).inSeconds > 6) _behind = true;
      _pausedAt = null;
    }
    _userPaused = false;
    _pauseInfo = false;
    _e?.play();
    _setAutoPip(true);
  }

  void _togglePlay() {
    final e = _e;
    if (e == null) return;
    _autoChain = 0;
    HapticFeedback.selectionClick();
    if (_ended) {
      e.seek(Duration.zero);
      e.play();
      setState(() { _ended = false; _userPaused = false; });
      return;
    }
    _userPaused ? _resume() : _pause();
    setState(() {});
    _showUi();
  }

  void _seekRel(Duration d) {
    final e = _e;
    if (e == null || widget.isLive) return;
    final dur = _dur.value;
    var t = _pos.value + d;
    if (t < Duration.zero) t = Duration.zero;
    if (dur > Duration.zero && t > dur) t = dur - const Duration(seconds: 1);
    e.seek(t);
    _pos.value = t;
  }

  void _seekTo(Duration t) {
    if (widget.isLive) return;
    _e?.seek(t);
    _pos.value = t;
  }

  Future<void> _setRate(double r) async {
    _rate = r;
    await _e?.setRate(r);
    _flash('السرعة ${r == 1 ? 'عادية' : '${r}x'}');
  }

  void _flash(String t) {
    if (!mounted) return;
    setState(() => _toast = t);
    _hudT?.cancel();
    _hudT = Timer(const Duration(milliseconds: 1500), () { if (mounted) setState(() => _toast = ''); });
  }

  void _setFit(BoxFit f) {
    setState(() => _fit = f);
    PlayerPrefs.setFit(const [BoxFit.contain, BoxFit.cover, BoxFit.fill].indexOf(f).clamp(0, 2));
  }

  void _cycleFit() {
    const order = [BoxFit.contain, BoxFit.cover, BoxFit.fill];
    final n = order[(order.indexOf(_fit) + 1) % order.length];
    _setFit(n);
    _flash(n == BoxFit.contain ? 'الحجم الأصلي' : n == BoxFit.cover ? 'ملء الشاشة' : 'تمديد');
  }

  Future<void> _enterPip() async {
    try {
      final ok = await _pipCh.invokeMethod('enterPiP');
      if (ok != true) _flash('صورة داخل صورة غير مدعومة على هذا الجهاز');
    } catch (_) { _flash('صورة داخل صورة غير مدعومة'); }
  }

  void _setSleep(int minutes) {
    _sleepT?.cancel();
    _sleepFadeT?.cancel();
    if (_engVol != 1) { _engVol = 1; _e?.setVolume(1); }
    setState(() => _sleepMin = minutes);
    if (minutes <= 0) { _flash('أُلغي مؤقت النوم'); return; }
    // ★ قبل النهاية بـ 12 ثانية يتلاشى الصوت تدريجياً ثم يتوقف التشغيل
    _sleepT = Timer(Duration(seconds: math.max(5, minutes * 60 - 12)), () {
      _sleepFadeT = Timer.periodic(const Duration(milliseconds: 600), (t) {
        _engVol = (_engVol - .05).clamp(0.0, 1.0);
        _e?.setVolume(_engVol);
        if (_engVol <= 0) {
          t.cancel();
          _e?.pause();
          if (mounted) Navigator.of(context).maybePop();
        }
      });
    });
    _flash('يتوقف التشغيل بعد $minutes دقيقة');
  }

  void _toggleFav() {
    final on = PlayerPrefs.toggleFav(_item);
    HapticFeedback.selectionClick();
    _flash(on ? 'أُضيفت إلى المفضلة' : 'أُزيلت من المفضلة');
  }

  void _paywall() {
    if (!mounted) return;
    _guardT?.cancel();
    _e?.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => _PaywallSheet(
        onSubscribe: () {
          Navigator.pop(sheet);
          Navigator.of(context).maybePop();
          rootNavKey.currentState?.push(PageRouteBuilder(
            pageBuilder: (_, __, ___) => const SubscriptionPage(),
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c)));
        },
        onClose: () { Navigator.pop(sheet); Navigator.of(context).maybePop(); },
      ),
    );
  }

  // ── أدوات الأدمن: علامات المقدمة والشارة للمسلسل ─────────────────
  Future<void> _saveMark(String key) async {
    final pos = _pos.value.inSeconds, dur = _dur.value.inSeconds;
    final Map<String, int> f = switch (key) {
      'intro_start' => {'intro_start': pos},
      'intro_end' => {'intro_end': pos},
      'credits_left' => {'credits_left': dur > pos ? dur - pos : 0},
      _ => {'intro_start': 0, 'intro_end': 0, 'credits_left': 0},
    };
    final ok = await SkipMarkers.save(_seriesId, f);
    if (!mounted) return;
    if (ok) {
      final m = await SkipMarkers.fetch(_seriesId);
      if (mounted) setState(() => _marks = m);
    }
    _flash(ok ? 'تم الحفظ لكل حلقات المسلسل ✓' : 'تعذّر الحفظ — تحقق من صلاحيات الأدمن');
  }

  // ── الإيماءات ──────────────────────────────────────────────────
  void _onDoubleTap(Size size) {
    if (_locked) return;
    final x = _lastDoubleTap.dx / size.width;
    if (x > .36 && x < .64) { _togglePlay(); return; }
    if (widget.isLive) return;
    _skipSide(x >= .5 ? 1 : -1);
  }

  void _skipSide(int side) {
    HapticFeedback.lightImpact();
    if (_tapSide != side) _tapSecs = 0;
    _tapSide = side;
    _tapSecs += 10;
    _seekRel(Duration(seconds: 10 * side));
    _tapT?.cancel();
    _tapT = Timer(const Duration(milliseconds: 850), () { if (mounted) setState(() { _tapSide = 0; _tapSecs = 0; }); });
    setState(() {});
  }

  void _onTapUp(TapUpDetails d, Size size) {
    _autoChain = 0;
    if (_pauseInfo) { setState(() => _pauseInfo = false); _showUi(); return; }
    if (_locked) { setState(() => _ui = !_ui); return; }
    // أثناء موجة التقديم: كل نقرة على نفس الجهة = 10 ثوانٍ إضافية (مثل يوتيوب)
    if (_tapSide != 0 && !widget.isLive) {
      final side = d.localPosition.dx / size.width >= .5 ? 1 : -1;
      if (side == _tapSide) { _skipSide(side); return; }
    }
    if (_panel != _Panel.none) { _closePanel(); return; }
    _toggleUi();
  }

  void _scaleStart(ScaleStartDetails d) {
    if (_locked) return;
    _drag = _Drag.none;
    _dragStart = d.localFocalPoint;
    _dragAcc = Offset.zero;
    _scrubFrom = _pos.value;
    _scrubTo = _pos.value;
  }

  void _scaleUpdate(ScaleUpdateDetails d, Size size) {
    if (_locked) return;
    if (d.pointerCount >= 2) {
      _drag = _Drag.zoom;
      setState(() => _zoom = d.scale.clamp(.7, 1.6));
      return;
    }
    _dragAcc += d.focalPointDelta;
    if (_drag == _Drag.none) {
      if (_dragAcc.dx.abs() > 14 && _dragAcc.dx.abs() > _dragAcc.dy.abs() && !widget.isLive && _dur.value > Duration.zero) {
        _drag = _Drag.seek;
      } else if (_dragAcc.dy.abs() > 14 && _dragAcc.dy.abs() > _dragAcc.dx.abs()) {
        _drag = _dragStart.dx < size.width / 2 ? _Drag.bright : _Drag.vol;
      } else {
        return;
      }
    }
    switch (_drag) {
      case _Drag.seek:
        // عرض الشاشة كاملاً = 120 ثانية (أو مدة المحتوى إن كانت أقصر)
        final span = math.min(_dur.value.inMilliseconds, 120000);
        final ms = (_scrubFrom.inMilliseconds + _dragAcc.dx / size.width * span)
            .clamp(0, _dur.value.inMilliseconds.toDouble()).round();
        setState(() => _scrubTo = Duration(milliseconds: ms));
        break;
      case _Drag.bright:
        _bright = (_bright - d.focalPointDelta.dy / (size.height * .7)).clamp(0.0, 1.0);
        try { ScreenBrightnessPlatform.instance.setApplicationScreenBrightness(_bright); } catch (_) {}
        setState(() {});
        break;
      case _Drag.vol:
        _vol = (_vol - d.focalPointDelta.dy / (size.height * .7)).clamp(0.0, 1.0);
        try { VolumeController.instance.setVolume(_vol); } catch (_) {}
        setState(() {});
        break;
      default:
        break;
    }
  }

  void _scaleEnd(ScaleEndDetails d) {
    if (_drag == _Drag.seek) {
      _seekTo(_scrubTo);
      HapticFeedback.selectionClick();
    } else if (_drag == _Drag.zoom) {
      final cover = _zoom > 1.08;
      final contain = _zoom < .94;
      setState(() => _zoom = 1);
      if (cover) { _setFit(BoxFit.cover); _flash('ملء الشاشة'); }
      if (contain) { _setFit(BoxFit.contain); _flash('الحجم الأصلي'); }
    }
    setState(() => _drag = _Drag.none);
  }

  static final _digitKeys = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.digit0: '0', LogicalKeyboardKey.digit1: '1', LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3', LogicalKeyboardKey.digit4: '4', LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6', LogicalKeyboardKey.digit7: '7', LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0', LogicalKeyboardKey.numpad1: '1', LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3', LogicalKeyboardKey.numpad4: '4', LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6', LogicalKeyboardKey.numpad7: '7', LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    _autoChain = 0;
    // ★ أرقام الريموت: اكتب رقم القناة مباشرة
    final dg = _digitKeys[k];
    if (dg != null && widget.isLive && _channels.isNotEmpty) {
      setState(() => _digits = (_digits + dg).length > 4 ? dg : _digits + dg);
      _digT?.cancel();
      _digT = Timer(const Duration(milliseconds: 1600), () {
        final n = int.tryParse(_digits) ?? 0;
        if (mounted) setState(() => _digits = '');
        if (n >= 1 && n <= _channels.length) { _goChannel(_channels[n - 1]); } else { _flash('لا توجد قناة بهذا الرقم'); }
      });
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.channelUp) { _stepChannel(1); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.channelDown) { _stepChannel(-1); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.mediaPlayPause || k == LogicalKeyboardKey.mediaPlay || k == LogicalKeyboardKey.mediaPause) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    // داخل اللوحات: الأسهم والاختيار للتنقّل بين العناصر
    if (_panel != _Panel.none) return KeyEventResult.ignored;
    if (_pauseInfo) { setState(() => _pauseInfo = false); _showUi(); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) {
      if (!_ui) { _showUi(); return KeyEventResult.handled; }
      // لا زر محدد ⇐ تشغيل/إيقاف · زر محدد ⇐ يُفعَّل هو
      if (node.hasPrimaryFocus) { _togglePlay(); return KeyEventResult.handled; }
      return KeyEventResult.ignored;
    }
    if (!_ui) {
      if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.mediaFastForward) {
        if (widget.isLive) { _stepChannel(1); } else { _seekRel(const Duration(seconds: 10)); _flash('+10 ثوانٍ'); }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.mediaRewind) {
        if (widget.isLive) { _stepChannel(-1); } else { _seekRel(const Duration(seconds: -10)); _flash('-10 ثوانٍ'); }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) { _showUi(); return KeyEventResult.handled; }
    }
    if (k == LogicalKeyboardKey.mediaFastForward) { _seekRel(const Duration(seconds: 30)); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.mediaRewind) { _seekRel(const Duration(seconds: -30)); return KeyEventResult.handled; }
    _schedHide();
    return KeyEventResult.ignored;
  }

  // ══════════════════════════════════════════════════════════════
  //  البناء
  // ══════════════════════════════════════════════════════════════
  Widget _video() {
    final e = _e;
    if (e == null) return const ColoredBox(color: Colors.black);
    return Transform.scale(
      scale: _zoom,
      child: e.view(
        fit: _fit,
        subStyle: T.cairo(s: PlayerPrefs.subFontSize, w: FontWeight.w700, c: Colors.white).copyWith(
          backgroundColor: PlayerPrefs.subBg ? const Color(0xA6000000) : null,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6), Shadow(color: Colors.black, blurRadius: 2)]),
        subPad: EdgeInsets.fromLTRB(24, 0, 24, _ui ? 120 : 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pip) return Scaffold(backgroundColor: Colors.black, body: Center(child: _video()));

    return PopScope(
      canPop: _panel == _Panel.none && !_locked && _askStill == null,
      onPopInvokedWithResult: (did, _) {
        if (did) return;
        if (_locked) { setState(() => _ui = true); return; }
        if (_panel != _Panel.none) { _closePanel(); return; }
        if (_askStill != null) setState(() => _askStill = null);
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: _landscape ? Colors.black : const Color(0xFF0A0A0C),
          body: LayoutBuilder(builder: (context, box) {
            final full = Size(box.maxWidth, box.maxHeight);
            return Stack(fit: StackFit.expand, children: [
              if (_landscape) _stage(full, compact: false) else _portrait(full),
              _panelView(full),
              if (_toast.isNotEmpty) _toastView(),
            ]);
          }),
        ),
      ),
    );
  }

  /// منطقة الفيديو كاملة بطبقاتها (تُستخدم في الوضعين الأفقي والعمودي)
  Widget _stage(Size size, {required bool compact}) => Stack(fit: StackFit.expand, children: [
    Positioned.fill(child: _video()),
    _watermark(),
    // ── طبقة الإيماءات ──
    Positioned.fill(child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onTapUp(d, size),
      onDoubleTapDown: (d) => _lastDoubleTap = d.localPosition,
      onDoubleTap: () => _onDoubleTap(size),
      onLongPressStart: (_) {
        if (_locked || widget.isLive || _paused) return;
        HapticFeedback.mediumImpact();
        _e?.setRate(2.0);
        setState(() => _boost = true);
      },
      onLongPressEnd: (_) {
        if (!_boost) return;
        _e?.setRate(_rate);
        setState(() => _boost = false);
      },
      onScaleStart: _scaleStart,
      onScaleUpdate: (d) => _scaleUpdate(d, size),
      onScaleEnd: _scaleEnd,
    )),
    if (_tapSide != 0) _ripple(size),
    _hud(),
    if (!_started && !_error) _splash(compact),
    if (_buffering && _started && !_error && !_userPaused) _spinner(),
    if (_pauseInfo && !_error) _pauseScreen(compact),
    if (!_locked && !_pauseInfo) _controls(size, compact),
    if (_locked) _lockBadge(),
    if (_resumedFrom != null && _ui && !_locked && !compact) _resumeChip(),
    if (_isSeries && !_introSkipped && !_locked && _started && !widget.isLive && !_pauseInfo) _skipIntro(compact),
    if (_nextShown && !_nextDismissed && _hasNext && !compact) _nextCard(),
    if (_digits.isNotEmpty) _digitsView(),
    if (_askStill != null) _stillWatching(),
    if (_error) _errorView(compact),
  ]);

  // ── الوضع العمودي: فيديو في الأعلى وتحته المعلومات والقوائم ─────────
  Widget _portrait(Size full) {
    final w = full.width;
    final h = w * 9 / 16;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(children: [
        ColoredBox(color: Colors.black, child: SafeArea(bottom: false, child: SizedBox(
          width: w, height: h,
          child: Directionality(textDirection: TextDirection.ltr, child: _stage(Size(w, h), compact: true)),
        ))),
        Expanded(child: _portraitInfo()),
      ]),
    );
  }

  Widget _portraitInfo() {
    final sub = _subtitleLine();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
        Text(_isSeries ? _seriesName : _title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: T.cairo(s: 19, w: FontWeight.w900, c: Colors.white)),
        if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
            child: Text(sub, style: T.cairo(s: 13.5, w: FontWeight.w600, c: _pDim))),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _actions(compact: true))),
        if (!_isSeries && !widget.isLive && _plot().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_plot(), style: T.cairo(s: 13.5, w: FontWeight.w500, c: _pDim, h: 1.6)),
        ],
        if (_isSeries) ...[
          const SizedBox(height: 14),
          _seasonChips(),
          for (int i = 0; i < _epsOf(_shownSeason).length; i++) _episodeTile(i),
        ],
        if (widget.isLive && _channels.isNotEmpty) ...[
          const SizedBox(height: 14),
          _chTabs(),
          const SizedBox(height: 6),
          for (final ch in _chList().take(300)) _channelTile(ch),
        ],
      ],
    );
  }

  String _subtitleLine() {
    if (_isSeries) {
      final s = widget.seasons.length > 1 ? 'الموسم $_season · ' : '';
      final t = _epTitle(_ep);
      final l = _epLabel(_ep);
      return '$s$l${t != l ? ' — $t' : ''}';
    }
    if (widget.isLive) {
      final n = _chIdx;
      return n >= 0 ? 'القناة ${n + 1}' : '';
    }
    return '';
  }

  // ── العلامة المائية ────────────────────────────────────────────
  Widget _watermark() {
    const al = [Alignment(.9, -.82), Alignment(-.9, .78), Alignment(.9, .78), Alignment(-.9, -.82)];
    return IgnorePointer(child: AnimatedAlign(
      duration: const Duration(milliseconds: 900), curve: Curves.easeInOut,
      alignment: al[_wm],
      child: Opacity(opacity: .16, child: Text('TOTV+', textDirection: TextDirection.ltr,
          style: TExtra.cinzel(s: 12, c: Colors.white).copyWith(letterSpacing: 3, fontWeight: FontWeight.w700))),
    ));
  }

  // ── بداية التشغيل: بوستر مموّه + عنوان ─────────────────────────
  Widget _splash(bool compact) {
    final it = _item;
    String img = '';
    if (it != null) {
      final info = it['info'];
      img = '${it['cover'] ?? it['stream_icon'] ?? it['movie_image'] ?? (info is Map ? info['movie_image'] ?? '' : '')}';
      if (!img.startsWith('http')) img = _epImage(_ep);
    }
    return Positioned.fill(child: IgnorePointer(child: Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Colors.black),
      if (img.startsWith('http'))
        Opacity(opacity: .35, child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, memCacheWidth: 300,
              errorWidget: (_, __, ___) => const SizedBox()))),
      Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_isSeries ? _seriesName : _title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: _pt(compact ? 17 : 22, w: FontWeight.w900)),
          if (_isSeries) Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(_subtitleLine(), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _pt(compact ? 12 : 14, c: _pDim))),
          SizedBox(height: compact ? 14 : 22),
          SizedBox(width: 170, child: ClipRRect(borderRadius: BorderRadius.circular(2),
              child: const LinearProgressIndicator(minHeight: 2.5, color: Colors.white, backgroundColor: _pFaint))),
          const SizedBox(height: 12),
          Text(_hint.isNotEmpty ? _hint : (widget.isLive ? 'جاري الاتصال بالبث…' : 'جاري التحميل…'),
              style: _pt(13, c: _pDim, w: FontWeight.w500)),
        ]),
      )),
    ])));
  }

  Widget _spinner() => IgnorePointer(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const SizedBox(width: 46, height: 46, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
    if (_hint.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_hint, style: _pt(13, c: _pDim))),
  ])));

  // ── شاشة الإيقاف المؤقت (أسلوب نتفليكس) ────────────────────────
  Widget _pauseScreen(bool compact) {
    final plot = _plot();
    return Positioned.fill(child: IgnorePointer(child: AnimatedOpacity(
      opacity: 1, duration: const Duration(milliseconds: 400),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerRight, end: Alignment.centerLeft,
          colors: [Color(0xE6000000), Color(0x99000000), Color(0x33000000)])),
        child: SafeArea(child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 18 : 48, 0, compact ? 18 : 48, 0),
          child: Directionality(textDirection: TextDirection.rtl, child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('أنت تشاهد', style: _pt(compact ? 12 : 14, c: _pDim, w: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_isSeries ? _seriesName : _title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: _pt(compact ? 20 : 32, w: FontWeight.w900, h: 1.2)),
                if (_subtitleLine().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text(_subtitleLine(), style: _pt(compact ? 13 : 16, w: FontWeight.w700))),
                if (plot.isNotEmpty && !compact) Padding(padding: const EdgeInsets.only(top: 12),
                    child: Text(plot, maxLines: 4, overflow: TextOverflow.ellipsis,
                        style: _pt(14.5, c: _pDim, w: FontWeight.w500, h: 1.6))),
                SizedBox(height: compact ? 10 : 22),
                Text('متوقف مؤقتاً', style: _pt(compact ? 12 : 14, c: _pDim, w: FontWeight.w700)),
              ])),
          )),
        )),
      ),
    )));
  }

  // ── موجة النقر المزدوج ─────────────────────────────────────────
  Widget _ripple(Size size) {
    final fwd = _tapSide > 0;
    return Positioned(
      top: 0, bottom: 0,
      left: fwd ? null : 0, right: fwd ? 0 : null,
      width: size.width * .42,
      child: IgnorePointer(child: ClipPath(
        clipper: _ArcClipper(right: fwd),
        child: Container(
          color: const Color(0x1FFFFFFF),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _ArrowsAnim(forward: fwd),
            const SizedBox(height: 6),
            Text('$_tapSecs ثانية', style: _pt(15, w: FontWeight.w800)),
          ]),
        ),
      )),
    );
  }

  // ── مؤشرات السحب والسرعة ───────────────────────────────────────
  Widget _hud() {
    Widget? child;
    if (_drag == _Drag.seek) {
      final diff = _scrubTo - _scrubFrom;
      child = _glass(Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${diff.isNegative ? '' : '+'}${_clock(diff)}', textDirection: TextDirection.ltr, style: _pt(30, w: FontWeight.w900)),
        const SizedBox(height: 2),
        Text('${_clock(_scrubTo)} / ${_clock(_dur.value)}', textDirection: TextDirection.ltr, style: _pt(14, c: _pDim)),
      ]), pad: const EdgeInsets.symmetric(horizontal: 26, vertical: 14));
    } else if (_drag == _Drag.bright || _drag == _Drag.vol) {
      final v = _drag == _Drag.bright ? _bright : _vol;
      final icon = _drag == _Drag.bright
          ? Icons.brightness_6_rounded
          : (v == 0 ? Icons.volume_off_rounded : v < .5 ? Icons.volume_down_rounded : Icons.volume_up_rounded);
      child = _glass(SizedBox(width: 200, child: Row(children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 12),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: v, minHeight: 5, color: Colors.white, backgroundColor: _pFaint))),
        const SizedBox(width: 10),
        SizedBox(width: 34, child: Text('${(v * 100).round()}', textAlign: TextAlign.end, style: _pt(13, w: FontWeight.w800))),
      ])), pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 12));
    }
    return Stack(children: [
      if (child != null) Center(child: IgnorePointer(child: child)),
      if (_boost) Positioned(top: 22, left: 0, right: 0, child: IgnorePointer(child: Center(child: _glass(
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('2×', textDirection: TextDirection.ltr, style: _pt(15, w: FontWeight.w900)),
          const SizedBox(width: 6),
          const Icon(Icons.fast_forward_rounded, color: Colors.white, size: 20),
        ]), pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 7))))),
    ]);
  }

  Widget _glass(Widget child, {EdgeInsets pad = const EdgeInsets.all(12), double r = 14}) => ClipRRect(
    borderRadius: BorderRadius.circular(r),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(padding: pad, decoration: BoxDecoration(color: _pGlass, borderRadius: BorderRadius.circular(r),
          border: Border.all(color: _pStroke)), child: child),
    ),
  );

  // ══════════════════════════════════════════════════════════════
  //  أدوات التحكم
  // ══════════════════════════════════════════════════════════════
  Widget _controls(Size size, bool compact) {
    final show = _ui || _paused;
    final strip = widget.isLive && _channels.length > 1 && !compact && size.height > 300;
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Stack(fit: StackFit.expand, children: [
          // تدرّجات للوضوح
          const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xB3000000), Color(0x00000000), Color(0x00000000), Color(0xD9000000)],
            stops: [0, .28, .52, 1])))),
          SafeArea(child: Padding(
            padding: EdgeInsets.fromLTRB(compact ? 6 : 14, compact ? 0 : 6, compact ? 6 : 14, compact ? 0 : 6),
            child: Column(children: [
              _topBar(compact),
              const Spacer(),
              _centerRow(compact),
              const Spacer(),
              if (widget.isLive) _liveBar(compact) else _progressRow(compact),
              if (strip) _channelStrip(),
              if (!compact) ...[
                const SizedBox(height: 2),
                Directionality(textDirection: TextDirection.rtl, child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, child: Row(children: _actions(compact: false)))),
              ],
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData i, VoidCallback? f, {double size = 26, String? tip, Color color = Colors.white}) => IconButton(
    tooltip: tip, onPressed: f == null ? null : () { f(); _schedHide(); },
    icon: Icon(i, size: size, color: color),
    splashRadius: 24,
  );

  Widget _healthBars({double h = 14}) {
    final q = _health;
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (int i = 1; i <= 3; i++) Container(
        width: 3.5, height: h * (0.4 + i * 0.2), margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: i <= q ? (q == 1 ? const Color(0xFFFFB020) : Colors.white) : _pFaint,
          borderRadius: BorderRadius.circular(1.5)),
      ),
    ]);
  }

  Widget _topBar(bool compact) => Directionality(
    textDirection: TextDirection.rtl,
    child: Row(children: [
      _iconBtn(Icons.arrow_forward_rounded, () {
        if (compact) { Navigator.of(context).maybePop(); return; }
        Navigator.of(context).maybePop();
      }, tip: 'رجوع', size: compact ? 22 : 26),
      const SizedBox(width: 4),
      Expanded(child: compact ? const SizedBox() : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(_isSeries ? _seriesName : (widget.isLive && _chIdx >= 0 ? '${_chIdx + 1}  ·  $_title' : _title),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: _pt(17, w: FontWeight.w800)),
        if (_isSeries)
          Text(_subtitleLine(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _pt(12.5, c: _pDim, w: FontWeight.w500))
        else if (widget.isLive)
          Text('بث مباشر', style: _pt(12.5, c: _pDim, w: FontWeight.w600)),
      ])),
      if (!SubCompat.isPremium && !compact) Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: _glass(Text(WatchTimer.remainingStr, textDirection: TextDirection.ltr, style: _pt(12, w: FontWeight.w800)),
            pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), r: 20),
      ),
      if (_sleepT?.isActive ?? false) const Padding(padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.bedtime_rounded, color: Colors.white, size: 18)),
      if (widget.isLive && _startedThis) GestureDetector(
        onTap: () {
          final q = _health;
          _flash('جودة الاتصال: ${q == 3 ? 'ممتازة' : q == 2 ? 'متوسطة' : 'ضعيفة — نعيد الاتصال تلقائياً'}');
        },
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _healthBars()),
      ),
      if (widget.isLive && _item != null && !compact)
        _iconBtn(PlayerPrefs.isFav(_item) ? Icons.star_rounded : Icons.star_outline_rounded,
            () { _toggleFav(); setState(() {}); }, size: 24, tip: 'المفضلة'),
      if (!compact && Plat.isAndroid) _iconBtn(Icons.picture_in_picture_alt_rounded, _enterPip, size: 23, tip: 'صورة داخل صورة'),
      _iconBtn(Icons.tune_rounded, () => _openPanel(_Panel.settings), size: compact ? 21 : 24, tip: 'الإعدادات'),
    ]),
  );

  Widget _centerRow(bool compact) {
    final big = _ended ? Icons.replay_rounded : (_paused ? Icons.play_arrow_rounded : Icons.pause_rounded);
    final d1 = compact ? 42.0 : 56.0, d2 = compact ? 58.0 : 78.0;
    final s1 = compact ? 24.0 : 30.0, s2 = compact ? 34.0 : 46.0;
    final gap = compact ? 22.0 : 34.0;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (!widget.isLive) _roundBtn(Icons.replay_10_rounded, () => _seekRel(const Duration(seconds: -10)), d1, s1),
        if (widget.isLive && _channels.length > 1) _roundBtn(Icons.skip_previous_rounded, () => _stepChannel(-1), d1, s1),
        SizedBox(width: gap),
        _roundBtn(big, _togglePlay, d2, s2, strong: true),
        SizedBox(width: gap),
        if (!widget.isLive) _roundBtn(Icons.forward_10_rounded, () => _seekRel(const Duration(seconds: 10)), d1, s1),
        if (widget.isLive && _channels.length > 1) _roundBtn(Icons.skip_next_rounded, () => _stepChannel(1), d1, s1),
      ]),
    );
  }

  Widget _roundBtn(IconData i, VoidCallback f, double d, double s, {bool strong = false}) => SizedBox(
    width: d, height: d,
    child: Material(
      color: strong ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF),
      shape: const CircleBorder(side: BorderSide(color: _pStroke)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () { f(); _schedHide(); },
        child: Center(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(i, key: ValueKey(i), color: Colors.white, size: s),
        )),
      ),
    ),
  );

  Widget _fullBtn() => _iconBtn(Icons.fullscreen_rounded, () => setState(() => _setLandscape(true)), size: 24, tip: 'ملء الشاشة');

  Widget _progressRow(bool compact) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(children: [
      ValueListenableBuilder<Duration>(valueListenable: _pos, builder: (_, p, __) => SizedBox(width: compact ? 54 : 64,
          child: Text(_clock(_seeking ? _seekPreview : p), textAlign: TextAlign.center, style: _pt(compact ? 12 : 13, w: FontWeight.w700)))),
      Expanded(child: _ProBar(
        pos: _pos, dur: _dur, buf: _buf,
        onStart: () { setState(() { _seeking = true; _seekPreview = _pos.value; }); _hideT?.cancel(); },
        onPreview: (d) => setState(() => _seekPreview = d),
        onEnd: (d) { _seekTo(d); setState(() => _seeking = false); _schedHide(); },
      )),
      GestureDetector(
        onTap: () => setState(() => _showRemain = !_showRemain),
        child: ValueListenableBuilder<Duration>(valueListenable: _pos, builder: (_, p, __) {
          final d = _dur.value;
          return SizedBox(width: compact ? 58 : 70, child: Text(_showRemain ? _clock(p - d) : _clock(d),
              textAlign: TextAlign.center, style: _pt(compact ? 12 : 13, w: FontWeight.w700, c: _pDim)));
        }),
      ),
      if (compact) _fullBtn(),
    ]),
  );

  Widget _liveBar(bool compact) => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 2 : 6),
      child: Row(children: [
        GestureDetector(
          onTap: _behind ? _goLive : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _behind ? const Color(0x33FFFFFF) : _pRed, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(
                  color: _behind ? _pDim : Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(_behind ? 'متأخر عن البث' : 'مباشر', style: _pt(12.5, w: FontWeight.w900)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        if (_behind)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: const Color(0x1FFFFFFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: _goLive,
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: Text('العودة للمباشر', style: _pt(12.5, w: FontWeight.w800)),
          )
        else
          Expanded(child: Container(height: 3, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))),
        if (_behind) const Spacer(),
        if (compact) Directionality(textDirection: TextDirection.ltr, child: _fullBtn()),
      ]),
    ),
  );

  // ── شريط القنوات السفلي (أسلوب TOD) ─────────────────────────────
  Widget _channelStrip() {
    final cur = '${_item?['stream_id'] ?? ''}';
    return SizedBox(
      height: 62,
      child: Directionality(textDirection: TextDirection.ltr, child: ListView.builder(
        controller: _strip,
        scrollDirection: Axis.horizontal,
        itemExtent: _stripW,
        itemCount: _channels.length,
        itemBuilder: (_, i) {
          final ch = _channels[i];
          final on = '${ch['stream_id'] ?? ''}' == cur;
          final logo = '${ch['stream_icon'] ?? ''}';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Material(
              color: on ? Colors.white : const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(9),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: on ? null : () { _goChannel(ch); _schedHide(); },
                child: Stack(children: [
                  Positioned.fill(child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 14),
                    child: logo.startsWith('http')
                        ? CachedNetworkImage(imageUrl: logo, fit: BoxFit.contain, memCacheWidth: 160,
                            errorWidget: (_, __, ___) => Center(child: Text('${ch['name'] ?? ''}', maxLines: 2,
                                textAlign: TextAlign.center, style: T.cairo(s: 9.5, w: FontWeight.w700, c: on ? Colors.black : Colors.white))))
                        : Center(child: Text('${ch['name'] ?? ''}', maxLines: 2, textAlign: TextAlign.center,
                            style: T.cairo(s: 9.5, w: FontWeight.w700, c: on ? Colors.black : Colors.white))),
                  )),
                  Positioned(left: 5, bottom: 2, child: Text('${i + 1}',
                      style: T.cairo(s: 9.5, w: FontWeight.w900, c: on ? Colors.black54 : _pDim))),
                ]),
              ),
            ),
          );
        },
      )),
    );
  }

  List<Widget> _actions({required bool compact}) {
    final dark = compact;   // في الوضع العمودي الأزرار على خلفية داكنة صلبة
    Widget chip(IconData i, String l, VoidCallback f) => _chipBtn(i, l, f, filled: dark);
    return [
      if (_isSeries) chip(Icons.video_library_rounded, 'الحلقات', () => _openPanel(_Panel.episodes)),
      if (_hasNext) chip(Icons.skip_next_rounded, 'الحلقة التالية', () { final n = _next; if (n != null) _goEpisode(n.$1, n.$2); }),
      if (widget.isLive && _channels.isNotEmpty && !compact) chip(Icons.live_tv_rounded, 'القنوات', () => _openPanel(_Panel.channels)),
      if (widget.isLive && _prevCh != null) chip(Icons.history_rounded, 'القناة السابقة', () => _goChannel(_prevCh)),
      if (widget.isLive && _item != null && compact) chip(PlayerPrefs.isFav(_item) ? Icons.star_rounded : Icons.star_outline_rounded,
          PlayerPrefs.isFav(_item) ? 'في المفضلة' : 'أضف للمفضلة', () { _toggleFav(); setState(() {}); }),
      if (_e?.supportsTracks ?? false) chip(Icons.subtitles_rounded, 'الصوت والترجمة', () => _openPanel(_Panel.settings)),
      if (!widget.isLive) chip(Icons.speed_rounded, _rate == 1 ? 'السرعة' : '${_rate}x', () => _openPanel(_Panel.settings)),
      if (!compact) chip(_fit == BoxFit.contain ? Icons.fit_screen_rounded : Icons.crop_free_rounded,
          _fit == BoxFit.contain ? 'ملء الشاشة' : 'الحجم الأصلي', _cycleFit),
      if (!compact) chip(Icons.lock_outline_rounded, 'قفل', () { setState(() { _locked = true; _ui = false; }); _flash('الشاشة مقفلة'); }),
      if (compact && Plat.isAndroid) chip(Icons.picture_in_picture_alt_rounded, 'صورة داخل صورة', _enterPip),
      chip(_landscape ? Icons.stay_current_portrait_rounded : Icons.stay_current_landscape_rounded,
          _landscape ? 'عمودي' : 'أفقي', () => setState(() => _setLandscape(!_landscape))),
    ];
  }

  Widget _chipBtn(IconData i, String l, VoidCallback f, {bool filled = false}) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 6),
    child: TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: Colors.white,
          backgroundColor: filled ? const Color(0xFF1A1A1F) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      onPressed: () { HapticFeedback.selectionClick(); f(); _schedHide(); },
      icon: Icon(i, size: 20, color: Colors.white),
      label: Text(l, style: _pt(13.5, w: FontWeight.w700)),
    ),
  );

  Widget _lockBadge() => AnimatedOpacity(
    opacity: _ui ? 1 : 0, duration: const Duration(milliseconds: 200),
    child: IgnorePointer(ignoring: !_ui, child: SafeArea(child: Align(
      alignment: const Alignment(0, .82),
      child: GestureDetector(
        onTap: () { setState(() { _locked = false; _ui = true; }); _flash('أُلغي القفل'); _schedHide(); },
        child: _glass(Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_open_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text('اضغط لإلغاء القفل', style: _pt(14, w: FontWeight.w700)),
        ]), pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), r: 30),
      ),
    ))),
  );

  Widget _resumeChip() => SafeArea(child: Align(
    alignment: const AlignmentDirectional(-.96, .5),
    child: Directionality(textDirection: TextDirection.rtl, child: _glass(Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.history_rounded, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Text('استكملنا من ${_clock(_resumedFrom!)}', style: _pt(13.5, w: FontWeight.w700)),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: () { _seekTo(Duration.zero); setState(() => _resumedFrom = null); },
        child: Text('من البداية', style: _pt(13.5, w: FontWeight.w900).copyWith(decoration: TextDecoration.underline,
            decorationColor: Colors.white)),
      ),
    ]), pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), r: 24)),
  ));

  Widget _skipIntro(bool compact) => ValueListenableBuilder<Duration>(
    valueListenable: _pos,
    builder: (_, p, __) {
      final s = p.inSeconds;
      final m = _marks;
      final int from, to;
      if (m != null && m.hasIntro) {
        from = m.introStart; to = m.introEnd;
      } else {
        from = 5; to = 88;     // افتراضي حين لا توجد علامات لهذا المسلسل
      }
      if (s < from || s >= to - 2 || (m == null || !m.hasIntro) && s > 100) return const SizedBox.shrink();
      return SafeArea(child: Align(
        alignment: AlignmentDirectional(-.96, compact ? .45 : .62),
        child: Directionality(textDirection: TextDirection.rtl, child: Material(
          color: Colors.white, borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () { _seekTo(Duration(seconds: to)); setState(() => _introSkipped = true); HapticFeedback.selectionClick(); },
            child: Padding(padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: compact ? 7 : 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('تخطي المقدمة', style: T.cairo(s: compact ? 12.5 : 14, w: FontWeight.w800, c: Colors.black)),
              const SizedBox(width: 6),
              Icon(Icons.skip_next_rounded, color: Colors.black, size: compact ? 18 : 20),
            ])),
          ),
        )),
      ));
    },
  );

  // ── بطاقة الحلقة التالية (بوستر + عدّاد يملأ الزر) ───────────────
  Widget _nextCard() {
    final n = _next!;
    final img = _epImage(n.$2, n.$1);
    final newSeason = n.$1 != _season;
    return SafeArea(child: Align(
      alignment: const AlignmentDirectional(-.97, .70),
      child: Directionality(textDirection: TextDirection.rtl, child: _glass(SizedBox(width: 360, child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 128, height: 72, child: Stack(fit: StackFit.expand, children: [
            img.startsWith('http')
                ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, memCacheWidth: 320,
                    errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1A1E)))
                : const ColoredBox(color: Color(0xFF1A1A1E)),
            const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30)),
          ])),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(newSeason ? 'الموسم ${n.$1} يبدأ' : 'الحلقة التالية', style: _pt(12, c: _pDim, w: FontWeight.w600)),
          Text(_epLabel(n.$2, n.$1), maxLines: 1, overflow: TextOverflow.ellipsis, style: _pt(15, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => _goEpisode(n.$1, n.$2),
              child: ClipRRect(borderRadius: BorderRadius.circular(7), child: SizedBox(height: 34, child: Stack(children: [
                const Positioned.fill(child: ColoredBox(color: Color(0x40FFFFFF))),
                Positioned.fill(child: AnimatedBuilder(animation: _nextAc, builder: (_, __) => FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart, widthFactor: _nextAc.value, heightFactor: 1,
                    child: const ColoredBox(color: Colors.white)))),
                Center(child: AnimatedBuilder(animation: _nextAc, builder: (_, __) => Text(
                    'شاهد الآن  ${(10 - _nextAc.value * 10).ceil()}',
                    style: T.cairo(s: 13, w: FontWeight.w900, c: _nextAc.value > .45 ? Colors.black : Colors.white)))),
              ]))),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () { _nextAc.stop(); setState(() => _nextDismissed = true); },
              child: Text('مشاهدة الشارة', style: _pt(12.5, c: _pDim, w: FontWeight.w700)),
            ),
          ]),
        ])),
      ])), pad: const EdgeInsets.all(10))),
    ));
  }

  // ── «هل ما زلت تشاهد؟» ───────────────────────────────────────────
  Widget _stillWatching() {
    final n = _askStill!;
    return Positioned.fill(child: ColoredBox(color: const Color(0xCC000000), child: Center(child: Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('هل ما زلت تشاهد؟', style: _pt(24, w: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('${_seriesName.isNotEmpty ? '$_seriesName · ' : ''}${_epLabel(n.$2, n.$1)}', style: _pt(14, c: _pDim)),
        const SizedBox(height: 22),
        Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 46, child: FilledButton(
            autofocus: true,
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { _autoChain = 0; setState(() => _askStill = null); _goEpisode(n.$1, n.$2); },
            child: Text('متابعة المشاهدة', style: T.cairo(s: 14.5, w: FontWeight.w900, c: Colors.black)),
          )),
          const SizedBox(width: 10),
          SizedBox(height: 46, child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: _pStroke),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('رجوع', style: _pt(14.5, w: FontWeight.w800)),
          )),
        ]),
      ])),
    ))));
  }

  Widget _digitsView() => IgnorePointer(child: Align(
    alignment: const Alignment(.9, -.75),
    child: _glass(Text(_digits, textDirection: TextDirection.ltr, style: _pt(34, w: FontWeight.w900)),
        pad: const EdgeInsets.symmetric(horizontal: 20, vertical: 6)),
  ));

  // ── الخطأ ──────────────────────────────────────────────────────
  Widget _errorView(bool compact) => Positioned.fill(child: ColoredBox(color: Colors.black, child: SafeArea(child: Center(
    child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      child: Directionality(textDirection: TextDirection.rtl, child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!compact) ...[
          Container(width: 74, height: 74, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _pStroke, width: 1.5)),
              child: const Icon(Icons.wifi_tethering_error_rounded, color: Colors.white, size: 34)),
          const SizedBox(height: 18),
        ],
        Text(_err, textAlign: TextAlign.center, style: _pt(compact ? 15 : 18, w: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(_title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: _pt(13, c: _pDim)),
        SizedBox(height: compact ? 12 : 24),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          SizedBox(height: compact ? 38 : 46, child: FilledButton.icon(
            autofocus: true,
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('إعادة المحاولة', style: T.cairo(s: 14.5, w: FontWeight.w900, c: Colors.black)),
          )),
          if (_queue.length > 1) SizedBox(height: compact ? 38 : 46, child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: _pStroke),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              _qi = (_qi + 1) % _queue.length; _soft = 0;
              _open(_queue[_qi], start: widget.isLive ? null : _pos.value);
            },
            icon: const Icon(Icons.dns_rounded, size: 18),
            label: Text('تبديل المصدر', style: _pt(14.5, w: FontWeight.w800)),
          )),
          if (widget.isLive && _channels.length > 1) SizedBox(height: compact ? 38 : 46, child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: _pStroke),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => _openPanel(_Panel.channels),
            icon: const Icon(Icons.live_tv_rounded, size: 18),
            label: Text('قناة أخرى', style: _pt(14.5, w: FontWeight.w800)),
          )),
          SizedBox(height: compact ? 38 : 46, child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: _pStroke),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('رجوع', style: _pt(14.5, w: FontWeight.w800)),
          )),
        ]),
        if (!compact) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 18, alignment: WrapAlignment.center, children: [
            TextButton(onPressed: () => rootNavKey.currentState?.push(_fade(const ChatPage())),
                child: Text('راسل الدعم', style: _pt(13.5, c: _pDim, w: FontWeight.w700))),
            TextButton(onPressed: () => ComplaintSheet.show(context),
                child: Text('تقديم شكوى', style: _pt(13.5, c: _pDim, w: FontWeight.w700))),
          ]),
        ],
      ])),
    ),
  ))));

  Widget _toastView() => IgnorePointer(child: Align(
    alignment: const Alignment(0, -.62),
    child: Directionality(textDirection: TextDirection.rtl,
        child: _glass(Text(_toast, style: _pt(14, w: FontWeight.w800)), pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 9), r: 24)),
  ));

  // ══════════════════════════════════════════════════════════════
  //  اللوحات الجانبية: الحلقات · القنوات · الإعدادات
  // ══════════════════════════════════════════════════════════════
  Widget _panelView(Size size) {
    final open = _panel != _Panel.none;
    final w = math.min(size.width * (_landscape ? .42 : .9), 440.0);
    return Stack(children: [
      if (open) Positioned.fill(child: GestureDetector(
        onTap: _closePanel,
        child: const ColoredBox(color: Color(0x66000000)))),
      AnimatedPositioned(
        duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic,
        top: 0, bottom: 0, width: w,
        right: open ? 0 : -w - 20,
        child: Directionality(textDirection: TextDirection.rtl, child: Container(
          decoration: const BoxDecoration(color: Color(0xF20A0A0C), border: Border(left: BorderSide(color: _pStroke))),
          child: SafeArea(left: false, child: FocusScope(child: switch (_panel) {
            _Panel.episodes => _episodesPanel(),
            _Panel.channels => _channelsPanel(),
            _Panel.settings => _settingsPanel(),
            _Panel.none => const SizedBox.shrink(),
          })),
        )),
      ),
    ]);
  }

  Widget _panelHead(String t, {String? sub}) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: _pt(18, w: FontWeight.w900)),
        if (sub != null) Text(sub, style: _pt(12.5, c: _pDim, w: FontWeight.w500)),
      ])),
      IconButton(onPressed: _closePanel, icon: const Icon(Icons.close_rounded, color: Colors.white)),
    ]),
  );

  // ── الحلقات والمواسم ─────────────────────────────────────────────
  int _viewSeason = -1;   // الموسم المعروض في اللوحة (قد يختلف عن الحالي)
  int get _shownSeason => _viewSeason < 0 ? _season : _viewSeason;

  Widget _seasonChips() {
    if (widget.seasons.length < 2) return const SizedBox.shrink();
    final ks = widget.seasons.keys.toList()..sort();
    return SizedBox(height: 44, child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: ks.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final s = ks[i];
        final on = s == _shownSeason;
        return ChoiceChip(
          label: Text('الموسم $s', style: T.cairo(s: 13, w: FontWeight.w800, c: on ? Colors.black : Colors.white)),
          selected: on, showCheckmark: false,
          selectedColor: Colors.white, backgroundColor: const Color(0x14FFFFFF),
          side: const BorderSide(color: _pStroke),
          onSelected: (_) => setState(() => _viewSeason = s),
        );
      },
    ));
  }

  Widget _episodeTile(int i) {
    final season = _shownSeason;
    final list = _epsOf(season);
    final on = season == _season && i == _ep;
    final img = _epImage(i, season);
    final ep = list[i];
    final id = '${ep['id'] ?? ''}';
    final info = ep['info'];
    final ds = info is Map ? int.tryParse('${info['duration_secs'] ?? ''}') ?? 0 : 0;
    final prog = id.isEmpty ? 0.0 : WatchHistory.getPercent(id, ds > 0 ? ds : 2700).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: on ? const Color(0x1FFFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: on ? null : () => _goEpisode(season, i),
          child: Padding(padding: const EdgeInsets.all(6), child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 112, height: 63, child: Stack(fit: StackFit.expand, children: [
              img.startsWith('http')
                  ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, memCacheWidth: 280,
                      errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1A1E)))
                  : const ColoredBox(color: Color(0xFF1A1A1E)),
              if (on) const ColoredBox(color: Color(0x80000000), child: Center(child: Icon(Icons.equalizer_rounded, color: Colors.white))),
              if (prog > 0.02) Align(alignment: Alignment.bottomCenter, child: LinearProgressIndicator(
                  value: prog, minHeight: 3, color: Colors.white, backgroundColor: _pFaint)),
            ]))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_epLabel(i, season), style: _pt(14.5, w: FontWeight.w800)),
              if (_epTitle(i, season) != _epLabel(i, season))
                Text(_epTitle(i, season), maxLines: 2, overflow: TextOverflow.ellipsis, style: _pt(12, c: _pDim, w: FontWeight.w500)),
              if (ds > 0) Text('${(ds / 60).round()} د', style: _pt(11.5, c: _pDim, w: FontWeight.w600)),
            ])),
          ])),
        ),
      ),
    );
  }

  Widget _episodesPanel() {
    final list = _epsOf(_shownSeason);
    return Column(children: [
      _panelHead('الحلقات', sub: widget.seasons.length > 1 ? 'الموسم $_shownSeason · ${list.length} حلقة' : '${list.length} حلقة'),
      _seasonChips(),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: list.length,
        itemBuilder: (_, i) => _episodeTile(i),
      )),
    ]);
  }

  // ── القنوات: الكل · المفضلة · الأخيرة ───────────────────────────
  List<dynamic> _chList() {
    final base = switch (_chTab) {
      1 => PlayerPrefs.resolve(PlayerPrefs.favorites),
      2 => PlayerPrefs.resolve(PlayerPrefs.recent),
      _ => _channels,
    };
    final q = _chQ.text.trim().toLowerCase();
    return q.isEmpty ? base : base.where((c) => '${c['name'] ?? ''}'.toLowerCase().contains(q)).toList();
  }

  Widget _chTabs() {
    Widget tab(int i, String l) {
      final on = _chTab == i;
      return Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: ChoiceChip(
        label: Text(l, style: T.cairo(s: 13, w: FontWeight.w800, c: on ? Colors.black : Colors.white)),
        selected: on, showCheckmark: false,
        selectedColor: Colors.white, backgroundColor: const Color(0x14FFFFFF),
        side: const BorderSide(color: _pStroke),
        onSelected: (_) => setState(() => _chTab = i),
      ));
    }
    return Row(children: [tab(0, 'الكل'), tab(1, 'المفضلة'), tab(2, 'الأخيرة')]);
  }

  Widget _channelTile(dynamic ch) {
    final cur = '${_item?['stream_id'] ?? ''}';
    final on = '${ch['stream_id'] ?? ''}' == cur;
    final logo = '${ch['stream_icon'] ?? ''}';
    final num = _channels.indexWhere((c) => '${c['stream_id'] ?? ''}' == '${ch['stream_id'] ?? ''}');
    final fav = PlayerPrefs.isFav(ch);
    return Material(
      color: on ? const Color(0x1FFFFFFF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: on ? null : () => _goChannel(ch),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Row(children: [
          SizedBox(width: 30, child: Text(num >= 0 ? '${num + 1}' : '', textAlign: TextAlign.center,
              style: _pt(12, c: _pDim, w: FontWeight.w800))),
          SizedBox(width: 54, height: 34, child: logo.startsWith('http')
              ? CachedNetworkImage(imageUrl: logo, fit: BoxFit.contain, memCacheWidth: 160,
                  errorWidget: (_, __, ___) => const Icon(Icons.live_tv_rounded, color: _pDim))
              : const Icon(Icons.live_tv_rounded, color: _pDim)),
          const SizedBox(width: 10),
          Expanded(child: Text('${ch['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr, textAlign: TextAlign.right,
              style: _pt(14, w: on ? FontWeight.w900 : FontWeight.w600))),
          if (on) const Padding(padding: EdgeInsetsDirectional.only(start: 6),
              child: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () { PlayerPrefs.toggleFav(ch); setState(() {}); },
            icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded, color: fav ? Colors.white : _pDim, size: 21),
          ),
        ])),
      ),
    );
  }

  Widget _channelsPanel() {
    final list = _chList();
    return Column(children: [
      _panelHead('القنوات المباشرة', sub: '${_channels.length} قناة'),
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8), child: TextField(
        controller: _chQ,
        onChanged: (_) => setState(() {}),
        style: _pt(14, w: FontWeight.w600),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          isDense: true, filled: true, fillColor: const Color(0x14FFFFFF),
          prefixIcon: const Icon(Icons.search_rounded, color: _pDim),
          hintText: 'ابحث عن قناة', hintStyle: _pt(13.5, c: _pDim, w: FontWeight.w500),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      )),
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 6), child: _chTabs()),
      Expanded(child: list.isEmpty
          ? Center(child: Text(_chTab == 1 ? 'اضغط ☆ بجانب أي قناة لإضافتها للمفضلة' : 'لا توجد قنوات',
              textAlign: TextAlign.center, style: _pt(13.5, c: _pDim)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              itemCount: list.length,
              itemBuilder: (_, i) => _channelTile(list[i]),
            )),
    ]);
  }

  // ── الإعدادات ────────────────────────────────────────────────────
  String _srcLabel(int i) {
    final u = _queue[i].toLowerCase();
    final kind = u.contains('.m3u8') ? 'HLS متكيّف' : u.contains('.ts') ? 'بث TS سريع'
        : u.contains('.mkv') ? 'MKV' : u.contains('.mp4') ? 'MP4' : 'رابط مباشر';
    return 'المصدر ${i + 1} · $kind';
  }

  Widget _settingsPanel() {
    final e = _e;
    final tracks = e?.supportsTracks ?? false;
    final audio = tracks ? e?.audioTracks() ?? const <EngineTrack>[] : const <EngineTrack>[];
    final subs = tracks ? e?.subtitleTracks() ?? const <EngineTrack>[] : const <EngineTrack>[];
    final vids = tracks ? e?.videoTracks() ?? const <EngineTrack>[] : const <EngineTrack>[];
    final curSub = e?.currentSubtitle;

    Widget sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Text(t, style: _pt(13, c: _pDim, w: FontWeight.w800)));
    Widget opt(String t, bool on, VoidCallback f, {IconData? icon, String? sub}) => InkWell(
      onTap: () { HapticFeedback.selectionClick(); f(); setState(() {}); },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11), child: Row(children: [
        if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 12)],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: _pt(15, w: on ? FontWeight.w900 : FontWeight.w600, c: on ? _pWhite : _pDim)),
          if (sub != null) Text(sub, style: _pt(11.5, c: _pDim, w: FontWeight.w500)),
        ])),
        if (on) const Icon(Icons.check_rounded, color: Colors.white, size: 22),
      ])),
    );
    Widget toggle(String t, bool v, ValueChanged<bool> f, {String? sub, IconData? icon}) => SwitchListTile(
      value: v, onChanged: (x) { f(x); setState(() {}); },
      activeColor: Colors.black, activeTrackColor: Colors.white,
      inactiveThumbColor: _pDim, inactiveTrackColor: const Color(0x22FFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      secondary: icon == null ? null : Icon(icon, color: Colors.white, size: 20),
      title: Text(t, style: _pt(15, w: FontWeight.w700)),
      subtitle: sub == null ? null : Text(sub, style: _pt(11.5, c: _pDim, w: FontWeight.w500)),
    );
    Widget chips<V>(List<(V, String)> items, V cur, ValueChanged<V> f) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final it in items) ChoiceChip(
          label: Text(it.$2, textDirection: TextDirection.ltr,
              style: T.cairo(s: 13.5, w: FontWeight.w800, c: cur == it.$1 ? Colors.black : Colors.white)),
          selected: cur == it.$1, showCheckmark: false,
          selectedColor: Colors.white, backgroundColor: const Color(0x14FFFFFF),
          side: const BorderSide(color: _pStroke),
          onSelected: (_) { f(it.$1); setState(() {}); },
        ),
      ]),
    );

    final isAdmin = AuthService.isAdmin;
    return Column(children: [
      _panelHead('الإعدادات', sub: _kind == EngineKind.native ? 'المحرك السلس' : 'المحرك المتقدم'),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        if (!widget.isLive) ...[
          sec('السرعة'),
          chips<double>([for (final s in _speeds) (s, s == 1 ? 'عادية' : '${s}x')], _rate, (s) => _setRate(s)),
        ],
        if (audio.length > 1) ...[
          sec('الصوت'),
          for (final t in audio) opt(t.label, e?.currentAudio == t.id, () => e?.selectAudio(t), icon: Icons.graphic_eq_rounded),
        ],
        sec('الترجمة'),
        if (tracks) ...[
          opt('إيقاف', curSub == null || curSub == 'no', () => e?.selectSubtitle(null)),
          for (final t in subs) opt(t.label, curSub == t.id, () => e?.selectSubtitle(t)),
          if (subs.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text('لا توجد ترجمة مضمّنة في هذا المحتوى', style: _pt(12.5, c: _pDim, w: FontWeight.w500))),
          sec('حجم الترجمة'),
          chips<int>(const [(0, 'صغير'), (1, 'متوسط'), (2, 'كبير')], PlayerPrefs.subSize, PlayerPrefs.setSubSize),
          toggle('خلفية خلف الترجمة', PlayerPrefs.subBg, PlayerPrefs.setSubBg),
        ] else
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Text(
              widget.isLive ? 'الترجمة غير متاحة في البث المباشر'
                  : 'الصوت والترجمة متاحان في المحرك المتقدم (أدناه)',
              style: _pt(12.5, c: _pDim, w: FontWeight.w500))),
        if (vids.length > 1) ...[
          sec('الجودة'),
          opt('تلقائي', e?.currentVideo == null || e?.currentVideo == 'auto', () => e?.selectVideo(null)),
          for (final t in vids) opt(t.label, e?.currentVideo == t.id, () => e?.selectVideo(t)),
        ],
        if (_queue.length > 1) ...[
          sec('مصدر التشغيل'),
          for (int i = 0; i < _queue.length && i < 6; i++)
            opt(_srcLabel(i), i == _qi, () {
              if (i == _qi) return;
              _qi = i;
              _open(_queue[i], start: widget.isLive ? null : _pos.value);
              setState(() => _panel = _Panel.none);
            }, icon: Icons.dns_rounded),
        ],
        sec('المحرك'),
        opt('تلقائي (موصى به)', PlayerPrefs.engine == 'auto', () {
          PlayerPrefs.setEngine('auto');
          _switchEngine(widget.isLive || ProPlayer.engineFailed ? EngineKind.native : EngineKind.mpv);
        }, icon: Icons.auto_awesome_rounded, sub: 'المباشر بالسلس · الأفلام بالمتقدم'),
        opt('السلس', PlayerPrefs.engine == 'native', () { PlayerPrefs.setEngine('native'); _switchEngine(EngineKind.native); },
            icon: Icons.bolt_rounded, sub: 'أسرع وأثبت للبث المباشر'),
        if (!ProPlayer.engineFailed)
          opt('المتقدم', PlayerPrefs.engine == 'mpv', () { PlayerPrefs.setEngine('mpv'); _switchEngine(EngineKind.mpv); },
              icon: Icons.memory_rounded, sub: 'كل الصيغ · مسارات الصوت والترجمة'),
        sec('حجم الصورة'),
        opt('الحجم الأصلي', _fit == BoxFit.contain, () => _setFit(BoxFit.contain), icon: Icons.fit_screen_rounded),
        opt('ملء الشاشة', _fit == BoxFit.cover, () => _setFit(BoxFit.cover), icon: Icons.crop_free_rounded),
        opt('تمديد', _fit == BoxFit.fill, () => _setFit(BoxFit.fill), icon: Icons.aspect_ratio_rounded),
        sec('عام'),
        toggle('توفير البيانات', PlayerPrefs.dataSaver, PlayerPrefs.setDataSaver, icon: Icons.data_saver_on_rounded,
            sub: 'جودة أقل حين يوفّر البث أكثر من جودة'),
        if (Plat.isAndroid) toggle('صورة داخل صورة تلقائياً', PlayerPrefs.autoPip, (v) { PlayerPrefs.setAutoPip(v); _setAutoPip(true); },
            icon: Icons.picture_in_picture_alt_rounded, sub: 'عند الخروج من التطبيق أثناء المشاهدة'),
        sec('مؤقت النوم'),
        for (final m in const [0, 15, 30, 45, 60, 90])
          opt(m == 0 ? 'إيقاف' : '$m دقيقة', m == 0 ? !(_sleepT?.isActive ?? false) && !(_sleepFadeT?.isActive ?? false)
              : _sleepMin == m && ((_sleepT?.isActive ?? false) || (_sleepFadeT?.isActive ?? false)),
              () => _setSleep(m), icon: m == 0 ? Icons.bedtime_off_rounded : Icons.bedtime_rounded),
        if (isAdmin && _isSeries && _seriesId.isNotEmpty) ...[
          sec('أدوات الأدمن — علامات المسلسل (لكل الحلقات)'),
          if (_marks != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Text(
              'المقدمة: ${_clock(Duration(seconds: _marks!.introStart))} ← ${_clock(Duration(seconds: _marks!.introEnd))}'
              '  ·  الشارة: آخر ${_marks!.creditsLeft} ث',
              textDirection: TextDirection.rtl, style: _pt(12, c: _pDim, w: FontWeight.w600))),
          opt('بداية المقدمة = الموضع الحالي', false, () => _saveMark('intro_start'), icon: Icons.first_page_rounded),
          opt('نهاية المقدمة = الموضع الحالي', false, () => _saveMark('intro_end'), icon: Icons.last_page_rounded),
          opt('بداية الشارة = الموضع الحالي', false, () => _saveMark('credits_left'), icon: Icons.movie_filter_rounded),
          opt('مسح العلامات', false, () => _saveMark('clear'), icon: Icons.delete_outline_rounded),
        ],
      ])),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
//  شريط التقدّم الاحترافي
// ════════════════════════════════════════════════════════════════════
class _ProBar extends StatefulWidget {
  final ValueNotifier<Duration> pos, dur, buf;
  final VoidCallback onStart;
  final ValueChanged<Duration> onPreview, onEnd;
  const _ProBar({required this.pos, required this.dur, required this.buf,
      required this.onStart, required this.onPreview, required this.onEnd});
  @override
  State<_ProBar> createState() => _ProBarState();
}

class _ProBarState extends State<_ProBar> {
  bool _drag = false;
  double _f = 0;

  double _frac(Duration d) {
    final t = widget.dur.value.inMilliseconds;
    return t <= 0 ? 0 : (d.inMilliseconds / t).clamp(0.0, 1.0);
  }

  Duration _at(double f) => Duration(milliseconds: (widget.dur.value.inMilliseconds * f).round());

  void _set(double dx, double w, {bool end = false}) {
    _f = (dx / w).clamp(0.0, 1.0);
    if (end) {
      widget.onEnd(_at(_f));
    } else {
      widget.onPreview(_at(_f));
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
    final w = box.maxWidth;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (d) { setState(() => _drag = true); widget.onStart(); _set(d.localPosition.dx, w); },
      onHorizontalDragUpdate: (d) { setState(() {}); _set(d.localPosition.dx, w); },
      onHorizontalDragEnd: (_) { setState(() => _drag = false); widget.onEnd(_at(_f)); },
      onTapDown: (d) { widget.onStart(); setState(() { _drag = true; _f = (d.localPosition.dx / w).clamp(0.0, 1.0); }); },
      onTapUp: (d) { setState(() => _drag = false); _set(d.localPosition.dx, w, end: true); },
      onTapCancel: () => setState(() => _drag = false),
      child: SizedBox(
        height: 40,
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.pos, widget.buf, widget.dur]),
          builder: (_, __) {
            final played = _drag ? _f : _frac(widget.pos.value);
            final bufd = _frac(widget.buf.value);
            return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              CustomPaint(size: Size(w, 40), painter: _BarPainter(played, bufd, _drag)),
              if (_drag) Positioned(
                left: (played * w - 34).clamp(0.0, math.max(0.0, w - 68)), bottom: 34,
                child: Container(
                  width: 68, padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
                  child: Text(_clock(_at(played)), textAlign: TextAlign.center, textDirection: TextDirection.ltr,
                      style: T.cairo(s: 13, w: FontWeight.w900, c: Colors.black)),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  });
}

class _BarPainter extends CustomPainter {
  final double played, buffered;
  final bool active;
  _BarPainter(this.played, this.buffered, this.active);

  @override
  void paint(Canvas c, Size s) {
    final h = active ? 6.0 : 3.5;
    final y = s.height / 2;
    final r = Radius.circular(h);
    RRect bar(double to) => RRect.fromLTRBR(0, y - h / 2, s.width * to, y + h / 2, r);
    c.drawRRect(bar(1), Paint()..color = const Color(0x40FFFFFF));
    if (buffered > 0) c.drawRRect(bar(buffered), Paint()..color = const Color(0x73FFFFFF));
    c.drawRRect(bar(played), Paint()..color = Colors.white);
    final x = s.width * played;
    c.drawCircle(Offset(x, y), active ? 9 : 6.5, Paint()..color = Colors.white);
    if (active) c.drawCircle(Offset(x, y), 17, Paint()..color = const Color(0x33FFFFFF));
  }

  @override
  bool shouldRepaint(_BarPainter o) => o.played != played || o.buffered != buffered || o.active != active;
}

// ── قوس موجة النقر المزدوج ──────────────────────────────────────────
class _ArcClipper extends CustomClipper<Path> {
  final bool right;
  _ArcClipper({required this.right});
  @override
  Path getClip(Size s) {
    final p = Path();
    if (right) {
      p.moveTo(s.width, 0);
      p.lineTo(s.width * .22, 0);
      p.quadraticBezierTo(-s.width * .12, s.height / 2, s.width * .22, s.height);
      p.lineTo(s.width, s.height);
    } else {
      p.moveTo(0, 0);
      p.lineTo(s.width * .78, 0);
      p.quadraticBezierTo(s.width * 1.12, s.height / 2, s.width * .78, s.height);
      p.lineTo(0, s.height);
    }
    p.close();
    return p;
  }

  @override
  bool shouldReclip(_ArcClipper o) => o.right != right;
}

/// ثلاثة أسهم تتوهج بالتتابع (مثل يوتيوب)
class _ArrowsAnim extends StatefulWidget {
  final bool forward;
  const _ArrowsAnim({required this.forward});
  @override
  State<_ArrowsAnim> createState() => _ArrowsAnimState();
}

class _ArrowsAnimState extends State<_ArrowsAnim> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..repeat();
  @override
  void dispose() { _a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) {
      final step = (_a.value * 3).floor();
      final items = List.generate(3, (i) => Icon(
        Icons.play_arrow_rounded,
        size: 26,
        color: Colors.white.withOpacity(i == step ? 1 : .35),
      ));
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..scale(widget.forward ? 1.0 : -1.0, 1.0),
          child: Row(mainAxisSize: MainAxisSize.min, children: items),
        ),
      );
    },
  );
}
