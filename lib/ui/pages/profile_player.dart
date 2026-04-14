part of '../../main.dart';


// ════════════════════════════════════════════════════════════
//  STATS PAGE — إحصائيات المشاهدة
// ════════════════════════════════════════════════════════════
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final history = WatchHistory.recentHistory.take(100).toList();
    // حساب إجمالي وقت المشاهدة من progress المحفوظة
    int totalSecs = 0;
    for (final h in history) {
      final posMs = WatchHistory.getProgressMs(h['id']?.toString() ?? '');
      totalSecs += posMs ~/ 1000;
    }
    final hours   = totalSecs ~/ 3600;
    final minutes = (totalSecs % 3600) ~/ 60;
    final movies  = history.where((h) => h['type'] == 'movie').length;
    final series  = history.where((h) => h['type'] == 'series').length;
    final live    = history.where((h) => h['type'] == 'live').length;
    final favs    = WL.all.length;
    if (mounted) setState(() {
      _stats = {
        'hours': hours, 'minutes': minutes,
        'movies': movies, 'series': series, 'live': live,
        'total': history.length, 'favs': favs,
      };
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: Text('إحصائياتي', style: TExtra.h2())),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.gold))
          : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
              // Watch Time Hero
              Container(
                width: double.infinity, padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [C.gold.withOpacity(0.15), Colors.transparent]),
                  borderRadius: BorderRadius.circular(R.md),
                  border: Border.all(color: C.gold.withOpacity(0.3)),
                ),
                child: Column(children: [
                  Text('وقت المشاهدة الكلي', style: T.caption()),
                  const SizedBox(height: 8),
                  Text('${_stats['hours']}س ${_stats['minutes']}د',
                      style: TExtra.display(c: C.gold).copyWith(fontSize: FS.x3l)),
                ]),
              ),
              const SizedBox(height: 16),
              // Stats Grid
              GridView.count(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.8,
                children: [
                  _statCard('🎬', 'أفلام شاهدتها', '${_stats['movies']}', CC.info),
                  _statCard('📺', 'مسلسلات', '${_stats['series']}', CExtra.live),
                  _statCard('📡', 'قنوات مباشرة', '${_stats['live']}', CC.success),
                  _statCard('❤️', 'المفضلة', '${_stats['favs']}', C.gold),
                ],
              ),
              const SizedBox(height: 16),
              // Last Watched
              if (WatchHistory.recentHistory.isNotEmpty) ...[
                Align(alignment: Alignment.centerRight,
                    child: Text('آخر ما شاهدت', style: TExtra.h2())),
                const SizedBox(height: 10),
                ...WatchHistory.recentHistory.take(5).map((h) {
                  final pct = WatchHistory.getPercent(h['id']?.toString() ?? '', 0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md)),
                    child: Row(children: [
                      const Icon(Icons.play_circle_outline_rounded, color: C.gold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(h['name']?.toString() ?? '', style: T.cairo(s: FS.sm, w: FontWeight.w600), maxLines: 1),
                        if (pct > 0)
                          LinearProgressIndicator(value: pct, backgroundColor: CExtra.border, color: C.gold, minHeight: 2),
                      ])),
                      Text('${(pct * 100).round()}%', style: T.caption(c: C.gold)),
                    ]),
                  );
                }),
              ],
            ])),
    );
  }

  Widget _statCard(String emoji, String label, String value, Color color) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: FS.xl)),
        const SizedBox(height: 4),
        Text(value, style: TExtra.mont(s: FS.xl, w: FontWeight.w700, c: color)),
        Text(label, style: T.caption(), textAlign: TextAlign.center),
      ]),
    );
}


// ─────────────────────────────────────────────────────────
class _QualityLevel {
  final String label;
  final String ext;
  const _QualityLevel(this.label, this.ext);
}


class PlayerPage extends StatefulWidget {
  final List<String> urls;
  final String title;
  final bool isLive;
  final dynamic item; // للبحث عن الرابط تلقائياً
  const PlayerPage({required this.urls, required this.title, this.isLive = false, this.item});
  @override State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TickerProviderStateMixin {
  VideoPlayerController? _vc;

  late final AnimationController _ov, _sp;
  late final Animation<double> _ovAn;

  bool _inited = false, _err = false, _buf = true;
  bool _overlay = true, _fs = true, _muted = false;
  double _vol = 1.0, _brightness = 1.0;
  bool _seekDrag = false; double _seekVal = 0;
  bool _volDrag = false, _brightDrag = false;
  double _gestY = 0;
  String _errMsg = '';
  int _urlIdx = 0;
  static const _maxR = 4;
  Timer? _hideT;

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
  bool _fitContain = true; // true = حجم أصلي، false = fullscreen

  // ── Speed Control ───────────────────────────────────────
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
  int _speedIdx = 2; // 1.0x default
  bool _showSpeed = false;

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
    _ov = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _sp = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _ovAn = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ov, curve: Curves.easeOut));

    if (!kIsWeb) WakelockPlus.enable();
    _enterFs();
    SecurityLayer.enableScreenRecord();
    _ov.forward(); _schedHide();

    // العلامة المائية تتنقل كل 30 ثانية
    _wmTimer = Timer.periodic(const Duration(seconds: FS.x3l), (_) {
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
        final id = widget.item['stream_id']?.toString() ??
                   widget.item['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          final base = SubCompat.isTOTV && SubCompat.xtreamUser.isNotEmpty
              ? SubCompat.xtreamBase.replaceAll(RegExp(r'/$'), '')
              : RCCompat.serverUrl.replaceAll(RegExp(r'/$'), '');
          final user = SubCompat.isTOTV && SubCompat.xtreamUser.isNotEmpty ? SubCompat.xtreamUser : RCCompat.username;
          final pass = SubCompat.isTOTV && SubCompat.xtreamUser.isNotEmpty ? SubCompat.xtreamPass : RCCompat.password;
          // جرّب امتدادات مختلفة
          for (final ext in ['mp4', 'ts', 'm3u8', 'mkv']) {
            final url = '$base/movie/$user/$pass/$id.$ext';
            _init(url);
            return;
          }
        }
      } catch (e) { debugPrint('[profile_player] $e'); }
      setState(() { _err = true; _buf = false; _errMsg = 'لم يُعثر على رابط تشغيل'; });
    }
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
        setState(() { _vc = vc; _inited = true; _buf = false; });
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
    if (vc.value.hasError && !_err) setState(() { _err = true; _buf = false; _errMsg = vc.value.errorDescription ?? ''; });
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
    // لا تُظهر خطأ — أظهر رسالة واضحة
    String msg;
    if (r.toLowerCase().contains('timeout')) msg = 'انتهت مهلة الاتصال — تحقق من الإنترنت';
    else if (r.contains('404')) msg = 'المحتوى غير متاح حالياً';
    else if (r.contains('403')) msg = 'انتهت صلاحية الرابط';
    else msg = 'تعذّر تشغيل المحتوى';
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
      await newVc.initialize().timeout(const Duration(seconds: FS.xl));
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
        backgroundColor: const C.card,
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
    _wmTimer?.cancel();
    _progressTimer?.cancel();
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
    if (!TVLayout.isTV) return scaffold;
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
          Text('تعذّر التشغيل', style: T.cairo(s: FS.lg, w: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_errMsg, style: T.body(c: C.grey), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('تحقق من اتصالك بالإنترنت', style: T.caption(c: C.dim)),
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
              onTap: () { setState(() { _err = false; _buf = true; _urlIdx = 0; });
                  _init(widget.urls.isNotEmpty ? widget.urls.first : ''); },
              child: Container(height: 44,
                decoration: BoxDecoration(
                  gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.refresh_rounded, color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Text('إعادة المحاولة', style: T.cairo(s: FS.md, c: Colors.black, w: FontWeight.w800)),
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
                  color: const C.goldBg,
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
          // رابط واتساب
          if (SubCompat.whatsapp.isNotEmpty)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://wa.me/${SubCompat.whatsapp}')),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.headset_mic_rounded, color: C.whatsapp, size: 14),
                const SizedBox(width: 6),
                Text('تواصل مع الدعم الفني', style: T.caption(c: const C.whatsapp)),
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
      onTap: _toggleOv,
      onDoubleTapDown: (d) => _seekBy(d.globalPosition.dx < context.size!.width / 2 ? -10 : 10),
      // سحب رأسي: يمين = صوت، يسار = سطوع، وسط = تجسيم بصري
      onVerticalDragStart: (d) {
        _gestY     = d.localPosition.dy;
        _volDrag   = d.localPosition.dx > context.size!.width * 0.65;
        _brightDrag= d.localPosition.dx < context.size!.width * 0.35;
      },
      onVerticalDragUpdate: (d) {
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
                child: _fitContain
                  // حجم أصلي — لا قص للأطراف
                  ? AspectRatio(
                      aspectRatio: vidW / vidH,
                      child: VideoPlayer(vc))
                  // fullscreen — يملأ الشاشة
                  : FittedBox(fit: BoxFit.cover,
                      child: SizedBox(width: vidW, height: vidH,
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
      onTap: () {},
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
      backgroundColor: const C.card,
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

  Widget _buildOverlay(VideoPlayerController? vc) => Stack(fit: StackFit.expand, children: [
    DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        stops: const [0.0, 0.25, 0.72, 1.0],
        colors: [Colors.black.withOpacity(0.75), Colors.transparent,
                 Colors.transparent, Colors.black.withOpacity(0.9)]))),
    Positioned(top: 0, left: 0, right: 0, child: _buildTop()),
    Center(child: _buildControls(vc)),
    Positioned(bottom: 0, left: 0, right: 0, child: _buildBottom(vc)),
  ]);

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
        // زر الجودة
        GestureDetector(
          onTap: () => setState(() { _showQuality = !_showQuality; _showSpeed = false; _hideT?.cancel(); }),
          child: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(R.sm)),
            child: Icon(Icons.hd_rounded, color: _showQuality ? C.gold : Colors.white, size: 18))),
        const SizedBox(width: 6),
        // زر تبديل الحجم (أصلي / ملء شاشة)
        GestureDetector(
          onTap: () { setState(() => _fitContain = !_fitContain); Sound.hapticL(); },
          child: Container(width: 34, height: 34,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(R.sm)),
            child: Icon(
              _fitContain ? Icons.fit_screen_rounded : Icons.crop_rounded,
              color: Colors.white, size: 18))),
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
        child: Container(width: 58, height: 58,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.5),
              border: Border.all(color: C.gold.withOpacity(0.5), width: 1.5)),
          child: Icon(vc.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white, size: 28))),
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
}


// ══════════════════════════════════════════════════════════════
//  MICRO WIDGETS
// ══════════════════════════════════════════════════════════════

class _Pulse extends StatefulWidget {
  final String label;
  _Pulse({required this.label});
  @override State<_Pulse> createState() => _PulseState();
}
class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    AnimatedBuilder(animation: _a, builder: (_, __) => Container(width: 56, height: 56,
      decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: C.gold.withOpacity(0.2 + _a.value * 0.6), width: 1.2)),
      child: Center(child: Text('T', style: TExtra.cinzel(s: FS.xl,
          c: C.gold.withOpacity(0.4 + _a.value * 0.55)))))),
    const SizedBox(height: 14),
    Text('جاري التحميل...', style: TExtra.mont(s: FS.sm, c: C.grey.withOpacity(0.6))),
  ]);
}

class _CounterBar extends StatelessWidget {
  final String label;
  _CounterBar({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [CC.goldLight, CC.goldDark]), borderRadius: BorderRadius.circular(R.tiny))),
    const SizedBox(width: 8),
    Text(label, style: TExtra.mont(s: FS.sm, c: C.gold, w: FontWeight.w600, ls: 1)),
  ]);
}

class _AppHdr extends StatelessWidget {
  final double top; final String title; final VoidCallback onRefresh;
  _AppHdr({required this.top, required this.title, required this.onRefresh});
  @override
  Widget build(BuildContext context) => Container(
    height: 52 + top, padding: EdgeInsets.only(top: top, left: 16, right: 16),
    decoration: const BoxDecoration(color: Color(0xF5000000),
        border: Border(bottom: BorderSide(color: C.card, width: 0.5))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text('TOTV+', style: TExtra.cinzel(s: FS.md, c: C.gold).copyWith(letterSpacing: 2)),
      const SizedBox(width: 10),
      Text(title, style: T.cairo(s: FS.lg, w: FontWeight.w700)),
      const Spacer(),
      if (!SubCompat.isPremium)
        GestureDetector(
          onTap: () => Navigator.push(context, _fade(const ProfilePage())),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.sm)),
            child: Text('اشتراك', style: T.cairo(s: FS.sm, c: Colors.black, w: FontWeight.w800)))),
      const SizedBox(width: 8),
      GestureDetector(onTap: onRefresh,
        child: Container(width: 32, height: 32,
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.sm),
              border: Border.all(color: CExtra.border, width: 0.5)),
          child: const Icon(Icons.refresh_rounded, color: C.grey, size: 16))),
    ]));
}

class _Chip extends StatelessWidget {
  final String label; final bool sel; final VoidCallback onTap;
  _Chip({required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: sel ? C.gold : C.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: sel ? C.gold : CExtra.border, width: sel ? 0 : 0.5)),
      child: Text(label, style: T.cairo(s: FS.sm, c: sel ? Colors.black : C.grey,
          w: sel ? FontWeight.w700 : FontWeight.w400))));
}

class _TagW extends StatelessWidget {
  final String text;
  const _TagW(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: CC.goldBg, borderRadius: BorderRadius.circular(R.tiny),
        border: Border.all(color: CC.goldDark.withOpacity(0.35), width: 0.5)),
    child: Text(text, style: TExtra.mont(s: FS.xs, c: C.gold, w: FontWeight.w600)));
}

// ── LiveBadge ────────────────────────────────────────────────
class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: CExtra.live, borderRadius: BorderRadius.circular(R.sm)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5, margin: const EdgeInsets.only(left: 4),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
      Text('LIVE', style: TExtra.mont(s: FS.xs, c: Colors.white, w: FontWeight.w700)),
    ]));
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl; final ValueChanged<String> onChanged;
  _SearchBar({required this.ctrl, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(height: 42,
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: CExtra.border, width: 0.5)),
    child: Row(children: [
      const SizedBox(width: 12),
      Icon(Icons.search_rounded, color: C.gold.withOpacity(0.4), size: 18),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: ctrl, onChanged: onChanged,
          textDirection: TextDirection.rtl, style: T.cairo(s: FS.md),
          decoration: InputDecoration(hintText: 'ابحث...',
              hintStyle: T.cairo(s: FS.md, c: C.dim), border: InputBorder.none, isDense: true))),
    ]));
}

class _Tile extends StatelessWidget {
  final IconData icon; final String title, value;
  const _Tile(this.icon, this.title, this.value);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: CExtra.border, width: 0.5)),
    child: Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: CC.goldBg,
          borderRadius: BorderRadius.circular(R.sm)),
        child: Icon(icon, color: C.gold, size: 16)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TExtra.mont(s: FS.sm, c: C.grey)),
        const SizedBox(height: 2),
        Text(value, style: T.cairo(s: FS.sm, w: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]));
}

class _LiveDot extends StatefulWidget {
  @override State<_LiveDot> createState() => _LiveDotState();
}
class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _a = Tween<double>(begin: 0.4, end: 1.0).animate(_c);
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _a,
    builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle,
          color: CExtra.live.withOpacity(_a.value))),
      const SizedBox(width: 4),
      Text('مباشر', style: TExtra.mont(s: FS.sm, c: CExtra.live, w: FontWeight.w700)),
    ]));
}

class _LiveClock extends StatefulWidget {
  @override State<_LiveClock> createState() => _LiveClockState();
}
class _LiveClockState extends State<_LiveClock> {
  late Timer _t; late DateTime _now;
  @override void initState() {
    super.initState();
    _now = DateTime.now();
    _t = Timer.periodic(const Duration(seconds: 1),
        (_) { if (mounted) setState(() => _now = DateTime.now()); });
  }
  @override void dispose() { _t.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Text(
    '${_now.hour.toString().padLeft(2,'0')}:${_now.minute.toString().padLeft(2,'0')}:${_now.second.toString().padLeft(2,'0')}',
    style: TExtra.mont(s: FS.sm, c: Colors.white));
}

// ══════════════════════════════════════════════════════════════
//  _AutoPageView — بديل لـ CarouselWidget بـ PageView مدمج
//  لا يحتاج package خارجي — يتجنب تعارض CarouselController
// ══════════════════════════════════════════════════════════════
class _AutoPageView extends StatefulWidget {
  final int itemCount;
  final Duration interval;
  final ValueChanged<int>? onPageChanged;
  final Widget Function(BuildContext, int) itemBuilder;
  final double? height;
  _AutoPageView({
    required this.itemCount,
    required this.itemBuilder,
    this.interval = const Duration(seconds: 5),
    this.onPageChanged,
    this.height,
  });
  @override State<_AutoPageView> createState() => _AutoPageViewState();
}

class _AutoPageViewState extends State<_AutoPageView> {
  late final PageController _pc;
  Timer? _timer;
  int _cur = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
    if (widget.itemCount > 1) {
      _timer = Timer.periodic(widget.interval, (_) {
        if (!mounted) return;
        final int next = (_cur + 1) % widget.itemCount;
        _pc.animateToPage(next,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = PageView.builder(
      controller: _pc,
      itemCount: widget.itemCount,
      onPageChanged: (i) {
        _cur = i;
        widget.onPageChanged?.call(i);
      },
      itemBuilder: widget.itemBuilder,
    );
    return widget.height != null
        ? SizedBox(height: widget.height, child: view)
        : view;
  }
}

class _BlurredBackground extends StatelessWidget {
  final VideoPlayerController controller;
  final double vidW, vidH;
  _BlurredBackground({required this.controller, required this.vidW, required this.vidH});
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    FittedBox(fit: BoxFit.cover,
        child: SizedBox(width: vidW, height: vidH, child: VideoPlayer(controller))),
    BackdropFilter(filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(color: Colors.black.withOpacity(0.45))),
  ]);
}

// ── Helpers ────────────────────────────────────────────────
Route _fade(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, a, __, c) {
    // Slide up + fade — مثل iOS
    final slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic));
    final fade = CurvedAnimation(parent: a, curve: Curves.easeOut);
    return FadeTransition(opacity: fade,
        child: SlideTransition(position: slide, child: c));
  },
  transitionDuration: const Duration(milliseconds: 320));


// ═══════════════════════════════════════════ END TOTV+ v12.0 ═══════════════════════════════════


// ═══════════════════════════════════════════════════════════════
//  FIREBASE AUTH SERVICE — إدارة مركزية للمصادقة
// ═══════════════════════════════════════════════════════════════
class AuthService {
  static final _auth   = FirebaseAuth.instance;
  static final _db     = FirebaseFirestore.instance;
  static final _google = GoogleSignIn(scopes: ['email', 'profile']);

  static String? _verificationId;
  static int?    _resendToken;
  static String  _phoneNumber = '';

  // ════════════════════════════════════════════════════════
  //  FIX 1 — isAdmin حقيقي من Firestore
  //  مستمع منفصل خفيف — لا يُسبب حلقة مفرغة
  // ════════════════════════════════════════════════════════
  static bool _isAdminCached = false;
  static StreamSubscription<DocumentSnapshot>? _adminSub;

  // Stream لإخبار الـ UI بالتغيير فوراً
  static final _adminCtrl = StreamController<bool>.broadcast();
  static Stream<bool> get adminStream => _adminCtrl.stream;

  // ── Getters ──────────────────────────────────────────────
  static User? get currentUser => _auth.currentUser;
  static bool  get isLoggedIn  => currentUser != null;
  static bool  get isAdmin     => _isAdminCached;
  static Stream<User?> get authChanges => _auth.authStateChanges();

  /// يستمع لتغييرات is_admin/role فقط — لا يلمس الاشتراك
  static void startAdminListener(String uid) {
    _adminSub?.cancel();
    _adminSub = _db.collection('users').doc(uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final d = snap.data()!;
      final v = d['is_admin'] == true ||
                d['role']?.toString() == 'admin' ||
                _isAdminEmail(currentUser?.email);
      if (v != _isAdminCached) {
        _isAdminCached = v;
        _adminCtrl.add(v);
        debugPrint('AuthService: isAdmin=$v');
      }
    }, onError: (_) {});
  }

  static void stopAdminListener() {
    _adminSub?.cancel();
    _adminSub = null;
    _isAdminCached = false;
    _adminCtrl.add(false);
  }

  static bool _isAdminEmail(String? e) {
    if (e == null) return false;
    return e.endsWith('@totv.com') ||
        e == 'admin@totv.com' ||
        e == 'haedirasso@gmail.com';
  }

  // ════════════════════════════════════════════════════════
  //  تسجيل الدخول
  // ════════════════════════════════════════════════════════
  static Future<AuthResult> signInEmail(String email, String pass) async {
    try {
      final c = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: pass.trim());
      await _trackLogin('email', c.user);
      return AuthResult.ok(c.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.err(_msg(e.code));
    } catch (_) {
      return AuthResult.err('حدث خطأ غير متوقع');
    }
  }

  static Future<AuthResult> registerEmail(String email, String pass, String name) async {
    try {
      final c = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: pass.trim());
      await c.user?.updateDisplayName(name.trim());
      await c.user?.reload();
      await _trackLogin('register', c.user);
      return AuthResult.ok(_auth.currentUser!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.err(_msg(e.code));
    }
  }

  static Future<AuthResult> signInGoogle() async {
    try {
      final acc = await _google.signIn();
      if (acc == null) return AuthResult.err('تم الإلغاء');
      final auth = await acc.authentication;
      final cred = GoogleAuthProvider.credential(
          accessToken: auth.accessToken, idToken: auth.idToken);
      final uc = await _auth.signInWithCredential(cred);
      await _trackLogin('google', uc.user);
      return AuthResult.ok(uc.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.err(_msg(e.code));
    } catch (_) {
      return AuthResult.err('فشل تسجيل الدخول بـ Google');
    }
  }

  static Future<AuthResult> signInFacebook() async {
    try {
      final provider = OAuthProvider('facebook.com');
      provider.addScope('email');
      provider.addScope('public_profile');
      provider.setCustomParameters({'display': 'popup'});
      UserCredential uc;
      if (kIsWeb) {
        uc = await _auth.signInWithPopup(provider);
      } else {
        uc = await _auth.signInWithProvider(provider);
      }
      await _trackLogin('facebook', uc.user);
      return AuthResult.ok(uc.user!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        return AuthResult.err('هذا البريد مرتبط بطريقة تسجيل أخرى');
      }
      return AuthResult.err(_msg(e.code));
    } catch (_) {
      return AuthResult.err('فشل تسجيل الدخول بـ Facebook');
    }
  }

  static Future<AuthResult> sendPhoneOTP(String phone, {
    void Function(String, int?)? onCodeSent,
    void Function(PhoneAuthCredential)? onAutoVerify,
    void Function(String)? onError,
  }) async {
    if (phone.trim().isEmpty) return AuthResult.err('أدخل رقم الهاتف');
    _phoneNumber = phone.trim();
    if (!_phoneNumber.startsWith('+')) _phoneNumber = '+$_phoneNumber';
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential cred) async {
          try {
            final uc = await _auth.signInWithCredential(cred);
            await _trackLogin('phone_auto', uc.user);
            onAutoVerify?.call(cred);
          } catch (e) { debugPrint('[profile_player] $e'); }
        },
        verificationFailed: (e) => onError?.call(_msg(e.code)),
        codeSent: (vid, token) {
          _verificationId = vid;
          _resendToken    = token;
          onCodeSent?.call(vid, token);
        },
        codeAutoRetrievalTimeout: (vid) => _verificationId = vid,
      );
      return AuthResult.ok(null, msg: 'تم إرسال الكود');
    } on FirebaseAuthException catch (e) {
      return AuthResult.err(_msg(e.code));
    } catch (_) {
      return AuthResult.err('فشل إرسال الكود — تأكد من الرقم');
    }
  }

  static Future<AuthResult> verifyPhoneOTP(String smsCode) async {
    if (smsCode == 'AUTO') {
      final u = _auth.currentUser;
      return u != null ? AuthResult.ok(u) : AuthResult.err('فشل التحقق التلقائي');
    }
    if (_verificationId == null) return AuthResult.err('أعد إرسال الكود أولاً');
    if (smsCode.trim().length < 6) return AuthResult.err('أدخل الكود المكوّن من 6 أرقام');
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: smsCode.trim());
      final uc = await _auth.signInWithCredential(cred);
      if (uc.user?.displayName == null || uc.user!.displayName!.isEmpty) {
        await uc.user?.updateDisplayName(_phoneNumber);
        await uc.user?.reload();
      }
      await _trackLogin('phone', _auth.currentUser);
      _verificationId = null;
      return AuthResult.ok(_auth.currentUser!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        return AuthResult.err('الكود غير صحيح — تأكد وأعد المحاولة');
      }
      return AuthResult.err(_msg(e.code));
    } catch (_) {
      return AuthResult.err('فشل التحقق — حاول مجدداً');
    }
  }

  static Future<AuthResult> resendPhoneOTP({
    void Function(String, int?)? onCodeSent,
    void Function(String)? onError,
  }) => sendPhoneOTP(_phoneNumber, onCodeSent: onCodeSent, onError: onError);

  static Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.ok(null, msg: 'تم إرسال رابط إعادة التعيين إلى بريدك');
    } on FirebaseAuthException catch (e) {
      return AuthResult.err(_msg(e.code));
    }
  }

  static Future<bool> updateDisplayName(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name.trim());
      await _auth.currentUser?.reload();
      if (_auth.currentUser != null) {
        await _db.collection('users').doc(_auth.currentUser!.uid)
            .update({'name': name.trim()}).catchError((_) {});
      }
      return true;
    } catch (_) { return false; }
  }

  static Future<bool> updatePhotoURL(String url) async {
    try {
      await _auth.currentUser?.updatePhotoURL(url);
      await _auth.currentUser?.reload();
      if (_auth.currentUser != null) {
        await _db.collection('users').doc(_auth.currentUser!.uid)
            .update({'photo': url}).catchError((_) {});
      }
      return true;
    } catch (_) { return false; }
  }

  // ════════════════════════════════════════════════════════
  //  تسجيل الخروج
  // ════════════════════════════════════════════════════════
  static Future<void> signOut() async {
    stopAdminListener();
    await _google.signOut().catchError((_) {});
    await _auth.signOut();
  }

  // ════════════════════════════════════════════════════════
  //  UPGRADED — _trackLogin يستخدم SafeUserWriter (check-then-write)
  //  يمنع التعارض ويحمي بيانات المستخدم الموجود
  // ════════════════════════════════════════════════════════
  static Future<void> _trackLogin(String method, User? user) async {
    if (user == null) return;
    try {
      final devId = await DeviceId.get();

      // ── SafeUserWriter: كتابة آمنة مع check-then-write ──
      await SafeUserWriter.writeUserData(
        uid:      user.uid,
        method:   method,
        baseData: {
          'email':        user.email         ?? '',
          'phone':        user.phoneNumber   ?? '',
          'display_name': user.displayName   ?? '',
          'name':         user.displayName   ?? '',
          'photo_url':    user.photoURL      ?? '',
          'photo':        user.photoURL      ?? '',
          'method':       method,
          'platform':     Plat.name,
          'device_id':    devId,
          'app_version':  AppVersion.version,
          'is_admin':     _isAdminEmail(user.email),
        },
      );

      // ── ابدأ مستمع الأدمن (خفيف — يقرأ فقط) ─────────────
      startAdminListener(user.uid);

      // ── ابدأ المستمع الشامل لبيانات المستخدم ─────────────
      // يستجيب فوراً لأي تغيير من لوحة الإدارة
      UserDataWatcher.startListening(user.uid);

    } catch (e) {
      debugPrint('AuthService._trackLogin error: $e');
    }
  }

  static String _msg(String code) {
    const m = {
      'user-not-found':            'البريد الإلكتروني غير مسجّل',
      'wrong-password':            'كلمة المرور غير صحيحة',
      'invalid-credential':        'البيانات غير صحيحة',
      'email-already-in-use':      'البريد مسجّل مسبقاً',
      'weak-password':             'كلمة المرور ضعيفة (6 أحرف على الأقل)',
      'invalid-email':             'البريد الإلكتروني غير صالح',
      'too-many-requests':         'محاولات كثيرة — انتظر قليلاً',
      'network-request-failed':    'تحقق من اتصالك بالإنترنت',
      'user-disabled':             'تم تعطيل هذا الحساب',
      'invalid-phone-number':      'رقم الهاتف غير صالح',
      'quota-exceeded':            'تم تجاوز الحد — حاول لاحقاً',
      'invalid-verification-code': 'كود التحقق غير صحيح',
      'session-expired':           'انتهت صلاحية الكود — أعد الإرسال',
    };
    return m[code] ?? 'خطأ: $code';
  }
}

// ════════════════════════════════════════════════════════════════
//  AdminAwareBuilder — يُعيد البناء فوراً عند تغيير is_admin
//  استخدمه بدلاً من if(AuthService.isAdmin) في الـ build()
// ════════════════════════════════════════════════════════════════
class AdminAwareBuilder extends StatelessWidget {
  final Widget Function(bool isAdmin) builder;
  const AdminAwareBuilder({required this.builder, super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: AuthService.adminStream,
    initialData: AuthService.isAdmin,
    builder: (_, snap) => builder(snap.data ?? false),
  );
}

class AuthResult {
  final bool   ok;
  final User?  user;
  final String msg;
  const AuthResult._(this.ok, this.user, this.msg);
  factory AuthResult.ok(User? u, {String msg = ''}) => AuthResult._(true, u, msg);
  factory AuthResult.err(String msg) => AuthResult._(false, null, msg);
}

// ═══════════════════════════════════════════════════════════════
//  FIREBASE LOGIN PAGE — شاشة تسجيل الدخول الكاملة
// ═══════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
//  PAYWALL SHEET — شاشة الاشتراك عند انتهاء وقت الضيف
// ═══════════════════════════════════════════════════════════════
class _PaywallSheet extends StatelessWidget {
  final VoidCallback onSubscribe;
  final VoidCallback onClose;
  const _PaywallSheet({required this.onSubscribe, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const C.goldBg,
        borderRadius: BorderRadius.circular(R.xl),
        border: Border.all(color: C.gold.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(
          color: C.gold.withOpacity(0.15),
          blurRadius: FS.x3l, spreadRadius: 2)]),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(width: 40, height: 3,
              decoration: BoxDecoration(color: CExtra.border, borderRadius: BorderRadius.circular(R.tiny))),
          const SizedBox(height: 24),

          // Icon
          Container(width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [C.goldBg, C.goldBg]),
              border: Border.all(color: C.gold.withOpacity(0.5), width: 1.5),
              boxShadow: [BoxShadow(
                color: C.gold.withOpacity(0.2), blurRadius: FS.xl)]),
            child: Center(child: ShaderMask(
              shaderCallback: (r) => CC.goldGrad.createShader(r),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 32)))),
          const SizedBox(height: 20),

          // Title
          Text('انتهى وقت المشاهدة المجاني',
              style: T.cairo(s: FS.lg, w: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('استمتع بمشاهدة غير محدودة مع اشتراك TOTV+',
              style: T.cairo(s: FS.md, c: C.grey), textAlign: TextAlign.center),
          const SizedBox(height: 24),

          // Features
          _feature(Icons.all_inclusive_rounded, 'مشاهدة غير محدودة 24/7'),
          _feature(Icons.hd_rounded,            'جودة Full HD وأعلى'),
          _feature(Icons.speed_rounded,         'سيرفرك الخاص بدون انقطاع'),
          _feature(Icons.block_rounded,         'بدون إعلانات نهائياً'),
          const SizedBox(height: 24),

          // Subscribe button
          GestureDetector(
            onTap: onSubscribe,
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(
                gradient: C.playGrad,
                borderRadius: BorderRadius.circular(R.md),
                boxShadow: [BoxShadow(
                  color: C.gold.withOpacity(0.3),
                  blurRadius: FS.lg, offset: const Offset(0, 4))]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Text('اشترك الآن — TOTV+',
                    style: T.cairo(s: FS.lg, c: Colors.black, w: FontWeight.w800)),
              ]))),
          const SizedBox(height: 12),

          // Close
          GestureDetector(
            onTap: onClose,
            child: Text('إغلاق المشغل', style: T.cairo(s: FS.sm, c: C.dim))),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _feature(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(width: 28, height: 28,
        decoration: BoxDecoration(shape: BoxShape.circle, color: CC.goldBg),
        child: Icon(icon, color: C.gold, size: 14)),
      const SizedBox(width: 10),
      Text(text, style: T.cairo(s: FS.sm, c: CC.textSec)),
    ]));
}


// ═══════════════════════════════════════════════════════════════
//  ACTOR PAGE — صفحة الممثل وأعماله
// ═══════════════════════════════════════════════════════════════
