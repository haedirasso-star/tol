part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════
//  TOTV+ Player Engines (v3.4)
//  ─────────────────────────────────────────────────────────────────
//  واجهة واحدة فوق محرّكين — نفس تصميم المشغّل الاحترافي مهما كان المحرك:
//
//   • NativeEngine  (ExoPlayer عبر video_player)
//       الأسلس للبث المباشر (HLS / TS) — نفس محرك متصفح Chrome على أندرويد.
//       يدير «حافة البث» بنفسه فلا تقطيع ولا تعليق. يحتفظ بآخر صورة أثناء
//       تبديل القناة (زاب فوري بلا شاشة سوداء).
//
//   • MpvEngine     (libmpv عبر media_kit)
//       للأفلام والمسلسلات: كل الصيغ (MKV / AVI / AC3 / DTS)، مسارات صوت
//       وترجمة متعددة، اختيار الجودة.
//
//  الاختيار تلقائي (مباشر ⇐ Native · أفلام ⇐ mpv) ويمكن فرضه من الإعدادات
//  أو من الإدارة (player_engine = native | mpv | legacy).
//  إن فشل محرك في كل المصادر ⇐ ينتقل المشغّل تلقائياً للمحرك الآخر.
// ════════════════════════════════════════════════════════════════════

enum EngineKind { native, mpv }

class EngineTrack {
  final String id;
  final String label;
  final Object raw;
  const EngineTrack(this.id, this.label, this.raw);
}

abstract class PlayerEngine {
  EngineKind get kind;

  // ── الأحداث (يضبطها المشغّل) ─────────────────────────────────────
  void Function(bool playing)? onPlaying;
  void Function(bool buffering)? onBuffering;
  void Function(Duration pos)? onPosition;
  void Function(Duration dur)? onDuration;
  void Function(Duration buf)? onBuffer;
  VoidCallback? onCompleted;
  void Function(String error)? onError;
  VoidCallback? onFirstFrame;
  VoidCallback? onTracks;
  VoidCallback? onSurface;          // تغيّر سطح العرض (تبديل المتحكم) ⇐ إعادة بناء

  Future<void> init();
  Future<void> open(String url, {Duration? start, required bool live, bool dataSaver = false});
  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration t);
  Future<void> setRate(double r);
  /// 0..1 — صوت المشغّل نفسه (للتلاشي التدريجي في مؤقت النوم)
  Future<void> setVolume(double v);
  bool get playing;

  bool get supportsTracks;
  List<EngineTrack> audioTracks() => const [];
  List<EngineTrack> subtitleTracks() => const [];
  List<EngineTrack> videoTracks() => const [];
  String? get currentAudio => null;
  String? get currentSubtitle => null;   // null أو 'no' = إيقاف
  String? get currentVideo => null;      // null أو 'auto' = تلقائي
  Future<void> selectAudio(EngineTrack t) async {}
  Future<void> selectSubtitle(EngineTrack? t) async {}
  Future<void> selectVideo(EngineTrack? t) async {}

  Widget view({required BoxFit fit, required TextStyle subStyle, required EdgeInsets subPad});
  Future<void> dispose();

  static PlayerEngine create(EngineKind k, {required String title, required bool live}) =>
      k == EngineKind.native ? NativeEngine() : MpvEngine(title: title, live: live);
}

// ════════════════════════════════════════════════════════════════════
//  NativeEngine — ExoPlayer
// ════════════════════════════════════════════════════════════════════
class NativeEngine extends PlayerEngine {
  @override EngineKind get kind => EngineKind.native;

  VideoPlayerController? _c;
  int _gen = 0;
  bool _live = false;
  bool _p = false, _b = false, _first = false, _done = false, _errSent = false;
  Duration _d = Duration.zero;
  double _rate = 1, _vol = 1;

  @override Future<void> init() async {}

  @override
  Future<void> open(String url, {Duration? start, required bool live, bool dataSaver = false}) async {
    final gen = ++_gen;
    _live = live;
    // ★ الزاب الفوري: نوقف القديم (تبقى آخر صورة ظاهرة) حتى يجهز الجديد
    //   ونفصل مستمعه فوراً كي لا يُنسب أي خطأ منه إلى المصدر الجديد
    _c?.removeListener(_onValue);
    try { await _c?.pause(); } catch (_) {}
    final lower = url.toLowerCase();
    final c = VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: lower.contains('.m3u8') ? VideoFormat.hls : null,
      httpHeaders: SecurityLayer.streamHeaders(isLive: live),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    try {
      await c.initialize();
    } catch (e) {
      try { await c.dispose(); } catch (_) {}
      if (gen == _gen) onError?.call('$e');
      return;
    }
    if (gen != _gen) { try { await c.dispose(); } catch (_) {} return; }

    final old = _c;
    old?.removeListener(_onValue);
    _c = c;
    _p = false; _b = false; _first = false; _done = false; _errSent = false; _d = Duration.zero;
    c.addListener(_onValue);
    try {
      await c.setVolume(_vol);
      if (_rate != 1 && !live) await c.setPlaybackSpeed(_rate);
      if (start != null && !live && start > Duration.zero) await c.seekTo(start);
      await c.play();
    } catch (e) {
      if (gen == _gen) onError?.call('$e');
    }
    onSurface?.call();
    if (old != null) {
      // نؤجّل التخلص قليلاً كي لا تومض الشاشة أثناء تبديل السطح
      Future.delayed(const Duration(milliseconds: 250), () { try { old.dispose(); } catch (_) {} });
    }
  }

  void _onValue() {
    final c = _c;
    if (c == null) return;
    final v = c.value;
    if (v.hasError) {
      if (!_errSent) { _errSent = true; onError?.call(v.errorDescription ?? 'playback error'); }
      return;
    }
    if (v.isPlaying != _p) { _p = v.isPlaying; onPlaying?.call(_p); }
    if (v.isBuffering != _b) { _b = v.isBuffering; onBuffering?.call(_b); }
    onPosition?.call(v.position);
    if (!_live && v.duration != _d && v.duration > Duration.zero) { _d = v.duration; onDuration?.call(_d); }
    if (v.buffered.isNotEmpty) onBuffer?.call(v.buffered.last.end);
    if (!_first && v.isInitialized && v.size.width > 0 && (v.isPlaying || v.position > Duration.zero)) {
      _first = true;
      onFirstFrame?.call();
    }
    if (!_live && !_done && _d > Duration.zero && !v.isPlaying &&
        v.position >= _d - const Duration(milliseconds: 600)) {
      _done = true;
      onCompleted?.call();
    }
  }

  @override Future<void> play() async { _done = false; await _c?.play(); }
  @override Future<void> pause() async => _c?.pause();
  @override Future<void> playOrPause() async {
    final c = _c;
    if (c == null) return;
    c.value.isPlaying ? await c.pause() : await play();
  }
  @override Future<void> seek(Duration t) async { _done = false; await _c?.seekTo(t); }
  @override Future<void> setRate(double r) async { _rate = r; if (!_live) await _c?.setPlaybackSpeed(r); }
  @override Future<void> setVolume(double v) async { _vol = v.clamp(0.0, 1.0); await _c?.setVolume(_vol); }
  @override bool get playing => _c?.value.isPlaying ?? false;
  @override bool get supportsTracks => false;

  @override
  Widget view({required BoxFit fit, required TextStyle subStyle, required EdgeInsets subPad}) {
    final c = _c;
    if (c == null || !c.value.isInitialized) return const ColoredBox(color: Colors.black);
    final s = c.value.size;
    final w = s.width > 0 ? s.width : 1920.0, h = s.height > 0 ? s.height : 1080.0;
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(child: FittedBox(
        fit: fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: w, height: h, child: VideoPlayer(c)),
      )),
    );
  }

  @override
  Future<void> dispose() async {
    _gen++;
    final c = _c;
    _c = null;
    c?.removeListener(_onValue);
    try { await c?.dispose(); } catch (_) {}
  }
}

// ════════════════════════════════════════════════════════════════════
//  MpvEngine — libmpv (media_kit)
// ════════════════════════════════════════════════════════════════════
class MpvEngine extends PlayerEngine {
  final String title;
  final bool live;
  MpvEngine({required this.title, required this.live});

  @override EngineKind get kind => EngineKind.mpv;

  mk.Player? _p;
  mkv.VideoController? _vc;
  final List<StreamSubscription> _subs = [];
  bool _first = false;

  @override
  Future<void> init() async {
    final p = mk.Player(configuration: mk.PlayerConfiguration(
      title: title,
      bufferSize: live ? 32 * 1024 * 1024 : 96 * 1024 * 1024,
      logLevel: mk.MPVLogLevel.warn,
    ));
    _p = p;
    _vc = mkv.VideoController(p, configuration: const mkv.VideoControllerConfiguration(enableHardwareAcceleration: true));
    await _props({
      'network-timeout': '20',
      'cache': 'yes',
      'keep-open': 'yes',
    });
    _subs.addAll([
      p.stream.playing.listen((v) => onPlaying?.call(v)),
      p.stream.buffering.listen((v) => onBuffering?.call(v)),
      p.stream.position.listen((v) {
        onPosition?.call(v);
        // بث صوتي بلا صورة: الموضع يتقدّم ⇐ بدأ التشغيل فعلاً
        if (!_first && v > const Duration(milliseconds: 400)) { _first = true; onFirstFrame?.call(); }
      }),
      p.stream.duration.listen((v) { if (!live) onDuration?.call(v); }),
      p.stream.buffer.listen((v) => onBuffer?.call(v)),
      p.stream.completed.listen((v) { if (v && !live) onCompleted?.call(); }),
      p.stream.error.listen((e) => onError?.call(e)),
      p.stream.tracks.listen((_) => onTracks?.call()),
      p.stream.width.listen((w) { if ((w ?? 0) > 0 && !_first) { _first = true; onFirstFrame?.call(); } }),
    ]);
  }

  Future<void> _props(Map<String, String> m) async {
    final np = _p?.platform;
    if (np is! mk.NativePlayer) return;
    for (final e in m.entries) {
      try { await np.setProperty(e.key, e.value); } catch (_) {}
    }
  }

  @override
  Future<void> open(String url, {Duration? start, required bool live, bool dataSaver = false}) async {
    final p = _p;
    if (p == null) return;
    _first = false;
    final hls = url.toLowerCase().contains('.m3u8');
    // ★ إعدادات حسب نوع المصدر:
    //   HLS: لا reconnect_streamed (كان يعتبر نهاية كل مقطع انقطاعاً فيعلّق) +
    //        بداية بهامش 3 مقاطع قبل حافة البث.
    //   TS/MKV المستمر: إعادة اتصال FFmpeg تلقائية.
    await _props({
      'stream-lavf-o': hls ? '' : 'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=4',
      'demuxer-lavf-o': hls && live
          ? 'live_start_index=-3'
          : (live ? 'probesize=1000000,analyzeduration=1000000' : ''),
      'cache-secs': live ? '10' : '120',
      'demuxer-readahead-secs': live ? '6' : '60',
      'cache-pause-wait': live ? '2' : '1',
      'hls-bitrate': dataSaver ? 'min' : 'max',
    });
    await p.open(mk.Media(url, httpHeaders: SecurityLayer.streamHeaders(isLive: live), start: start), play: true);
  }

  @override Future<void> play() async => _p?.play();
  @override Future<void> pause() async => _p?.pause();
  @override Future<void> playOrPause() async => _p?.playOrPause();
  @override Future<void> seek(Duration t) async => _p?.seek(t);
  @override Future<void> setRate(double r) async => _p?.setRate(r);
  @override Future<void> setVolume(double v) async => _p?.setVolume((v.clamp(0.0, 1.0)) * 100);
  @override bool get playing => _p?.state.playing ?? false;
  @override bool get supportsTracks => true;

  static bool _real(String id) => id != 'auto' && id != 'no';

  static String _lbl(String? title, String? lang, String id) {
    final l = <String>[if ((title ?? '').isNotEmpty) title!, if ((lang ?? '').isNotEmpty) langAr(lang!)];
    return l.isEmpty ? 'مسار $id' : l.join(' · ');
  }

  @override
  List<EngineTrack> audioTracks() => [
    for (final t in _p?.state.tracks.audio ?? const <mk.AudioTrack>[])
      if (_real(t.id)) EngineTrack(t.id, _lbl(t.title, t.language, t.id), t),
  ];
  @override
  List<EngineTrack> subtitleTracks() => [
    for (final t in _p?.state.tracks.subtitle ?? const <mk.SubtitleTrack>[])
      if (_real(t.id)) EngineTrack(t.id, _lbl(t.title, t.language, t.id), t),
  ];
  @override
  List<EngineTrack> videoTracks() => [
    for (final t in _p?.state.tracks.video ?? const <mk.VideoTrack>[])
      if (_real(t.id)) EngineTrack(t.id, (t.h ?? 0) > 0 ? '${t.h}p' : _lbl(t.title, t.language, t.id), t),
  ];
  @override String? get currentAudio => _p?.state.track.audio.id;
  @override String? get currentSubtitle => _p?.state.track.subtitle.id;
  @override String? get currentVideo => _p?.state.track.video.id;
  @override Future<void> selectAudio(EngineTrack t) async => _p?.setAudioTrack(t.raw as mk.AudioTrack);
  @override Future<void> selectSubtitle(EngineTrack? t) async =>
      _p?.setSubtitleTrack(t == null ? mk.SubtitleTrack.no() : t.raw as mk.SubtitleTrack);
  @override Future<void> selectVideo(EngineTrack? t) async =>
      _p?.setVideoTrack(t == null ? mk.VideoTrack.auto() : t.raw as mk.VideoTrack);

  @override
  Widget view({required BoxFit fit, required TextStyle subStyle, required EdgeInsets subPad}) {
    final vc = _vc;
    if (vc == null) return const ColoredBox(color: Colors.black);
    return mkv.Video(
      controller: vc,
      controls: mkv.NoVideoControls,
      fit: fit,
      fill: Colors.black,
      wakelock: true,
      pauseUponEnteringBackgroundMode: false,
      subtitleViewConfiguration: mkv.SubtitleViewConfiguration(style: subStyle, padding: subPad),
    );
  }

  @override
  Future<void> dispose() async {
    for (final s in _subs) { s.cancel(); }
    _subs.clear();
    final p = _p;
    _p = null; _vc = null;
    try { await p?.dispose(); } catch (_) {}
  }
}

/// أسماء اللغات بالعربية لمسارات الصوت والترجمة
String langAr(String l) => switch (l.toLowerCase()) {
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
      'kur' || 'ku' => 'الكردية',
      _ => l,
    };
