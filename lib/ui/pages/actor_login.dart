part of '../../main.dart';

// ══════════════════════════════════════════════════════════════
//  LOGIN PAGE v5 — Glass Morphism / World-Class Design
//  فور فتح التطبيق → شاشة تسجيل الدخول مباشرة
//  بعد الدخول → شاشة حالة الحساب الشاملة
// ══════════════════════════════════════════════════════════════

class FirebaseLoginPage extends StatefulWidget {
  const FirebaseLoginPage({super.key});
  @override State<FirebaseLoginPage> createState() => _FirebaseLoginPageState();
}

class _FirebaseLoginPageState extends State<FirebaseLoginPage>
    with TickerProviderStateMixin {

  // ── Animations ───────────────────────────────────────────────
  late final AnimationController _bgCtrl;
  late final AnimationController _cardCtrl;
  late final Animation<double>   _cardFade;
  late final Animation<Offset>   _cardSlide;

  // ── Poster BG ────────────────────────────────────────────────
  final List<String> _posters = [];
  int    _posterIdx  = 0;
  Timer? _posterTimer;

  // ── Form state ───────────────────────────────────────────────
  String _mode     = 'choose'; // choose | email_login | email_register
  bool   _busy     = false;
  bool   _showPass = false;
  String _err      = '';
  int    _countdown = 0;
  Timer? _cdTimer;

  final _emailC = TextEditingController();
  final _passC  = TextEditingController();
  final _nameC  = TextEditingController();
  final _phoneC = TextEditingController();
  final _otpC   = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Background ambient animation
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);

    // Card entrance animation
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _cardFade  = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));

    _loadPosters();
  }

  Future<void> _loadPosters() async {
    try {
      final r = await DioClient.tmdb.get(
        'https://api.themoviedb.org/3/movie/popular',
        queryParameters: {'api_key': TMDB._defaultKey, 'language': 'ar', 'page': 1},
      );
      final results = (r.data['results'] as List?)?.cast<Map>() ?? [];
      for (final m in results.take(12)) {
        final p = m['backdrop_path']?.toString() ?? '';
        if (p.isNotEmpty) _posters.add('https://image.tmdb.org/t/p/w1280$p');
      }
      if (mounted && _posters.isNotEmpty) {
        setState(() {});
        _posterTimer = Timer.periodic(const Duration(seconds: 5), (_) {
          if (!mounted) return;
          setState(() => _posterIdx = (_posterIdx + 1) % _posters.length);
        });
      }
    } catch (e) { debugPrint('[login] poster: $e'); }
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _cardCtrl.dispose();
    _posterTimer?.cancel();
    _cdTimer?.cancel();
    _emailC.dispose(); _passC.dispose();
    _nameC.dispose(); _phoneC.dispose(); _otpC.dispose();
    super.dispose();
  }

  // ── State helpers ─────────────────────────────────────────────
  void _setErr(String e) { if (mounted) setState(() { _err = e; _busy = false; }); }
  void _setBusy()        { if (mounted) setState(() { _busy = true; _err = ''; }); }

  // ── Auth callbacks ───────────────────────────────────────────
  Future<void> _afterLogin(AuthResult res) async {
    if (!res.ok) { _setErr(res.msg); return; }
    if (!mounted) return;
    final uid = res.user?.uid;
    if (uid != null) {
      AuthService.startAdminListener(uid);
      unawaited(Sub.load());
      unawaited(AppState.loadAll());
      // ★ النظام الجديد: لا سيرفر افتراضي. فقط تأكد من وجود وثيقة المستخدم
      //   ليملأها الأدمن لاحقاً بسيرفر المستخدم الخاص.
      unawaited(_ensureUserDoc(uid, res.user?.email ?? ''));
    }
    // ★ بعد الدخول: شاشة «من يتابع الآن؟» ثم المحتوى
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) =>
          const ProfileGatePage(next: Shell()),
      transitionDuration: const Duration(milliseconds: 450),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  // ينشئ وثيقة المستخدم الأساسية فقط (بلا سيرفر) — الأدمن يضيف السيرفر لاحقاً.
  Future<void> _ensureUserDoc(String uid, String email) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await ref.get();
      final data = snap.data() ?? {};
      final hasSub = (data['subscription'] as Map?)?['plan'] == 'premium';
      if (hasSub) return; // مفعّل مسبقاً — لا تلمس
      final u = FirebaseAuth.instance.currentUser;
      await ref.set({
        'email': email.toLowerCase(),
        'display_name': u?.displayName ?? data['display_name'] ?? '',
        'subscription': {
          'plan': data['subscription']?['plan'] ?? 'free',
          'updated_at': FieldValue.serverTimestamp(),
        },
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) { debugPrint('[login] ensureUserDoc: $e'); }
  }

  Future<void> _googleSignIn()   async { if (_busy) return; _setBusy(); await _afterLogin(await AuthService.signInGoogle()); }
  Future<void> _facebookSignIn() async { if (_busy) return; _setBusy(); await _afterLogin(await AuthService.signInFacebook()); }
  Future<void> _emailLogin()     async { if (_busy) return; _setBusy(); await _afterLogin(await AuthService.signInEmail(_emailC.text.trim(), _passC.text)); }
  Future<void> _emailRegister()  async { if (_busy) return; _setBusy(); await _afterLogin(await AuthService.registerEmail(_emailC.text.trim(), _passC.text, _nameC.text.trim())); }

  // (أُلغي الدخول كضيف — كل مستخدم يجب أن يسجّل دخوله)


  // ══ BUILD ════════════════════════════════════════════════════
  @override
  // ════════════════════════════════════════════════════════════
  //  ★ v2 — واجهة دخول بأسلوب منصّات البثّ الحديثة
  //  البنية: مشهد بوسترات في الأعلى يذوب في أسود صافٍ،
  //  ثم لوحة دخول سوداء مطفأة في الأسفل.
  //  الخلفية سوداء 100% فتبدو الشاشة مطفأة على OLED.
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size    = MediaQuery.of(context).size;
    final kb      = MediaQuery.of(context).viewInsets.bottom;
    final onForm  = _mode != 'choose';
    // يتقلّص المشهد عند فتح لوحة المفاتيح أو الانتقال لنموذج البريد
    final heroH   = onForm || kb > 0
        ? size.height * 0.26
        : size.height * 0.52;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [

        // ── 1. المشهد العلوي ──────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          height: heroH,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            if (_posters.isNotEmpty)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 1600),
                transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
                child: CachedNetworkImage(
                  key: ValueKey(_posterIdx),
                  imageUrl: _posters[_posterIdx],
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 600),
                  errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
                ),
              )
            else
              const ColoredBox(color: Colors.black),

            // تعتيم كثيف — يبقي المشهد إيحاءً لا صورة صارخة
            const DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                stops: [0.0, 0.42, 0.78, 1.0],
                colors: [Color(0xB3000000), Color(0x66000000),
                         Color(0xE6000000), Color(0xFF000000)],
              ))),

            // وهج ذهبي هادئ
            AnimatedBuilder(
              animation: _bgCtrl,
              builder: (_, __) => Positioned(
                top: -70, right: -50,
                child: Container(
                  width: 240, height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      C.gold.withOpacity(0.05 + _bgCtrl.value * 0.04),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),

        // ── 2. المحتوى ────────────────────────────────────
        SafeArea(
          child: Column(children: [
            // الشعار داخل المشهد
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              height: heroH - MediaQuery.of(context).padding.top,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _cardFade,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LogoBlock(),
                    if (!onForm && kb == 0) ...[
                      const SizedBox(height: 14),
                      Text('آلاف الأفلام والمسلسلات والمباريات المباشرة',
                          textAlign: TextAlign.center,
                          style: T.cairo(s: FS.md, c: Colors.white70, h: 1.6)),
                    ],
                  ],
                ),
              ),
            ),

            // لوحة الدخول السوداء
            Expanded(
              child: FadeTransition(
                opacity: _cardFade,
                child: SlideTransition(
                  position: _cardSlide,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(22, 4, 22, 24 + kb * 0.02),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04), end: Offset.zero,
                          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                          child: child,
                        ),
                      ),
                      child: _buildMode(),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Mode Router ──────────────────────────────────────────────
  Widget _buildMode() {
    switch (_mode) {
      case 'email_login':    return _EmailView(key: const ValueKey('el'), isLogin: true, parent: this);
      case 'email_register': return _EmailView(key: const ValueKey('er'), isLogin: false, parent: this);
      default:               return _ChooseView(key: const ValueKey('ch'), parent: this);
    }
  }
}

// ══════════════════════════════════════════════════════════════
//  LOGO BLOCK
// ══════════════════════════════════════════════════════════════
class _LogoBlock extends StatelessWidget {
  // ★ v2: شعار التطبيق الفعلي بدل النص المكتوب
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Image.asset(
        'assets/images/logo_full.png',
        width: 190, height: 190, fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFF7CE68), Color(0xFFFFAA00), Color(0xFFF7CE68)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ).createShader(b),
          blendMode: BlendMode.srcIn,
          child: Text('TOTV+',
              textDirection: TextDirection.ltr,
              style: GoogleFonts.cinzelDecorative(
                  fontSize: 46, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: 10)),
        ),
      ),
      const SizedBox(height: 2),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _dot(), const SizedBox(width: 6),
        Text('منصة البث الذكي',
            style: T.cairo(s: FS.sm, c: C.textDim, w: FontWeight.w400)
                .copyWith(letterSpacing: 2)),
        const SizedBox(width: 6), _dot(),
      ]),
    ],
  );

  Widget _dot() => Container(
    width: 4, height: 4,
    decoration: BoxDecoration(color: C.gold.withOpacity(0.5), shape: BoxShape.circle),
  );
}

// ══════════════════════════════════════════════════════════════
//  CHOOSE VIEW — الشاشة الرئيسية للتسجيل
// ══════════════════════════════════════════════════════════════
class _ChooseView extends StatelessWidget {
  final _FirebaseLoginPageState parent;
  const _ChooseView({super.key, required this.parent});

  @override
  Widget build(BuildContext context) {
    final p = parent;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

      // ── Google — الإجراء الأساسي ──────────────────────────
      _AuthBtn(
        label: 'المتابعة باستخدام Google',
        icon: Icons.g_mobiledata_rounded,
        primary: true,
        busy: p._busy,
        autofocus: true,
        onTap: p._googleSignIn,
      ),
      const SizedBox(height: 11),

      // ── البريد ────────────────────────────────────────────
      _AuthBtn(
        label: 'المتابعة بالبريد الإلكتروني',
        icon: Icons.alternate_email_rounded,
        primary: false,
        busy: p._busy,
        onTap: () => p.setState(() { p._mode = 'email_login'; p._err = ''; }),
      ),

      const SizedBox(height: 22),

      // ── فاصل ──────────────────────────────────────────────
      Row(children: [
        const Expanded(child: Divider(color: Color(0xFF1F1F22), height: 1)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('جديد على TOTV+؟',
              style: T.cairo(s: FS.sm, c: C.textDim))),
        const Expanded(child: Divider(color: Color(0xFF1F1F22), height: 1)),
      ]),
      const SizedBox(height: 16),

      // ── إنشاء حساب ────────────────────────────────────────
      GestureDetector(
        onTap: p._busy ? null : () =>
            p.setState(() { p._mode = 'email_register'; p._err = ''; }),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text('إنشاء حساب جديد',
                style: T.cairo(s: FS.md, c: C.gold, w: FontWeight.w700)),
          ),
        ),
      ),

      _ErrWidget(err: p._err),

      const SizedBox(height: 14),
      Text('بالمتابعة أنت توافق على شروط الاستخدام وسياسة الخصوصية',
          textAlign: TextAlign.center,
          style: T.cairo(s: FS.xs, c: C.textDim, h: 1.6)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
//  ★ v2 — زر دخول موحّد (مسطّح، بلا تدرّجات صاخبة)
// ══════════════════════════════════════════════════════════════
class _AuthBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool primary, busy, autofocus;
  final VoidCallback? onTap;
  const _AuthBtn({
    required this.label, required this.icon, required this.primary,
    required this.busy, this.autofocus = false, this.onTap,
  });
  @override State<_AuthBtn> createState() => _AuthBtnState();
}

class _AuthBtnState extends State<_AuthBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.primary;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _down = true),
        onTapUp:     (_) => setState(() => _down = false),
        onTapCancel: ()  => setState(() => _down = false),
        onTap: widget.busy ? null : widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: on ? C.gold : const Color(0xFF141416),
              borderRadius: BorderRadius.circular(14),
              border: on ? null : Border.all(color: const Color(0xFF232326)),
            ),
            child: Center(
              child: widget.busy && on
                  ? const SizedBox(width: 21, height: 21,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.black))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.icon, size: on ? 26 : 20,
                          color: on ? Colors.black : C.textPri),
                      const SizedBox(width: 9),
                      Text(widget.label,
                          style: T.cairo(
                              s: FS.md, w: FontWeight.w800,
                              c: on ? Colors.black : C.textPri)),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  EMAIL VIEW — دخول / تسجيل بالبريد
// ══════════════════════════════════════════════════════════════
class _EmailView extends StatelessWidget {
  final _FirebaseLoginPageState parent;
  final bool isLogin;
  const _EmailView({super.key, required this.parent, required this.isLogin});

  @override
  Widget build(BuildContext context) {
    final p = parent;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Back row ─────────────────────────────────────────
      Row(children: [
        GestureDetector(
          onTap: () => p.setState(() { p._mode = 'choose'; p._err = ''; }),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(R.sm),
              border: Border.all(color: const Color(0xFF232326))),
            child: const Center(child: Icon(Icons.arrow_back_ios_new_rounded,
                color: C.textSec, size: 15))),
        ),
        const SizedBox(width: 12),
        Text(isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
            style: T.cairo(s: FS.lg, w: FontWeight.w800)),
      ]),
      const SizedBox(height: 22),

      // ── Name (register only) ──────────────────────────────
      if (!isLogin) ...[
        _GlassField(ctrl: p._nameC, hint: 'الاسم الكامل', icon: Icons.person_outline_rounded),
        const SizedBox(height: 12),
      ],

      // ── Email ─────────────────────────────────────────────
      _GlassField(ctrl: p._emailC, hint: 'البريد الإلكتروني',
          icon: Icons.email_outlined, type: TextInputType.emailAddress),
      const SizedBox(height: 12),

      // ── Password ─────────────────────────────────────────
      _GlassField(
        ctrl: p._passC,
        hint: 'كلمة المرور',
        icon: Icons.lock_outline_rounded,
        obscure: !p._showPass,
        suffix: IconButton(
          icon: Icon(p._showPass ? Icons.visibility_off : Icons.visibility,
              size: 18, color: Colors.white38),
          onPressed: () => p.setState(() => p._showPass = !p._showPass)),
      ),
      const SizedBox(height: 20),

      // ── Submit ────────────────────────────────────────────
      _PrimaryBtn(
        label: isLogin ? 'تسجيل الدخول' : 'إنشاء الحساب',
        icon: isLogin ? Icons.login_rounded : Icons.person_add_rounded,
        busy: p._busy,
        onTap: isLogin ? p._emailLogin : p._emailRegister,
      ),
      const SizedBox(height: 14),

      // ── Toggle ────────────────────────────────────────────
      GestureDetector(
        onTap: () => p.setState(() {
          p._mode = isLogin ? 'email_register' : 'email_login';
          p._err = '';
        }),
        child: Text(
          isLogin ? 'ليس لديك حساب؟  إنشاء حساب جديد'
                  : 'لديك حساب بالفعل؟  تسجيل الدخول',
          style: T.caption(c: C.gold), textAlign: TextAlign.center),
      ),

      // ── Forgot password ───────────────────────────────────
      if (isLogin) ...[
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final email = p._emailC.text.trim();
            if (email.isEmpty) { p._setErr('أدخل بريدك الإلكتروني أولاً'); return; }
            p._setBusy();
            final res = await AuthService.resetPassword(email);
            p._setErr(res.msg);
          },
          child: Text('نسيت كلمة المرور؟',
              style: T.caption(c: Colors.white38), textAlign: TextAlign.center)),
      ],

      _ErrWidget(err: p._err),
      if (p._busy)
        const Padding(padding: EdgeInsets.only(top: 14),
          child: Center(child: SizedBox(width: 24, height: 24,
            child: CircularProgressIndicator(color: C.gold, strokeWidth: 2)))),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════

class _TVFocusable extends StatefulWidget {
  final Widget Function(bool focused) builder;
  final VoidCallback? onTap;
  final bool autofocus;
  const _TVFocusable({required this.builder, this.onTap, this.autofocus = false});
  @override State<_TVFocusable> createState() => _TVFocusableState();
}
class _TVFocusableState extends State<_TVFocusable> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    autofocus: widget.autofocus,
    onShowFocusHighlight: (v) => setState(() => _focused = v),
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) { widget.onTap?.call(); return null; }),
    },
    child: GestureDetector(onTap: widget.onTap, child: widget.builder(_focused)),
  );
}

class _GlassField extends StatelessWidget {
  final TextEditingController ctrl;
  final String   hint;
  final IconData icon;
  final TextInputType? type;
  final bool obscure;
  final Widget? suffix;
  final TextAlign align;
  const _GlassField({required this.ctrl, required this.hint, required this.icon,
      this.type, this.obscure = false, this.suffix, this.align = TextAlign.right});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: type,
    obscureText: obscure,
    textAlign: align,
    style: T.cairo(s: FS.md, c: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: T.cairo(s: FS.sm, c: C.textDim),
      prefixIcon: Icon(icon, color: C.textDim, size: 19),
      suffixIcon: suffix,
      filled: true,
      // ★ v2: حقول سوداء مطفأة بحدّ رمادي محايد
      fillColor: const Color(0xFF0E0E10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: C.gold, width: 1.2)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF232326), width: 1)),
    ),
  );
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.icon, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: busy ? null : onTap,
    child: Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: busy ? null : C.playGrad,
        color: busy ? Colors.white12 : null,
        borderRadius: BorderRadius.circular(R.md),
        boxShadow: busy ? null : [BoxShadow(color: C.gold.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: busy ? Colors.white38 : Colors.black, size: 20),
        const SizedBox(width: 10),
        Text(label, style: T.cairo(s: FS.lg, c: busy ? Colors.white38 : Colors.black, w: FontWeight.w900)),
      ]),
    ),
  );
}

class _ErrWidget extends StatelessWidget {
  final String err;
  const _ErrWidget({required this.err});
  @override
  Widget build(BuildContext context) => err.isEmpty
    ? const SizedBox(height: 4)
    : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(R.sm),
            border: Border.all(color: Colors.red.withOpacity(0.3), width: 0.5)),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(err, style: T.caption(c: Colors.redAccent), textAlign: TextAlign.right)),
          ]),
        ),
      );
}


// ══════════════════════════════════════════════════════════════
//  ACCOUNT STATUS PAGE — شاشة حالة الحساب بعد تسجيل الدخول
//  تُظهر: اسم المستخدم + حالة الاشتراك + CTA واضح
// ══════════════════════════════════════════════════════════════

class _AccountStatusPage extends StatefulWidget {
  const _AccountStatusPage();
  @override State<_AccountStatusPage> createState() => _AccountStatusPageState();
}

class _AccountStatusPageState extends State<_AccountStatusPage>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;
  bool _subLoaded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // تحميل حالة الاشتراك بعد الدخول مباشرة
    _loadSub();
  }

  Future<void> _loadSub() async {
    await Sub.load().timeout(const Duration(seconds: 6), onTimeout: () {});
    if (mounted) setState(() => _subLoaded = true);
  }

  void _goToShell() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const ProfileGatePage(next: Shell()),
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final user      = AuthService.currentUser;
    final isPremium = SubCompat.isPremium;
    final userName  = user?.displayName ?? user?.email?.split('@').first ?? 'مستخدم TOTV+';
    final size      = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [

        // ── Ambient gradient background ──────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.5),
              radius: 1.2,
              colors: [Color(0xFF1A1400), Color(0xFF000000)],
            ),
          ),
        ),

        // ── Top glow ─────────────────────────────────────────
        Positioned(
          top: -100, left: 0, right: 0,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [
                (isPremium ? C.gold : const Color(0xFF4A90D9)).withOpacity(0.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        // ── Content ──────────────────────────────────────────
        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                  // ── Top: Logo small ───────────────────────
                  Center(child: ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                        colors: [C.gold, C.imdb, C.goldDim]).createShader(b),
                    blendMode: BlendMode.srcIn,
                    child: Text('TOTV+',
          textDirection: TextDirection.ltr,
                        style: GoogleFonts.cinzelDecorative(
                            fontSize: 22, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: 6)),
                  )),

                  const SizedBox(height: 36),

                  // ── User avatar + greeting ─────────────────
                  _UserGreeting(userName: userName, isPremium: isPremium),

                  const SizedBox(height: 28),

                  // ── Status Card ───────────────────────────
                  _subLoaded
                      ? (isPremium
                          ? _PremiumStatusCard(onContinue: _goToShell)
                          : _FreeStatusCard(onContinue: _goToShell))
                      : _LoadingStatusCard(),

                  const SizedBox(height: 20),

                  // ── Features Preview ──────────────────────
                  if (!isPremium || !_subLoaded) _FeaturesPreview(),

                  const SizedBox(height: 28),

                  // ── Continue button ───────────────────────
                  _PrimaryBtn(
                    label: isPremium ? 'ابدأ المشاهدة الآن' : 'تصفح التطبيق',
                    icon: isPremium
                        ? Icons.play_circle_fill_rounded
                        : Icons.explore_rounded,
                    busy: false,
                    onTap: _goToShell,
                  ),

                  const SizedBox(height: 12),

                  if (!isPremium && _subLoaded) ...[
                    // ── Subscribe CTA ─────────────────────
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse('https://payment-totv.vercel.app/'),
                        mode: LaunchMode.externalApplication),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: C.playGrad,
                          borderRadius: BorderRadius.circular(R.md),
                          boxShadow: [BoxShadow(
                              color: C.gold.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 4))],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Text('اشترك الآن — payment-totv.vercel.app',
                              style: T.cairo(s: FS.sm, c: Colors.black, w: FontWeight.w900)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.push(context, PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const HowToSubscribePage(),
                          transitionDuration: const Duration(milliseconds: 400),
                          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c))),
                      child: Center(child: Text('كيف أشترك؟ — اعرف الخطوات',
                          style: T.caption(c: C.gold))),
                    ),
                  ],

                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── User Greeting ────────────────────────────────────────────
class _UserGreeting extends StatelessWidget {
  final String userName;
  final bool   isPremium;
  const _UserGreeting({required this.userName, required this.isPremium});

  @override
  Widget build(BuildContext context) => Row(children: [
    // Avatar
    Container(
      width: 58, height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xFFFFD740), const Color(0xFFFF8C00)]
              : [const Color(0xFF4A90D9), const Color(0xFF1565C0)],
        ),
        boxShadow: [BoxShadow(
            color: (isPremium ? C.gold : const Color(0xFF4A90D9)).withOpacity(0.4),
            blurRadius: 16)],
      ),
      child: Center(child: Text(
        userName.isNotEmpty ? userName[0].toUpperCase() : 'T',
        style: T.cairo(s: FS.x2l, w: FontWeight.w900, c: Colors.black),
      )),
    ),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('أهلاً وسهلاً،', style: T.cairo(s: FS.sm, c: Colors.white38)),
      Text(userName, style: T.cairo(s: FS.lg, w: FontWeight.w800),
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isPremium
              ? C.gold.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(R.xl),
          border: Border.all(
              color: isPremium ? C.gold.withOpacity(0.4) : Colors.white12,
              width: 0.6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isPremium ? Icons.workspace_premium_rounded : Icons.person_rounded,
              color: isPremium ? C.gold : Colors.white38, size: 13),
          const SizedBox(width: 5),
          Text(isPremium ? 'PREMIUM' : 'مجاني',
              style: T.cairo(s: FS.xs, c: isPremium ? C.gold : Colors.white38,
                  w: FontWeight.w700)),
        ]),
      ),
    ])),
  ]);
}

// ── Premium Status Card ───────────────────────────────────────
class _PremiumStatusCard extends StatelessWidget {
  final VoidCallback onContinue;
  const _PremiumStatusCard({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final days = Sub.daysLeft;
    final exp  = Sub.expiryStr;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                C.gold.withOpacity(0.18),
                C.gold.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: C.gold.withOpacity(0.4), width: 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Header
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: C.gold.withOpacity(0.15),
                  border: Border.all(color: C.gold.withOpacity(0.4))),
                child: const Center(child: Icon(Icons.workspace_premium_rounded, color: C.gold, size: 22))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('اشتراكك نشط ✓', style: T.cairo(s: FS.lg, w: FontWeight.w900, c: C.gold)),
                Text('TOTV+ Premium', style: T.cairo(s: FS.sm, c: Colors.white54)),
              ]),
            ]),
            const SizedBox(height: 20),
            // Days left
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: Colors.white.withOpacity(0.06))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _statItem('$days', 'يوم متبقي', C.gold),
                Container(width: 0.5, height: 36, color: Colors.white12),
                _statItem(exp, 'تاريخ الانتهاء', Colors.white54),
                Container(width: 0.5, height: 36, color: Colors.white12),
                _statItem('∞', 'قنوات وأفلام', C.gold),
              ]),
            ),
            const SizedBox(height: 16),
            // Features
            _premFeat(Icons.live_tv_rounded,         'جميع القنوات والبث المباشر'),
            _premFeat(Icons.hd_rounded,              'جودة Full HD وأعلى'),
            _premFeat(Icons.block_rounded,           'بدون قيود أو إعلانات'),
            _premFeat(Icons.devices_rounded,         'جهازان في نفس الوقت'),
          ]),
        ),
      ),
    );
  }

  Widget _statItem(String val, String lbl, Color c) => Column(children: [
    Text(val, style: T.cairo(s: FS.xl, w: FontWeight.w900, c: c)),
    Text(lbl, style: T.cairo(s: FS.xs, c: Colors.white38)),
  ]);

  Widget _premFeat(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(children: [
      Icon(icon, color: C.gold, size: 16),
      const SizedBox(width: 10),
      Text(text, style: T.cairo(s: FS.sm, c: Colors.white70)),
    ]),
  );
}

// ── Free / No-Sub Status Card ─────────────────────────────────
class _FreeStatusCard extends StatelessWidget {
  final VoidCallback onContinue;
  const _FreeStatusCard({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final freeLeft = (GuestSession.remainingSecs ~/ 60);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.09),
                Colors.white.withOpacity(0.02),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ── Status header ─────────────────────────────
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A90D9).withOpacity(0.12),
                  border: Border.all(color: const Color(0xFF4A90D9).withOpacity(0.35))),
                child: const Center(child: Icon(Icons.info_outline_rounded,
                    color: Color(0xFF4A90D9), size: 22))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('حساب مجاني', style: T.cairo(s: FS.lg, w: FontWeight.w900)),
                Text('لا يوجد اشتراك نشط حالياً', style: T.cairo(s: FS.sm, c: Colors.white38)),
              ])),
            ]),

            const SizedBox(height: 20),

            // ── Free trial remaining ──────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90D9).withOpacity(0.08),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: const Color(0xFF4A90D9).withOpacity(0.25))),
              child: Row(children: [
                const Icon(Icons.timer_rounded, color: Color(0xFF4A90D9), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('وقت المشاهدة المجاني المتبقي',
                      style: T.cairo(s: FS.xs, c: Colors.white38)),
                  Text('$freeLeft دقيقة',
                      style: T.cairo(s: FS.lg, w: FontWeight.w900, c: const Color(0xFF4A90D9))),
                ])),
              ]),
            ),

            const SizedBox(height: 20),

            // ── Subscription invitation ───────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [C.gold.withOpacity(0.12), C.gold.withOpacity(0.03)],
                ),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: C.gold.withOpacity(0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: C.gold, size: 18),
                  const SizedBox(width: 8),
                  Text('مطلوب اشتراك لمشاهدة المحتوى',
                      style: T.cairo(s: FS.md, w: FontWeight.w800, c: C.gold)),
                ]),
                const SizedBox(height: 8),
                Text(
                  'للاستمتاع بآلاف الأفلام والمسلسلات والقنوات بجودة عالية '
                  'بدون قيود، يرجى الاشتراك في TOTV+ من خلال رابط الدفع الخاص بنا.',
                  style: T.cairo(s: FS.sm, c: Colors.white54),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                // ── Payment link ──────────────────────────
                GestureDetector(
                  onTap: () => launchUrl(
                    Uri.parse('https://payment-totv.vercel.app/'),
                    mode: LaunchMode.externalApplication),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: C.playGrad,
                      borderRadius: BorderRadius.circular(R.md),
                      boxShadow: [BoxShadow(
                          color: C.gold.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 3))],
                    ),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.open_in_browser_rounded, color: Colors.black, size: 18),
                        const SizedBox(width: 8),
                        Text('صفحة الاشتراك الرسمية',
                            style: T.cairo(s: FS.md, c: Colors.black, w: FontWeight.w900)),
                      ]),
                      const SizedBox(height: 2),
                      Text('payment-totv.vercel.app',
                          style: T.cairo(s: FS.xs, c: Colors.black54, w: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // ── Plans preview ─────────────────────────────
            Row(children: [
              Expanded(child: _miniPlan('شهري',   '5,000',  'د.ع')),
              const SizedBox(width: 8),
              Expanded(child: _miniPlan('ربعي',   '13,000', 'د.ع')),
              const SizedBox(width: 8),
              Expanded(child: _miniPlan('سنوي',   '45,000', 'د.ع')),
            ]),

            const SizedBox(height: 16),

            // ── Support buttons ───────────────────────────
            if (RC.whatsapp.isNotEmpty)
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://wa.me/${RC.whatsapp}?text=${Uri.encodeComponent("مرحباً، أريد الاشتراك في TOTV+")}'),
                  mode: LaunchMode.externalApplication),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: C.whatsapp.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(R.md),
                    border: Border.all(color: C.whatsapp.withOpacity(0.35))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.support_agent_rounded, color: C.whatsapp, size: 18),
                    const SizedBox(width: 8),
                    Text('تواصل مع الدعم عبر واتساب',
                        style: T.cairo(s: FS.sm, c: C.whatsapp, w: FontWeight.w700)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _miniPlan(String title, String price, String cur) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(R.sm),
      border: Border.all(color: Colors.white.withOpacity(0.08))),
    child: Column(children: [
      Text(title, style: T.cairo(s: FS.xs, c: Colors.white54)),
      const SizedBox(height: 4),
      Text(price, style: T.cairo(s: FS.md, w: FontWeight.w900, c: C.gold)),
      Text(cur, style: T.cairo(s: FS.xs, c: Colors.white38)),
    ]),
  );
}

// ── Loading Status Card ───────────────────────────────────────
class _LoadingStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 28, height: 28,
            child: CircularProgressIndicator(color: C.gold, strokeWidth: 2)),
          SizedBox(height: 12),
          Text('جارٍ التحقق من الاشتراك...', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ])),
      ),
    ),
  );
}

// ── Features Preview (for free users) ────────────────────────
class _FeaturesPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('ماذا ستحصل مع TOTV+ Premium',
          style: T.cairo(s: FS.md, w: FontWeight.w800), textAlign: TextAlign.center),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [
        _feat(Icons.live_tv_rounded,         'آلاف القنوات'),
        _feat(Icons.movie_rounded,           'أفلام بلا حدود'),
        _feat(Icons.hd_rounded,             'جودة 4K/HD'),
        _feat(Icons.block_rounded,          'بدون إعلانات'),
        _feat(Icons.speed_rounded,          'بث سريع'),
        _feat(Icons.devices_rounded,        'جهازان'),
      ]),
    ],
  );

  Widget _feat(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(R.md),
      border: Border.all(color: Colors.white.withOpacity(0.08))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: C.gold, size: 15),
      const SizedBox(width: 6),
      Text(label, style: T.cairo(s: FS.xs, c: Colors.white70, w: FontWeight.w600)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════
//  POST LOGIN SPLASH — فيديو ترحيب بعد تسجيل الدخول
// ══════════════════════════════════════════════════════════════
class _PostLoginSplash extends StatefulWidget {
  const _PostLoginSplash();
  @override State<_PostLoginSplash> createState() => _PostLoginSplashState();
}

class _PostLoginSplashState extends State<_PostLoginSplash> {
  VideoPlayerController? _vc;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _init();
    Future.delayed(const Duration(seconds: 6), _go);
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.asset('assets/videos/0320.mp4',
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      await ctrl.setVolume(1.0);
      await ctrl.setLooping(false);
      ctrl.addListener(_listen);
      if (mounted) setState(() => _vc = ctrl);
      await ctrl.play();
    } catch (_) {
      await Future.delayed(const Duration(seconds: 2));
      _go();
    }
  }

  void _listen() {
    final v = _vc;
    if (v == null || !mounted) return;
    final dur = v.value.duration;
    final pos = v.value.position;
    if (dur > Duration.zero && pos >= dur - const Duration(milliseconds: 150)) _go();
    if (v.value.hasError) _go();
  }

  Future<void> _go() async {
    if (_done || !mounted) return;
    _done = true;
    // ★ بعد الفيديو → شاشة حالة الحساب
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const _AccountStatusPage(),
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  @override
  void dispose() { _vc?.removeListener(_listen); _vc?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: _vc != null && _vc!.value.isInitialized
        ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover,
            child: SizedBox(width: _vc!.value.size.width, height: _vc!.value.size.height,
                child: VideoPlayer(_vc!))))
        : const SizedBox.expand(child: ColoredBox(color: Colors.black)),
  );
}

// ══════════════════════════════════════════════════════════════
//  ACTOR PAGE
// ══════════════════════════════════════════════════════════════
class ActorPage extends StatefulWidget {
  final int    actorId;
  final String actorName;
  final String? photoUrl;
  const ActorPage({super.key, required this.actorId, required this.actorName, this.photoUrl});
  @override State<ActorPage> createState() => _ActorPageState();
}

class _ActorPageState extends State<ActorPage> {
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await TMDB.getActorDetails(widget.actorId);
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final photo   = _data['profile_path']?.toString() ?? widget.photoUrl ?? '';
    final name    = _data['name']?.toString() ?? widget.actorName;
    final bio     = _data['biography']?.toString() ?? '';
    final movies  = (_data['movies']   as List?) ?? [];
    final tvShows = (_data['tv_shows'] as List?) ?? [];

    return Scaffold(
      backgroundColor: C.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.gold))
          : CustomScrollView(slivers: [
              SliverAppBar(
                expandedHeight: 300, pinned: true, backgroundColor: C.bg,
                leading: _backBtn(context),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(fit: StackFit.expand, children: [
                    if (photo.isNotEmpty)
                      CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover)
                    else Container(color: C.surface),
                    Container(decoration: const BoxDecoration(gradient: CExtra.heroGrad)),
                    Positioned(bottom: 16, right: 16, left: 16, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name, style: TExtra.display()),
                        if (_data['birthday'] != null)
                          Text('المولد: ${_data['birthday']}', style: T.caption()),
                      ],
                    )),
                  ]),
                ),
              ),
              if (bio.isNotEmpty) SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('السيرة الذاتية', style: TExtra.h2()),
                  const SizedBox(height: 8),
                  Text(bio, style: T.body(), maxLines: 6, overflow: TextOverflow.ellipsis),
                ]),
              )),
              if (movies.isNotEmpty) ...[
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,16,16,8),
                    child: Text('أفلامه', style: TExtra.h2()))),
                SliverToBoxAdapter(child: SizedBox(height: 195, child: ListView.separated(
                  scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemCount: movies.length,
                  itemBuilder: (ctx, i) => _card(ctx, movies[i], false),
                ))),
              ],
              if (tvShows.isNotEmpty) ...[
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,16,16,8),
                    child: Text('مسلسلاته', style: TExtra.h2()))),
                SliverToBoxAdapter(child: SizedBox(height: 195, child: ListView.separated(
                  scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemCount: tvShows.length,
                  itemBuilder: (ctx, i) => _card(ctx, tvShows[i], true),
                ))),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ]),
    );
  }

  Widget _card(BuildContext ctx, Map item, bool isTv) {
    final poster = item['poster']?.toString() ?? item['poster_path']?.toString() ?? '';
    final title  = item['title']?.toString() ?? item['name']?.toString() ?? '';
    return GestureDetector(
      onTap: () => showModalBottomSheet(context: ctx, backgroundColor: Colors.transparent,
          isScrollControlled: true, useSafeArea: true,
          builder: (_) => _InfoSheetLoader(
            item: {...item, 'name': title, 'tmdb_id': item['id']?.toString() ?? ''},
            type: isTv ? 'series' : 'movie',
          )),
      child: SizedBox(width: 110, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(R.md),
          child: poster.isNotEmpty
              ? CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover, width: 110)
              : Container(color: C.surface, child: const Icon(Icons.movie, color: C.dim)))),
        const SizedBox(height: 4),
        Text(title, style: T.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    );
  }

  Widget _backBtn(BuildContext ctx) => GestureDetector(
    onTap: () => Navigator.pop(ctx),
    child: Container(margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(R.sm)),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white)),
  );
}

// ══════════════════════════════════════════════════════════════
//  PRICING PAGE

// ══════════════════════════════════════════════════════════════
//  PRICING PAGE
