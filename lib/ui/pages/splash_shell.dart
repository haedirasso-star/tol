part of '../../main.dart';

// ════════════════════════════════════════════════════════════════
//  SPLASH — شاشة البداية
// ════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════
//  SPLASH v3 — Ultra-Fast (< 800ms to Shell)
//  Strategy: show UI at frame 1, all network = background
// ════════════════════════════════════════════════════════════════
class Splash extends StatefulWidget {
  const Splash();
  @override State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<double>   _scale;
  bool _nav = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);

    // ★ Animation — 600ms (was 1200ms)
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    // ★ Launch after 800ms — show UI instantly, don't wait for network
    Future.delayed(const Duration(milliseconds: 800), _go);
  }

  Future<void> _go() async {
    if (_nav || !mounted) return;
    _nav = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: []);

    if (RC.needsUpdate) {
      if (mounted) Navigator.of(context).pushReplacement(_route(_UpdateGatePage()));
      return;
    }

    // ★ FAST PATH: go to shell immediately, load everything in background
    final user = AuthService.currentUser;
    if (user != null) {
      // Fire-and-forget — don't await anything
      AuthService.startAdminListener(user.uid);
      Future(() => UserDataWatcher.startListening(user.uid));
      UserDataWatcher.setOnBanned(() {
        if (mounted) Navigator.of(context).pushReplacement(_route(const BannedPage()));
      });
      // Background checks — never block navigation
      unawaited(_backgroundChecks(user.uid));
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(_route(const Shell()));
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
        // Navigate to banned page from anywhere in the app
        Navigator.of(context).pushAndRemoveUntil(
          _route(const BannedPage()), (_) => false);
      }
    } catch (e) { debugPrint('[splash_shell] $e'); }
  }

  static PageRouteBuilder _route(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
  );

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ★ Logo
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [C.gold, C.imdb, C.goldDim],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ).createShader(b),
            blendMode: BlendMode.srcIn,
            child: Text('TOTV+', style: GoogleFonts.cinzelDecorative(
                fontSize: FS.logo, fontWeight: FontWeight.w900,
                color: C.textPri, letterSpacing: 8)),
          ),
          const SizedBox(height: 10),
          Text('منصة البث الذكية', style: GoogleFonts.cairo(
              fontSize: FS.md, color: C.textDim, fontWeight: FontWeight.w400,
              letterSpacing: 2)),
          const SizedBox(height: 60),
          // ★ Thin loader
          SizedBox(width: 32, height: 32,
            child: CircularProgressIndicator(
              color: C.gold.withOpacity(0.5),
              strokeWidth: 1.2)),
        ])),
    )),
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
          // أيقونة
          Container(width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [C.goldBg, C.goldBg]),
              border: Border.all(color: C.gold.withOpacity(0.5), width: 1.5),
              boxShadow: [BoxShadow(color: C.gold.withOpacity(0.2), blurRadius: FS.xl)]),
            child: Center(child: ShaderMask(
              shaderCallback: (r) => C.playGrad.createShader(r),
              child: const Icon(Icons.play_circle_fill_rounded, color: C.textPri, size: 34)))),
          const SizedBox(height: 20),
          Text('سجّل الدخول للمشاهدة',
              style: T.cairo(s: FS.xl, w: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          // بانر ساعة مجانية
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
//  FREE HOUR EXPIRED SHEET — منتهي الوقت المجاني
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
              gradient: const LinearGradient(colors: [C.goldBg, C.goldBg]),
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

    // ── إشعار التحديث التدريجي ──────────────────────────────
    AppState.onPartialLoad = () { if (mounted) setState(() {}); };

    // ★ تأخير 1 frame لإظهار الـ UI أولاً ثم تحميل البيانات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // تحميل المحتوى — يبدأ من الكاش فوراً
      unawaited(AppState.loadAll().then((_) {
        if (mounted) {
          setState(() {});
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) AppState.preloadPosters(context);
          });
        }
      }));

      unawaited(TVLayout.detect());

      // ★ تحميل الاشتراك في الخلفية — بدون إعادة تحميل كاملة
      unawaited(Sub.load().catchError((_) {}));
    });
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
      extendBody: true,  // ★ allows content to scroll under floating nav
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    // ★ 2026 Floating Nav — زجاجي عائم مع تأثير blur
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
                _navBtn(4, Icons.sports_soccer_rounded, Icons.sports_soccer_outlined, 'رياضة'),
                _navBtn(5, Icons.search_rounded,        Icons.search_outlined,        'بحث'),
                _navBtn(6, Icons.person_rounded,        Icons.person_outline_rounded, 'حسابي'),
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
          Sound.hapticL();
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
          // ★ Pill indicator + icon in one animated block
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
          width: _navFocused ? 180 : 72, color: C.bg,
          child: Column(children: [
            const SizedBox(height: 40),
            Padding(padding: const EdgeInsets.only(bottom: 32, left: 16, right: 16),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(colors: [C.gold, C.goldDim]).createShader(b),
                blendMode: BlendMode.srcIn,
                child: Text(_navFocused ? 'TOTV+' : 'T+',
                  style: GoogleFonts.cinzelDecorative(fontSize: _navFocused ? 18 : 14, fontWeight: FontWeight.w900, color: C.textPri)))),
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
                    borderRadius: BorderRadius.circular(R.md),
                    border: active ? Border.all(color: C.gold.withOpacity(0.4), width: 0.8) : null),
                  child: Row(children: [
                    Icon(icon, color: active ? C.gold : Colors.white54, size: 22),
                    if (_navFocused) ...[const SizedBox(width: 12),
                      Expanded(child: Text(label, style: GoogleFonts.cairo(
                          fontSize: FS.md, color: active ? C.gold : Colors.white70,
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
