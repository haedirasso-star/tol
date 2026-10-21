part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════
//  TOTV+ Pro Player (2027)
//  ─────────────────────────────────────────────────────────────────
//  المحرك: libmpv (media_kit) — فك تشفير بالمعالج الرسومي، كل الصيغ
//  (TS · MKV · HLS · MP4)، تقديم سريع، مسارات صوت وترجمة، إعادة اتصال
//  تلقائية على مستوى الشبكة (FFmpeg reconnect) قبل أن يلاحظ المستخدم.
//
//  التجربة:
//   • نقرتان يميناً/يساراً ±10 ثوانٍ (تتراكم) · وسط = تشغيل/إيقاف
//   • ضغطة مطوّلة = ×2 · سحب أفقي = تمرير دقيق بفقاعة الوقت
//   • سحب عمودي: يسار السطوع · يمين الصوت · قرص بإصبعين = ملء الشاشة
//   • شريط تقدّم احترافي (المحمَّل مسبقاً + فقاعة الوقت + لمس سهل)
//   • استكمال تلقائي + «من البداية» · تخطي المقدمة · الحلقة التالية ببوستر
//     وعدّاد · قائمة الحلقات والقنوات داخل المشغّل · صوت/ترجمة/سرعة/مؤقت نوم
//   • تبديل الحلقة/القناة داخل نفس المشغّل (بلا إعادة بناء) = أسرع بكثير
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
  const PlayerPage({super.key, required this.urls, required this.title, this.isLive = false, this.item,
      this.episodes = const [], this.episodeIndex = 0, this.onEpisodeChanged});

  static bool get useLegacy => RC.playerEngine == 'legacy' || ProPlayer.engineFailed;

  @override
  Widget build(BuildContext context) => useLegacy
      ? LegacyPlayerPage(urls: urls, title: title, isLive: isLive, item: item,
          episodes: episodes, episodeIndex: episodeIndex, onEpisodeChanged: onEpisodeChanged)
      : ProPlayer(urls: urls, title: title, isLive: isLive, item: item,
          episodes: episodes, episodeIndex: episodeIndex, onEpisodeChanged: onEpisodeChanged);
}

class ProPlayer extends StatefulWidget {
  final List<String> urls;
  final String title;
  final bool isLive;
  final dynamic item;
  final List<dynamic> episodes;
  final int episodeIndex;
  final void Function(int)? onEpisodeChanged;
  const ProPlayer({super.key, required this.urls, required this.title, this.isLive = false, this.item,
      this.episodes = const [], this.episodeIndex = 0, this.onEpisodeChanged});

  /// يُضبط في main() إن فشل تحميل مكتبة التشغيل ⇐ المشغّل القديم تلقائياً
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
  mk.Player? _p;
  mkv.VideoController? _vc;
  final List<StreamSubscription> _subs = [];
  final _pos = ValueNotifier<Duration>(Duration.zero);
  final _dur = ValueNotifier<Duration>(Duration.zero);
  final _buf = ValueNotifier<Duration>(Duration.zero);
  bool _playing = false, _buffering = true, _started = false, _startedThis = false, _ended = false;
  bool _error = false, _failing = false;
  String _err = '', _hint = '';

  // ── المصادر ────────────────────────────────────────────────────
  List<String> _queue = [];
  int _qi = 0, _soft = 0, _stalls = 0;
  String _openedUrl = '';
  Timer? _watchdog, _stallT, _progT, _guardT, _hideT, _wmT, _sleepT, _resumeT, _tapT, _hudT;

  // ── المحتوى الحالي (يتغيّر عند تبديل الحلقة/القناة) ──────────────
  late int _ep = widget.episodeIndex;
  late dynamic _item = widget.item;
  late String _title = widget.title;
  List<dynamic> _channels = [];

  // ── الواجهة ────────────────────────────────────────────────────
  bool _ui = true, _locked = false, _pip = false, _landscape = true, _showRemain = false;
  _Panel _panel = _Panel.none;
  BoxFit _fit = BoxFit.contain;
  double _zoom = 1, _rate = 1, _bright = .5, _vol = .7;
  bool _boost = false;            // ضغطة مطوّلة ×2
  int _wm = 0;
  Duration? _resumedFrom;
  bool _introSkipped = false;
  String _toast = '';

  // ── الإيماءات ──────────────────────────────────────────────────
  _Drag _drag = _Drag.none;
  Offset _dragStart = Offset.zero, _dragAcc = Offset.zero;
  Duration _scrubFrom = Duration.zero, _scrubTo = Duration.zero;
  int _tapSide = 0, _tapSecs = 0;
  Offset _lastDoubleTap = Offset.zero;
  bool _seeking = false;          // سحب شريط التقدّم
  Duration _seekPreview = Duration.zero;

  // ── الحلقة التالية ──────────────────────────────────────────────
  bool _nextShown = false, _nextDismissed = false;
  late final AnimationController _nextAc = AnimationController(vsync: this, duration: const Duration(seconds: 10))
    ..addStatusListener((s) { if (s == AnimationStatus.completed) _goEpisode(_ep + 1); });

  static const _pipCh = MethodChannel('totv_pip');
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  String get _cid {
    final it = _item;
    if (it == null) return '';
    return '${it['stream_id'] ?? it['id'] ?? it['series_id'] ?? ''}';
  }

  bool get _hasNext => !widget.isLive && widget.episodes.isNotEmpty && _ep + 1 < widget.episodes.length;
  bool get _isSeries => widget.episodes.isNotEmpty;

  // ══════════════════════════════════════════════════════════════
  //  دورة الحياة
  // ══════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setLandscape(true);
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
    if (!SubCompat.isPremium) {
      try { await WatchTimer.load(); } catch (_) {}
      _guardT = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && !SubCompat.isPremium && WatchTimer.isExpired) _paywall();
      });
    }
    WatchTimer.startPlayback();
    try {
      await _createEngine();
    } catch (e) {
      debugPrint('[pro_player] engine: $e');
      ProPlayer.engineFailed = true;
      if (mounted) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          pageBuilder: (_, __, ___) => LegacyPlayerPage(urls: widget.urls, title: widget.title, isLive: widget.isLive,
              item: widget.item, episodes: widget.episodes, episodeIndex: widget.episodeIndex,
              onEpisodeChanged: widget.onEpisodeChanged),
          transitionDuration: Duration.zero));
      }
      return;
    }
    if (widget.isLive) _loadChannels();
    _queue = _buildQueue(widget.urls);
    if (_queue.isEmpty) {
      setState(() { _error = true; _err = 'لم يُعثر على رابط تشغيل'; });
      return;
    }
    _open(_queue.first, start: _resumePos());
  }

  Future<void> _createEngine() async {
    final p = mk.Player(configuration: mk.PlayerConfiguration(
      title: widget.title,
      bufferSize: widget.isLive ? 32 * 1024 * 1024 : 96 * 1024 * 1024,
      logLevel: mk.MPVLogLevel.warn,
    ));
    _p = p;
    _vc = mkv.VideoController(p, configuration: const mkv.VideoControllerConfiguration(enableHardwareAcceleration: true));
    final np = p.platform;
    if (np is mk.NativePlayer) {
      final props = <String, String>{
        'network-timeout': '20',
        // ★ إعادة اتصال تلقائية من داخل FFmpeg: الانقطاع القصير لا يوقف الصورة
        'stream-lavf-o': 'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=4',
        'cache': 'yes',
        'cache-secs': widget.isLive ? '12' : '120',
        'demuxer-readahead-secs': widget.isLive ? '8' : '60',
        'tls-verify': 'no',
        'keep-open': 'yes',
        if (widget.isLive) 'demuxer-lavf-o': 'probesize=2000000,analyzeduration=2000000',
      };
      for (final e in props.entries) {
        try { await np.setProperty(e.key, e.value); } catch (_) {}
      }
    }
    _subs.addAll([
      p.stream.playing.listen((v) { _playing = v; _ended = false; _refresh(); if (v) _schedHide(); }),
      p.stream.buffering.listen(_onBuffering),
      p.stream.position.listen(_onTick),
      p.stream.duration.listen((v) => _dur.value = v),
      p.stream.buffer.listen((v) => _buf.value = v),
      p.stream.completed.listen((v) { if (v) _onCompleted(); }),
      p.stream.error.listen(_onError),
      p.stream.tracks.listen((_) => _refresh()),
      p.stream.width.listen((w) { if ((w ?? 0) > 0) _onStarted(); }),
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveProgress(force: true);
    for (final t in [_watchdog, _stallT, _progT, _guardT, _hideT, _wmT, _sleepT, _resumeT, _tapT, _hudT]) { t?.cancel(); }
    for (final s in _subs) { s.cancel(); }
    _nextAc.dispose();
    _chQ.dispose();
    _p?.dispose();
    _pos.dispose(); _dur.dispose(); _buf.dispose();
    WatchTimer.stopPlayback();
    final uid = AuthService.currentUser?.uid;
    if (uid != null) unawaited(GuestSession.stopPlayback(uid));
    if (!kIsWeb) _pipCh.setMethodCallHandler(null);
    try { ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness(); } catch (_) {}
    SecurityLayer.disableScreenRecord();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused && !_pip) { _p?.pause(); _saveProgress(force: true); }
  }

  void _refresh() { if (mounted) setState(() {}); }

  void _setLandscape(bool on) {
    _landscape = on;
    SystemChrome.setPreferredOrientations(on
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
  }

  // ══════════════════════════════════════════════════════════════
  //  المصادر والتشغيل
  // ══════════════════════════════════════════════════════════════
  List<String> _buildQueue(List<String> urls) {
    final out = <String>[];
    void add(String u) { if (u.trim().isNotEmpty && !out.contains(u)) out.add(u); }
    final cached = _cid.isEmpty ? null : PlayUrlCache.get(_cid);
    if (cached != null) add(cached);
    if (widget.isLive && urls.length > 1) add(LiveLoadBalancer.pickBest(urls));
    for (final u in urls) { add(u); }
    for (final u in _candidates()) { add(u); }
    return out;
  }

  /// كل روابط التشغيل الممكنة من بيانات السيرفر (احتياط)
  List<String> _candidates() {
    final it = _item;
    final id = '${it?['stream_id'] ?? it?['id'] ?? ''}';
    if (id.isEmpty) return const [];
    final useTotv = SubCompat.isTOTV && SubCompat.xtreamUser.isNotEmpty;
    final base = (useTotv ? SubCompat.xtreamBase : RCCompat.serverUrl).replaceAll(RegExp(r'/+$'), '');
    final user = useTotv ? SubCompat.xtreamUser : RCCompat.username;
    final pass = useTotv ? SubCompat.xtreamPass : RCCompat.password;
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
    final p = _p;
    if (p == null || !mounted) return;
    _openedUrl = url;
    _startedThis = false;
    _failing = false;
    _stallT?.cancel();
    setState(() { _error = false; _buffering = true; _ended = false; });
    _watchdog?.cancel();
    _watchdog = Timer(Duration(seconds: widget.isLive ? 18 : 25), () {
      if (mounted && !_startedThis) _fail('timeout');
    });
    try {
      await p.open(mk.Media(url, httpHeaders: SecurityLayer.streamHeaders(isLive: widget.isLive), start: start), play: true);
      if (_rate != 1) await p.setRate(_rate);
      if (start != null && !_started) {
        _resumedFrom = start;
        _resumeT?.cancel();
        _resumeT = Timer(const Duration(seconds: 8), () { if (mounted) setState(() => _resumedFrom = null); });
      }
    } catch (e) {
      _fail('$e');
    }
  }

  void _onStarted() {
    if (_startedThis || !mounted) return;
    _startedThis = true;
    _watchdog?.cancel();
    _soft = 0; _stalls = 0; _hint = '';
    if (_cid.isNotEmpty && _openedUrl.isNotEmpty) PlayUrlCache.put(_cid, _openedUrl);
    if (!_started) {
      _started = true;
      HapticFeedback.lightImpact();
    }
    if (_item != null) WatchHistory.addItem(_item, widget.isLive ? 'live' : 'movie');
    _progT?.cancel();
    _progT = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
    _schedHide();
    _refresh();
  }

  void _onError(String e) {
    debugPrint('[pro_player] mpv: $e');
    if (!_startedThis) _fail(e);
  }

  void _onBuffering(bool v) {
    _buffering = v;
    _stallT?.cancel();
    if (v && _startedThis && _playing) {
      // تقطيع طويل ⇐ إعادة فتح نفس المصدر من نفس الموضع، ثم مصدر بديل
      _stallT = Timer(Duration(seconds: widget.isLive ? 12 : 20), () {
        if (!mounted || !_buffering) return;
        _stalls++;
        if (_stalls >= 2 && _qi + 1 < _queue.length) {
          _qi++;
          _hint = 'تبديل إلى سيرفر أسرع…';
        } else {
          _hint = 'إعادة الاتصال…';
        }
        _open(_queue[_qi], start: widget.isLive ? null : _pos.value);
      });
    }
    _refresh();
  }

  bool _transient(String r) {
    final l = r.toLowerCase();
    return l.contains('timeout') || l.contains('socket') || l.contains('connection') || l.contains('reset') ||
        l.contains('502') || l.contains('503') || l.contains('504') || l.contains('network');
  }

  void _fail(String r) {
    if (!mounted || _failing) return;
    _failing = true;
    _watchdog?.cancel();
    try { LiveLoadBalancer.markFail(Uri.parse(_openedUrl).host); } catch (_) {}
    if (_cid.isNotEmpty && PlayUrlCache.get(_cid) == _openedUrl) PlayUrlCache.put(_cid, '');
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
    if (widget.isLive && Sub.hasServer) ChannelReport.add(widget.title, _cid, r);
  }

  void _retry() {
    _qi = 0; _soft = 0; _stalls = 0;
    if (_queue.isEmpty) _queue = _buildQueue(widget.urls);
    if (_queue.isEmpty) return;
    _open(_queue.first, start: widget.isLive ? null : (_pos.value > Duration.zero ? _pos.value : _resumePos()));
  }

  void _onTick(Duration pos) {
    _pos.value = pos;
    // بثّ صوتي بلا صورة: الموضع يتقدّم ⇐ بدأ التشغيل فعلاً
    if (!_startedThis && pos > const Duration(milliseconds: 400)) _onStarted();
    if (widget.isLive || !_startedThis) return;
    final dur = _dur.value;
    // الحلقة التالية: قبل النهاية بـ 25 ثانية
    if (_hasNext && !_nextShown && !_nextDismissed && dur.inSeconds > 90 && (dur - pos).inSeconds <= 25) {
      _nextShown = true;
      _nextAc.forward(from: 0);
      _refresh();
    }
  }

  void _onCompleted() {
    _saveProgress(force: true);
    if (_hasNext && !_nextDismissed) { _goEpisode(_ep + 1); return; }
    setState(() { _ended = true; _ui = true; });
  }

  void _saveProgress({bool force = false}) {
    if (widget.isLive || _cid.isEmpty || !_started) return;
    final pos = _pos.value.inSeconds, dur = _dur.value.inSeconds;
    if (dur <= 0 || (!force && !_playing)) return;
    if (pos > 5) WatchHistory.saveProgress(_cid, pos, dur);
  }

  // ══════════════════════════════════════════════════════════════
  //  الحلقات والقنوات (تبديل داخل نفس المشغّل)
  // ══════════════════════════════════════════════════════════════
  String _epLabel(int i) {
    final ep = widget.episodes[i];
    final n = '${ep['episode_num'] ?? (i + 1)}';
    return 'الحلقة $n';
  }

  String _epTitle(int i) {
    final ep = widget.episodes[i];
    final t = '${ep['title'] ?? ''}'.trim();
    return t.isEmpty ? _epLabel(i) : t;
  }

  String _epImage(int i) {
    final ep = widget.episodes[i];
    final info = ep['info'];
    final img = info is Map ? '${info['movie_image'] ?? info['cover_big'] ?? ''}' : '';
    if (img.isNotEmpty) return img;
    final it = widget.item;
    return it == null ? '' : '${it['cover'] ?? it['stream_icon'] ?? it['movie_image'] ?? ''}';
  }

  Future<void> _goEpisode(int i) async {
    if (i < 0 || i >= widget.episodes.length) return;
    _saveProgress(force: true);
    _nextAc.stop();
    List<String> urls = const [];
    try { urls = Api.episodeUrls(widget.episodes[i]); } catch (_) {}
    setState(() {
      _ep = i;
      _item = widget.episodes[i];
      _title = _epTitle(i);
      _nextShown = false; _nextDismissed = false; _introSkipped = false;
      _started = false; _resumedFrom = null; _panel = _Panel.none; _ended = false;
    });
    widget.onEpisodeChanged?.call(i);
    _pos.value = Duration.zero; _dur.value = Duration.zero;
    _qi = 0; _soft = 0;
    _queue = _buildQueue(urls);
    if (_queue.isEmpty) { setState(() { _error = true; _err = 'لم يُعثر على رابط هذه الحلقة'; }); return; }
    _open(_queue.first, start: _resumePos());
  }

  void _loadChannels() {
    _channels = AppState.allLive.where((c) => Sub.liveAllowed('${c['name'] ?? ''}')).toList();
  }

  int get _chIdx {
    final id = '${_item?['stream_id'] ?? ''}';
    if (id.isEmpty) return -1;
    return _channels.indexWhere((c) => '${c['stream_id'] ?? ''}' == id);
  }

  void _goChannel(dynamic ch) {
    if (ch == null) return;
    setState(() {
      _item = ch; _title = '${ch['name'] ?? ''}'; _panel = _Panel.none; _started = false;
    });
    _qi = 0; _soft = 0;
    _queue = _buildQueue(Api.liveUrls(ch));
    if (_queue.isEmpty) return;
    HapticFeedback.selectionClick();
    _open(_queue.first);
  }

  void _stepChannel(int d) {
    if (_channels.isEmpty) return;
    final i = _chIdx;
    final n = ((i < 0 ? 0 : i) + d) % _channels.length;
    _goChannel(_channels[n < 0 ? n + _channels.length : n]);
  }

  // ══════════════════════════════════════════════════════════════
  //  التحكم
  // ══════════════════════════════════════════════════════════════
  void _schedHide() {
    _hideT?.cancel();
    if (!_playing || _panel != _Panel.none || _seeking) return;
    _hideT = Timer(const Duration(milliseconds: 3800), () {
      if (mounted && _playing && _panel == _Panel.none && !_seeking) setState(() => _ui = false);
    });
  }

  void _showUi() { if (!_ui) setState(() => _ui = true); _schedHide(); }
  void _toggleUi() { setState(() => _ui = !_ui); if (_ui) _schedHide(); }

  void _togglePlay() {
    final p = _p;
    if (p == null) return;
    HapticFeedback.selectionClick();
    if (_ended) { p.seek(Duration.zero); p.play(); setState(() => _ended = false); return; }
    p.playOrPause();
    _showUi();
  }

  void _seekRel(Duration d) {
    final p = _p;
    if (p == null || widget.isLive) return;
    final dur = _dur.value;
    var t = _pos.value + d;
    if (t < Duration.zero) t = Duration.zero;
    if (dur > Duration.zero && t > dur) t = dur - const Duration(seconds: 1);
    p.seek(t);
    _pos.value = t;
  }

  void _seekTo(Duration t) {
    if (widget.isLive) return;
    _p?.seek(t);
    _pos.value = t;
  }

  Future<void> _setRate(double r) async {
    _rate = r;
    await _p?.setRate(r);
    _flash('السرعة ${r == 1 ? 'عادية' : '${r}x'}');
  }

  void _flash(String t) {
    setState(() => _toast = t);
    _hudT?.cancel();
    _hudT = Timer(const Duration(milliseconds: 1400), () { if (mounted) setState(() => _toast = ''); });
  }

  void _cycleFit() {
    const order = [BoxFit.contain, BoxFit.cover, BoxFit.fill];
    final n = order[(order.indexOf(_fit) + 1) % order.length];
    setState(() => _fit = n);
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
    if (minutes <= 0) { _flash('أُلغي مؤقت النوم'); setState(() {}); return; }
    _sleepT = Timer(Duration(minutes: minutes), () {
      _p?.pause();
      if (mounted) Navigator.of(context).maybePop();
    });
    _flash('يتوقف التشغيل بعد $minutes دقيقة');
  }

  void _paywall() {
    if (!mounted) return;
    _guardT?.cancel();
    _p?.pause();
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
    if (_locked) { setState(() => _ui = !_ui); return; }
    // أثناء موجة التقديم: كل نقرة على نفس الجهة = 10 ثوانٍ إضافية (مثل يوتيوب)
    if (_tapSide != 0 && !widget.isLive) {
      final side = d.localPosition.dx / size.width >= .5 ? 1 : -1;
      if (side == _tapSide) { _skipSide(side); return; }
    }
    if (_panel != _Panel.none) { setState(() => _panel = _Panel.none); _schedHide(); return; }
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
      setState(() {
        if (cover) _fit = BoxFit.cover;
        if (contain) _fit = BoxFit.contain;
        _zoom = 1;
      });
      if (cover) _flash('ملء الشاشة');
      if (contain) _flash('الحجم الأصلي');
    }
    setState(() => _drag = _Drag.none);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.mediaPlayPause || k == LogicalKeyboardKey.mediaPlay || k == LogicalKeyboardKey.mediaPause) {
      if (!_ui && k != LogicalKeyboardKey.mediaPlayPause) { _showUi(); return KeyEventResult.handled; }
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.mediaFastForward) {
      if (widget.isLive) { _stepChannel(1); } else { _seekRel(const Duration(seconds: 10)); _showUi(); }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.mediaRewind) {
      if (widget.isLive) { _stepChannel(-1); } else { _seekRel(const Duration(seconds: -10)); _showUi(); }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.channelUp) { _stepChannel(1); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.channelDown) { _stepChannel(-1); return KeyEventResult.handled; }
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) { _showUi(); return KeyEventResult.handled; }
    return KeyEventResult.ignored;
  }

  // ══════════════════════════════════════════════════════════════
  //  البناء
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final vc = _vc;
    final video = vc == null ? const SizedBox.shrink() : Transform.scale(
      scale: _zoom,
      child: mkv.Video(
        controller: vc,
        controls: mkv.NoVideoControls,
        fit: _fit,
        fill: Colors.black,
        wakelock: true,
        pauseUponEnteringBackgroundMode: false,
        subtitleViewConfiguration: mkv.SubtitleViewConfiguration(
          style: T.cairo(s: 22, w: FontWeight.w700, c: Colors.white).copyWith(
            shadows: const [Shadow(color: Colors.black, blurRadius: 6), Shadow(color: Colors.black, blurRadius: 2)]),
          padding: EdgeInsets.fromLTRB(24, 0, 24, _ui ? 120 : 36),
        ),
      ),
    );

    if (_pip) return Scaffold(backgroundColor: Colors.black, body: Center(child: video));

    return PopScope(
      canPop: _panel == _Panel.none && !_locked,
      onPopInvokedWithResult: (did, _) {
        if (did) return;
        if (_locked) { setState(() => _ui = true); return; }
        setState(() => _panel = _Panel.none);
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return Stack(fit: StackFit.expand, children: [
              Positioned.fill(child: video),
              _watermark(),
              // ── طبقة الإيماءات ──
              Positioned.fill(child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onTapUp(d, size),
                onDoubleTapDown: (d) => _lastDoubleTap = d.localPosition,
                onDoubleTap: () => _onDoubleTap(size),
                onLongPressStart: (_) {
                  if (_locked || widget.isLive || !_playing) return;
                  HapticFeedback.mediumImpact();
                  _p?.setRate(2.0);
                  setState(() => _boost = true);
                },
                onLongPressEnd: (_) {
                  if (!_boost) return;
                  _p?.setRate(_rate);
                  setState(() => _boost = false);
                },
                onScaleStart: _scaleStart,
                onScaleUpdate: (d) => _scaleUpdate(d, size),
                onScaleEnd: _scaleEnd,
              )),
              if (_tapSide != 0) _ripple(size),
              _hud(),
              if (!_started && !_error) _splash(),
              if (_buffering && _started && !_error) _spinner(),
              if (!_locked) _controls(size),
              if (_locked) _lockBadge(),
              if (_resumedFrom != null && _ui && !_locked) _resumeChip(),
              if (_isSeries && !_introSkipped && !_locked && _started && !widget.isLive) _skipIntro(),
              if (_nextShown && !_nextDismissed && _hasNext) _nextCard(),
              if (_error) _errorView(),
              _panelView(size),
              if (_toast.isNotEmpty) _toastView(),
            ]);
          }),
        ),
      ),
    );
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
  Widget _splash() {
    final it = _item;
    String img = '';
    if (it != null) {
      final info = it['info'];
      img = '${it['cover'] ?? it['stream_icon'] ?? it['movie_image'] ?? (info is Map ? info['movie_image'] ?? '' : '')}';
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
          Text(_title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: _pt(22, w: FontWeight.w900)),
          if (_isSeries) Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(_epLabel(_ep), style: _pt(14, c: _pDim))),
          const SizedBox(height: 22),
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
  Widget _controls(Size size) {
    final show = _ui || !_playing || _ended;
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
            stops: [0, .28, .58, 1])))),
          SafeArea(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Column(children: [
              _topBar(),
              const Spacer(),
              _centerRow(),
              const Spacer(),
              if (widget.isLive) _liveBar() else _progressRow(),
              const SizedBox(height: 4),
              _actionsRow(),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData i, VoidCallback? f, {double size = 26, String? tip}) => IconButton(
    tooltip: tip, onPressed: f == null ? null : () { f(); _schedHide(); },
    icon: Icon(i, size: size, color: Colors.white),
    splashRadius: 24,
  );

  Widget _topBar() => Directionality(
    textDirection: TextDirection.rtl,
    child: Row(children: [
      _iconBtn(Icons.arrow_forward_rounded, () => Navigator.of(context).maybePop(), tip: 'رجوع'),
      const SizedBox(width: 4),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _pt(17, w: FontWeight.w800)),
        if (_isSeries)
          Text('${_epLabel(_ep)} من ${widget.episodes.length}', style: _pt(12.5, c: _pDim, w: FontWeight.w500))
        else if (widget.isLive)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('مباشر', style: _pt(12.5, w: FontWeight.w700)),
          ]),
      ])),
      if (!SubCompat.isPremium) Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: _glass(Text(WatchTimer.remainingStr, textDirection: TextDirection.ltr, style: _pt(12, w: FontWeight.w800)),
            pad: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), r: 20),
      ),
      if (_sleepT?.isActive ?? false) const Padding(padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.bedtime_rounded, color: Colors.white, size: 18)),
      _iconBtn(Icons.picture_in_picture_alt_rounded, _enterPip, size: 23, tip: 'صورة داخل صورة'),
      _iconBtn(Icons.tune_rounded, () => setState(() => _panel = _Panel.settings), size: 24, tip: 'الإعدادات'),
    ]),
  );

  Widget _centerRow() {
    final big = _ended ? Icons.replay_rounded : (_playing ? Icons.pause_rounded : Icons.play_arrow_rounded);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (!widget.isLive) _roundBtn(Icons.replay_10_rounded, () => _seekRel(const Duration(seconds: -10)), 56, 30),
        if (widget.isLive && _channels.length > 1) _roundBtn(Icons.skip_previous_rounded, () => _stepChannel(-1), 56, 30),
        const SizedBox(width: 34),
        _roundBtn(big, _togglePlay, 78, 46, strong: true),
        const SizedBox(width: 34),
        if (!widget.isLive) _roundBtn(Icons.forward_10_rounded, () => _seekRel(const Duration(seconds: 10)), 56, 30),
        if (widget.isLive && _channels.length > 1) _roundBtn(Icons.skip_next_rounded, () => _stepChannel(1), 56, 30),
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

  Widget _progressRow() => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(children: [
      ValueListenableBuilder<Duration>(valueListenable: _pos, builder: (_, p, __) => SizedBox(width: 64,
          child: Text(_clock(_seeking ? _seekPreview : p), textAlign: TextAlign.center, style: _pt(13, w: FontWeight.w700)))),
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
          return SizedBox(width: 70, child: Text(_showRemain ? _clock(p - d) : _clock(d),
              textAlign: TextAlign.center, style: _pt(13, w: FontWeight.w700, c: _pDim)));
        }),
      ),
    ]),
  );

  Widget _liveBar() => Directionality(
    textDirection: TextDirection.rtl,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(6)),
          child: Text('مباشر', style: _pt(12.5, w: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 3, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))),
      ]),
    ),
  );

  Widget _actionsRow() => Directionality(
    textDirection: TextDirection.rtl,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        if (_isSeries) _chipBtn(Icons.video_library_rounded, 'الحلقات', () => setState(() => _panel = _Panel.episodes)),
        if (_hasNext) _chipBtn(Icons.skip_next_rounded, 'الحلقة التالية', () => _goEpisode(_ep + 1)),
        if (widget.isLive && _channels.isNotEmpty) _chipBtn(Icons.live_tv_rounded, 'القنوات', () => setState(() => _panel = _Panel.channels)),
        _chipBtn(Icons.subtitles_rounded, 'الصوت والترجمة', () => setState(() => _panel = _Panel.settings)),
        if (!widget.isLive) _chipBtn(Icons.speed_rounded, _rate == 1 ? 'السرعة' : '${_rate}x', () => setState(() => _panel = _Panel.settings)),
        _chipBtn(_fit == BoxFit.contain ? Icons.fit_screen_rounded : Icons.crop_free_rounded,
            _fit == BoxFit.contain ? 'ملء الشاشة' : 'الحجم الأصلي', _cycleFit),
        _chipBtn(Icons.lock_outline_rounded, 'قفل', () { setState(() { _locked = true; _ui = false; }); _flash('الشاشة مقفلة'); }),
        _chipBtn(_landscape ? Icons.stay_current_portrait_rounded : Icons.stay_current_landscape_rounded,
            _landscape ? 'عمودي' : 'أفقي', () => setState(() => _setLandscape(!_landscape))),
      ]),
    ),
  );

  Widget _chipBtn(IconData i, String l, VoidCallback f) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 4),
    child: TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    alignment: const AlignmentDirectional(-.96, .55),
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

  Widget _skipIntro() => ValueListenableBuilder<Duration>(
    valueListenable: _pos,
    builder: (_, p, __) {
      final s = p.inSeconds;
      if (s < 5 || s > 100) return const SizedBox.shrink();
      return SafeArea(child: Align(
        alignment: const AlignmentDirectional(-.96, .62),
        child: Directionality(textDirection: TextDirection.rtl, child: Material(
          color: Colors.white, borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () { _seekTo(const Duration(seconds: 88)); setState(() => _introSkipped = true); HapticFeedback.selectionClick(); },
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('تخطي المقدمة', style: T.cairo(s: 14, w: FontWeight.w800, c: Colors.black)),
              const SizedBox(width: 6),
              const Icon(Icons.skip_next_rounded, color: Colors.black, size: 20),
            ])),
          ),
        )),
      ));
    },
  );

  // ── بطاقة الحلقة التالية (بوستر + عدّاد يملأ الزر) ───────────────
  Widget _nextCard() {
    final n = _ep + 1;
    final img = _epImage(n);
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
          Text('الحلقة التالية', style: _pt(12, c: _pDim, w: FontWeight.w600)),
          Text(_epLabel(n), maxLines: 1, overflow: TextOverflow.ellipsis, style: _pt(15, w: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => _goEpisode(n),
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
              child: Text('إلغاء', style: _pt(13, c: _pDim, w: FontWeight.w700)),
            ),
          ]),
        ])),
      ])), pad: const EdgeInsets.all(10))),
    ));
  }

  // ── الخطأ ──────────────────────────────────────────────────────
  Widget _errorView() => Positioned.fill(child: ColoredBox(color: Colors.black, child: SafeArea(child: Center(child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 36),
    child: Directionality(textDirection: TextDirection.rtl, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 74, height: 74, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _pStroke, width: 1.5)),
          child: const Icon(Icons.wifi_tethering_error_rounded, color: Colors.white, size: 34)),
      const SizedBox(height: 18),
      Text(_err, textAlign: TextAlign.center, style: _pt(18, w: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(_title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: _pt(13, c: _pDim)),
      const SizedBox(height: 24),
      Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(height: 46, child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: _retry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text('إعادة المحاولة', style: T.cairo(s: 14.5, w: FontWeight.w900, c: Colors.black)),
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
      const SizedBox(height: 14),
      Wrap(spacing: 18, alignment: WrapAlignment.center, children: [
        TextButton(onPressed: () => rootNavKey.currentState?.push(_fade(const ChatPage())),
            child: Text('راسل الدعم', style: _pt(13.5, c: _pDim, w: FontWeight.w700))),
        TextButton(onPressed: () => ComplaintSheet.show(context),
            child: Text('تقديم شكوى', style: _pt(13.5, c: _pDim, w: FontWeight.w700))),
      ]),
    ])),
  )))));

  Widget _toastView() => IgnorePointer(child: Align(
    alignment: const Alignment(0, -.62),
    child: _glass(Text(_toast, style: _pt(14, w: FontWeight.w800)), pad: const EdgeInsets.symmetric(horizontal: 18, vertical: 9), r: 24),
  ));

  // ══════════════════════════════════════════════════════════════
  //  اللوحات الجانبية: الحلقات · القنوات · الإعدادات
  // ══════════════════════════════════════════════════════════════
  Widget _panelView(Size size) {
    final open = _panel != _Panel.none;
    final w = math.min(size.width * (_landscape ? .42 : .9), 420.0);
    return Stack(children: [
      if (open) Positioned.fill(child: GestureDetector(
        onTap: () { setState(() => _panel = _Panel.none); _schedHide(); },
        child: const ColoredBox(color: Color(0x66000000)))),
      AnimatedPositioned(
        duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic,
        top: 0, bottom: 0, width: w,
        right: open ? 0 : -w - 20,
        child: Directionality(textDirection: TextDirection.rtl, child: Container(
          decoration: const BoxDecoration(color: Color(0xF20A0A0C), border: Border(left: BorderSide(color: _pStroke))),
          child: SafeArea(left: false, child: switch (_panel) {
            _Panel.episodes => _episodesPanel(),
            _Panel.channels => _channelsPanel(),
            _Panel.settings => _settingsPanel(),
            _Panel.none => const SizedBox.shrink(),
          }),
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
      IconButton(onPressed: () { setState(() => _panel = _Panel.none); _schedHide(); },
          icon: const Icon(Icons.close_rounded, color: Colors.white)),
    ]),
  );

  Widget _episodesPanel() => Column(children: [
    _panelHead('الحلقات', sub: '${widget.episodes.length} حلقة'),
    Expanded(child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: widget.episodes.length,
      itemBuilder: (_, i) {
        final on = i == _ep;
        final img = _epImage(i);
        final id = '${widget.episodes[i]['id'] ?? ''}';
        final prog = id.isEmpty ? 0.0 : WatchHistory.getPercent(id, 3600).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: on ? const Color(0x1FFFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: on ? null : () => _goEpisode(i),
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
                  Text(_epLabel(i), style: _pt(14.5, w: FontWeight.w800)),
                  Text(_epTitle(i), maxLines: 2, overflow: TextOverflow.ellipsis, style: _pt(12, c: _pDim, w: FontWeight.w500)),
                ])),
              ])),
            ),
          ),
        );
      },
    )),
  ]);

  final _chQ = TextEditingController();
  Widget _channelsPanel() {
    final q = _chQ.text.trim().toLowerCase();
    final list = q.isEmpty ? _channels : _channels.where((c) => '${c['name'] ?? ''}'.toLowerCase().contains(q)).toList();
    final cur = '${_item?['stream_id'] ?? ''}';
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
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final ch = list[i];
          final on = '${ch['stream_id'] ?? ''}' == cur;
          final logo = '${ch['stream_icon'] ?? ''}';
          return Material(
            color: on ? const Color(0x1FFFFFFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: on ? null : () => _goChannel(ch),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), child: Row(children: [
                SizedBox(width: 54, height: 34, child: logo.startsWith('http')
                    ? CachedNetworkImage(imageUrl: logo, fit: BoxFit.contain, memCacheWidth: 160,
                        errorWidget: (_, __, ___) => const Icon(Icons.live_tv_rounded, color: _pDim))
                    : const Icon(Icons.live_tv_rounded, color: _pDim)),
                const SizedBox(width: 12),
                Expanded(child: Text('${ch['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr, textAlign: TextAlign.right,
                    style: _pt(14, w: on ? FontWeight.w900 : FontWeight.w600))),
                if (on) const Padding(padding: EdgeInsetsDirectional.only(start: 8),
                    child: Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18)),
              ])),
            ),
          );
        },
      )),
    ]);
  }

  Widget _settingsPanel() {
    final p = _p;
    final tracks = p?.state.tracks;
    final cur = p?.state.track;
    final audio = (tracks?.audio ?? const <mk.AudioTrack>[]).where((t) => t.id != 'auto' && t.id != 'no').toList();
    final subs = (tracks?.subtitle ?? const <mk.SubtitleTrack>[]).where((t) => t.id != 'auto' && t.id != 'no').toList();
    final vids = (tracks?.video ?? const <mk.VideoTrack>[]).where((t) => t.id != 'auto' && t.id != 'no').toList();

    String label(String? title, String? lang, String id) {
      final l = <String>[if ((title ?? '').isNotEmpty) title!, if ((lang ?? '').isNotEmpty) _langAr(lang!)];
      return l.isEmpty ? 'مسار $id' : l.join(' · ');
    }

    Widget sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Text(t, style: _pt(13, c: _pDim, w: FontWeight.w800)));
    Widget opt(String t, bool on, VoidCallback f, {IconData? icon}) => InkWell(
      onTap: () { HapticFeedback.selectionClick(); f(); setState(() {}); },
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11), child: Row(children: [
        if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 12)],
        Expanded(child: Text(t, style: _pt(15, w: on ? FontWeight.w900 : FontWeight.w600, c: on ? _pWhite : _pDim))),
        if (on) const Icon(Icons.check_rounded, color: Colors.white, size: 22),
      ])),
    );

    return Column(children: [
      _panelHead('الإعدادات'),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        if (!widget.isLive) ...[
          sec('السرعة'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _speeds) ChoiceChip(
              label: Text(s == 1 ? 'عادية' : '${s}x', textDirection: TextDirection.ltr,
                  style: T.cairo(s: 13.5, w: FontWeight.w800, c: _rate == s ? Colors.black : Colors.white)),
              selected: _rate == s, showCheckmark: false,
              selectedColor: Colors.white, backgroundColor: const Color(0x14FFFFFF),
              side: const BorderSide(color: _pStroke),
              onSelected: (_) => _setRate(s).then((_) => setState(() {})),
            ),
          ])),
        ],
        if (audio.length > 1) ...[
          sec('الصوت'),
          for (final t in audio) opt(label(t.title, t.language, t.id), cur?.audio.id == t.id, () => p?.setAudioTrack(t)),
        ],
        sec('الترجمة'),
        opt('إيقاف', cur == null || cur.subtitle.id == 'no', () => p?.setSubtitleTrack(mk.SubtitleTrack.no())),
        for (final t in subs) opt(label(t.title, t.language, t.id), cur?.subtitle.id == t.id, () => p?.setSubtitleTrack(t)),
        if (subs.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text('لا توجد ترجمة مضمّنة في هذا المحتوى', style: _pt(12.5, c: _pDim, w: FontWeight.w500))),
        if (vids.length > 1) ...[
          sec('الجودة'),
          opt('تلقائي', cur == null || cur.video.id == 'auto', () => p?.setVideoTrack(mk.VideoTrack.auto())),
          for (final t in vids) opt((t.h ?? 0) > 0 ? '${t.h}p' : label(t.title, t.language, t.id),
              cur?.video.id == t.id, () => p?.setVideoTrack(t)),
        ],
        if (_queue.length > 1) ...[
          sec('مصدر التشغيل'),
          for (int i = 0; i < _queue.length && i < 6; i++)
            opt('السيرفر ${i + 1}${i == _qi ? ' (الحالي)' : ''}', i == _qi, () {
              if (i == _qi) return;
              _qi = i;
              _open(_queue[i], start: widget.isLive ? null : _pos.value);
              setState(() => _panel = _Panel.none);
            }, icon: Icons.dns_rounded),
        ],
        sec('حجم الصورة'),
        opt('الحجم الأصلي', _fit == BoxFit.contain, () => setState(() => _fit = BoxFit.contain), icon: Icons.fit_screen_rounded),
        opt('ملء الشاشة', _fit == BoxFit.cover, () => setState(() => _fit = BoxFit.cover), icon: Icons.crop_free_rounded),
        opt('تمديد', _fit == BoxFit.fill, () => setState(() => _fit = BoxFit.fill), icon: Icons.aspect_ratio_rounded),
        sec('مؤقت النوم'),
        for (final m in const [0, 15, 30, 60, 90])
          opt(m == 0 ? 'إيقاف' : '$m دقيقة', m == 0 ? !(_sleepT?.isActive ?? false) : false, () => _setSleep(m),
              icon: m == 0 ? Icons.bedtime_off_rounded : Icons.bedtime_rounded),
      ])),
    ]);
  }

  static String _langAr(String l) => switch (l.toLowerCase()) {
        'ara' || 'ar' => 'العربية',
        'eng' || 'en' => 'الإنجليزية',
        'fre' || 'fra' || 'fr' => 'الفرنسية',
        'tur' || 'tr' => 'التركية',
        'spa' || 'es' => 'الإسبانية',
        'ger' || 'deu' || 'de' => 'الألمانية',
        'hin' || 'hi' => 'الهندية',
        'kor' || 'ko' => 'الكورية',
        'jpn' || 'ja' => 'اليابانية',
        'per' || 'fas' || 'fa' => 'الفارسية',
        _ => l,
      };
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
                left: (played * w - 34).clamp(0.0, w - 68), bottom: 34,
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
        widget.forward ? Icons.play_arrow_rounded : Icons.play_arrow_rounded,
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
