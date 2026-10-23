part of '../../main.dart';

// عناصر واجهة مشتركة بين الصفحات + انتقال _fade + نافذة الاشتراك (Paywall)

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
      Text('TOTV+', textDirection: TextDirection.ltr, style: TExtra.cinzel(s: FS.md, c: C.gold).copyWith(letterSpacing: 2)),
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

// ── ★ تأثير النقر المزدوج للتقديم/الإرجاع (Netflix-style) ──
class _SeekFlash extends StatefulWidget {
  final bool forward;
  const _SeekFlash({required this.forward});
  @override State<_SeekFlash> createState() => _SeekFlashState();
}
class _SeekFlashState extends State<_SeekFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final fwd = widget.forward;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeOut.transform(_c.value);
        final fade = (1.0 - t).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: fwd ? const Alignment(0.9, 0) : const Alignment(-0.9, 0),
              radius: 0.9,
              colors: [C.gold.withOpacity(0.16 * fade), Colors.transparent],
              stops: const [0.0, 1.0]),
            borderRadius: BorderRadius.horizontal(
              left: fwd ? const Radius.circular(400) : Radius.zero,
              right: fwd ? Radius.zero : const Radius.circular(400)),
          ),
          child: Center(child: Opacity(opacity: fade, child:
            Column(mainAxisSize: MainAxisSize.min, children: [
              Transform.translate(
                offset: Offset((fwd ? 1 : -1) * 8 * t, 0),
                child: Icon(
                  fwd ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                  color: Colors.white, size: 40,
                  shadows: [Shadow(color: C.gold.withOpacity(0.7), blurRadius: 16)])),
              const SizedBox(height: 4),
              Text('10 ثانية',
                style: T.cairo(s: FS.sm, w: FontWeight.w800, c: Colors.white)
                    .copyWith(shadows: const [Shadow(color: Colors.black54, blurRadius: 6)])),
            ]))),
        );
      });
  }
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
        color: C.goldBg,
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
