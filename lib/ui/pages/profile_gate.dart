part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — شاشة «من يتابع الآن؟»
//  تظهر بعد تسجيل الدخول مباشرةً.
//  عند الضغط على الملف الشخصي:
//    • يُشغَّل صوت TOTV+ المميّز (أصلي — مؤلَّف خصيصاً للتطبيق)
//    • حركة تكبير + توهّج ذهبي + انتشار دائري ثم انتقال ناعم
//  ثم تظهر بطاقة زجاجية تدعو للانضمام لقناة تلجرام.
// ════════════════════════════════════════════════════════════════════════

class ProfileGatePage extends StatefulWidget {
  /// الصفحة التي ننتقل إليها بعد اختيار الملف الشخصي.
  final Widget next;
  const ProfileGatePage({super.key, required this.next});

  @override
  State<ProfileGatePage> createState() => _ProfileGatePageState();
}

class _ProfileGatePageState extends State<ProfileGatePage>
    with TickerProviderStateMixin {

  late final AnimationController _entry;   // ظهور الشاشة
  late final AnimationController _select;  // حركة الاختيار

  late final Animation<double> _titleFade;
  late final Animation<double> _cardFade;
  late final Animation<double> _cardRise;

  late final Animation<double> _scale;     // تكبير البطاقة المختارة
  late final Animation<double> _ripple;    // انتشار دائري ذهبي
  late final Animation<double> _glow;      // توهّج
  late final Animation<double> _fadeOut;   // اختفاء بقية العناصر

  bool _picked = false;

  String get _name {
    final u = AuthService.currentUser;
    final dn = (u?.displayName ?? '').trim();
    if (dn.isNotEmpty) return dn.split(' ').first;
    final em = (u?.email ?? '').trim();
    if (em.isNotEmpty) return em.split('@').first;
    return 'مشترك';
  }

  String? get _photo {
    final p = AuthService.currentUser?.photoURL;
    return (p != null && p.isNotEmpty) ? p : null;
  }

  @override
  void initState() {
    super.initState();

    _entry = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _select = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));

    _titleFade = CurvedAnimation(
        parent: _entry, curve: const Interval(0.0, 0.45, curve: Curves.easeOut));
    _cardFade = CurvedAnimation(
        parent: _entry, curve: const Interval(0.20, 0.75, curve: Curves.easeOut));
    _cardRise = Tween<double>(begin: 26, end: 0).animate(CurvedAnimation(
        parent: _entry, curve: const Interval(0.20, 0.85, curve: Curves.easeOutCubic)));

    // ── حركة الاختيار ──
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.92)
              .chain(CurveTween(curve: Curves.easeOut)), weight: 12),
      TweenSequenceItem(
          tween: Tween(begin: 0.92, end: 1.16)
              .chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 1.16, end: 1.06)
              .chain(CurveTween(curve: Curves.easeInOut)), weight: 58),
    ]).animate(_select);

    _ripple = CurvedAnimation(
        parent: _select, curve: const Interval(0.10, 0.72, curve: Curves.easeOutCubic));

    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 26),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.35), weight: 74),
    ]).animate(_select);

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: _select, curve: const Interval(0.55, 1.0, curve: Curves.easeIn)));
  }

  @override
  void dispose() {
    _entry.dispose();
    _select.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    if (_picked) return;
    setState(() => _picked = true);

    Sound.hapticM();
    Sound.signature();          // ★ الصوت المميّز الأصلي
    _select.forward();

    await Future.delayed(const Duration(milliseconds: 1350));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (_, __, ___) => widget.next,
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1.06, end: 1.0).animate(
              CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // ── وهج ذهبي خلفي ──
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _select,
            builder: (_, __) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 0.95,
                  colors: [
                    C.gold.withOpacity(0.10 + 0.16 * _glow.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── العنوان ──
                  FadeTransition(
                    opacity: _titleFade,
                    child: AnimatedBuilder(
                      animation: _select,
                      builder: (_, child) =>
                          Opacity(opacity: _fadeOut.value, child: child),
                      child: Column(children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [C.goldDim, C.gold, Color(0xFFFFF3C4), C.gold],
                          ).createShader(b),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            'TOTV+',
                            style: GoogleFonts.cinzelDecorative(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text('من يتابع الآن؟',
                            style: T.cairo(s: 26, w: FontWeight.w800)),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 44),

                  // ── بطاقة الملف الشخصي ──
                  AnimatedBuilder(
                    animation: Listenable.merge([_entry, _select]),
                    builder: (_, __) => Opacity(
                      opacity: _cardFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _cardRise.value),
                        child: Transform.scale(
                          scale: _picked ? _scale.value : 1.0,
                          child: _profileCard(size),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── بطاقة تلجرام الزجاجية ──
                  FadeTransition(
                    opacity: _cardFade,
                    child: AnimatedBuilder(
                      animation: _select,
                      builder: (_, child) =>
                          Opacity(opacity: _fadeOut.value, child: child),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22),
                        child: TelegramGlassCard(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ── تبديل الحساب ──
                  FadeTransition(
                    opacity: _cardFade,
                    child: AnimatedBuilder(
                      animation: _select,
                      builder: (_, child) =>
                          Opacity(opacity: _fadeOut.value, child: child),
                      child: TextButton(
                        onPressed: _picked ? null : () async {
                          Sound.nav();
                          await Sub.endSession();
                          GuestSession.reset();
                          await AuthService.signOut();
                          if (!mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const FirebaseLoginPage()),
                            (r) => false,
                          );
                        },
                        child: Text('تبديل الحساب',
                            style: T.cairo(s: FS.sm, c: C.textSec, w: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── بطاقة الملف الشخصي + حلقة الانتشار ──────────────────────────────
  Widget _profileCard(Size size) {
    const box = 116.0;
    final rippleMax = size.longestSide * 1.15;

    return SizedBox(
      width: box + 60,
      height: box + 74,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // حلقة الانتشار الذهبية
          if (_picked)
            Positioned(
              top: box / 2,
              child: IgnorePointer(
                child: Container(
                  width: rippleMax * _ripple.value,
                  height: rippleMax * _ripple.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: C.gold.withOpacity((1 - _ripple.value) * 0.55),
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),

          Column(children: [
            GestureDetector(
              onTap: _choose,
              child: AnimatedBuilder(
                animation: _select,
                builder: (_, child) => Container(
                  width: box,
                  height: box,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: C.gold.withOpacity(_picked
                          ? 0.45 + 0.55 * _glow.value
                          : 0.35),
                      width: _picked ? 2.0 + 1.4 * _glow.value : 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: C.gold.withOpacity(
                            _picked ? 0.30 + 0.40 * _glow.value : 0.14),
                        blurRadius: _picked ? 26 + 34 * _glow.value : 18,
                        spreadRadius: _picked ? 1 + 5 * _glow.value : 0,
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _avatar(box),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _select,
              builder: (_, child) => Opacity(
                  opacity: _picked ? _fadeOut.value : 1.0, child: child),
              child: Text(
                _name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.cairo(s: FS.lg, w: FontWeight.w700),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _avatar(double box) {
    final photo = _photo;
    if (photo != null) {
      return CachedNetworkImage(
        imageUrl: photo,
        width: box, height: box, fit: BoxFit.cover,
        placeholder: (_, __) => _initialsAvatar(box),
        errorWidget: (_, __, ___) => _initialsAvatar(box),
      );
    }
    return _initialsAvatar(box);
  }

  Widget _initialsAvatar(double box) {
    final letter = _name.isNotEmpty ? _name.characters.first.toUpperCase() : '؟';
    return Container(
      width: box,
      height: box,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1F), Color(0xFF0B0B0E)],
        ),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
          child: Opacity(
            opacity: 0.10,
            child: Image.asset('assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox()),
          ),
        ),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFFFE27A), C.gold, C.goldDim],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ).createShader(b),
          blendMode: BlendMode.srcIn,
          child: Text(
            letter,
            style: GoogleFonts.cairo(
              fontSize: box * 0.44,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  بطاقة تلجرام الزجاجية (Glassmorphism)
//  تظهر بعد تسجيل الدخول وفي صفحة الحساب.
// ════════════════════════════════════════════════════════════════════════
class TelegramGlassCard extends StatelessWidget {
  final bool dismissible;
  final VoidCallback? onDismiss;
  const TelegramGlassCard({super.key, this.dismissible = false, this.onDismiss});

  static const _tgBlue = Color(0xFF2AABEE);

  void _open(BuildContext context) {
    Sound.hapticM();
    var url = RC.telegram.trim();
    if (url.isEmpty) url = kTgChannel;
    if (!url.startsWith('http')) {
      url = 'https://t.me/${url.replaceAll('@', '')}';
    }
    try {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[telegram] $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(R.xl),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: _tgBlue.withOpacity(0.12),
                blurRadius: 26,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _tgBlue.withOpacity(0.30),
                      _tgBlue.withOpacity(0.10),
                    ]),
                    shape: BoxShape.circle,
                    border: Border.all(color: _tgBlue.withOpacity(0.45)),
                  ),
                  child: const Icon(Icons.send_rounded, color: _tgBlue, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('انضم إلى قناة تلجرام',
                          style: T.cairo(s: FS.md, w: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                        'مواعيد جميع المباريات وتحديثات التطبيق أولاً بأول',
                        style: T.cairo(s: FS.sm, c: Colors.white70, h: 1.45),
                      ),
                    ],
                  ),
                ),
                if (dismissible)
                  GestureDetector(
                    onTap: () { Sound.nav(); onDismiss?.call(); },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 18),
                      child: Icon(Icons.close_rounded,
                          size: 18, color: Colors.white.withOpacity(0.45)),
                    ),
                  ),
              ]),
              const SizedBox(height: 13),
              GestureDetector(
                onTap: () => _open(context),
                child: Container(
                  height: 44,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3EC0F5), _tgBlue],
                    ),
                    borderRadius: BorderRadius.circular(R.md),
                    boxShadow: [
                      BoxShadow(
                        color: _tgBlue.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.send_rounded, size: 17, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('انضم الآن',
                            style: T.cairo(
                                s: FS.md, w: FontWeight.w900, c: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
