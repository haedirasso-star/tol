part of '../../main.dart';

// ════════════════════════════════════════════════════════════════
//  TelegramWelcome — رسالة الترحيب بقناة تلجرام
//  ────────────────────────────────────────────────────────────
//  • تصميم زجاجي (Glassmorphism) فوق شبكة بوسترات من TMDB
//  • تظهر بعد تسجيل الدخول ودخول الشاشة الرئيسية
//  • النص والرابط قابلان للتعديل من لوحة الأدمن (Firestore)
//  • زر «اشترك في القناة» + زر X للإغلاق + «تخطي»
//
//  التحكم من Firestore:
//    app_config/remote_config
//      telegram          : "https://t.me/O_2828"
//      tg_title          : "انضم إلى قناتنا"
//      tg_body           : "..."
//      tg_button         : "اشترك في القناة"
//      tg_enabled        : true
//      tg_show_always    : false   ← true = كل فتح، false = مرة واحدة
// ════════════════════════════════════════════════════════════════

class TgWelcome {
  static const _kShownKey = 'tg_welcome_shown_v1';

  /// هل عُرضت من قبل؟ (تُخزَّن محلياً — لا قراءة Firestore)
  static Future<bool> _wasShown() async {
    try {
      final p = await SPref.i;
      return p.getBool(_kShownKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _markShown() async {
    try {
      final p = await SPref.i;
      await p.setBool(_kShownKey, true);
    } catch (_) {}
  }

  /// إعادة التعيين — للاختبار أو عند تغيير الرسالة من الأدمن
  static Future<void> reset() async {
    try {
      final p = await SPref.i;
      await p.remove(_kShownKey);
    } catch (_) {}
  }

  /// ★ نقطة الاستدعاء الوحيدة — نادِها من Shell.initState
  static Future<void> maybeShow(BuildContext ctx) async {
    if (!RC.tgEnabled) return;
    if (!RC.tgShowAlways && await _wasShown()) return;
    if (!ctx.mounted) return;

    // انتظر استقرار الواجهة قبل العرض
    await Future.delayed(const Duration(milliseconds: 900));
    if (!ctx.mounted) return;

    await _markShown();

    await showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withOpacity(0.72),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, __, ___) => const _TgWelcomeDialog(),
      transitionBuilder: (_, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// فتح رابط القناة — يحاول تطبيق تلجرام أولاً ثم المتصفح
  static Future<void> openChannel() async {
    final url = RC.telegram.trim();
    if (url.isEmpty) return;

    // حوّل https://t.me/xxx إلى tg://resolve?domain=xxx لفتح التطبيق مباشرة
    String? deepLink;
    final m = RegExp(r't\.me/(?:s/)?([A-Za-z0-9_]+)').firstMatch(url);
    if (m != null) deepLink = 'tg://resolve?domain=${m.group(1)}';

    try {
      if (deepLink != null &&
          await canLaunchUrl(Uri.parse(deepLink))) {
        await launchUrl(Uri.parse(deepLink));
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[TgWelcome.openChannel] $e');
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  الحوار نفسه
// ════════════════════════════════════════════════════════════════
class _TgWelcomeDialog extends StatefulWidget {
  const _TgWelcomeDialog();
  @override
  State<_TgWelcomeDialog> createState() => _TgWelcomeDialogState();
}

class _TgWelcomeDialogState extends State<_TgWelcomeDialog>
    with SingleTickerProviderStateMixin {
  List<String> _posters = const [];
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    // حركة بطيئة جداً للخلفية — 40 ثانية للدورة الكاملة.
    // بطيئة عمداً: الحركة السريعة خلف نص تُتعب العين وتستهلك بطارية.
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
    _loadPosters();
  }

  Future<void> _loadPosters() async {
    try {
      // ★ يستخدم مفتاح TMDB الموجود أصلاً في التطبيق
      final list = await TMDB.popularPosters();
      if (mounted && list.isNotEmpty) setState(() => _posters = list);
    } catch (_) {}
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  void _close() {
    Sound.hapticL();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final maxW = w > 520 ? 440.0 : w - 40;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                // ═══ ① خلفية البوسترات ═══════════════════════
                Positioned.fill(child: _TgPosterWall(
                  posters: _posters,
                  drift: _drift,
                )),

                // ═══ ② طبقة التعتيم + التدرّج ════════════════
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          C.bg.withOpacity(0.82),
                          C.bg.withOpacity(0.90),
                          C.bg.withOpacity(0.96),
                        ],
                      ),
                    ),
                  ),
                ),

                // ═══ ③ الزجاج ════════════════════════════════
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.14),
                        width: 1,
                      ),
                    ),
                    child: _content(),
                  ),
                ),

                // ═══ ④ زر الإغلاق X ══════════════════════════
                Positioned(
                  top: 10,
                  left: 10, // RTL: يسار = أعلى-يسار بصرياً
                  child: _TgGlassIconBtn(
                    icon: Icons.close_rounded,
                    onTap: _close,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── أيقونة تلجرام في دائرة زجاجية ─────────────────
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  C.telegram.withOpacity(0.90),
                  C.telegram.withOpacity(0.55),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: C.telegram.withOpacity(0.38),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.28),
                width: 1.2,
              ),
            ),
            child: const Icon(Icons.send_rounded,
                color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),

          // ── العنوان (قابل للتعديل من Firestore) ───────────
          Text(
            RC.tgTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: C.textPri,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // ── النص (قابل للتعديل من Firestore) ──────────────
          Text(
            RC.tgBody,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: C.textSec,
              fontSize: 14,
              height: 1.75,
            ),
          ),
          const SizedBox(height: 16),

          // ── الرابط الظاهر ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: R.rPill,
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_rounded, size: 15, color: C.telegram),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    RC.telegram.replaceFirst(RegExp(r'^https?://'), ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: C.textSec,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── زر الاشتراك ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                Sound.hapticM();
                await TgWelcome.openChannel();
                if (mounted) Navigator.of(context).maybePop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: C.telegram,
                foregroundColor: Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(borderRadius: R.rPill),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send_rounded, size: 19),
                  const SizedBox(width: 9),
                  Text(
                    RC.tgButton,
                    style: GoogleFonts.cairo(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ── تخطي ──────────────────────────────────────────
          TextButton(
            onPressed: _close,
            child: Text(
              'تخطي',
              style: GoogleFonts.cairo(
                color: C.textDim,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  جدار البوسترات — شبكة منزلقة ببطء
// ════════════════════════════════════════════════════════════════
class _TgPosterWall extends StatelessWidget {
  final List<String> posters;
  final AnimationController drift;
  const _TgPosterWall({required this.posters, required this.drift});

  @override
  Widget build(BuildContext context) {
    if (posters.isEmpty) {
      // بديل أنيق أثناء التحميل أو عند فشل TMDB — لا شاشة فارغة
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1815), Color(0xFF0F0E0D)],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: drift,
      builder: (_, __) {
        final t = drift.value;
        return OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.translate(
            // انزلاق قطري بطيء + تكبير خفيف لملء الإطار
            offset: Offset(-60 + t * 120, -40 + t * 80),
            child: Transform.scale(
              scale: 1.35,
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 2 / 3,
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < 16; i++)
                    _TgPosterCell(url: posters[i % posters.length]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TgPosterCell extends StatelessWidget {
  final String url;
  const _TgPosterCell({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 400),
        // memCacheWidth صغير عمداً: هذه خلفية مموّهة، لا تحتاج دقة عالية.
        // بدونه تُحمَّل 16 صورة بحجمها الكامل في الذاكرة بلا فائدة.
        memCacheWidth: 180,
        placeholder: (_, __) => Container(color: C.card),
        errorWidget: (_, __, ___) => Container(color: C.card),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  زر أيقونة زجاجي
// ════════════════════════════════════════════════════════════════
class _TgGlassIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TgGlassIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Icon(icon, color: C.textPri, size: 19),
          ),
        ),
      ),
    );
  }
}
