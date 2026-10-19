part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — شاشة «من يشاهد الآن؟»  (v3 — أسود وأبيض بأسلوب منصّات البث)
//  • خلفية سوداء صافية، نص أبيض، بلا توهّج ذهبي
//  • بطاقة الملف الشخصي + مربّع تلجرام بالشعار الحقيقي
//  • سطر دعوة: «تابع كل شيء، العروض والمسابقات عبر تلجرام»
//  • زر «الدخول إلى القائمة الرئيسية»
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

  late final Animation<double> _fade;
  late final Animation<double> _rise;
  late final Animation<double> _scale;     // تكبير البطاقة المختارة
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
        vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _select = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));

    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _rise = Tween<double>(begin: 18, end: 0).animate(
        CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.94)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.10)
          .chain(CurveTween(curve: Curves.easeOutBack)), weight: 45),
      TweenSequenceItem(tween: ConstantTween(1.10), weight: 40),
    ]).animate(_select);

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: _select, curve: const Interval(0.45, 1.0, curve: Curves.easeIn)));
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

    await Future.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 480),
      pageBuilder: (_, __, ___) => widget.next,
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: child,
      ),
    ));
  }

  Future<void> _switchAccount() async {
    Sound.nav();
    await Sub.endSession();
    GuestSession.reset();
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const FirebaseLoginPage()),
      (r) => false,
    );
  }

  // عنصر يختفي تدريجياً عند الاختيار
  Widget _fading(Widget child) => AnimatedBuilder(
        animation: _select,
        builder: (_, c) => Opacity(opacity: _fadeOut.value, child: c),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final w    = MediaQuery.of(context).size.width;
    final tile = (w * 0.27).clamp(92.0, 132.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Directionality(
       textDirection: TextDirection.rtl,
       child: SafeArea(
        child: AnimatedBuilder(
          animation: _entry,
          builder: (_, child) => Opacity(
            opacity: _fade.value,
            child: Transform.translate(offset: Offset(0, _rise.value), child: child),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _fading(Text('من يشاهد الآن؟',
                        style: T.cairo(s: 24, w: FontWeight.w700, c: Colors.white))),
                    const SizedBox(height: 34),

                    // ── الملف الشخصي + تلجرام ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedBuilder(
                          animation: _select,
                          builder: (_, child) => Transform.scale(
                              scale: _picked ? _scale.value : 1.0, child: child),
                          child: _GateTile(
                            size: tile,
                            label: _name,
                            selected: _picked,
                            onTap: _choose,
                            child: _avatar(tile),
                          ),
                        ),
                        SizedBox(width: tile * 0.36),
                        _fading(_GateTile(
                          size: tile,
                          label: 'قناة تلجرام',
                          onTap: () => openTelegram(),
                          child: ColoredBox(
                            color: const Color(0xFF16161A),
                            child: Center(child: TelegramLogo(size: tile * 0.52)),
                          ),
                        )),
                      ],
                    ),

                    const SizedBox(height: 26),

                    // ── سطر الدعوة لتلجرام ──
                    _fading(GestureDetector(
                      onTap: () => openTelegram(),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const TelegramLogo(size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'تابع كل شيء، العروض والمسابقات عبر تلجرام',
                              textAlign: TextAlign.center,
                              style: T.cairo(s: 14, w: FontWeight.w600,
                                  c: Colors.white.withOpacity(0.82), h: 1.5),
                            ),
                          ),
                        ],
                      ),
                    )),

                    const SizedBox(height: 30),

                    // ── زر الدخول ──
                    _fading(_GateButton(
                      label: 'الدخول إلى القائمة الرئيسية',
                      onTap: _picked ? null : _choose,
                    )),

                    const SizedBox(height: 14),

                    _fading(TextButton(
                      onPressed: _picked ? null : _switchAccount,
                      child: Text('تبديل الحساب',
                          style: T.cairo(s: FS.sm, c: Colors.white54, w: FontWeight.w600)),
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
       ),
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

  // حرف أبيض على مربع داكن مسطّح — بلا توهّج
  Widget _initialsAvatar(double box) {
    final letter = _name.isNotEmpty ? _name.characters.first.toUpperCase() : '؟';
    return Container(
      width: box, height: box,
      color: const Color(0xFF26262B),
      alignment: Alignment.center,
      child: Text(letter,
          style: GoogleFonts.cairo(
              fontSize: box * 0.42, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

// ── مربّع بأسلوب «من يشاهد» — حدّ أبيض عند التحديد أو التركيز (TV) ──────
class _GateTile extends StatefulWidget {
  final double size;
  final String label;
  final Widget child;
  final VoidCallback onTap;
  final bool selected;
  const _GateTile({required this.size, required this.label, required this.child,
      required this.onTap, this.selected = false});
  @override State<_GateTile> createState() => _GateTileState();
}

class _GateTileState extends State<_GateTile> {
  bool _focus = false;
  bool _down  = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected || _focus;
    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.onTap(); return null; }),
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.size + 12,
          child: Column(children: [
            AnimatedScale(
              scale: _down ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: widget.size, height: widget.size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: on ? Colors.white : Colors.transparent, width: 2.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(on ? 7.5 : 10),
                  child: SizedBox.expand(child: widget.child),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(widget.label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: T.cairo(s: 16, w: FontWeight.w700,
                    c: on ? Colors.white : Colors.white.withOpacity(0.86))),
          ]),
        ),
      ),
    );
  }
}

// ── زر رمادي عريض بأسلوب «إدارة الملفات الشخصية» ───────────────────────
class _GateButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _GateButton({required this.label, this.onTap});
  @override State<_GateButton> createState() => _GateButtonState();
}

class _GateButtonState extends State<_GateButton> {
  bool _focus = false;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    onShowFocusHighlight: (v) => setState(() => _focus = v),
    actions: <Type, Action<Intent>>{
      ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.onTap?.call(); return null; }),
    },
    child: Material(
      color: _focus ? Colors.white : const Color(0xFF2E2E33),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.onTap,
        child: SizedBox(
          height: 54, width: double.infinity,
          child: Center(child: Text(widget.label,
              style: T.cairo(s: 16, w: FontWeight.w700,
                  c: _focus ? Colors.black : Colors.white))),
        ),
      ),
    ),
  );
}

// ── شعار تلجرام الرسمي (دائرة زرقاء وطائرة ورقية بيضاء) ─────────────────
class TelegramLogo extends StatelessWidget {
  final double size;
  const TelegramLogo({super.key, this.size = 24});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: Stack(alignment: Alignment.center, children: [
      // خلفية بيضاء تظهر من فتحة الطائرة في الأيقونة
      Container(width: size * 0.82, height: size * 0.82,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
      FaIcon(FontAwesomeIcons.telegram, size: size, color: const Color(0xFF29A9EB)),
    ]),
  );
}

/// يفتح قناة تلجرام (الرابط من Firestore → app_config/remote_config → telegram)
void openTelegram() {
  Sound.hapticM();
  var url = RC.telegram.trim();
  if (url.isEmpty) url = kTgChannel;
  if (!url.startsWith('http')) url = 'https://t.me/${url.replaceAll('@', '')}';
  try {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('[telegram] $e');
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

  // ★ v2: بلون هوية التطبيق بدل أزرق تلجرام — لا ينشز عن بقية الشاشة
  static const _tg = C.gold;

  void _open(BuildContext context) => openTelegram();

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
                color: _tg.withOpacity(0.12),
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
                      _tg.withOpacity(0.30),
                      _tg.withOpacity(0.10),
                    ]),
                    shape: BoxShape.circle,
                    border: Border.all(color: _tg.withOpacity(0.45)),
                  ),
                  child: const Center(child: TelegramLogo(size: 30)),
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
                      colors: [Color(0xFFFFD98A), C.gold],
                    ),
                    borderRadius: BorderRadius.circular(R.md),
                    boxShadow: [
                      BoxShadow(
                        color: _tg.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TelegramLogo(size: 18),
                        const SizedBox(width: 8),
                        Text('انضم الآن',
                            style: T.cairo(
                                s: FS.md, w: FontWeight.w900, c: Colors.black)),
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
