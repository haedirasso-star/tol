part of '../../main.dart';

// ════════════════════════════════════════════════════════════════
//  SPLASH v4 — Ultra-Fast + Default Server Preload
//  Strategy: show UI at frame 1, load default server content
//  in background so Shell has data ready on arrival.
// ════════════════════════════════════════════════════════════════
class Splash extends StatefulWidget {
  const Splash();
  @override State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _tScale;   // اندفاع الحرف
  late final Animation<double>   _tFade;
  late final Animation<double>   _glow;     // انفجار التوهّج عند الضربة
  late final Animation<double>   _sweep;    // مرور الضوء على المعدن
  late final Animation<double>   _ring;     // حلقة تنتشر من الحرف
  late final Animation<double>   _subFade;  // كلمة TOTV+ تحت الحرف
  late final Animation<double>   _lineW;    // الخط الذهبي يتمدّد
  late final Animation<double>   _vig;      // تعتيم الأطراف
  late final Animation<double>   _outFade;  // اختفاء نهائي
  bool _nav = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);

    // ★ v2 — انترو سينمائي مضبوط على الصوت بدقّة
    //   قِسْتُ ملف intro.wav: مدّته 3.40s وذروته عند 1.40s تماماً.
    //   لذا مدّة الحركة = 3400ms، و«هبوط» الحرف عند 1.40s / 3.40s = 0.412
    //   أي أن الحرف يستقرّ في اللحظة نفسها التي تضرب فيها الموسيقى.
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3400))..forward();
    Sound.intro();

    // 1) الحرف يندفع من العمق ويستقرّ عند الضربة بالضبط (0.08 → 0.412)
    _tFade  = CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.08, 0.30, curve: Curves.easeOut));
    _tScale = Tween<double>(begin: 1.55, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.08, 0.412, curve: Curves.easeOutExpo)));

    // 2) انفجار التوهّج عند الضربة (0.412) ثم هدوء بطيء
    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOutCubic)), weight: 8),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.40)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 92),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.38, 1.0)));

    // 3) حلقة ذهبية تنتشر من الحرف لحظة الضربة (0.412 → 0.70)
    _ring = CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.412, 0.70, curve: Curves.easeOutCubic));

    // 4) ضوء يمرّ على سطح المعدن بعد الضربة (0.45 → 0.75)
    _sweep = Tween<double>(begin: -1.4, end: 2.4).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.45, 0.75, curve: Curves.easeInOut)));

    // 5) الخط ثم الاسم (0.50 → 0.74)
    _lineW = CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.50, 0.64, curve: Curves.easeOutCubic));
    _subFade = CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.56, 0.74, curve: Curves.easeOut));

    // 6) تعتيم الأطراف يشتدّ مع بناء الموسيقى
    _vig = CurvedAnimation(parent: _ctrl,
        curve: const Interval(0.0, 0.60, curve: Curves.easeOut));

    // 7) اختفاء مع تلاشي الصوت (0.92 → 1.0)
    _outFade = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.92, 1.0, curve: Curves.easeIn)));

    unawaited(_preloadDefaultContent());
    Future.delayed(const Duration(milliseconds: 3380), _go);
  }

  /// يحمّل محتوى سيرفر المستخدم الخاص فور توفّره
  Future<void> _preloadDefaultContent() async {
    try {
      // النظام الجديد: لا سيرفر افتراضي. حمّل فقط إذا كان للمستخدم سيرفر خاص.
      await Sub.load().timeout(const Duration(seconds: 3), onTimeout: () {});
      if (!AppState.isLoaded && Sub.hasServer) {
        await AppState.loadAll().timeout(
          const Duration(seconds: 20),
          onTimeout: () {},
        );
      }
    } catch (e) {
      debugPrint('[splash] preloadDefaultContent: $e');
    }
  }

  Future<void> _go() async {
    if (_nav || !mounted) return;
    _nav = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: []);

    if (RC.needsUpdate) {
      if (mounted) Navigator.of(context).pushReplacement(_route(_UpdateGatePage()));
      return;
    }

    final user = AuthService.currentUser;
    if (user == null) {
      // لا حساب → واجهة تسجيل الدخول مباشرةً (لا دخول بلا حساب)
      if (mounted) Navigator.of(context).pushReplacement(_route(const FirebaseLoginPage()));
      return;
    }
    AuthService.startAdminListener(user.uid);
    // ★ تهيئة الإشعارات بعد تسجيل الدخول — لضمان حفظ fcm_token والاشتراك في all_users
    unawaited(NotifService.init().catchError((e) => debugPrint('[Notif] $e')));
    // ★ مراقب طلبات الأدمن — إشعار فوري بصوت عند وصول طلب (للأدمن فقط)
    AdminOrderWatcher.start();
    Future(() => UserDataWatcher.startListening(user.uid));
    UserDataWatcher.setOnBanned(() {
      if (mounted) Navigator.of(context).pushReplacement(_route(const BannedPage()));
    });
    unawaited(_backgroundChecks(user.uid));

    // ★ ضمان استعادة الاشتراك محلياً قبل بناء الرئيسية (يمنع نسيان الاشتراك)
    await Sub.quickRestore().timeout(
        const Duration(seconds: 2), onTimeout: () {});

    if (!mounted) return;
    // ★ شاشة «من يتابع الآن؟» عند كل فتح — تعطي الطابع الفخم للتطبيق
    Navigator.of(context).pushReplacement(
        _route(const ProfileGatePage(next: Shell())));
  }

  Future<void> _backgroundChecks(String uid) async {
    try {
      await Sub.load().timeout(const Duration(seconds: 3), onTimeout: () {});
      await GuestSession.load(uid)
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      final status = await UserStatusService.checkStatus(uid)
          .timeout(const Duration(seconds: 3), onTimeout: () => UserStatus.active)
          .catchError((_) => UserStatus.active);
      if (status == UserStatus.banned && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          _route(const BannedPage()), (_) => false);
      }
    } catch (e) {
      debugPrint('[splash_shell] $e');
    }
  }

  static PageRouteBuilder _route(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
  );

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // ضوء يمرّ على سطح المعدن — يُستخدم كقناع فوق الحرف
    Shader goldSweep(Rect b) => LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: const [
        Colors.transparent, Color(0x00FFFFFF),
        Color(0x66FFF6D8), Color(0xCCFFFFFF), Color(0x66FFF6D8),
        Color(0x00FFFFFF), Colors.transparent,
      ],
      stops: [
        (_sweep.value - 0.42).clamp(0.0, 1.0),
        (_sweep.value - 0.26).clamp(0.0, 1.0),
        (_sweep.value - 0.10).clamp(0.0, 1.0),
        _sweep.value.clamp(0.0, 1.0),
        (_sweep.value + 0.10).clamp(0.0, 1.0),
        (_sweep.value + 0.26).clamp(0.0, 1.0),
        (_sweep.value + 0.42).clamp(0.0, 1.0),
      ],
    ).createShader(b);

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final size   = MediaQuery.of(context).size;
          final markSz = math.min(size.width * 0.52, 240.0);

          return Opacity(
            opacity: _outFade.value,
            child: Stack(alignment: Alignment.center, children: [

              // ── 1. هالة خلفية تتنفّس مع الضربة ──────────────
              Center(child: Container(
                width: markSz * 2.4, height: markSz * 2.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    C.gold.withOpacity(0.13 * _glow.value),
                    C.gold.withOpacity(0.03 * _glow.value),
                    Colors.transparent,
                  ], stops: const [0.0, 0.45, 1.0]),
                ),
              )),

              // ── 2. حلقة تنتشر من الحرف عند الضربة ───────────
              if (_ring.value > 0 && _ring.value < 1)
                Center(child: Container(
                  width:  markSz * (0.7 + _ring.value * 2.6),
                  height: markSz * (0.7 + _ring.value * 2.6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: C.gold.withOpacity((1 - _ring.value) * 0.42),
                      width: 1.4,
                    ),
                  ),
                )),

              // ── 3. الحرف + الضوء المارّ ─────────────────────
              Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Opacity(
                  opacity: _tFade.value,
                  child: Transform.scale(
                    scale: _tScale.value,
                    child: Container(
                      decoration: BoxDecoration(boxShadow: [
                        BoxShadow(
                          color: C.gold.withOpacity(0.34 * _glow.value),
                          blurRadius: 80 * _glow.value,
                          spreadRadius: 4 * _glow.value),
                      ]),
                      child: Stack(alignment: Alignment.center, children: [
                        Image.asset(
                          'assets/images/intro_mark.png',
                          width: markSz, height: markSz, fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Text('T',
                              textDirection: TextDirection.ltr,
                              style: GoogleFonts.cinzelDecorative(
                                  fontSize: markSz * 0.72,
                                  fontWeight: FontWeight.w900, color: C.gold)),
                        ),
                        // بريق يمرّ فوق المعدن
                        if (_sweep.value > -1.3 && _sweep.value < 2.3)
                          IgnorePointer(child: ShaderMask(
                            shaderCallback: goldSweep,
                            blendMode: BlendMode.srcIn,
                            child: Image.asset(
                              'assets/images/intro_mark.png',
                              width: markSz, height: markSz, fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          )),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── 4. الخط الذهبي ثم اسم التطبيق ──────────────
                Container(
                  width: 74 * _lineW.value, height: 1.1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      C.gold.withOpacity(0.85),
                      Colors.transparent,
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: _subFade.value,
                  child: Text('TOTV+',
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.cinzelDecorative(
                          fontSize: 19, fontWeight: FontWeight.w700,
                          color: C.gold.withOpacity(0.92), letterSpacing: 9)),
                ),
                const SizedBox(height: 7),
                Opacity(
                  opacity: _subFade.value * 0.8,
                  child: Text('منصة البث الذكية',
                      style: GoogleFonts.cairo(
                          fontSize: FS.sm, color: C.textDim,
                          fontWeight: FontWeight.w400, letterSpacing: 4)),
                ),
              ])),

              // ── 5. تعتيم الأطراف — يركّز العين على المركز ────
              IgnorePointer(child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.95,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.55 * _vig.value),
                      Colors.black.withOpacity(0.88 * _vig.value),
                    ],
                    stops: const [0.42, 0.78, 1.0],
                  ),
                ),
              )),
            ]),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  UPDATE GATE PAGE
// ════════════════════════════════════════════════════════════════
class _UpdateGatePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final msg = RC.updateMsg.isNotEmpty
        ? RC.updateMsg
        : 'نسخة جديدة من TOTV+ متاحة!\nحدّث للاستمتاع بأحدث المميزات.';
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(child: Center(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 90, height: 90,
            decoration: BoxDecoration(shape: BoxShape.circle, color: C.surface,
              border: Border.all(color: C.gold.withOpacity(0.4), width: 1.5)),
            child: const Center(child: Icon(Icons.system_update_rounded, color: C.gold, size: 42))),
          const SizedBox(height: 28),
          Text('تحديث مطلوب', style: T.cairo(s: FS.xl, w: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('الإصدار الحالي: ${AppVersion.version}',
              style: T.caption(c: C.grey)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(T.rLg),
              border: Border.all(color: Colors.white.withOpacity(0.06))),
            child: Text(msg, style: T.body(c: CC.textSec), textAlign: TextAlign.center,
                textDirection: TextDirection.rtl)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: RC.updateUrl.isNotEmpty
                ? () => launchUrl(Uri.parse(RC.updateUrl), mode: LaunchMode.externalApplication)
                : null,
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(T.rMd)),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.download_rounded, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Text('تحديث الآن', style: T.cairo(s: FS.lg, c: Colors.black, w: FontWeight.w800)),
              ])),
            ),
          ),
          const SizedBox(height: 14),
          if (RC.whatsapp.isNotEmpty)
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('https://wa.me/${RC.whatsapp}'),
                  mode: LaunchMode.externalApplication),
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  color: C.whatsapp.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(T.rMd),
                  border: Border.all(color: C.whatsapp.withOpacity(0.35))),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.support_agent_rounded, color: C.whatsapp, size: 20),
                  const SizedBox(width: 8),
                  Text('الدعم عبر واتساب',
                      style: T.cairo(s: FS.md, c: C.whatsapp, w: FontWeight.w700)),
                ])),
              ),
            ),
        ]),
      ))),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  BANNED PAGE
// ════════════════════════════════════════════════════════════════
class BannedPage extends StatelessWidget {
  const BannedPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: C.red.withOpacity(0.1),
            border: Border.all(color: C.red.withOpacity(0.4), width: 1.5)),
          child: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 40)),
        const SizedBox(height: 24),
        Text('تم تعليق حسابك', style: T.heading(s: FS.xl)),
        const SizedBox(height: 8),
        Text('تواصل مع الدعم الفني', style: T.body(c: C.grey), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () async {
            final wa = RC.whatsapp;
            final url = wa.isNotEmpty ? 'https://wa.me/$wa' : RC.telegram;
            try { await launchUrl(Uri.parse(url)); } catch (e) { debugPrint('[splash_shell] $e'); }
          },
          child: Container(
            width: double.infinity, height: 50,
            decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(T.rMd)),
            child: Center(child: Text('تواصل مع الدعم',
                style: T.cairo(s: FS.md, w: FontWeight.w800, c: Colors.black))))),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            await AuthService.signOut();
            if (context.mounted) {
              Navigator.of(context).pushReplacement(PageRouteBuilder(
                pageBuilder: (_, __, ___) => const FirebaseLoginPage(),
                transitionDuration: const Duration(milliseconds: 400),
                transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
              ));
            }
          },
          child: Text('تسجيل الخروج', style: T.caption(c: C.textDim))),
      ]),
    )),
  );
}

// ════════════════════════════════════════════════════════════════
//  LOGIN GATE — شاشة تظهر عند محاولة التشغيل بدون تسجيل دخول
// ════════════════════════════════════════════════════════════════
class LoginGateSheet extends StatelessWidget {
  final String? message;
  const LoginGateSheet({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.bg,
        borderRadius: BorderRadius.circular(R.xl),
        border: Border.all(color: C.gold.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 3,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(R.tiny))),
          const SizedBox(height: 24),
          Container(width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [C.goldBg, C.goldBg]),
              border: Border.all(color: C.gold.withOpacity(0.5), width: 1.5),
              boxShadow: [BoxShadow(color: C.gold.withOpacity(0.2), blurRadius: FS.xl)]),
            child: Center(child: ShaderMask(
              shaderCallback: (r) => C.playGrad.createShader(r),
              child: const Icon(Icons.play_circle_fill_rounded, color: C.textPri, size: 34)))),
          const SizedBox(height: 20),
          Text('سجّل الدخول للمشاهدة',
              style: T.cairo(s: FS.xl, w: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.gold.withOpacity(0.15), C.gold.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: C.gold.withOpacity(0.3))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.access_time_rounded, color: C.gold, size: 18),
              const SizedBox(width: 8),
              Text('ساعة مشاهدة مجانية كاملة عند التسجيل!',
                  style: T.cairo(s: FS.md, c: C.gold, w: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          if (message != null && message!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(message!, style: T.body(c: CC.textSec), textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl)),
          _feature(Icons.live_tv_rounded,   'تصفح جميع الأفلام والمسلسلات والقنوات'),
          _feature(Icons.hd_rounded,        'جودة عالية — HD وأعلى'),
          _feature(Icons.timer_rounded,     'ساعة مشاهدة مجانية يومياً بعد التسجيل'),
          _feature(Icons.lock_open_rounded, 'بدون بطاقة ائتمان'),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(PageRouteBuilder(
                pageBuilder: (_, __, ___) => const FirebaseLoginPage(),
                transitionDuration: const Duration(milliseconds: 350),
                transitionsBuilder: (_, a, __, c) =>
                    SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                        .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c),
              ));
            },
            child: Container(
              width: double.infinity, height: 54,
              decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md),
                boxShadow: [BoxShadow(color: C.gold.withOpacity(0.3), blurRadius: FS.lg, offset: const Offset(0,4))]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.person_add_rounded, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Text('تسجيل الدخول مجاناً — ساعة كاملة',
                    style: T.cairo(s: FS.lg, c: Colors.black, w: FontWeight.w900)),
              ])),
          ),
          const SizedBox(height: 10),
          // ★ زر "كيف أشترك؟" للزوار
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HowToSubscribePage(),
                transitionDuration: const Duration(milliseconds: 350),
                transitionsBuilder: (_, a, __, c) =>
                    SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                        .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c),
              ));
            },
            child: Container(
              width: double.infinity, height: 44,
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.help_outline_rounded, color: C.gold, size: 18),
                const SizedBox(width: 8),
                Text('كيف أشترك؟', style: T.cairo(s: FS.md, c: C.gold, w: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text('تصفح بدون تسجيل', style: T.caption(c: C.textDim))),
        ]),
      ),
    );
  }

  Widget _feature(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(children: [
      Icon(icon, color: C.gold, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: T.cairo(s: FS.sm, c: CC.textSec))),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
//  FREE HOUR EXPIRED SHEET
// ════════════════════════════════════════════════════════════════
class FreeExpiredSheet extends StatelessWidget {
  const FreeExpiredSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.goldBg,
        borderRadius: BorderRadius.circular(R.xl),
        border: Border.all(color: C.gold.withOpacity(0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 3,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(R.tiny))),
          const SizedBox(height: 24),
          Container(width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: LinearGradient(colors: [C.goldBg, C.goldBg]),
              border: Border.all(color: C.gold.withOpacity(0.5), width: 1.5),
              boxShadow: [BoxShadow(color: C.gold.withOpacity(0.2), blurRadius: FS.xl)]),
            child: Center(child: ShaderMask(
              shaderCallback: (r) => C.playGrad.createShader(r),
              child: const Icon(Icons.lock_clock_rounded, color: C.textPri, size: 32)))),
          const SizedBox(height: 20),
          Text('انتهت ساعتك المجانية', style: T.cairo(s: FS.lg, w: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('اشترك للاستمتاع بمشاهدة غير محدودة',
              style: T.body(c: CC.textSec), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _perk(Icons.all_inclusive_rounded, 'مشاهدة غير محدودة'),
          _perk(Icons.hd_rounded,            'جودة Full HD وأعلى'),
          _perk(Icons.block_rounded,         'بدون إعلانات'),
          _perk(Icons.speed_rounded,         'سرعة وجودة فائقة'),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(PageRouteBuilder(
                pageBuilder: (_, __, ___) => const SubscriptionPage(),
                transitionDuration: const Duration(milliseconds: 350),
                transitionsBuilder: (_, a, __, c) =>
                    SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                        .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c),
              ));
            },
            child: Container(
              width: double.infinity, height: 52,
              decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(R.md),
                boxShadow: [BoxShadow(color: C.gold.withOpacity(0.3), blurRadius: FS.lg, offset: const Offset(0,4))]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Text('اشترك الآن — TOTV+',
                    style: T.cairo(s: FS.lg, c: Colors.black, w: FontWeight.w800)),
              ])),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(RC.buyUrl), mode: LaunchMode.externalApplication);
            },
            child: Container(
              width: double.infinity, height: 44,
              decoration: BoxDecoration(
                color: C.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: C.gold.withOpacity(0.4)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.shopping_cart_rounded, color: C.gold, size: 16),
                const SizedBox(width: 6),
                Text('شراء اشتراك جديد', style: T.cairo(s: FS.md, c: C.gold, w: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          // ★ زر "كيف أشترك؟"
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(PageRouteBuilder(
                pageBuilder: (_, __, ___) => const HowToSubscribePage(),
                transitionDuration: const Duration(milliseconds: 350),
                transitionsBuilder: (_, a, __, c) =>
                    SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                        .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c),
              ));
            },
            child: Text('كيف أشترك؟ — اعرف الخطوات', style: T.caption(c: C.gold)),
          ),
          const SizedBox(height: 8),
          if (RC.whatsapp.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('https://wa.me/${RC.whatsapp}'), mode: LaunchMode.externalApplication);
              },
              child: Text('تواصل معنا عبر واتساب', style: T.caption(c: C.gold))),
        ]),
      ),
    );
  }

  Widget _perk(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, color: C.gold, size: 16),
      const SizedBox(width: 10),
      Text(text, style: T.cairo(s: FS.md, c: CC.textSec)),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
//  HOW TO SUBSCRIBE PAGE — صفحة تعليمات الاشتراك
// ════════════════════════════════════════════════════════════════
class HowToSubscribePage extends StatelessWidget {
  const HowToSubscribePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('كيف تشترك في TOTV+؟',
            style: T.cairo(s: FS.lg, w: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── بانر تعريفي ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.goldBg,
              borderRadius: BorderRadius.circular(T.rLg),
              border: Border.all(color: C.gold.withOpacity(0.35))),
            child: Column(children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                    colors: [C.gold, C.imdb, C.goldDim]).createShader(b),
                blendMode: BlendMode.srcIn,
                child: Text('TOTV+',
          textDirection: TextDirection.ltr,
                    style: GoogleFonts.cinzelDecorative(
                        fontSize: 28, fontWeight: FontWeight.w900,
                        color: C.textPri, letterSpacing: 6))),
              const SizedBox(height: 8),
              Text('آلاف القنوات · الأفلام · المسلسلات · البث المباشر',
                  style: T.cairo(s: FS.sm, c: C.gold, w: FontWeight.w600),
                  textAlign: TextAlign.center),
            ]),
          ),

          const SizedBox(height: 28),
          Text('خطوات الاشتراك',
              style: T.cairo(s: FS.lg, w: FontWeight.w800),
              textDirection: TextDirection.rtl),
          const SizedBox(height: 16),

          // ── الخطوات ──────────────────────────────────────────
          _step(
            num: '١',
            title: 'اختر خطة الاشتراك',
            desc: 'شهري: 5,000 د.ع  •  ربعي: 13,000 د.ع  •  سنوي: 45,000 د.ع',
            icon: Icons.checklist_rounded,
          ),
          _step(
            num: '٢',
            title: 'ادفع عبر طريقتك المفضلة',
            desc: 'FIB — سوبر كي — كي — أو عبر موقعنا الإلكتروني مباشرة.',
            icon: Icons.account_balance_rounded,
          ),
          _step(
            num: '٣',
            title: 'أرسل بيانات الطلب',
            desc: 'من داخل التطبيق أرسل اسمك ورقم هاتفك وطريقة الدفع. سيصل طلبك فوراً لفريق الدعم.',
            icon: Icons.send_rounded,
          ),
          _step(
            num: '٤',
            title: 'انتظر التأكيد',
            desc: 'يتواصل معك فريق الدعم خلال دقائق عبر واتساب ويرسل لك بيانات التفعيل.',
            icon: Icons.mark_chat_read_rounded,
          ),
          _step(
            num: '٥',
            title: 'فعّل اشتراكك',
            desc: 'أدخل اسم المستخدم وكلمة المرور التي أُرسلت إليك في صفحة "تفعيل الاشتراك"، واستمتع بالمحتوى.',
            icon: Icons.verified_user_rounded,
          ),

          const SizedBox(height: 28),

          // ── خطط الأسعار ──────────────────────────────────────
          Text('خطط الأسعار',
              style: T.cairo(s: FS.lg, w: FontWeight.w800),
              textDirection: TextDirection.rtl),
          const SizedBox(height: 12),
          _planCard('شهري',    '5,000',  '/شهر',    'الأكثر شيوعاً', const Color(0xFFFFD740), false),
          const SizedBox(height: 10),
          _planCard('3 أشهر', '13,000', '/3 أشهر', 'وفّر 13%',      const Color(0xFF00D2FF), true),
          const SizedBox(height: 10),
          _planCard('سنوي',   '45,000', '/سنة',     'أفضل قيمة',     const Color(0xFFFF6B35), false),

          const SizedBox(height: 32),

          // ── أزرار الإجراء ────────────────────────────────────
          GestureDetector(
            onTap: () => Navigator.push(context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const SubscriptionPage(),
                  transitionDuration: const Duration(milliseconds: 350),
                  transitionsBuilder: (_, a, __, c) =>
                      SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                        child: c),
                )),
            child: Container(
              width: double.infinity, height: 54,
              decoration: BoxDecoration(
                  gradient: C.playGrad,
                  borderRadius: BorderRadius.circular(T.rMd),
                  boxShadow: [BoxShadow(color: C.gold.withOpacity(0.35), blurRadius: FS.md, offset: const Offset(0, 4))]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 22),
                const SizedBox(width: 10),
                Text('اشترك الآن', style: T.cairo(s: FS.lg, c: Colors.black, w: FontWeight.w900)),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          if (RC.whatsapp.isNotEmpty)
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://wa.me/${RC.whatsapp}?text=${Uri.encodeComponent("مرحباً، أريد الاشتراك في TOTV+")}'),
                mode: LaunchMode.externalApplication),
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  color: C.whatsapp.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(T.rMd),
                  border: Border.all(color: C.whatsapp.withOpacity(0.4))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.support_agent_rounded, color: C.whatsapp, size: 20),
                  const SizedBox(width: 8),
                  Text('تواصل مع الدعم عبر واتساب',
                      style: T.cairo(s: FS.md, c: C.whatsapp, w: FontWeight.w700)),
                ]),
              ),
            ),

          const SizedBox(height: 10),

          GestureDetector(
            onTap: () => launchUrl(Uri.parse(RC.telegram), mode: LaunchMode.externalApplication),
            child: Container(
              width: double.infinity, height: 50,
              decoration: BoxDecoration(
                color: C.telegram.withOpacity(0.1),
                borderRadius: BorderRadius.circular(T.rMd),
                border: Border.all(color: C.telegram.withOpacity(0.3))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.telegram, color: C.telegram, size: 20),
                const SizedBox(width: 8),
                Text('القناة الرسمية على تيليغرام',
                    style: T.cairo(s: FS.md, c: C.telegram, w: FontWeight.w700)),
              ]),
            ),
          ),

        ]),
      ),
    );
  }

  Widget _step({required String num, required String title, required String desc, required IconData icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(T.rMd),
          border: Border.all(color: Colors.white.withOpacity(0.07))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36, height: 36,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: C.playGrad),
          child: Center(
              child: Text(num, style: T.cairo(s: FS.md, c: Colors.black, w: FontWeight.w900)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.cairo(s: FS.md, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(desc, style: T.cairo(s: FS.sm, c: CC.textSec), textDirection: TextDirection.rtl),
        ])),
        const SizedBox(width: 8),
        Icon(icon, color: C.gold, size: 20),
      ]),
    );
  }

  Widget _planCard(String title, String price, String period, String badge, Color accent, bool featured) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: featured ? accent.withOpacity(0.07) : C.surface,
        borderRadius: BorderRadius.circular(T.rMd),
        border: Border.all(
            color: accent.withOpacity(featured ? 0.5 : 0.2),
            width: featured ? 1.5 : 1)),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(T.rSm)),
          child: Center(child: Text(title,
              style: T.cairo(s: FS.sm, w: FontWeight.w900, c: accent),
              textAlign: TextAlign.center))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('اشتراك $title', style: T.cairo(s: FS.md, w: FontWeight.w700)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(T.rSm),
                  border: Border.all(color: accent.withOpacity(0.3))),
              child: Text(badge,
                  style: TextStyle(fontSize: 9, color: accent, fontWeight: FontWeight.w700,
                      fontFamily: GoogleFonts.montserrat().fontFamily))),
          ]),
          const SizedBox(height: 2),
          Text('جهازان • جميع الأجهزة', style: T.caption(c: CC.textSec)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(price,
              style: TextStyle(
                  fontSize: FS.lg, fontWeight: FontWeight.w900, color: C.textPri,
                  fontFamily: GoogleFonts.montserrat().fontFamily)),
          Text('د.ع$period',
              style: TextStyle(
                  fontSize: FS.xs, color: accent.withOpacity(0.8),
                  fontFamily: GoogleFonts.montserrat().fontFamily)),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SUBSCRIBE BANNER — بانر صغير يظهر أعلى الشاشة للزوار
// ════════════════════════════════════════════════════════════════
class SubscribeBanner extends StatelessWidget {
  const SubscribeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // لا تُظهر البانر للمشتركين
    if (SubCompat.isPremium) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => Navigator.push(context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HowToSubscribePage(),
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (_, a, __, c) =>
                SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                      .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                  child: c),
          )),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: C.goldBg,
          borderRadius: BorderRadius.circular(T.rMd),
          border: Border.all(color: C.gold.withOpacity(0.4))),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            AuthService.currentUser == null
                ? 'سجّل الدخول للوصول إلى المحتوى'
                : 'اشترك الآن للوصول الكامل بدون قيود',
            style: T.cairo(s: FS.sm, c: C.gold, w: FontWeight.w700))),
          const Icon(Icons.arrow_forward_ios_rounded, color: C.gold, size: 13),
        ]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────
void showLoginGate(BuildContext context, {String? message}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => LoginGateSheet(message: message),
  );
}

void showFreeExpired(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FreeExpiredSheet(),
  );
}

// ════════════════════════════════════════════════════════════════
//  SHELL — الغلاف الرئيسي
// ════════════════════════════════════════════════════════════════
class Shell extends StatefulWidget {
  const Shell();
  @override State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _idx = 0;
  static const _pages = [
    HomePage(),
    ContentPage(type: 'movie',   label: 'أفلام'),
    ContentPage(type: 'series',  label: 'مسلسلات'),
    LivePage(),
    SearchPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: []);

    AppState.onPartialLoad = () { if (mounted) setState(() {}); };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(TVLayout.detect());

      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        unawaited(Sub.load().catchError((_) {}));
      });

      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        // ★ تحميل المحتوى فقط إذا لم يكن محمّلاً من الـ Splash
        if (!AppState.isLoaded) {
          unawaited(AppState.loadAll().then((_) {
            if (!mounted) return;
            setState(() {});
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) AppState.preloadPosters(context);
            });
          }).catchError((_) {}));
        } else {
          // البيانات موجودة من الـ Splash → اعرضها فوراً
          if (mounted) setState(() {});
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) AppState.preloadPosters(context);
          });
        }
      });
    });
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  DateTime? _lastResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastResume == null || now.difference(_lastResume!).inMinutes >= 5) {
        _lastResume = now;
        unawaited(AppState.loadAll().catchError((_) {}));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (TVLayout.isTV) return _TVShell(pages: _pages);
    return Scaffold(
      backgroundColor: C.bg,
      extendBody: true,
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(R.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(R.xl),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
              ),
              child: Row(children: [
                _navBtn(0, Icons.home_rounded,         Icons.home_outlined,         'الرئيسية'),
                _navBtn(1, Icons.movie_rounded,         Icons.movie_outlined,         'أفلام'),
                _navBtn(2, Icons.tv_rounded,            Icons.tv_outlined,            'مسلسلات'),
                _navBtn(3, Icons.sensors_rounded,       Icons.sensors_outlined,       'مباشر'),
                _navBtn(4, Icons.search_rounded,        Icons.search_outlined,        'بحث'),
                _navBtn(5, Icons.person_rounded,        Icons.person_outline_rounded, 'حسابي'),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navBtn(int i, IconData active, IconData inactive, String label) {
    final on = _idx == i;
    return Expanded(child: GestureDetector(
      onTap: () {
        if (_idx != i) {
          Sound.nav();
          HapticFeedback.selectionClick();
        }
        setState(() => _idx = i);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: 30,
            width: on ? 48 : 30,
            decoration: BoxDecoration(
              color: on ? C.gold.withOpacity(0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(R.md),
            ),
            child: Center(child: Icon(
              on ? active : inactive,
              size: 20,
              color: on ? C.gold : Colors.white.withOpacity(0.4),
            )),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: FS.xs,
              fontWeight: on ? FontWeight.w700 : FontWeight.w400,
              color: on ? C.gold : Colors.white.withOpacity(0.35),
              fontFamily: GoogleFonts.cairo().fontFamily,
            ),
            child: Text(label),
          ),
        ]),
      ),
    ));
  }
}

// ════════════════════════════════════════════════════════════════
//  TV SHELL
// ════════════════════════════════════════════════════════════════
class _TVShell extends StatefulWidget {
  final List<Widget> pages;
  const _TVShell({required this.pages});
  @override State<_TVShell> createState() => _TVShellState();
}

class _TVShellState extends State<_TVShell> {
  int  _idx = 0;
  bool _navFocused = false;
  final _navFocus  = FocusNode();
  static const _navItems = [
    (Icons.home_rounded,         'الرئيسية'),
    (Icons.movie_rounded,         'أفلام'),
    (Icons.tv_rounded,            'مسلسلات'),
    (Icons.sensors_rounded,       'مباشر'),
    (Icons.sports_soccer_rounded, 'رياضة'),
    (Icons.search_rounded,        'بحث'),
    (Icons.person_rounded,        'حسابي'),
  ];

  @override void dispose() { _navFocus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: Row(children: [
      Focus(
        focusNode: _navFocus,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            setState(() => _idx = (_idx - 1).clamp(0, _navItems.length - 1));
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() => _idx = (_idx + 1).clamp(0, _navItems.length - 1));
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            setState(() => _navFocused = false);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _navFocused ? 180 : 72,
          color: C.bg,
          child: Column(children: [
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.only(bottom: 32, left: 16, right: 16),
              child: ShaderMask(
                shaderCallback: (b) => LinearGradient(colors: [C.gold, C.goldDim]).createShader(b),
                blendMode: BlendMode.srcIn,
                child: Text(
                  _navFocused ? 'TOTV+' : 'T+',
                  style: GoogleFonts.cinzelDecorative(
                      fontSize: _navFocused ? 18 : 14,
                      fontWeight: FontWeight.w900,
                      color: C.textPri)))),
            ...List.generate(_navItems.length, (i) {
              final (icon, label) = _navItems[i];
              final active = _idx == i;
              return GestureDetector(
                onTap: () { Sound.nav(); setState(() { _idx = i; _navFocused = false; }); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: EdgeInsets.symmetric(
                      horizontal: _navFocused ? 16 : 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? C.gold.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(R.md),
                    border: active
                        ? Border.all(color: C.gold.withOpacity(0.4), width: 0.8)
                        : null),
                  child: Row(children: [
                    Icon(icon, color: active ? C.gold : Colors.white54, size: 22),
                    if (_navFocused) ...[
                      const SizedBox(width: 12),
                      Expanded(child: Text(label,
                          style: GoogleFonts.cairo(
                              fontSize: FS.md,
                              color: active ? C.gold : Colors.white70,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w400))),
                    ],
                  ])));
            }),
          ]),
        )),
      Expanded(child: GestureDetector(
        onTap: () => setState(() => _navFocused = false),
        child: IndexedStack(index: _idx, children: widget.pages))),
    ]),
  );
}
