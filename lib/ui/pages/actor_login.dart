part of '../../main.dart';

// ══════════════════════════════════════════════════════════════
//  LOGIN PAGE — خلفية بوسترات TMDB + واجهة شفافة
//  يدعم: Email/Password، Google Auth، Facebook Auth، Guest Mode
// ══════════════════════════════════════════════════════════════
class FirebaseLoginPage extends StatefulWidget {
  const FirebaseLoginPage({super.key});
  @override State<FirebaseLoginPage> createState() => _FirebaseLoginPageState();
}

class _FirebaseLoginPageState extends State<FirebaseLoginPage>
    with TickerProviderStateMixin {

  late final AnimationController _cardAnim;
  late final Animation<double>   _fadeIn;
  late final Animation<Offset>   _slideUp;
  late final AnimationController _posterAnim;

  final List<String> _posters = [];
  int    _posterIdx = 0;
  Timer? _posterTimer;
  String _mode = 'choose';

  final _phoneC = TextEditingController();
  final _otpC   = TextEditingController();
  final _emailC = TextEditingController();
  final _passC  = TextEditingController();
  final _nameC  = TextEditingController();
  bool   _busy      = false;
  bool   _showPass  = false;
  String _err       = '';
  int    _countdown = 0;
  Timer? _cdTimer;

  @override
  void initState() {
    super.initState();
    _cardAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _posterAnim= AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeIn    = CurvedAnimation(parent: _cardAnim, curve: Curves.easeOut);
    _slideUp   = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardAnim, curve: Curves.easeOutCubic));
    _loadPosters();
  }

  Future<void> _loadPosters() async {
    try {
      final r = await DioClient.tmdb.get('https://api.themoviedb.org/3/movie/popular',
          queryParameters: {'api_key': TMDB._defaultKey, 'language': 'ar', 'page': 1});
      final results = (r.data['results'] as List?)?.cast<Map>() ?? [];
      for (final m in results.take(14)) {
        final p = m['backdrop_path']?.toString() ?? '';
        if (p.isNotEmpty) _posters.add('https://image.tmdb.org/t/p/w1280$p');
      }
      if (mounted && _posters.isNotEmpty) {
        setState(() {});
        _posterTimer = Timer.periodic(const Duration(seconds: 4), (_) {
          if (!mounted) return;
          _posterAnim.forward(from: 0);
          setState(() => _posterIdx = (_posterIdx + 1) % _posters.length);
        });
      }
    } catch (e) { debugPrint('[actor_login] $e'); }
  }

  @override
  void dispose() {
    _cardAnim.dispose(); _posterAnim.dispose();
    _posterTimer?.cancel(); _cdTimer?.cancel();
    _phoneC.dispose(); _otpC.dispose();
    _emailC.dispose(); _passC.dispose(); _nameC.dispose();
    super.dispose();
  }

  void _err_(String e) { if (mounted) setState(() { _err = e; _busy = false; }); }
  void _busy_()        { if (mounted) setState(() { _busy = true; _err = ''; }); }

  Future<void> _afterLogin(AuthResult res) async {
    if (!res.ok) { _err_(res.msg); return; }
    if (!mounted) return;
    final uid = res.user?.uid;
    if (uid != null) {
      // FIX 1: ابدأ مستمع الأدمن — خفيف، لا يُسبب تجميداً
      AuthService.startAdminListener(uid);
      // FIX 2: حمّل الاشتراك المحلي أولاً (بدون انتظار Firestore)
      // _trackLogin في AuthService سبق وأعاد الاشتراك من Firestore
      unawaited(Sub.load());
      unawaited(GuestSession.load(uid));
      unawaited(AppState.loadAll());
    }
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const _PostLoginSplash(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  Future<void> _sendOTP() async {
    if (_busy) return;
    final phone = _phoneC.text.trim();
    if (phone.isEmpty) { _err_('أدخل رقم الهاتف'); return; }
    _busy_();
    bool codeSent = false;
    await AuthService.sendPhoneOTP(
      phone,
      onCodeSent: (vid, token) {
        codeSent = true;
        if (!mounted) return;
        setState(() { _mode = 'otp'; _busy = false; _countdown = 60; });
        _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (_countdown <= 0) { t.cancel(); return; }
          if (mounted) setState(() => _countdown--);
        });
      },
      onAutoVerify: (credential) async {
        final res = await AuthService.verifyPhoneOTP('AUTO');
        if (!mounted) return;
        await _afterLogin(res);
      },
      onError: (msg) {
        if (mounted) _err_(msg);
      },
    );
    if (!codeSent && mounted && _mode != 'otp') {
      _err_('تعذر إرسال الكود — تحقق من الرقم أو الاتصال بالإنترنت');
    }
  }

  Future<void> _verifyOTP() async {
    if (_busy) return; _busy_();
    final res = await AuthService.verifyPhoneOTP(_otpC.text.trim());
    if (!mounted) return; await _afterLogin(res);
  }

  Future<void> _emailLogin() async {
    if (_busy) return; _busy_();
    final res = await AuthService.signInEmail(_emailC.text.trim(), _passC.text);
    if (!mounted) return; await _afterLogin(res);
  }

  Future<void> _emailRegister() async {
    if (_busy) return; _busy_();
    final res = await AuthService.registerEmail(
        _emailC.text.trim(), _passC.text, _nameC.text.trim());
    if (!mounted) return; await _afterLogin(res);
  }

  Future<void> _googleSignIn() async {
    if (_busy) return; _busy_();
    final res = await AuthService.signInGoogle();
    if (!mounted) return; await _afterLogin(res);
  }

  Future<void> _facebookSignIn() async {
    if (_busy) return; _busy_();
    final res = await AuthService.signInFacebook();
    if (!mounted) return; await _afterLogin(res);
  }

  /// Guest Mode — تصفح فقط بدون تسجيل
  Future<void> _skipAsGuest() async {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const Shell(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(fit: StackFit.expand, children: [
        // ── Background Posters ──────────────────────────────
        if (_posters.isNotEmpty)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1200),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: CachedNetworkImage(
              key: ValueKey(_posterIdx),
              imageUrl: _posters[_posterIdx],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        // ── Gradient Overlay ────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xDD000000), Color(0x88000000), Color(0xCC000000), Color(0xFF000000)],
              stops: [0.0, 0.25, 0.65, 1.0],
            ),
          ),
        ),
        // ── Content ─────────────────────────────────────────
        SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(children: [
                  SizedBox(height: h * 0.08),
                  // Logo
                  Text('TOTV+',
                    style: TExtra.cinzel(s: 44, c: C.gold, w: FontWeight.w900)
                        .copyWith(letterSpacing: 12)),
                  const SizedBox(height: 6),
                  Text('منصة البث الذكية', style: T.cairo(s: FS.sm, c: Colors.white54)),
                  SizedBox(height: h * 0.06),
                  // Auth panel
                  _buildPanel(),
                  const SizedBox(height: 24),
                  // Guest Mode
                  GestureDetector(
                    onTap: _skipAsGuest,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(R.md),
                        border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.visibility_outlined, color: Colors.white38, size: 18),
                        const SizedBox(width: 8),
                        Text('تصفح كضيف', style: T.cairo(s: FS.md, c: Colors.white38)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('الضيف يمكنه التصفح فقط — المشاهدة تتطلب حساب',
                      style: T.caption(c: Colors.white24), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.xl),
      child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.52),
            borderRadius: BorderRadius.circular(R.xl),
            border: Border.all(color: Colors.white.withOpacity(0.09), width: 0.5),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildMode(),
          ),
        ),
    );
  }

  Widget _buildMode() {
    switch (_mode) {
      case 'email_login':    return _emailView(true);
      case 'email_register': return _emailView(false);
      default:               return _chooseView();
    }
  }

  Widget _chooseView() => Column(key: const ValueKey('choose'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('تسجيل الدخول', style: T.cairo(s: FS.xl, w: FontWeight.w800), textAlign: TextAlign.center),
    const SizedBox(height: 24),
    // Google
    _btn(icon: Icons.g_mobiledata_rounded, label: 'Google', color: Colors.white, textColor: Colors.black, onTap: _googleSignIn),
    const SizedBox(height: 10),
    // Email
    _btn(icon: Icons.email_outlined, label: 'البريد الإلكتروني', color: C.surface, textColor: Colors.white, onTap: () => setState(() { _mode = 'email_login'; _err = ''; })),
    _errWidget(),
    if (_busy) const Padding(padding: EdgeInsets.only(top: 14), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: C.gold, strokeWidth: 2)))),
  ]);

  Widget _phoneView() => Column(key: const ValueKey('phone'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _backRow('رقم الهاتف'),
    const SizedBox(height: 16),
    _input(_phoneC, 'رقم الهاتف (+9647...)', keyboardType: TextInputType.phone),
    const SizedBox(height: 14),
    _btn(icon: Icons.send_rounded, label: 'إرسال رمز التحقق', color: C.gold, textColor: Colors.black, onTap: _sendOTP),
    _errWidget(),
    if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator(color: C.gold, strokeWidth: 2))),
  ]);

  Widget _otpView() => Column(key: const ValueKey('otp'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _backRow('رمز التحقق'),
    const SizedBox(height: 6),
    Text('أُرسل الرمز إلى ${_phoneC.text}', style: T.caption(c: Colors.white54), textAlign: TextAlign.center),
    const SizedBox(height: 16),
    _input(_otpC, '000000', keyboardType: TextInputType.number, textAlign: TextAlign.center),
    const SizedBox(height: 14),
    _btn(icon: Icons.check_circle_outline_rounded, label: 'تحقق', color: C.gold, textColor: Colors.black, onTap: _verifyOTP),
    if (_countdown > 0) Padding(padding: const EdgeInsets.only(top: 10),
        child: Text('إعادة الإرسال بعد ${_countdown}ث', style: T.caption(c: Colors.white38), textAlign: TextAlign.center)),
    _errWidget(),
    if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator(color: C.gold, strokeWidth: 2))),
  ]);

  Widget _emailView(bool isLogin) => Column(key: ValueKey('email_$isLogin'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _backRow(isLogin ? 'تسجيل الدخول' : 'إنشاء حساب'),
    const SizedBox(height: 14),
    if (!isLogin) ...[_input(_nameC, 'الاسم الكامل'), const SizedBox(height: 10)],
    _input(_emailC, 'البريد الإلكتروني', keyboardType: TextInputType.emailAddress),
    const SizedBox(height: 10),
    _input(_passC, 'كلمة المرور', obscure: !_showPass, suffix: IconButton(
        icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, size: 18, color: Colors.white38),
        onPressed: () => setState(() => _showPass = !_showPass))),
    const SizedBox(height: 14),
    _btn(icon: isLogin ? Icons.login_rounded : Icons.person_add_rounded,
        label: isLogin ? 'دخول' : 'إنشاء الحساب',
        color: C.gold, textColor: Colors.black,
        onTap: isLogin ? _emailLogin : _emailRegister),
    const SizedBox(height: 10),
    GestureDetector(
        onTap: () => setState(() { _mode = isLogin ? 'email_register' : 'email_login'; _err = ''; }),
        child: Text(isLogin ? 'ليس لديك حساب؟ أنشئ حساباً' : 'لديك حساب؟ سجّل الدخول',
            style: T.caption(c: C.gold), textAlign: TextAlign.center)),
    if (isLogin) ...[
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () async {
          final email = _emailC.text.trim();
          if (email.isEmpty) { _err_('أدخل بريدك الإلكتروني أولاً'); return; }
          _busy_();
          final res = await AuthService.resetPassword(email);
          _err_(res.msg);
        },
        child: Text('نسيت كلمة المرور؟', style: T.caption(c: Colors.white38), textAlign: TextAlign.center)),
    ],
    _errWidget(),
    if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: CircularProgressIndicator(color: C.gold, strokeWidth: 2))),
  ]);

  Widget _backRow(String title) => Row(children: [
    GestureDetector(onTap: () => setState(() { _mode = 'choose'; _err = ''; }),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18)),
    const SizedBox(width: 10),
    Text(title, style: T.cairo(s: FS.lg, w: FontWeight.w700)),
  ]);

  Widget _btn({required IconData icon, required String label, required Color color,
      required Color textColor, required VoidCallback onTap}) =>
    GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(R.md)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(label, style: T.cairo(s: FS.md, w: FontWeight.w700, c: textColor)),
        ]),
      ),
    );

  Widget _input(TextEditingController c, String hint, {
    TextInputType? keyboardType, bool obscure = false,
    TextAlign textAlign = TextAlign.right, Widget? suffix}) =>
    TextField(
      controller: c, keyboardType: keyboardType,
      obscureText: obscure, textAlign: textAlign,
      style: T.cairo(s: FS.md, c: Colors.white),
      decoration: InputDecoration(
        hintText: hint, hintStyle: T.cairo(s: FS.sm, c: Colors.white38),
        filled: true, fillColor: Colors.white.withOpacity(0.07),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: const BorderSide(color: C.gold, width: 1)),
        suffixIcon: suffix,
      ),
    );

  Widget _errWidget() => _err.isEmpty ? const SizedBox(height: 4) :
    Padding(padding: const EdgeInsets.only(top: 10),
        child: Text(_err, style: T.caption(c: Colors.redAccent), textAlign: TextAlign.center));
}

// ══════════════════════════════════════════════════════════════
//  POST LOGIN SPLASH
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
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const Shell(),
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  @override
  void dispose() {
    _vc?.removeListener(_listen);
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _vc != null && _vc!.value.isInitialized
          ? SizedBox.expand(child: FittedBox(fit: BoxFit.cover,
              child: SizedBox(width: _vc!.value.size.width, height: _vc!.value.size.height,
                  child: VideoPlayer(_vc!))))
          : const SizedBox.expand(child: ColoredBox(color: Colors.black)),
    );
  }
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
    final photo = _data['profile_path']?.toString() ?? widget.photoUrl ?? '';
    final name  = _data['name']?.toString() ?? widget.actorName;
    final bio   = _data['biography']?.toString() ?? '';
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