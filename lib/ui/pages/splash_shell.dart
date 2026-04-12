part of '../../main.dart';

// ════════════════════════════════════════════════════════════════
//  SPLASH — شاشة البداية
// ════════════════════════════════════════════════════════════════
class Splash extends StatefulWidget {
  const Splash();
  @override State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<double>   _scaleAnim;
  late final AnimationController _posterFade;
  bool _nav = false;
  final List<String> _posters = [];
  int   _posterIdx = 0;
  Timer? _posterTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _posterFade = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _loadPosters();
    Future.delayed(const Duration(milliseconds: 3000), _go);
  }

  Future<void> _loadPosters() async {
    try {
      final r = await Dio().get(
        'https://api.themoviedb.org/3/trending/all/week',
        queryParameters: {'api_key': TMDB._defaultKey, 'language': 'ar', 'page': 1},
      );
      final results = (r.data['results'] as List?)?.cast<Map>() ?? [];
      for (final m in results.take(8)) {
        final p = m['backdrop_path']?.toString() ?? '';
        if (p.isNotEmpty) _posters.add('https://image.tmdb.org/t/p/w780$p');
      }
      if (mounted && _posters.isNotEmpty) {
        _posterFade.forward();
        setState(() {});
        _posterTimer = Timer.periodic(const Duration(seconds: 3), (_) {
          if (!mounted) return;
          setState(() => _posterIdx = (_posterIdx + 1) % _posters.length);
        });
      }
    } catch (_) {}
  }

  Future<void> _go() async {
    if (_nav || !mounted) return;
    _nav = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: []);

    // ① فحص التحديث الإجباري
    if (RC.needsUpdate) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(_route(_UpdateGatePage()));
      return;
    }

    final user = AuthService.currentUser;

    if (user != null) {
      // ① ابدأ مستمعات Firestore فوراً (Stream — تحديث حي)
      AuthService.startAdminListener(user.uid);

      // ② المستمع الشامل لبيانات المستخدم — يستجيب لأي تغيير من الإدارة
      UserDataWatcher.startListening(user.uid);
      UserDataWatcher.setOnBanned(() {
        // إذا تم تعليق الحساب من لوحة الإدارة — أوقف التطبيق فوراً
        if (mounted) {
          Navigator.of(context).pushReplacement(_route(const BannedPage()));
        }
      });

      // ③ حمّل الاشتراك + وقت المشاهدة
      await Sub.load();
      await GuestSession.load(user.uid);

      final status = await UserStatusService.checkStatus(user.uid);
      if (!mounted) return;
      if (status == UserStatus.banned) {
        Navigator.of(context).pushReplacement(_route(const BannedPage()));
        return;
      }
    }
    // ضيف أو مسجّل — الجميع يذهب للـ Shell
    // يُحمَّل المحتوى من السيرفر الافتراضي في الـ Shell
    if (!mounted) return;
    Navigator.of(context).pushReplacement(_route(const Shell()));
  }

  static PageRouteBuilder _route(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 500),
    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
  );

  @override
  void dispose() {
    _ctrl.dispose(); _posterFade.dispose(); _posterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(fit: StackFit.expand, children: [
      if (_posters.isNotEmpty)
        FadeTransition(
          opacity: Tween<double>(begin: 0, end: 0.18)
              .animate(CurvedAnimation(parent: _posterFade, curve: Curves.easeIn)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 1500),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: CachedNetworkImage(
              key: ValueKey(_posterIdx),
              imageUrl: _posters[_posterIdx],
              fit: BoxFit.cover,
              width: double.infinity, height: double.infinity,
            ),
          ),
        ),
      Container(decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center, radius: 1.2,
          colors: [Color(0x00000000), Color(0xCC000000), Color(0xFF000000)],
          stops: [0.0, 0.6, 1.0]),
      )),
      Center(child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(scale: _scaleAnim,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFFFFD740), Color(0xFFF5C518), Color(0xFFFFAB00)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ).createShader(b),
              blendMode: BlendMode.srcIn,
              child: Text('TOTV+', style: GoogleFonts.cinzelDecorative(
                  fontSize: 52, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 8)),
            ),
            const SizedBox(height: 12),
            Text('منصة البث الذكية', style: GoogleFonts.cairo(
                fontSize: 13, color: Colors.white38, fontWeight: FontWeight.w400)),
            const SizedBox(height: 48),
            SizedBox(width: 36, height: 36,
              child: CircularProgressIndicator(
                  color: const Color(0xFFFFD740).withOpacity(0.6), strokeWidth: 1.5)),
          ]),
        ),
      )),
    ]),
  );
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
          Text('تحديث مطلوب', style: T.cairo(s: 22, w: FontWeight.w800)),
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
                Text('تحديث الآن', style: T.cairo(s: 15, c: Colors.black, w: FontWeight.w800)),
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
                  color: const Color(0xFF25D366).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(T.rMd),
                  border: Border.all(color: const Color(0xFF25D366).withOpacity(0.35))),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.support_agent_rounded, color: Color(0xFF25D366), size: 20),
                  const SizedBox(width: 8),
                  Text('الدعم عبر واتساب',
                      style: T.cairo(s: 14, c: const Color(0xFF25D366), w: FontWeight.w700)),
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
        Text('تم تعليق حسابك', style: T.heading(s: 22)),
        const SizedBox(height: 8),
        Text('تواصل مع الدعم الفني', style: T.body(c: C.grey), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () async {
            final wa = RC.whatsapp;
            final url = wa.isNotEmpty ? 'https://wa.me/$wa' : RC.telegram;
            try { await launchUrl(Uri.parse(url)); } catch (_) {}
          },
          child: Container(
            width: double.infinity, height: 50,
            decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(T.rMd)),
            child: Center(child: Text('تواصل مع الدعم',
                style: T.cairo(s: 14, w: FontWeight.w800, c: Colors.black))))),
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
          child: Text('تسجيل الخروج', style: T.caption(c: Colors.white38))),
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
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.gold.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 3,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          // أيقونة
          Container(width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1200), Color(0xFF0A0800)]),
              border: Border.all(color: C.gold.withOpacity(0.5), width: 1.5),
              boxShadow: [BoxShadow(color: C.gold.withOpacity(0.2), blurRadius: 20)]),
            child: Center(child: ShaderMask(
              shaderCallback: (r) => C.playGrad.createShader(r),
              child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34)))),
          const SizedBox(height: 20),
          Text('سجّل الدخول للمشاهدة',
              style: T.cairo(s: 20, w: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          // بانر ساعة مجانية
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.gold.withOpacity(0.15), C.gold.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.gold.withOpacity(0.3))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.access_time_rounded, color: C.gold, size: 18),
              const SizedBox(width: 8),
              Text('ساعة مشاهدة مجانية كاملة عند التسجيل!',
                  style: T.cairo(s: 13, c: C.gold, w: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          if (message != null && message!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(message!, style: T.body(c: CC.textSec), textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl)),
          // مميزات الحساب المجاني
          _feature(Icons.live_tv_rounded,     'تصفح جميع الأفلام والمسلسلات والقنوات'),
          _feature(Icons.hd_rounded,          'جودة عالية — HD وأعلى'),
          _feature(Icons.timer_rounded,        'ساعة مشاهدة مجانية يومياً بعد التسجيل'),
          _feature(Icons.lock_open_rounded,   'بدون بطاقة ائتمان'),
          const SizedBox(height: 24),
          // زر تسجيل الدخول
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
              decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: C.gold.withOpacity(0.3), blurRadius: 18, offset: const Offset(0,4))]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.person_add_rounded, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Text('تسجيل الدخول مجاناً — ساعة كاملة',
                    style: T.cairo(s: 15, c: Colors.black, w: FontWeight.w900)),
              ])),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text('تصفح بدون تسجيل', style: T.caption(c: Colors.white38))),
        ]),
      ),
    );
  }

  Widget _feature(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(children: [
      Icon(icon, color: C.gold, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: T.cairo(s: 12, c: CC.textSec))),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
//  FREE HOUR EXPIRED SHEET — منتهي الوقت المجاني
// ════════════════════════════════════════════════════════════════
class FreeExpiredSheet extends StatelessWidget {
  const FreeExpiredSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0800),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: C.gold.withOpacity(0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 3,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF2A2200), Color(0xFF1A1500)]),
              border: Border.all(color: C.gold.withOpacity(0.5), width: 1.5),
              boxShadow: [BoxShadow(color: C.gold.withOpacity(0.2), blurRadius: 20)]),
            child: Center(child: ShaderMask(
              shaderCallback: (r) => C.playGrad.createShader(r),
              child: const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 32)))),
          const SizedBox(height: 20),
          Text('انتهت ساعتك المجانية', style: T.cairo(s: 18, w: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('اشترك للاستمتاع بمشاهدة غير محدودة',
              style: T.body(c: CC.textSec), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _perk(Icons.all_inclusive_rounded,   'مشاهدة غير محدودة'),
          _perk(Icons.hd_rounded,              'جودة Full HD وأعلى'),
          _perk(Icons.block_rounded,           'بدون إعلانات'),
          _perk(Icons.speed_rounded,           'سرعة وجودة فائقة'),
          const SizedBox(height: 24),
          // زر الاشتراك
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
              decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: C.gold.withOpacity(0.3), blurRadius: 16, offset: const Offset(0,4))]),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Text('اشترك الآن — TOTV+',
                    style: T.cairo(s: 15, c: Colors.black, w: FontWeight.w800)),
              ])),
          ),
          const SizedBox(height: 12),
          // ── زر شراء اشتراك جديد مباشر ──
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(RC.buyUrl), mode: LaunchMode.externalApplication);
            },
            child: Container(
              width: double.infinity, height: 44,
              decoration: BoxDecoration(
                color: C.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.gold.withOpacity(0.4)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.shopping_cart_rounded, color: C.gold, size: 16),
                const SizedBox(width: 6),
                Text('شراء اشتراك جديد', style: T.cairo(s: 13, c: C.gold, w: FontWeight.w700)),
              ]),
            ),
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
      Text(text, style: T.cairo(s: 13, c: CC.textSec)),
    ]),
  );
}

// Helper: show login gate
void showLoginGate(BuildContext context, {String? message}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => LoginGateSheet(message: message),
  );
}

// Helper: show free expired
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
    SportsPage(),
    SearchPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: []);
    // ── تحميل المحتوى الذكي بالأولوية ─────────────────────
    AppState.onPartialLoad = () { if (mounted) setState(() {}); };

    // ★ إعادة التحميل عند تغيّر RC (يحل مشكلة المستخدم المجاني)
    RC.onConfigChanged = () {
      if (mounted) {
        setState(() {});
        // إذا لم يكن المحتوى محمّلاً، حاول الآن
        if (!AppState.isLoaded || AppState.allMovies.isEmpty) {
          unawaited(AppState.loadAll(force: true).then((_) {
            if (mounted) setState(() {});
          }));
        }
      }
    };

    unawaited(AppState.loadAll().then((_) {
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) AppState.preloadPosters(context);
        });
      }
    }));
    unawaited(TVLayout.detect());
    unawaited(Sub.load().then((_) {
      // بعد تحميل الاشتراك، أعد التحميل إذا تغيّر وضع المستخدم
      if (mounted) {
        unawaited(AppState.loadAll(force: Sub.isActive).then((_) {
          if (mounted) setState(() {});
        }));
      }
    }));
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) AppState.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (TVLayout.isTV) return _TVShell(pages: _pages);
    return Scaffold(
      backgroundColor: C.bg,
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() => Container(
    decoration: BoxDecoration(
      color: C.bg,
      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.5)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0,-2))],
    ),
    child: SafeArea(top: false, child: SizedBox(height: 56,
      child: Row(children: [
        _navBtn(0, Icons.home_rounded,          Icons.home_outlined,         'الرئيسية'),
        _navBtn(1, Icons.movie_rounded,          Icons.movie_outlined,         'أفلام'),
        _navBtn(2, Icons.tv_rounded,             Icons.tv_outlined,            'مسلسلات'),
        _navBtn(3, Icons.sensors_rounded,        Icons.sensors_outlined,       'مباشر'),
        _navBtn(4, Icons.sports_soccer_rounded,  Icons.sports_soccer_outlined, 'رياضة'),
        _navBtn(5, Icons.search_rounded,         Icons.search_outlined,        'بحث'),
        _navBtn(6, Icons.person_rounded,         Icons.person_outline_rounded, 'حسابي'),
      ]),
    )),
  );

  Widget _navBtn(int i, IconData active, IconData inactive, String label) {
    final on = _idx == i;
    return Expanded(child: GestureDetector(
      onTap: () {
        if (_idx != i) {
          Sound.hapticL();
          SystemSound.play(SystemSoundType.click);
        }
        setState(() => _idx = i);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(duration: const Duration(milliseconds: 200),
          width: on ? 20 : 0, height: on ? 2 : 0,
          margin: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(1))),
        Icon(on ? active : inactive, size: 22, color: on ? C.gold : Colors.white38),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9.5,
          fontWeight: on ? FontWeight.w700 : FontWeight.w400,
          color: on ? C.gold : Colors.white38,
          fontFamily: GoogleFonts.cairo().fontFamily)),
      ]),
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
      Focus(focusNode: _navFocus,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowUp)   { setState(() => _idx = (_idx-1).clamp(0,_navItems.length-1)); return KeyEventResult.handled; }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) { setState(() => _idx = (_idx+1).clamp(0,_navItems.length-1)); return KeyEventResult.handled; }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight){ setState(() => _navFocused = false); return KeyEventResult.handled; }
          return KeyEventResult.ignored;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _navFocused ? 180 : 72, color: const Color(0xFF0D0D0D),
          child: Column(children: [
            const SizedBox(height: 40),
            Padding(padding: const EdgeInsets.only(bottom: 32, left: 16, right: 16),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(colors: [Color(0xFFFFD740), Color(0xFFFFAB00)]).createShader(b),
                blendMode: BlendMode.srcIn,
                child: Text(_navFocused ? 'TOTV+' : 'T+',
                  style: GoogleFonts.cinzelDecorative(fontSize: _navFocused ? 18 : 14, fontWeight: FontWeight.w900, color: Colors.white)))),
            ...List.generate(_navItems.length, (i) {
              final (icon, label) = _navItems[i];
              final active = _idx == i;
              return GestureDetector(
                onTap: () => setState(() { _idx = i; _navFocused = false; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: EdgeInsets.symmetric(horizontal: _navFocused ? 16 : 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? C.gold.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: active ? Border.all(color: C.gold.withOpacity(0.4), width: 0.8) : null),
                  child: Row(children: [
                    Icon(icon, color: active ? C.gold : Colors.white54, size: 22),
                    if (_navFocused) ...[const SizedBox(width: 12),
                      Expanded(child: Text(label, style: GoogleFonts.cairo(
                          fontSize: 13, color: active ? C.gold : Colors.white70,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400)))],
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
