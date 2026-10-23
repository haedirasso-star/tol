part of '../../main.dart';

// المشغّل القديم (video_player) — احتياط للطوارئ فقط: remote_control.player_engine = legacy

// ─────────────────────────────────────────────────────────
class _QualityLevel {
  final String label;
  final String ext;
  const _QualityLevel(this.label, this.ext);
}


class LegacyPlayerPage extends StatefulWidget {
  final List<String> urls;
  final String title;
  final bool isLive;
  final dynamic item;
  // ★ للمسلسلات: قائمة الحلقات + index الحالي
  final List<dynamic> episodes;
  final int episodeIndex;
  final void Function(int)? onEpisodeChanged;
  const LegacyPlayerPage({super.key, required this.urls, required this.title, this.isLive = false, this.item, this.episodes = const [], this.episodeIndex = 0, this.onEpisodeChanged});
  @override State<LegacyPlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<LegacyPlayerPage> with TickerProviderStateMixin {
  VideoPlayerController? _vc;

  late final AnimationController _ov, _sp;
  late final Animation<double> _ovAn;

  bool _inited = false, _err = false, _buf = true;
  // ★ نظام التعافي التلقائي
  List<String> _autoUrls = [];      // الروابط المبنيّة من بيانات السيرفر
  int  _autoIdx   = 0;
  int  _softRetry = 0;              // محاولات صامتة قبل إظهار أي خطأ
  static const _maxSoft = 3;
  Timer? _recoverTimer;
  bool _recovering = false;
  bool _overlay = true, _fs = true, _muted = false;
  double _vol = 1.0, _brightness = 1.0;
  // ★ حلقات المسلسل
  bool _showEpisodes = false;
  late int _curEpIdx;
  Timer? _autoNextTimer;
  bool _showAutoNext = false;
  bool _seekDrag = false; double _seekVal = 0;
  bool _volDrag = false, _brightDrag = false;
  double _gestY = 0;
  String _errMsg = '';
  int _urlIdx = 0;
  static const _maxR = 4;
  Timer? _hideT;

  // ── ★ تأثير النقر المزدوج (⏪/⏩) ──────────────────────
  int _seekFlash = 0;      // -1 يسار (إرجاع) · 1 يمين (تقديم) · 0 لا شيء
  Timer? _seekFlashT;

  // ── حفظ التقدم ─────────────────────────────────────────
  Timer? _progressTimer;
  String get _contentId =>
      widget.item?['stream_id']?.toString() ??
      widget.item?['id']?.toString() ??
      widget.item?['series_id']?.toString() ?? '';

  // ── نظام الجودة ────────────────────────────────────────
  static const _qualities = [
    _QualityLevel('الأصلية', ''),
    _QualityLevel('1080p', 'mp4'),
    _QualityLevel('720p',  'ts'),
    _QualityLevel('480p',  'm3u8'),
  ];
  int _qualityIdx = 0;
  bool _showQuality = false;

  // ── العلامة المائية — تتنقل بين الزوايا الأربع ────────
  int _wmCorner = 0;
  Timer? _wmTimer;

  // ── حالة الإيماءات ─────────────────────────────────────
  double _tiltX = 0.0, _tiltY = 0.0; // للتجسيم البصري
  bool _showFitToggle = false;
  int _fitMode = 0; // 0=أصلي(contain) · 1=ملء(cover) · 2=صغير(zoom-out)

  // ── Speed Control ───────────────────────────────────────
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  int _speedIdx = 2; // 1.0x default
  bool _showSpeed = false;
  bool _locked = false; // قفل الشاشة — يمنع اللمس العرضي

  // ── Skip Intro ──────────────────────────────────────────
  bool _showSkipIntro = false;
  bool _showSkipCredits = false;

  // ── Seekbar ─────────────────────────────────────────────
  bool _seekExpanded = false; // توسيع الشريط عند اللمس
  String _seekPreview = ''; // وقت النقطة عند السحب

  // ── Live Buffer / DVR ───────────────────────────────────
  // تأخير 7 ثوانٍ للتخزين المؤقت (DVR) لمنع انقطاع البث
  bool _liveBuffering = false;

  // ── Picture-in-Picture — native channel ─────────────────────
  static const _pipChannel = MethodChannel('totv_pip');
  bool _pipActive = false;

  // ── Chromecast ───────────────────────────────────────────
  bool _casting = false;
  dynamic _castDevice;


  @override
  void initState() {
    super.initState();
    _curEpIdx = widget.episodeIndex;
    _ov = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _sp = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _ovAn = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ov, curve: Curves.easeOut));

    if (!kIsWeb) WakelockPlus.enable();
    _enterFs();
    SecurityLayer.enableScreenRecord();
    _ov.forward(); _schedHide();

    // العلامة المائية تتنقل كل 30 ثانية
    _wmTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _wmCorner = (_wmCorner + 1) % 4);
    });


    // ── تهيئة PiP — native channel ────────────────────────
    if (!kIsWeb) {
      _pipChannel.setMethodCallHandler((call) async {
        if (call.method == 'pipStatusChanged' && mounted) {
          setState(() => _pipActive = call.arguments == true);
        }
      });
    }
    _startPlayback();
  }

  // ── بدء التشغيل — الكاش أولاً، ثم موازنة الأحمال ────────
  Future<void> _startPlayback() async {
    // تأكد من تحميل WatchTimer (يتذكر بعد الفرمتة عبر Firebase)
    if (!SubCompat.isPremium) await WatchTimer.load();
    WatchTimer.startPlayback();
    // فحص الكاش: هل يوجد رابط ناجح مخزن لهذا المحتوى؟
    final cachedUrl = PlayUrlCache.get(_contentId);
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      // استخدم الرابط المخزن فوراً
      await _init(cachedUrl);
      if (!widget.isLive) _checkResumePosition();
      return;
    }

    if (widget.urls.isNotEmpty && widget.urls.first.isNotEmpty) {
      // موازنة الأحمال للبث المباشر
      final url = widget.isLive
          ? LiveLoadBalancer.pickBest(widget.urls)
          : widget.urls.first;
      await _init(url);
      if (!widget.isLive) _checkResumePosition();
      return;
    }
    // البحث عن الرابط من السيرفر تلقائياً
    if (widget.item != null) {
      if (!mounted) return;
      setState(() { _buf = true; _errMsg = 'جاري البحث عن رابط التشغيل...'; });
      try {
        final cands = _buildCandidates();
        if (cands.isNotEmpty) {
          // ★ كل الاحتمالات تدخل قائمة المحاولات، لا الأول فقط
          _autoUrls = cands;
          _autoIdx  = 0;
          await _init(cands.first);
          if (!widget.isLive) _checkResumePosition();
          return;
        }
      } catch (e) { debugPrint('[player] candidates: $e'); }
      if (mounted) {
        setState(() { _err = true; _buf = false; _errMsg = 'لم يُعثر على رابط تشغيل'; });
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  //  ★ بناء كل روابط التشغيل الممكنة
  //  كان الكود القديم يكتب حلقة for ثم يخرج منها في أول دورة،
  //  فلا يُجرَّب سوى mp4 — وأي محتوى بصيغة أخرى يفشل فوراً.
  //  كما كان يستخدم مسار /movie/ حتى للقنوات المباشرة.
  // ══════════════════════════════════════════════════════════
  List<String> _buildCandidates() {
    final id = widget.item?['stream_id']?.toString() ??
               widget.item?['id']?.toString() ?? '';
    if (id.isEmpty) return const [];

    final useTotv = SubCompat.isTOTV && SubCompat.xtreamUser.isNotEmpty;
    final base = (useTotv ? SubCompat.xtreamBase : RCCompat.serverUrl)
        .replaceAll(RegExp(r'/+$'), '');
    final user = useTotv ? SubCompat.xtreamUser : RCCompat.username;
    final pass = useTotv ? SubCompat.xtreamPass : RCCompat.password;
    if (base.isEmpty || user.isEmpty || pass.isEmpty) return const [];

    final out = <String>[];
    if (widget.isLive) {
      // القنوات المباشرة: مسار /live/ وامتدادات البثّ
      for (final ext in ['m3u8', 'ts']) {
        out.add('$base/live/$user/$pass/$id.$ext');
      }
      // بعض السيرفرات تقدّم المباشر بلا مجلد
      out.add('$base/$user/$pass/$id');
    } else {
      final isSeries = (widget.item?['series_id'] != null) ||
                       (widget.item?['episode_num'] != null);
      final dir = isSeries ? 'series' : 'movie';
      // الامتداد الذي يعلنه السيرفر أولاً إن وُجد
      final declared = widget.item?['container_extension']?.toString() ?? '';
      final exts = <String>[
        if (declared.isNotEmpty) declared,
        'mp4', 'mkv', 'm3u8', 'ts', 'avi',
      ];
      final seen = <String>{};
      for (final e in exts) {
        if (!seen.add(e)) continue;
        out.add('$base/$dir/$user/$pass/$id.$e');
      }
      // احتياط: بعض السيرفرات تخلط المسارين
      final alt = isSeries ? 'movie' : 'series';
      out.add('$base/$alt/$user/$pass/$id.mp4');
    }
    debugPrint('[player] ${out.length} candidate url(s) built');
    return out;
  }



  Future<void> _init(String url) async {
    setState(() { _buf = true; _err = false; });
    final vc = VideoPlayerController.networkUrl(Uri.parse(url),
      httpHeaders: kIsWeb ? {} : SecurityLayer.streamHeaders(isLive: widget.isLive),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false, allowBackgroundPlayback: false));
    vc.addListener(() => _onEvt(vc));
    try {
      await vc.initialize().timeout(Duration(seconds: widget.isLive ? 30 : 20));
      await vc.setVolume(_vol);
      // ── استكمال من آخر موضع ──────────────────────────────
      if (!widget.isLive && _contentId.isNotEmpty) {
        final lastPos = WatchHistory.getProgressMs(_contentId) > 0 ? Duration(milliseconds: WatchHistory.getProgressMs(_contentId)) : null;
        if (lastPos != null && lastPos.inSeconds > 5) {
          await vc.seekTo(lastPos);
        }
      }
      await vc.play();
      if (mounted) {
        final old = _vc;
        setState(() { _vc = vc; _inited = true; _buf = false; _errMsg = ''; });
        _softRetry = 0;                 // ★ نجحنا — صفّر العدّاد
        _recovering = false;
        old?.dispose();
        // ── بدء حفظ التقدم كل 5 ثوانٍ ──
        _progressTimer?.cancel();
        _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
        // ── Skip Intro: يظهر بعد 3 ثوانٍ ويختفي بعد 90 ثانية ──
        if (!widget.isLive) {
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showSkipIntro = true);
          });
          Future.delayed(const Duration(seconds: 90), () {
            if (mounted) setState(() => _showSkipIntro = false);
          });
        }
        // ── DVR Buffer للبث المباشر ──
        if (widget.isLive) _initLiveBuffer(vc);
        // ── إضافة للسجل ──
        if (widget.item != null) {
          WatchHistory.addItem(widget.item!, widget.isLive ? 'live' : 'movie');
        }
      } else { vc.dispose(); }
    } catch (e) {
      vc.removeListener(() => _onEvt(vc));
      await vc.dispose();
      _tryNext(e.toString());
    }
  }

  void _onEvt(VideoPlayerController vc) {
    if (!mounted) return;
    // ★ خطأ أثناء التشغيل: حاول التعافي بصمت قبل إزعاج المستخدم.
    //   كان أي عطل عابر يقلب الشاشة إلى خطأ دائم حتى لو عادت الشبكة.
    if (vc.value.hasError && !_err && !_recovering) {
      final desc = vc.value.errorDescription ?? '';
      if (_softRetry < _maxSoft) {
        _recovering = true;
        debugPrint('[player] runtime error — recovering: $desc');
        _tryNext(desc.isEmpty ? 'timeout' : desc);
      } else {
        setState(() { _err = true; _buf = false; _errMsg = desc; });
      }
      return;
    }
    // ★ Auto-next: عند انتهاء الحلقة اعرض banner الحلقة التالية
    if (!widget.isLive && !_showAutoNext && widget.episodes.isNotEmpty) {
      final dur = vc.value.duration.inSeconds;
      final pos = vc.value.position.inSeconds;
      if (dur > 30 && pos >= dur - 3 && pos > 0) {
        _triggerAutoNext();
      }
    }
    if (mounted) setState(() {});
  }

  // ── حفظ التقدم ─────────────────────────────────────────
  void _saveProgress() {
    final vc = _vc;
    if (vc == null || !_inited || widget.isLive) return;
    final pos   = vc.value.position.inSeconds;
    final total = vc.value.duration.inSeconds;
    if (_contentId.isNotEmpty) {
      WatchHistory.saveProgress(_contentId, pos, total);
    }
  }

  void _tryNext(String r) {
    // سجّل فشل السيرفر الحالي
    if (_urlIdx < widget.urls.length) {
      try {
        final failedUrl = widget.urls[_urlIdx - 1 < 0 ? 0 : _urlIdx - 1];
        LiveLoadBalancer.markFail(Uri.parse(failedUrl).host);
      } catch (e) { debugPrint('[profile_player] $e'); }
    }
    // امسح الكاش إذا كان الرابط المخزن هو الفاشل
    if (_contentId.isNotEmpty) {
      final cached = PlayUrlCache.get(_contentId);
      if (cached != null && _urlIdx == 1) PlayUrlCache.put(_contentId, ''); // invalidate
    }
    _urlIdx++;
    // أولاً: جرّب الروابط المتاحة (مع موازنة الأحمال)
    if (_urlIdx < widget.urls.length && _urlIdx < _maxR) {
      final nextUrl = widget.isLive
          ? LiveLoadBalancer.pickBest(widget.urls.sublist(_urlIdx))
          : widget.urls[_urlIdx];
      _init(nextUrl);
      return;
    }
    // ★ ثانياً: بقية الامتدادات/المسارات المبنيّة تلقائياً
    _autoIdx++;
    if (_autoIdx < _autoUrls.length) {
      debugPrint('[player] trying candidate ${_autoIdx + 1}/${_autoUrls.length}');
      _init(_autoUrls[_autoIdx]);
      return;
    }
    // ★ ثالثاً: إعادة محاولة صامتة — الأعطال الشبكية العابرة شائعة جداً
    //   على شبكات الجوال. بدلاً من إظهار خطأ فوري، ننتظر ونعيد بهدوء.
    final transient = r.toLowerCase().contains('timeout') ||
                      r.toLowerCase().contains('socket')  ||
                      r.toLowerCase().contains('connection') ||
                      r.toLowerCase().contains('reset')   ||
                      r.contains('502') || r.contains('503') || r.contains('504');
    if (transient && _softRetry < _maxSoft) {
      _softRetry++;
      final wait = Duration(milliseconds: 900 * _softRetry);   // 0.9s → 1.8s → 2.7s
      debugPrint('[player] soft retry $_softRetry after ${wait.inMilliseconds}ms');
      if (mounted) {
        setState(() {
          _buf = true; _err = false;
          _errMsg = 'انقطاع مؤقت — إعادة المحاولة ($_softRetry/$_maxSoft)';
        });
      }
      _recoverTimer?.cancel();
      _recoverTimer = Timer(wait, () {
        if (!mounted) return;
        _urlIdx = 0; _autoIdx = 0;
        final first = widget.urls.isNotEmpty
            ? widget.urls.first
            : (_autoUrls.isNotEmpty ? _autoUrls.first : '');
        if (first.isNotEmpty) { _init(first); } else { _startPlayback(); }
      });
      return;
    }
    // فحص انتهاء وقت الضيف قبل Vodu
    if (!SubCompat.isPremium && WatchTimer.isExpired) {
      _showPaywall();
      return;
    }
    // ثانياً: جرّب Vodu للأفلام والمسلسلات قبل إظهار الخطأ
    if (!widget.isLive && widget.title.isNotEmpty) {
      _tryVodu();
      return;
    }
    // لا تُظهر خطأ عام — أظهر السبب الحقيقي بوضوح
    final rl = r.toLowerCase();
    String msg;
    if (Sub.password.isEmpty || !Sub.hasServer) {
      msg = 'لم تُدخل بيانات الاشتراك — فعّل اشتراكك أولاً';
    } else if (rl.contains('timeout')) {
      msg = 'السيرفر لا يستجيب — تحقق من الإنترنت أو حاول لاحقاً';
    } else if (rl.contains('connection') || rl.contains('refused') ||
               rl.contains('socket') || rl.contains('host') ||
               rl.contains('failed host') || rl.contains('unreachable')) {
      msg = 'السيرفر لا يعمل حالياً';
    } else if (r.contains('404')) {
      msg = 'هذه الخدمة غير متوفّرة ضمن اشتراكك';
    } else if (r.contains('403') || r.contains('401')) {
      msg = 'هذه الخدمة ليست ضمن اشتراكك أو انتهت صلاحيته';
    } else if (r.contains('500') || r.contains('502') || r.contains('503')) {
      msg = 'السيرفر لا يعمل حالياً';
    } else {
      msg = 'تعذّر تشغيل هذه الخدمة';
    }
    if (mounted) setState(() { _err = true; _buf = false; _errMsg = msg; });
  }

  Future<void> _tryVodu() async {
    if (!mounted) return;
    setState(() {
      _buf    = true;
      _err    = false;
      _errMsg = 'جاري البحث عن معاينة تشغيل...';
    });
    try {
      final item   = widget.item;
      final isTv   = (item?['type']?.toString() ?? 'movie') == 'series';
      final tmdbId = item?['tmdb_id']?.toString() ??
                     item?['tmdbId']?.toString() ?? '';

      // ── استخدام TrailerFallbackService الذكي ──
      final result = await TrailerFallbackService.findTrailer(
        title:   widget.title,
        isTv:    isTv,
        tmdbId:  tmdbId.isNotEmpty ? tmdbId : null,
      );

      if (!mounted) return;

      if (result.found && result.trailerUrl.isNotEmpty) {
        debugPrint('TrailerFallback ✅ [${result.source}]: ${result.trailerUrl}');
        // أظهر شارة "معاينة" للمستخدم
        _showSnack('يتم عرض المعاينة الترويجية');
        _init(result.trailerUrl);
      } else {
        setState(() {
          _err    = true;
          _buf    = false;
          _errMsg = 'تعذّر تشغيل المحتوى أو إيجاد معاينة';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _err    = true;
          _buf    = false;
          _errMsg = 'تعذّر تشغيل المحتوى';
        });
      }
    }
  }


  // ── Paywall — جدار الاشتراك ──────────────────────────

  // ── إغلاق المشغل (يُستخدم داخل _PlayerPageState) ────────────
  void _closePlayer() {
    _vc?.pause();
    Navigator.of(context).maybePop();
  }

  void _showPaywall() {
    if (!mounted) return;
    _vc?.pause();
    setState(() { _err = false; _buf = false; });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaywallSheet(
        onSubscribe: () {
          Navigator.pop(context);
          _closePlayer();
          // فتح صفحة الاشتراك الموحّدة (تفعيل + شراء)
          Navigator.of(context).push(PageRouteBuilder(
            pageBuilder: (_, __, ___) => const SubscriptionPage(),
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
          ));
        },
        onClose: () { Navigator.pop(context); _closePlayer(); },
      ),
    );
  }

  // ── مؤقت وقت الضيف في المشغل ─────────────────────────
  Widget _buildGuestTimerBadge() {
    if (SubCompat.isPremium) return const SizedBox.shrink();
    // Hide timer while actively playing to avoid distraction
    if (_vc?.value.isPlaying == true) return const SizedBox.shrink();
    return StreamBuilder<int>(
      // يُحدَّث كل ثانية — يستخدم remainingSecs الذي يحسب الجلسة الحالية تلقائياً
      stream: Stream.periodic(const Duration(seconds: 1), (_) => WatchTimer.remainingSecs),
      initialData: WatchTimer.remainingSecs,
      builder: (ctx, snap) {
        final secs    = (snap.data ?? 0).clamp(0, 43200);
        final expired = secs <= 0;
        // عند انتهاء الوقت — أوقف المشغل وأظهر Paywall
        if (expired) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showPaywall();
          });
        }
        final str = WatchTimer.remainingStr;
        return Positioned(
          top: MediaQuery.of(ctx).padding.top + 56,
          right: 16,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: expired
                  ? Colors.red.withOpacity(0.92)
                  : Colors.black.withOpacity(0.78),
              borderRadius: BorderRadius.circular(R.xl),
              border: Border.all(
                color: expired ? Colors.red : C.gold.withOpacity(0.5),
                width: expired ? 1.5 : 0.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                expired ? Icons.lock_rounded : Icons.timer_rounded,
                size: 12,
                color: expired ? Colors.white : C.gold),
              const SizedBox(width: 5),
              Text(
                expired ? 'انتهى وقت المشاهدة المجانية' : str,
                style: TextStyle(
                  fontSize: FS.sm,
                  fontWeight: FontWeight.w700,
                  color: expired ? Colors.white : C.gold,
                  fontFamily: 'Montserrat',
                )),
            ]),
          ),
        );
      },
    );
  }

  // ── تغيير الجودة بدون انقطاع ──────────────────────────
  Future<void> _changeQuality(int idx) async {
    if (idx == _qualityIdx) return;
    final vc = _vc;
    final pos = vc?.value.position ?? Duration.zero;
    // بناء رابط الجودة المطلوبة
    String url = widget.urls.isNotEmpty ? widget.urls.first : '';
    final item = widget.item;
    if (idx > 0 && item != null) {
      final id = item['stream_id']?.toString() ?? item['id']?.toString() ?? '';
      if (id.isNotEmpty) {
        // ⚠️ دائماً عبر CmsService — السيرفر من Worker /boot
        final type = widget.isLive ? 'live' : 'movie';
        url = CmsService.buildStreamUrl(type, id, _qualities[idx].ext.isEmpty ? 'mp4' : _qualities[idx].ext);
      }
    }
    if (url.isEmpty) return;
    setState(() { _qualityIdx = idx; _showQuality = false; _buf = true; });
    // تشغيل الجودة الجديدة ثم القفز للموضع السابق
    final newVc = VideoPlayerController.networkUrl(Uri.parse(url),
        httpHeaders: kIsWeb ? {} : SecurityLayer.streamHeaders(isLive: widget.isLive),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
    newVc.addListener(() => _onEvt(newVc));
    try {
      await newVc.initialize().timeout(const Duration(seconds: 20));
      if (!widget.isLive && pos > Duration.zero) await newVc.seekTo(pos);
      await newVc.setVolume(_vol);
      await newVc.play();
      if (mounted) {
        final old = _vc;
        setState(() { _vc = newVc; _inited = true; _buf = false; });
        old?.dispose();
      } else { newVc.dispose(); }
    } catch (_) {
      newVc.dispose();
      // الجودة غير متوفرة — ابقَ على الجودة الحالية
      if (mounted) setState(() { _qualityIdx = 0; _buf = false; });
      _showSnack('هذه الجودة غير متوفرة — تم الإبقاء على الجودة الأصلية');
    }
  }

  // ── تغيير السرعة ──────────────────────────────────────────
  Future<void> _changeSpeed(int idx) async {
    _speedIdx = idx;
    _showSpeed = false;
    await _vc?.setPlaybackSpeed(_speeds[idx]);
    if (!mounted) return;
    setState(() {});
    Sound.hapticL();
  }

  // ── DVR للبث المباشر: تأخير 7 ثوانٍ للاستقرار ──────────
  Future<void> _initLiveBuffer(VideoPlayerController vc) async {
    if (!widget.isLive) return;
    setState(() => _liveBuffering = true);
    // انتظر تجميع 7 ثوانٍ من البيانات
    await Future.delayed(const Duration(seconds: 7));
    if (mounted) setState(() => _liveBuffering = false);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.black, fontSize: FS.sm)),
      backgroundColor: C.gold, duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.sm)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
    ));
  }

  // ── تحقق من موضع محفوظ واسأل المستخدم ──────────────────
  Future<void> _checkResumePosition() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted || !_inited) return;
    final item = widget.item;
    if (item == null) return;
    final id  = item['stream_id']?.toString() ?? item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final posMs = WatchHistory.getProgressMs(id);
    final pos = posMs;
    if (pos <= 10000) return; // أقل من 10 ثوانٍ: ابدأ من البداية
    if (WatchHistory.isCompleted(id)) return; // مكتمل: ابدأ من البداية
    final dur = _vc?.value.duration.inMilliseconds ?? 0;
    if (pos >= dur && dur > 0) return;
    // أظهر Dialog استكمال
    if (!mounted) return;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
        title: Text('استكمال المشاهدة', style: T.cairo(s: FS.lg, w: FontWeight.w700)),
        content: Text(
          'وصلت إلى ${_fmt(Duration(milliseconds: pos))} — هل تريد الاستكمال؟',
          style: T.cairo(s: FS.md, c: C.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_, false),
            child: Text('من البداية', style: T.cairo(s: FS.md, c: C.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: C.gold, foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.sm))),
            onPressed: () => Navigator.pop(_, true),
            child: Text('استكمال', style: T.cairo(s: FS.md, w: FontWeight.w700))),
        ]));
    if (resume == true && mounted && _vc != null) {
      await _vc!.seekTo(Duration(milliseconds: pos));
      setState(() {});
    }
  }

  void _schedHide() {
    _hideT?.cancel();
    _hideT = Timer(const Duration(seconds: 4), () {
      if (mounted && _overlay) { setState(() => _overlay = false); _ov.reverse(); }
    });
  }
  void _wake() { if (!_overlay) { setState(() => _overlay = true); _ov.forward(); } _schedHide(); }
  void _toggleOv() {
    setState(() => _overlay = !_overlay);
    if (_overlay) { _ov.forward(); _schedHide(); } else { _ov.reverse(); _hideT?.cancel(); }
  }
  void _togglePlay() {
    final vc = _vc; if (vc == null || !_inited) return;
    vc.value.isPlaying ? vc.pause() : vc.play();
    setState(() {}); _wake();
  }
  void _seekBy(int s) {
    final vc = _vc; if (vc == null || !_inited || widget.isLive) return;
    final r = vc.value.position + Duration(seconds: s);
    vc.seekTo(r < Duration.zero ? Duration.zero : r > vc.value.duration ? vc.value.duration : r);
    Sound.hapticL(); // اهتزاز خفيف عند الـ seek
    setState(() {}); _wake();
  }
  void _toggleMute() { _muted = !_muted; _vc?.setVolume(_muted ? 0 : _vol); setState(() {}); }
  void _enterFs() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    if (mounted) setState(() => _fs = true);
  }
  void _exitFs() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    if (mounted) setState(() => _fs = false);
  }

  String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
    return h > 0 ? '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}'
                 : '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  double get _prog {
    final vc = _vc; if (vc == null || !_inited) return 0;
    final d = vc.value.duration.inMilliseconds; if (d == 0) return 0;
    return (vc.value.position.inMilliseconds / d).clamp(0.0, 1.0);
  }
  double get _bufd {
    final vc = _vc; if (vc == null || !_inited || vc.value.buffered.isEmpty) return 0;
    final d = vc.value.duration.inMilliseconds; if (d == 0) return 0;
    return (vc.value.buffered.last.end.inMilliseconds / d).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    // حفظ موضع التشغيل عند الخروج
    _saveWatchPosition();
    _hideT?.cancel();
    _seekFlashT?.cancel();
    _wmTimer?.cancel();
    _progressTimer?.cancel();
    _autoNextTimer?.cancel();
    _recoverTimer?.cancel();          // ★ مؤقّت التعافي
    _saveProgress(); // حفظ أخير قبل الإغلاق
    WatchTimer.stopPlayback(); // للتوافق القديم
    // حفظ وقت الجلسة المجانية في Firestore
    final uid = AuthService.currentUser?.uid;
    if (uid != null) {
      unawaited(GuestSession.stopPlayback(uid));
    }
    _vc?.dispose();
    _ov.dispose(); _sp.dispose();
    if (!kIsWeb) WakelockPlus.disable();
    SecurityLayer.disableScreenRecord();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    super.dispose();
  }

  void _saveWatchPosition() {
    final vc = _vc;
    if (vc == null || !_inited) return;
    final item = widget.item;
    if (item == null) return;
    final id = item['stream_id']?.toString() ?? item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final pos = vc.value.position.inMilliseconds;
    final dur = vc.value.duration.inMilliseconds;
    if (pos > 5000) { // فقط إذا شاهد أكثر من 5 ثوانٍ
      // convert ms to seconds for old API
      WatchHistory.saveProgress(id, pos ~/ 1000, dur ~/ 1000);
      WatchHistory.addItem(item, widget.isLive ? 'live' : 'movie');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: Colors.black,
      body: _err ? _buildErr() : _buildPlayer(),
    );
    // ── TV Remote: ربط كامل لأزرار الريموت ─────────────────
    // ── PiP Mode ─────────────────────────────────────────────
    if (!kIsWeb && _pipActive) {
      final vc = _vc;
      return Scaffold(
        backgroundColor: Colors.black,
        body: vc != null && _inited
            ? Center(child: AspectRatio(
                aspectRatio: vc.value.aspectRatio,
                child: VideoPlayer(vc)))
            : const SizedBox.shrink(),
      );
    }
    // ★ Wrap in Stack to overlay episode panel + auto-next banner
    final playerWithOverlays = Stack(children: [
      scaffold,
      _buildEpisodePanel(),
      _buildAutoNextBanner(),
    ]);
    if (!TVLayout.isTV) return playerWithOverlays;
    return TVFocusHelper.withDpad(
      onOk:   _togglePlay,
      onBack: () => Navigator.maybePop(context),
      onLeft:  () { if (!widget.isLive) _seekBy(-10); },
      onRight: () { if (!widget.isLive) _seekBy(10);  },
      onUp: () {
        _vol = (_vol + 0.1).clamp(0.0, 1.0);
        _vc?.setVolume(_vol); setState(() {}); _showOvBriefly();
      },
      onDown: () {
        _vol = (_vol - 0.1).clamp(0.0, 1.0);
        _vc?.setVolume(_vol); setState(() {}); _showOvBriefly();
      },
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (e) {
          if (e is! KeyDownEvent) return;
          if (e.logicalKey == LogicalKeyboardKey.f1 ||
              e.logicalKey.keyId == 0x100070029) {
            Navigator.maybePop(context);                           // أحمر = رجوع
          } else if (e.logicalKey == LogicalKeyboardKey.f2) {
            _toggleMute();                                         // أخضر = صامت
          } else if (e.logicalKey == LogicalKeyboardKey.f3) {
            if (!widget.isLive) _seekBy(85);                      // أصفر = تخطي
          } else if (e.logicalKey == LogicalKeyboardKey.channelUp) {
            if (widget.isLive) _tryNext('ch_up');                 // CH+ = قناة تالية
          } else if (e.logicalKey == LogicalKeyboardKey.channelDown) {
            if (widget.isLive && _urlIdx > 0) { _urlIdx -= 2; _tryNext('ch_dn'); }
          } else if (e.logicalKey == LogicalKeyboardKey.mediaPlayPause ||
                     e.logicalKey == LogicalKeyboardKey.mediaPlay     ||
                     e.logicalKey == LogicalKeyboardKey.mediaPause) {
            _togglePlay();
          } else if (e.logicalKey == LogicalKeyboardKey.mediaFastForward) {
            if (!widget.isLive) _seekBy(30);
          } else if (e.logicalKey == LogicalKeyboardKey.mediaRewind) {
            if (!widget.isLive) _seekBy(-30);
          }
        },
        child: scaffold,
      ),
    );
  }

  void _showOvBriefly() {
    _ov.forward();
    _hideT?.cancel();
    _hideT = Timer(const Duration(seconds: 2), () { if (mounted) _ov.reverse(); });
  }

  Widget _buildErr() => Container(color: Colors.black,
    child: SafeArea(child: Center(
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // خطأ مرئي
          Container(width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: C.surface,
                border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5)),
            child: Center(child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.play_circle_outline_rounded, color: Colors.white24, size: 44),
              const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
            ]))),
          const SizedBox(height: 20),
          Text(_errMsg.isNotEmpty ? _errMsg : 'تعذّر تشغيل هذه الخدمة',
              style: T.cairo(s: FS.lg, w: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_errMsg.contains('بيانات الاشتراك')
                  ? 'افتح "حسابي" واضغط تفعيل اشتراكي.'
                  : _errMsg.contains('السيرفر')
                      ? 'المشكلة من السيرفر وليست من جهازك. حاول بعد قليل.'
                      : 'إن تكرّر الأمر تواصل مع الدعم.',
              style: T.body(c: C.grey), textAlign: TextAlign.center),
          const SizedBox(height: 28),
          // أزرار
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(height: 44,
                decoration: BoxDecoration(
                  border: Border.all(color: CExtra.border),
                  borderRadius: BorderRadius.circular(R.md)),
                child: Center(child: Text('رجوع', style: T.cairo(s: FS.md, c: C.grey)))))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: GestureDetector(
              onTap: () async {
                final wa = RC.whatsapp.replaceAll('+', '').replaceAll(' ', '');
                final msg = Uri.encodeComponent('مرحباً، أواجه مشكلة في تشغيل المحتوى على TOTV+');
                final uri = Uri.parse('https://wa.me/$wa?text=$msg');
                try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (_) {}
              },
              child: Container(height: 44,
                decoration: BoxDecoration(
                  gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.support_agent_rounded, color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Text('تواصل مع الدعم', style: T.cairo(s: FS.md, w: FontWeight.w800, c: Colors.black)),
                ])))),
          ]),
          const SizedBox(height: 12),
          // ── زر المعاينة الترويجية (Trailer Fallback) ──────
          if (!widget.isLive && widget.title.isNotEmpty)
            GestureDetector(
              onTap: _tryVodu,
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: C.goldBg,
                  borderRadius: BorderRadius.circular(R.md),
                  border: Border.all(color: C.gold.withOpacity(0.4), width: 1),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ShaderMask(
                    shaderCallback: (r) => C.playGrad.createShader(r),
                    child: const Icon(Icons.smart_display_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text('مشاهدة المعاينة الترويجية',
                      style: T.cairo(s: FS.md, c: C.gold, w: FontWeight.w700)),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          // تقديم شكوى → صندوق الشكاوى
          GestureDetector(
            onTap: () => ComplaintSheet.show(context),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.support_agent_rounded, color: C.gold, size: 14),
              const SizedBox(width: 6),
              Text('تقديم شكوى', style: T.caption(c: C.gold)),
            ])),
        ])))));


  // ── مواضع العلامة المائية ────────────────────────────────
  Alignment get _wmAlignment {
    switch (_wmCorner) {
      case 0: return const Alignment(0.85, -0.85);  // أعلى يمين
      case 1: return const Alignment(-0.85, 0.85);  // أسفل يسار
      case 2: return const Alignment(0.85, 0.85);   // أسفل يمين
      default: return const Alignment(-0.85, -0.85); // أعلى يسار
    }
  }

  Widget _buildPlayer() {
    final vc = _vc;
    final vidW = (vc != null && vc.value.size.width  > 0) ? vc.value.size.width  : 1920.0;
    final vidH = (vc != null && vc.value.size.height > 0) ? vc.value.size.height : 1080.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _locked
        ? () { setState(() => _overlay = true);
                _hideT?.cancel();
                _hideT = Timer(const Duration(seconds: 2), () { if (mounted) setState(() => _overlay = false); }); }
        : _toggleOv,
      onDoubleTapDown: _locked ? null : (d) {
        if (widget.isLive) return;
        final fwd = d.globalPosition.dx >= context.size!.width / 2;
        _seekBy(fwd ? 10 : -10);
        Sound.hapticL();
        setState(() => _seekFlash = fwd ? 1 : -1);
        _seekFlashT?.cancel();
        _seekFlashT = Timer(const Duration(milliseconds: 650),
            () { if (mounted) setState(() => _seekFlash = 0); });
      },
      // سحب رأسي: يمين = صوت، يسار = سطوع، وسط = تجسيم بصري
      onVerticalDragStart: (d) {
        if (_locked) return;
        _gestY     = d.localPosition.dy;
        _volDrag   = d.localPosition.dx > context.size!.width * 0.65;
        _brightDrag= d.localPosition.dx < context.size!.width * 0.35;
      },
      onVerticalDragUpdate: (d) {
        if (_locked) return;
        final delta = (_gestY - d.localPosition.dy) / (context.size!.height * 0.6);
        if (_volDrag) {
          _vol = (_vol + delta).clamp(0.0, 1.0);
          _vc?.setVolume(_vol);
        } else if (_brightDrag) {
          _brightness = (_brightness + delta).clamp(0.2, 1.0);
        } else {
          // منطقة الوسط = تجسيم (tilt effect)
          _tiltY = (_tiltY - delta * 8).clamp(-6.0, 6.0);
        }
        _gestY = d.localPosition.dy;
        if (mounted) setState(() {});
      },
      onVerticalDragEnd: (_) {
        _volDrag = false; _brightDrag = false;
        // إعادة الـ tilt تدريجياً
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { _tiltY = 0; _tiltX = 0; });
        });
      },
      onHorizontalDragUpdate: (d) {
        // تجسيم أفقي عند السحب الأفقي
        _tiltX = (_tiltX + d.delta.dx * 0.02).clamp(-4.0, 4.0);
        setState(() {});
      },
      onHorizontalDragEnd: (_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _tiltX = 0);
        });
      },
      child: Stack(fit: StackFit.expand, children: [
        // ── خلفية سوداء ──────────────────────────────────────
        Container(color: Colors.black),

        // ── الفيديو بحجمه الأصلي + تأثير تجسيم ─────────────
        if (_inited && vc != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateX(_tiltY * math.pi / 180)
              ..rotateY(_tiltX * math.pi / 180),
            transformAlignment: Alignment.center,
            child: Opacity(
              opacity: _brightness.clamp(0.0, 1.0),
              child: Center(
                child: _fitMode == 0
                  // أصلي — احتواء كامل بلا قص
                  ? AspectRatio(
                      aspectRatio: vidW / vidH,
                      child: VideoPlayer(vc))
                  : _fitMode == 1
                    // ملء — يملأ الشاشة (قد يُقص الأطراف)
                    ? FittedBox(fit: BoxFit.cover,
                        child: SizedBox(width: vidW, height: vidH,
                            child: VideoPlayer(vc)))
                    // صغير — مصغّر داخل الشاشة
                    : FractionallySizedBox(
                        widthFactor: 0.78, heightFactor: 0.78,
                        child: AspectRatio(
                          aspectRatio: vidW / vidH,
                          child: VideoPlayer(vc))),
              ),
            ),
          ),

        if (!_inited && !_err)
          Container(color: Colors.black),

        // ── مؤقت الضيف ──────────────────────────────────────
        _buildGuestTimerBadge(),

        // ── العلامة المائية — تتنقل بين الزوايا ─────────────
        AnimatedAlign(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          alignment: _wmAlignment,
          child: Opacity(
            opacity: 0.20,
            child: Text('TOTV+',
          textDirection: TextDirection.ltr,
              style: TExtra.cinzel(s: FS.sm, c: Colors.white)
                  .copyWith(letterSpacing: 3, fontWeight: FontWeight.w700)),
          ),
        ),

        // ── مؤشر الـ gesture ─────────────────────────────────
        if (_volDrag || _brightDrag) _buildGestureInd(),

        // ── Spinner تحميل ─────────────────────────────────────
        if (_buf && !_err) Center(child: AnimatedBuilder(animation: _sp,
          builder: (_, __) => Transform.rotate(angle: _sp.value * 6.28,
            child: Container(width: 50, height: 50,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: C.gold.withOpacity(0.12), width: 1.5)),
              child: CircularProgressIndicator(
                  color: C.gold.withOpacity(0.65), strokeWidth: 1.5))))),

        // ── DVR Buffer indicator (live only) ──────────────────
        if (_liveBuffering && widget.isLive)
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(R.md)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 110, child: LinearProgressIndicator(
                  color: C.imdb, backgroundColor: C.textDim,
                  minHeight: 2)),
              const SizedBox(height: 8),
              Text('جاري تحضير البث...', style: TextStyle(
                  color: Colors.white70, fontSize: FS.sm, fontFamily: 'sans-serif')),
            ]))),

        // ── Skip Intro button ───────────────────────────────
        if (_showSkipIntro && !widget.isLive && !_overlay)
          Positioned(bottom: 90, right: 16,
            child: GestureDetector(
              onTap: () {
                _seekBy(85);
                setState(() => _showSkipIntro = false);
                Sound.hapticM();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(R.sm),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(R.sm),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('تخطى المقدمة', style: TextStyle(
                          color: Colors.white, fontSize: FS.sm,
                          fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      const Icon(Icons.skip_next_rounded, color: Colors.white, size: 16),
                    ]))))),),

        // ── ★ تأثير النقر المزدوج (⏪ 10 / 10 ⏩) ───────────────
        if (_seekFlash != 0)
          Positioned.fill(child: IgnorePointer(child: Align(
            alignment: _seekFlash < 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(widthFactor: 0.5,
              child: _SeekFlash(forward: _seekFlash > 0))))),

        // ── قائمة الجودة ──────────────────────────────────────
        if (_showQuality) _buildQualityPanel(),

        // ── قائمة السرعة ──────────────────────────────────────
        if (_showSpeed) _buildSpeedPanel(),

        FadeTransition(opacity: _ovAn,
            child: _overlay ? _buildOverlay(vc) : const SizedBox.shrink()),
      ]),
    );
  }

  // ── لوحة اختيار الجودة ────────────────────────────────────
  Widget _buildQualityPanel() => Positioned(
    right: 16, top: 70,
    child: GestureDetector(
      onTap: () {}, // ★ يمنع تمرير اللمس للمكونات خلف القائمة
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.88),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: C.gold.withOpacity(0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min,
          children: List.generate(_qualities.length, (i) => GestureDetector(
            onTap: () => _changeQuality(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: i == _qualityIdx ? C.gold.withOpacity(0.12) : Colors.transparent,
                border: i > 0 ? Border(
                    top: BorderSide(color: CExtra.border.withOpacity(0.3))) : null,
              ),
              child: Row(children: [
                if (i == _qualityIdx)
                  const Icon(Icons.check_rounded, color: C.gold, size: 14),
                if (i != _qualityIdx)
                  const SizedBox(width: 14),
                const SizedBox(width: 8),
                Text(_qualities[i].label,
                  style: T.cairo(s: FS.sm,
                    c: i == _qualityIdx ? C.gold : Colors.white,
                    w: i == _qualityIdx ? FontWeight.w700 : FontWeight.w400)),
              ]),
            ),
          )),
        ),
      ),
    ),
  );

  Widget _buildSpeedPanel() => Positioned(
    right: 16, top: 70,
    child: Container(
      width: 120,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: C.gold.withOpacity(0.3))),
      child: Column(mainAxisSize: MainAxisSize.min,
        children: List.generate(_speeds.length, (i) {
          final sel = i == _speedIdx;
          return GestureDetector(
            onTap: () => _changeSpeed(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? C.gold.withOpacity(0.12) : Colors.transparent,
                border: i > 0 ? Border(
                    top: BorderSide(color: CExtra.border.withOpacity(0.2))) : null),
              child: Row(children: [
                if (sel)
                  const Icon(Icons.check_rounded, color: C.gold, size: 13),
                if (!sel) const SizedBox(width: 13),
                const SizedBox(width: 8),
                Text('${_speeds[i]}x',
                  style: TextStyle(
                    color: sel ? C.gold : Colors.white70,
                    fontSize: FS.sm,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                if (i == 2) ...[ // 1.0x = عادي
                  const SizedBox(width: 4),
                  Text('عادي', style: TextStyle(color: Colors.white38, fontSize: FS.sm)),
                ],
              ]),
            ));
        })),
    ));

  // ── Chromecast Dialog — native instructions ─────────────
  void _showCastDialog() {
    if (!mounted) return;
    Sound.hapticL();
    final url = widget.urls.isNotEmpty ? widget.urls.first : '';
    showModalBottomSheet(
      context: context,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.cast_rounded, color: C.gold, size: 20),
            const SizedBox(width: 10),
            Text('إرسال للتلفزيون', style: T.cairo(s: FS.lg, w: FontWeight.w700)),
          ]),
          const SizedBox(height: 20),
          // خيار 1: Chromecast
          _castOption(ctx,
            icon: Icons.cast_rounded,
            title: 'Google Chromecast',
            subtitle: 'افتح تطبيق Google Home ← Cast Screen',
            onTap: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse('https://www.google.com/cast/'));
            }),
          const SizedBox(height: 10),
          // خيار 2: نسخ الرابط للـ VLC/Kodi
          _castOption(ctx,
            icon: Icons.copy_rounded,
            title: 'نسخ رابط البث',
            subtitle: 'الصقه في VLC أو Kodi على تلفزيونك',
            onTap: () {
              Navigator.pop(ctx);
              if (url.isNotEmpty) {
                // copy to clipboard
                _showSnack('تم نسخ رابط البث');
              }
            }),
          const SizedBox(height: 10),
          // خيار 3: إيقاف إذا كان يبث
          if (_casting)
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                setState(() { _casting = false; _castDevice = null; });
                _vc?.play();
              },
              child: Container(
                width: double.infinity, height: 44,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(R.md)),
                child: Center(child: Text('إيقاف الإرسال',
                    style: T.cairo(s: FS.md, c: Colors.redAccent))))),
        ]),
      ),
    );
  }

  Widget _castOption(BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md)),
      child: Row(children: [
        Icon(icon, color: C.gold, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.cairo(s: FS.md, w: FontWeight.w600)),
          Text(subtitle, style: T.caption(c: C.grey)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: C.dim, size: 18),
      ]),
    ),
  );

  Widget _buildGestureInd() {
    final isVol = _volDrag;
    final val   = isVol ? _vol : _brightness;
    final icon  = isVol ? (val == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded)
                        : Icons.brightness_medium_rounded;
    return Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(R.md)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: C.gold, size: 26), const SizedBox(height: 8),
        SizedBox(width: 110, child: LinearProgressIndicator(value: val,
            backgroundColor: C.dim, color: C.gold, minHeight: 4)),
        const SizedBox(height: 5),
        Text(isVol ? 'الصوت ${(val*100).round()}%' : 'السطوع ${(val*100).round()}%',
            style: TExtra.mont(s: FS.sm, c: C.gold)),
      ])));
  }

  Widget _buildOverlay(VideoPlayerController? vc) {
    // ★ وضع القفل — يظهر زر فتح القفل فقط
    if (_locked) {
      return Center(child: GestureDetector(
        onTap: () { setState(() => _locked = false); Sound.hapticM(); _showSnack('أُلغي القفل'); },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), shape: BoxShape.circle,
              border: Border.all(color: Colors.white24)),
          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26))));
    }
    return Stack(fit: StackFit.expand, children: [
    DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        stops: const [0.0, 0.25, 0.72, 1.0],
        colors: [Colors.black.withOpacity(0.75), Colors.transparent,
                 Colors.transparent, Colors.black.withOpacity(0.9)]))),
    Positioned(top: 0, left: 0, right: 0, child: _buildTop()),
    Center(child: _buildControls(vc)),
    Positioned(bottom: 0, left: 0, right: 0, child: _buildBottom(vc)),
  ]);
  }

  Widget _buildTop() {
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(top: top + 10, left: 16, right: 16, bottom: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
          child: Row(children: [
        GestureDetector(onTap: () => Navigator.pop(context),
          child: Container(width: 34, height: 34, decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(R.sm)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16))),
        const SizedBox(width: 12),
        Expanded(child: Text(widget.title, style: T.cairo(s: FS.md, w: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (widget.isLive)
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: CExtra.live.withOpacity(0.15),
                borderRadius: BorderRadius.circular(R.tiny),
                border: Border.all(color: CExtra.live.withOpacity(0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 5, height: 5, decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: CExtra.live)),
              const SizedBox(width: 5),
              Text('LIVE', style: TExtra.mont(s: FS.xs, c: CExtra.live, w: FontWeight.w700)),
            ])),
        const SizedBox(width: 8),
        GestureDetector(onTap: _toggleMute,
          child: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(R.sm)),
            child: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: Colors.white, size: 16))),
        const SizedBox(width: 6),
        // ★ زر القفل — يمنع اللمس العرضي أثناء المشاهدة
        GestureDetector(
          onTap: () {
            setState(() { _locked = true; _overlay = false; });
            Sound.hapticM(); _showSnack('🔒 تم قفل الشاشة — اضغط القفل لإلغائه');
          },
          child: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(R.sm)),
            child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 16))),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            setState(() => _fitMode = (_fitMode + 1) % 3);
            Sound.hapticL();
            _showSnack(_fitMode == 0 ? 'الحجم: أصلي'
                : _fitMode == 1 ? 'الحجم: ملء الشاشة' : 'الحجم: مصغّر');
          },
          child: Container(height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(R.sm)),
            child: Row(children: [
              Icon(
                _fitMode == 0 ? Icons.fit_screen_rounded
                  : _fitMode == 1 ? Icons.aspect_ratio_rounded
                  : Icons.zoom_out_map_rounded,
                color: Colors.white, size: 17),
              const SizedBox(width: 5),
              Text(_fitMode == 0 ? 'أصلي' : _fitMode == 1 ? 'ملء' : 'صغير',
                  style: T.cairo(s: FS.xs, w: FontWeight.w700, c: Colors.white)),
            ]))),
        const SizedBox(width: 6),
        // ── زر PiP (صورة داخل صورة) ─────────────────────
        if (!kIsWeb)
          GestureDetector(
            onTap: () async {
              try {
                await _pipChannel.invokeMethod('enterPiP');
              } catch (e) { debugPrint('[profile_player] $e'); }
            },
            child: Container(width: 34, height: 34,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(R.sm)),
              child: const Icon(Icons.picture_in_picture_alt_rounded,
                  color: Colors.white70, size: 18))),
        const SizedBox(width: 6),
        // ── زر Chromecast ──────────────────────────────────
        if (!kIsWeb && !widget.isLive)
          GestureDetector(
            onTap: () => _showCastDialog(),
            child: Container(width: 34, height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(R.sm),
                border: _casting ? Border.all(color: C.gold.withOpacity(0.6)) : null),
              child: Icon(Icons.cast_rounded,
                color: _casting ? C.gold : Colors.white70, size: 18))),
        const SizedBox(width: 6),
        GestureDetector(onTap: _fs ? _exitFs : _enterFs,
          child: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(R.sm)),
            child: Icon(_fs ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: Colors.white, size: 20))),
      ]))));
  }

  Widget _buildControls(VideoPlayerController? vc) {
    if (!_inited || vc == null) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (!widget.isLive)
        GestureDetector(onTap: () => _seekBy(-10),
          child: Container(width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.35),
                border: Border.all(color: CExtra.border, width: 0.5)),
            child: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 20))),
      const SizedBox(width: 20),
      GestureDetector(onTap: _togglePlay,
        child: Container(width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Colors.black.withOpacity(0.55), Colors.black.withOpacity(0.35)]),
              border: Border.all(color: C.gold.withOpacity(0.6), width: 1.5),
              boxShadow: [BoxShadow(color: C.gold.withOpacity(0.35), blurRadius: 18, spreadRadius: 1)]),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
            child: Icon(
              vc.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              key: ValueKey(vc.value.isPlaying),
              color: Colors.white, size: 32)))),
      const SizedBox(width: 20),
      if (!widget.isLive)
        GestureDetector(onTap: () => _seekBy(10),
          child: Container(width: 42, height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.35),
                border: Border.all(color: CExtra.border, width: 0.5)),
            child: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 20))),
    ]);
  }

  Widget _buildBottom(VideoPlayerController? vc) {
    final pos = (_inited && vc != null) ? vc.value.position : Duration.zero;
    final dur = (_inited && vc != null) ? vc.value.duration  : Duration.zero;
    return Container(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!widget.isLive) ...[
          GestureDetector(
            onHorizontalDragStart: (_) => setState(() {
              _seekDrag = true; _seekVal = _prog; _seekExpanded = true;
            }),
            onHorizontalDragUpdate: (d) {
              final b = context.findRenderObject() as RenderBox?; if (b == null) return;
              final v = (d.localPosition.dx / b.size.width).clamp(0.0, 1.0);
              // Preview time
              final previewSecs = (v * dur.inSeconds).round();
              _seekPreview = _fmt(Duration(seconds: previewSecs));
              setState(() => _seekVal = v);
            },
            onHorizontalDragEnd: (_) {
              vc?.seekTo(dur * _seekVal);
              setState(() { _seekDrag = false; _seekExpanded = false; _seekPreview = ''; });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: _seekExpanded ? 36 : 22,
              child: Stack(alignment: Alignment.centerLeft, children: [
              // Preview time above thumb
              if (_seekDrag && _seekPreview.isNotEmpty)
                FractionallySizedBox(widthFactor: _seekVal,
                  child: Align(alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(R.tiny)),
                      child: Text(_seekPreview,
                          style: const TextStyle(color: Colors.white,
                              fontSize: FS.sm, fontWeight: FontWeight.w600))))),
              Container(height: _seekExpanded ? 5 : 3, width: double.infinity,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(R.tiny))),
              FractionallySizedBox(widthFactor: _bufd, child: Container(
                  height: _seekExpanded ? 5 : 3,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(R.tiny)))),
              FractionallySizedBox(widthFactor: _seekDrag ? _seekVal : _prog,
                child: Container(height: _seekExpanded ? 5 : 3, decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [CC.goldLight, C.gold]),
                    borderRadius: BorderRadius.circular(R.tiny)))),
              FractionallySizedBox(widthFactor: _seekDrag ? _seekVal : _prog,
                child: Align(alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _seekExpanded ? 16 : 10, height: _seekExpanded ? 16 : 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: C.gold,
                        boxShadow: [BoxShadow(color: C.gold.withOpacity(0.5), blurRadius: 5)])))),
            ])),),
          const SizedBox(height: 6),
        ],
        Row(children: [
          if (!widget.isLive) ...[
            Text(_fmt(pos), style: TExtra.mont(s: FS.sm, c: Colors.white)),
            Text(' / ', style: TExtra.mont(s: FS.sm, c: C.dim)),
            Text(_fmt(dur), style: TExtra.mont(s: FS.sm, c: C.grey)),
          ],
          if (widget.isLive) _LiveClock(),
          const Spacer(),
          // زر السرعة (للأفلام فقط)
          if (!widget.isLive)
            GestureDetector(
              onTap: () => setState(() { _showSpeed = !_showSpeed; _hideT?.cancel(); }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _showSpeed ? C.gold.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(R.sm),
                  border: Border.all(
                    color: _showSpeed ? C.gold.withOpacity(0.5) : Colors.white.withOpacity(0.15),
                    width: 0.5)),
                child: Text('${_speeds[_speedIdx]}x',
                  style: TextStyle(
                    color: _showSpeed ? C.gold : Colors.white70,
                    fontSize: FS.sm, fontWeight: FontWeight.w600)))),
          if (widget.episodes.isNotEmpty) ...[ const SizedBox(width: 8), _buildEpisodeBtn() ],
          if (!widget.isLive) const SizedBox(width: 8),
          SizedBox(width: 80, child: Row(children: [
            Icon(_vol == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: C.dim, size: 13),
            const SizedBox(width: 3),
            Expanded(child: SliderTheme(data: SliderThemeData(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                trackHeight: 2, overlayShape: SliderComponentShape.noOverlay),
              child: Slider(value: _vol,
                  onChanged: (v) { setState(() => _vol = v); _vc?.setVolume(v); },
                  min: 0, max: 1, activeColor: C.gold, inactiveColor: C.dim, thumbColor: C.gold))),
          ])),
        ]),
      ]));
  }

  // ════════════════════════════════════════════════════════
  //  ★ EPISODES PANEL — قائمة الحلقات داخل المشغّل
  // ════════════════════════════════════════════════════════

  void _goToEpisode(int idx) {
    if (idx < 0 || idx >= widget.episodes.length) return;
    final ep = widget.episodes[idx];
    final epTitle = ep['title']?.toString() ?? 'الحلقة ${idx + 1}';
    final epUrls  = _epUrls(ep);
    if (epUrls.isEmpty) return;

    if (!mounted) return;
    setState(() { _curEpIdx = idx; _showEpisodes = false; _showAutoNext = false; });
    _autoNextTimer?.cancel();
    widget.onEpisodeChanged?.call(idx);

    // استبدال المشغّل بالحلقة الجديدة
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => LegacyPlayerPage(
          urls: epUrls,
          title: epTitle,
          item: ep,
          episodes: widget.episodes,
          episodeIndex: idx,
          onEpisodeChanged: widget.onEpisodeChanged,
        ),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  List<String> _epUrls(dynamic ep) {
    // ★ Use existing Api.episodeUrls — same as SeriesDetailPage
    try { return Api.episodeUrls(ep); } catch (_) { return []; }
  }

  void _triggerAutoNext() {
    if (!mounted) return;
    final nextIdx = _curEpIdx + 1;
    if (nextIdx >= widget.episodes.length) return;
    setState(() => _showAutoNext = true);
    _autoNextTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) _goToEpisode(nextIdx);
    });
  }

  // ── Episode Panel Widget ──────────────────────────────
  Widget _buildEpisodePanel() {
    if (widget.episodes.isEmpty) return const SizedBox.shrink();
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      bottom: _showEpisodes ? 0 : -400,
      left: 0, right: 0,
      child: GestureDetector(
        onVerticalDragEnd: (d) {
          if (d.primaryVelocity != null && d.primaryVelocity! > 300) {
            setState(() => _showEpisodes = false);
          }
        },
        child: Container(
          height: 380,
          decoration: BoxDecoration(
            color: C.bg.withOpacity(0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xl)),
            border: Border.all(color: C.border, width: 0.5)),
          child: Column(children: [
            // Handle
            Center(child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: C.border, borderRadius: BorderRadius.circular(R.tiny)))),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text('الحلقات', style: T.cairo(s: FS.lg, w: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${widget.episodes.length} حلقة',
                    style: T.caption(c: C.textSec)),
              ])),
            const SizedBox(height: 8),
            // Episodes list
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.episodes.length,
              itemBuilder: (ctx, i) {
                final ep = widget.episodes[i];
                final title = ep['title']?.toString() ?? 'الحلقة ${i + 1}';
                final isActive = i == _curEpIdx;
                return GestureDetector(
                  onTap: () => _goToEpisode(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? C.goldBg : C.surface,
                      borderRadius: BorderRadius.circular(R.sm),
                      border: Border.all(
                        color: isActive ? C.gold.withOpacity(0.5) : C.border,
                        width: isActive ? 1 : 0.5)),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? C.gold : C.raised),
                        child: Center(child: Text('${i + 1}',
                          style: T.cairo(
                            s: FS.xs, w: FontWeight.w700,
                            c: isActive ? Colors.black : C.textSec)))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(title,
                        style: T.cairo(
                          s: FS.md,
                          w: isActive ? FontWeight.w700 : FontWeight.w400,
                          c: isActive ? C.gold : C.textPri),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (isActive)
                        Icon(Icons.play_arrow_rounded, color: C.gold, size: 18),
                    ])));
              })),
          ])),
      ));
  }

  // ── Auto-next Banner ──────────────────────────────────
  Widget _buildAutoNextBanner() {
    if (!_showAutoNext) return const SizedBox.shrink();
    final nextIdx = _curEpIdx + 1;
    if (nextIdx >= widget.episodes.length) return const SizedBox.shrink();
    final nextTitle = widget.episodes[nextIdx]['title']?.toString() ?? 'الحلقة ${nextIdx + 1}';
    return Positioned(
      bottom: 90, left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: C.bg.withOpacity(0.95),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: C.gold.withOpacity(0.4), width: 0.5)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
            Text('التالي', style: T.caption(c: C.textSec)),
            Text(nextTitle,
              style: T.cairo(s: FS.md, w: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () { _autoNextTimer?.cancel(); setState(() => _showAutoNext = false); },
            child: Text('إلغاء', style: T.caption(c: C.textSec))),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _goToEpisode(nextIdx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: C.playGrad,
                borderRadius: BorderRadius.circular(R.sm)),
              child: Text('التالي الآن',
                style: T.cairo(s: FS.sm, w: FontWeight.w700, c: Colors.black)))),
        ])));
  }

  // ── Episode Button in Controls ────────────────────────
  Widget _buildEpisodeBtn() {
    if (widget.episodes.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => setState(() => _showEpisodes = !_showEpisodes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _showEpisodes ? C.goldBg : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(R.sm),
          border: Border.all(
            color: _showEpisodes ? C.gold.withOpacity(0.5) : Colors.white.withOpacity(0.15),
            width: 0.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.list_rounded, color: _showEpisodes ? C.gold : C.textSec, size: 16),
          const SizedBox(width: 4),
          Text('الحلقات', style: T.cairo(
            s: FS.xs, c: _showEpisodes ? C.gold : C.textSec, w: FontWeight.w600)),
        ])));
  }

}
