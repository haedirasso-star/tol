part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — شاشة الدفع المحسّنة (نسخة 2)
//  ────────────────────────────────────────────────────────────────────────
//  • Drop-in: أضِف هذا الملف إلى parts في main.dart:
//        part 'ui/pages/payment_sheet.dart';
//  • كلاسات بأسماء جديدة (بادئة Pay) كي لا تتعارض مع _PaymentSheet القديم.
//  • نقطة الدخول العامة:  BuyPremiumButton()   أو   PayPlansSheet.show(context)
//  • يستخدم نفس التوكنز: C / T / FS / R / Sound / DioClient.
//
//  لتفعيل رفع الإيصال داخل التطبيق (اختياري — يحتاج حزمتين):
//   1) pubspec.yaml:  image_picker: ^1.1.2   و   firebase_storage: ^13.0.5
//   2) main.dart imports:  import 'package:image_picker/image_picker.dart';
//                          import 'package:firebase_storage/firebase_storage.dart';
//   3) بدّل kReceiptUploadInApp إلى true وفعّل جسم _pickReceipt() المعلّق.
// ════════════════════════════════════════════════════════════════════════

/// عند true: يفتح منتقي الصور ويرفع الإيصال إلى Storage.
/// عند false (الافتراضي): يُحوّل المستخدم لإرسال الإيصال عبر واتساب (يعمل بلا حزم إضافية).
const bool kReceiptUploadInApp = true;

// ── نموذج الباقة ──────────────────────────────────────────────────────────
class PayPlan {
  final String id, title, price, period, badge, quality;
  final int priceNum, devices, accent;
  final List<String> features;
  const PayPlan({
    required this.id, required this.title, required this.price,
    required this.priceNum, required this.period, required this.devices,
    required this.badge, required this.accent, required this.quality,
    required this.features,
  });

  static const all = <PayPlan>[
    PayPlan(id: 'monthly',   title: 'شهري',  price: '5,000',  priceNum: 5000,
        period: '/شهر',    devices: 1, badge: 'الأكثر شيوعاً', accent: 0xFFFFD740,
        quality: 'SD / HD',
        features: ['جهاز واحد', 'جميع القنوات والأفلام', 'جودة HD', 'دعم فني']),
    PayPlan(id: 'quarterly', title: '3 أشهر', price: '13,000', priceNum: 13000,
        period: '/3 أشهر', devices: 2, badge: 'وفّر 13%',       accent: 0xFFFFD740,
        quality: 'FHD / 4K',
        features: ['جهازان', 'جميع القنوات والأفلام', 'جودة 4K', 'دعم 24/7', 'اختيار ذكي للمحتوى']),
    PayPlan(id: 'yearly',    title: 'سنوي',   price: '45,000', priceNum: 45000,
        period: '/سنة',    devices: 2, badge: 'أفضل قيمة',      accent: 0xFFFFD740,
        quality: '4K Ultra',
        features: ['جهازان', 'جميع القنوات والأفلام', 'أعلى جودة 4K', 'أولوية بالدعم', 'مزايا حصرية']),
  ];
}

// ── نموذج طريقة الدفع ──────────────────────────────────────────────────────
class PayMethod {
  final String id, label, sub;
  final String? asset, number, name, badge;
  final int color, bg;
  const PayMethod({
    required this.id, required this.label, required this.sub,
    this.asset, this.number, this.name, this.badge,
    required this.color, required this.bg,
  });

  static const all = <PayMethod>[
    PayMethod(id: 'fib', label: 'FIB', sub: 'First Iraqi Bank — تحويل بنكي فوري',
        asset: 'assets/payment/fib.png', number: '07714415816', name: 'حيدر عصام',
        badge: 'الأسرع', color: 0xFF00C9A7, bg: 0xFF0B2C2E),
    PayMethod(id: 'zain', label: 'Zain Cash', sub: 'زين كاش — محفظة إلكترونية',
        asset: 'assets/payment/zain.png', number: '07714415816',
        badge: 'شائع', color: 0xFFFFFFFF, bg: 0xFF111111),
    PayMethod(id: 'qi', label: 'Qi Card', sub: 'بطاقة كي — تحويل إلكتروني',
        asset: 'assets/payment/qi.png', number: '7065169257', name: 'حيدر عصام',
        color: 0xFFFFD800, bg: 0xFF1A1600),
    // ★ شراء مباشر عبر واتساب
    PayMethod(id: 'whatsapp', label: 'شراء عبر واتساب',
        sub: 'تواصل معنا مباشرة لإتمام الاشتراك',
        badge: 'الأسرع 💬', color: 0xFF25D366, bg: 0xFF0A1F12),
  ];

  // ★ مبلغ كرت آسيا سيل المطلوب حسب الخطة
  static String asiaAmount(String planId) {
    switch (planId) {
      case 'monthly':   return '5,000';
      case 'quarterly': return '15,000';
      case 'yearly':    return '50,000';
      default:          return '5,000';
    }
  }

  // ★ أرقام يمكن تغييرها من Firebase / صفحة الأدمن (app_config/payment_numbers)
  // المفتاح = id الطريقة، القيمة = {number, name}
  static Map<String, Map<String, String>> overrides = {};

  static Future<void> loadOverrides() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config').doc('payment_numbers').get();
      final d = doc.data() ?? {};
      final map = <String, Map<String, String>>{};
      d.forEach((k, v) {
        if (v is Map) {
          map[k] = {
            'number': v['number']?.toString() ?? '',
            'name': v['name']?.toString() ?? '',
          };
        }
      });
      overrides = map;
    } catch (_) {}
  }

  // الرقم الفعلي (من Firebase إن وُجد، وإلا الافتراضي)
  String get liveNumber => overrides[id]?['number']?.isNotEmpty == true
      ? overrides[id]!['number']! : (number ?? '');
  String get liveName => overrides[id]?['name']?.isNotEmpty == true
      ? overrides[id]!['name']! : (name ?? '');
}

// ════════════════════════════════════════════════════════════════════════
//  زر الدخول العام — ضَعه في صفحة الحساب بدل _PurchasePlansButton القديم
// ════════════════════════════════════════════════════════════════════════
class BuyPremiumButton extends StatelessWidget {
  const BuyPremiumButton({super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { Sound.hapticM(); PayPlansSheet.show(context); },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [C.gold.withOpacity(0.16), C.gold.withOpacity(0.04)],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: C.gold.withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: C.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(R.sm)),
            child: const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('اشترك في TOTV+ Premium',
                style: T.cairo(s: FS.md, w: FontWeight.w800)),
            Text('آلاف القنوات والأفلام بجودة 4K — بدون إعلانات',
                style: T.caption(c: C.textSec)),
          ])),
          const Icon(Icons.chevron_left_rounded, color: C.gold),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  PLANS SHEET — اختيار الباقة
// ════════════════════════════════════════════════════════════════════════
class PayPlansSheet extends StatelessWidget {
  const PayPlansSheet({super.key});

  static void show(BuildContext ctx) {
    PayMethod.loadOverrides(); // حمّل الأرقام من Firebase
    showModalBottomSheet(
        context: ctx, isScrollControlled: true,
        backgroundColor: Colors.transparent, useSafeArea: true,
        builder: (_) => const PayPlansSheet());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.90, minChildSize: 0.5, maxChildSize: 0.96,
      builder: (_, sc) => _glassSheet(posterBg: true, child: Column(children: [
        _grabHandle(),
        // ── Hero ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
          child: Row(children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                  colors: [C.gold, C.imdb, C.goldDim]).createShader(b),
              blendMode: BlendMode.srcIn,
              child: Text('TOTV+',
                  style: GoogleFonts.cinzelDecorative(
                      fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white))),
            const SizedBox(width: 10),
            _pill('Premium', C.gold),
            const Spacer(),
            Text('اختر خطتك', style: T.cairo(s: FS.lg, w: FontWeight.w900)),
          ]),
        ),
        const SizedBox(height: 8),
        // ── Plans ─────────────────────────────────────────────
        Expanded(child: ListView(controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
          physics: const BouncingScrollPhysics(),
          children: [
            for (final p in PayPlan.all)
              _PayPlanCard(plan: p, onTap: () {
                Navigator.pop(context);
                _PayInfoGate.show(context, p);
              }),
            const SizedBox(height: 8),
            _featuresBox(),
          ])),
      ])),
    );
  }

  Widget _featuresBox() => ClipRRect(
        borderRadius: BorderRadius.circular(R.md),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('كل الخطط تشمل:',
                  style: T.cairo(s: FS.sm, w: FontWeight.w800, c: C.gold)),
              const SizedBox(height: 10),
              for (final f in const [
                (Icons.live_tv_rounded,    'جميع القنوات والأفلام والمسلسلات'),
                (Icons.hd_rounded,         'جودة SD / HD / FHD / 4K'),
                (Icons.devices_rounded,    'يعمل على كل المنصّات والأجهزة'),
                (Icons.block_rounded,      'بدون إعلانات — دعم فني 24/7'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(f.$1, color: C.gold, size: 15),
                    const SizedBox(width: 10),
                    Text(f.$2, style: T.cairo(s: FS.sm, c: Colors.white70)),
                  ])),
            ]),
          ),
        ),
      );
}

// ── بطاقة باقة — تصميم Netflix ──────────────────────────────────────────
class _PayPlanCard extends StatelessWidget {
  final PayPlan plan;
  final VoidCallback onTap;
  const _PayPlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color   = C.gold; // ★ توحيد على الذهبي (ثابت)
    final popular = plan.id == 'quarterly'; // الأكثر قيمة يُبرز
    return GestureDetector(
      onTap: () { Sound.hapticM(); onTap(); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.xl),
          // ذهبي + أسود
          gradient: LinearGradient(
            begin: Alignment.topRight, end: Alignment.bottomLeft,
            colors: [
              const Color(0xFF1A1608).withOpacity(0.96),
              Colors.black.withOpacity(0.92),
            ]),
          border: Border.all(
              color: color.withOpacity(popular ? 0.85 : 0.4),
              width: popular ? 2 : 1.2),
          boxShadow: popular
              ? [BoxShadow(color: color.withOpacity(0.28), blurRadius: 30, spreadRadius: -4)]
              : [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 14)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // شريط الشارة العلوي
          if (popular)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(R.xl - 2))),
              child: Center(child: Text('⭐ ${plan.badge}',
                  style: T.cairo(s: FS.xs, w: FontWeight.w900, c: Colors.black)))),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // العنوان + الشارة
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(R.sm),
                    border: Border.all(color: color.withOpacity(0.4))),
                  child: Text(plan.quality,
                      style: T.cairo(s: FS.xs, w: FontWeight.w800, c: color))),
                const Spacer(),
                if (!popular)
                  Text(plan.badge, style: T.cairo(s: FS.xs, w: FontWeight.w700, c: color)),
              ]),
              const SizedBox(height: 14),
              Text('اشتراك ${plan.title}',
                  style: T.cairo(s: FS.lg, w: FontWeight.w900, c: C.textPri)),
              const SizedBox(height: 8),
              // السعر الكبير
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                ShaderMask(
                  shaderCallback: (r) =>
                      LinearGradient(colors: [color, color.withOpacity(0.65)]).createShader(r),
                  child: Text(plan.price,
                      style: T.cairo(s: 34, w: FontWeight.w900, c: Colors.white, h: 1))),
                const SizedBox(width: 6),
                Padding(padding: const EdgeInsets.only(bottom: 5),
                  child: Text('د.ع ${plan.period}',
                      style: T.cairo(s: FS.sm, w: FontWeight.w700, c: C.textSec))),
              ]),
              const SizedBox(height: 16),
              // المزايا
              for (final f in plan.features)
                Padding(padding: const EdgeInsets.only(bottom: 9),
                  child: Row(children: [
                    Container(width: 20, height: 20,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
                      child: Icon(Icons.check_rounded, size: 13, color: color)),
                    const SizedBox(width: 11),
                    Expanded(child: Text(f, style: T.cairo(s: FS.sm, c: Colors.white70))),
                  ])),
              const SizedBox(height: 8),
              // زر الاختيار
              Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.75)]),
                  borderRadius: BorderRadius.circular(R.md),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14)]),
                child: Center(child: Text('اختر هذه الباقة',
                    style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black))),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  PAYMENT SHEET — التدفّق: 0 طريقة · 1 تفاصيل · 2 نجاح + تتبّع
// ════════════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════════════
//  بوابة شرح إلزامية 5 ثوانٍ — قبل اختيار طريقة الدفع
// ════════════════════════════════════════════════════════════════════════
class _PayInfoGate extends StatefulWidget {
  final PayPlan plan;
  const _PayInfoGate({required this.plan});
  static void show(BuildContext ctx, PayPlan plan) => showModalBottomSheet(
        context: ctx, isScrollControlled: true,
        backgroundColor: Colors.transparent, useSafeArea: true,
        isDismissible: false, enableDrag: false,
        builder: (_) => _PayInfoGate(plan: plan));
  @override State<_PayInfoGate> createState() => _PayInfoGateState();
}

class _PayInfoGateState extends State<_PayInfoGate> {
  int _left = 5;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left <= 1) { _t?.cancel(); if (mounted) setState(() => _left = 0); }
      else if (mounted) setState(() => _left--);
    });
  }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ready = _left == 0;
    return DraggableScrollableSheet(
      initialChildSize: 0.74, minChildSize: 0.5, maxChildSize: 0.9,
      builder: (_, sc) => _glassSheet(posterBg: true, child: ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        physics: const BouncingScrollPhysics(),
        children: [
          Center(child: Container(width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)))),
          // شعار التطبيق
          Center(child: Container(width: 92, height: 92,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.gold.withOpacity(0.18), C.gold.withOpacity(0.04)]),
              shape: BoxShape.circle,
              border: Border.all(color: C.gold.withOpacity(0.5), width: 2),
              boxShadow: [BoxShadow(color: C.gold.withOpacity(0.3), blurRadius: 28, spreadRadius: 1)]),
            child: Padding(padding: const EdgeInsets.all(18),
              child: ClipOval(child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 38)))))),
          const SizedBox(height: 18),
          Center(child: Text('خطوات إتمام الاشتراك',
              style: T.cairo(s: FS.xl, w: FontWeight.w900))),
          const SizedBox(height: 6),
          Center(child: Text('باقة ${widget.plan.title} — ${widget.plan.price} د.ع',
              style: T.cairo(s: FS.sm, c: C.gold, w: FontWeight.w700))),
          const SizedBox(height: 20),
          _step(1, 'اختر طريقة الدفع', 'وحوّل المبلغ إلى الرقم الظاهر لك.'),
          _step(2, 'أرسل إثبات الدفع', 'أرسل رقم الطلب وصورة الحوالة إلى واتساب.'),
          _step(3, 'تفعيل تلقائي', 'يُفعّل حسابك خلال 1 إلى 30 دقيقة.'),
          _step(4, 'لم يُفعّل؟', 'تواصل مع فريق الدعم وقدّم شكوى من التطبيق.', last: true),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: ready ? () {
              Navigator.pop(context);
              _PayPaymentSheet.show(context, widget.plan);
            } : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 54,
              decoration: BoxDecoration(
                gradient: ready ? const LinearGradient(colors: [Color(0xFFFFE27A), C.gold]) : null,
                color: ready ? null : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(R.md),
                border: ready ? null : Border.all(color: Colors.white12)),
              child: Center(child: Text(
                ready ? 'فهمت، متابعة' : 'يرجى القراءة… $_left',
                style: T.cairo(s: FS.md, w: FontWeight.w900,
                    c: ready ? Colors.black : C.textSec)))),
          ),
        ])),
    );
  }

  Widget _step(int n, String title, String body, {bool last = false}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(
            color: C.gold.withOpacity(0.14), shape: BoxShape.circle,
            border: Border.all(color: C.gold.withOpacity(0.5))),
          child: Center(child: Text('$n',
              style: T.cairo(s: FS.sm, w: FontWeight.w900, c: C.gold)))),
        if (!last) Container(width: 2, height: 30, color: C.gold.withOpacity(0.2)),
      ]),
      const SizedBox(width: 13),
      Expanded(child: Padding(padding: const EdgeInsets.only(top: 2, bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.cairo(s: FS.md, w: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(body, style: T.cairo(s: FS.sm, c: C.textSec, h: 1.5)),
        ]))),
    ]);
}

class _PayPaymentSheet extends StatefulWidget {
  final PayPlan plan;
  const _PayPaymentSheet({required this.plan});

  static void show(BuildContext ctx, PayPlan plan) => showModalBottomSheet(
        context: ctx, isScrollControlled: true,
        backgroundColor: Colors.transparent, useSafeArea: true,
        builder: (_) => _PayPaymentSheet(plan: plan));

  @override
  State<_PayPaymentSheet> createState() => _PayPaymentSheetState();
}

class _PayPaymentSheetState extends State<_PayPaymentSheet> {
  // ⚠️ أمان: انقل هذا التوكن لاحقاً إلى Cloud Function — لا تتركه في التطبيق نهائياً.
  static const _tgBotToken = '7929309914:AAGsv_xZFX1I-KvFQUd8_xtGAeubH2YiReE';
  static const _tgChatId   = '1418184484';

  int     _step = 0;          // 0 method · 1 details · 2 success
  PayMethod? _method;
  bool    _busy = false;
  String  _err  = '';
  String  _orderId = '';
  bool    _receiptAttached = false;
  String  _receiptUrl = '';
  String  _receiptB64 = '';   // ★ الصورة مخزّنة كـ base64 (أوثق من Storage)

  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cardCtrl  = TextEditingController(); // ★ الرقم السري لكرت آسيا سيل

  @override
  void initState() {
    super.initState();
    // ── تعبئة تلقائية من حساب Firebase ──
    final u = FirebaseAuth.instance.currentUser;
    if ((u?.displayName ?? '').isNotEmpty) _nameCtrl.text = u!.displayName!;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _cardCtrl.dispose(); super.dispose(); }

  Color get _ac => Color(widget.plan.accent);

  // ★ هل الطريقة المختارة هي كرت رصيد آسيا سيل؟
  bool get _isAsia => _method?.id == 'asiacell';

  bool get _canSubmit {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_isAsia) {
      // يتطلب: رقم هاتف صحيح + رقم سري للكرت (12+ رقماً)
      final phoneOk = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '').length >= 10;
      final cardOk  = _cardCtrl.text.trim().replaceAll(RegExp(r'\D'), '').length >= 12;
      return phoneOk && cardOk;
    }
    return _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '').length >= 10;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _step == 2 ? 0.78 : 0.90,
      minChildSize: 0.4, maxChildSize: 0.96,
      builder: (_, sc) => _glassSheet(posterBg: true, child: Column(children: [
        _grabHandle(),
        _header(),
        Expanded(child: SingleChildScrollView(
          controller: sc,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 36),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.05, 0), end: Offset.zero)
                    .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                child: child)),
            child: _step == 0 ? _step0() : _step == 1 ? _step1() : _step2(),
          ),
        )),
      ])),
    );
  }

  // ── الترويسة + مؤشّر الخطوات ──────────────────────────────────────────
  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
    child: Row(children: [
      GestureDetector(
        onTap: () {
          Sound.hapticL();
          if (_step == 1) { setState(() { _step = 0; _method = null; _err = ''; }); }
          else { Navigator.pop(context); }
        },
        child: Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08), shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: Icon(_step == 2 ? Icons.close_rounded : Icons.arrow_back_ios_rounded,
              size: _step == 2 ? 16 : 14, color: Colors.white54))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_step == 2 ? 'تم إرسال الطلب 🎉' : 'إتمام الشراء',
            style: T.cairo(s: FS.lg, w: FontWeight.w900)),
        Text('اشتراك ${widget.plan.title} — ${widget.plan.price} د.ع',
            style: T.caption(c: _ac)),
      ])),
      if (_step < 2)
        Row(children: List.generate(3, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: i == _step ? 22 : 6, height: 6,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: i == _step ? _ac : i < _step ? _ac.withOpacity(0.4) : Colors.white12,
            borderRadius: BorderRadius.circular(R.tiny))))),
    ]),
  );

  // ════════════════════════════════════════════════════════════════════
  //  STEP 0 — اختيار طريقة الدفع
  // ════════════════════════════════════════════════════════════════════
  Widget _step0() => Column(key: const ValueKey('s0'),
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('اختر طريقة الدفع', style: T.cairo(s: FS.lg, w: FontWeight.w900)),
    const SizedBox(height: 4),
    Text('حوّل المبلغ وأرسل بياناتك ليُفعّل اشتراكك', style: T.caption(c: C.textSec)),
    const SizedBox(height: 16),
    // المبلغ المطلوب
    Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_ac.withOpacity(0.12), _ac.withOpacity(0.03)],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: _ac.withOpacity(0.3))),
      child: Row(children: [
        Icon(Icons.payments_rounded, color: _ac, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المبلغ المطلوب', style: T.caption(c: C.textSec)),
          Text('${widget.plan.price} د.ع', style: T.cairo(s: FS.xl, w: FontWeight.w900, c: _ac)),
        ])),
        _pill(widget.plan.period, _ac),
      ]),
    ),
    const SizedBox(height: 18),
    for (final m in PayMethod.all)
      _PayMethodCard(method: m, onTap: () {
        Sound.hapticL();
        if (m.id == 'whatsapp') {
          // ★ شراء مباشر عبر واتساب — رسالة جاهزة
          final wa = RC.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
          final u  = FirebaseAuth.instance.currentUser;
          final msg = Uri.encodeComponent(
            'مرحباً، أريد الاشتراك في TOTV+\n'
            'الباقة: ${widget.plan.title} (${widget.plan.price} د.ع)\n'
            'البريد: ${u?.email ?? '—'}');
          if (wa.isNotEmpty) {
            launchUrl(Uri.parse('https://wa.me/$wa?text=$msg'),
                mode: LaunchMode.externalApplication);
          }
          return;
        }
        setState(() { _method = m; _step = 1; _err = ''; });
      }),
  ]);

  // ════════════════════════════════════════════════════════════════════
  //  STEP 1 — تفاصيل الدفع
  // ════════════════════════════════════════════════════════════════════
  Widget _step1() {
    final m = _method!;
    final color = Color(m.color);
    return Column(key: const ValueKey('s1'),
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // بطاقة الدفع
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(m.bg).withOpacity(0.85),
          borderRadius: BorderRadius.circular(R.xl),
          border: Border.all(color: color.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (m.asset != null)
              Container(width: 80, height: 44, padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(R.sm)),
                child: Image.asset(m.asset!, fit: BoxFit.contain))
            else
              Container(width: 80, height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(R.sm),
                  border: Border.all(color: color.withOpacity(0.3))),
                child: Icon(Icons.language_rounded, color: color, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.label, style: T.cairo(s: FS.lg, w: FontWeight.w900, c: color)),
              Text(_isAsia ? 'أدخل الرقم السري للكرت أدناه' : 'حوّل المبلغ إلى الرقم أدناه',
                  style: T.caption(c: Colors.white38)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_isAsia ? PayMethod.asiaAmount(widget.plan.id) : widget.plan.price,
                  style: T.cairo(s: FS.xl, w: FontWeight.w900, c: color)),
              Text(_isAsia ? 'رصيد آسيا' : 'د.ع', style: T.caption(c: color.withOpacity(0.7))),
            ]),
          ]),
          const SizedBox(height: 18),
          Container(height: 0.5, color: color.withOpacity(0.2)),
          const SizedBox(height: 14),
          if (_isAsia) ...[
            // ★ تعليمات كرت آسيا سيل
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.sim_card_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'اشترِ كرت رصيد آسيا سيل بقيمة ${PayMethod.asiaAmount(widget.plan.id)} د.ع، '
                'ثم اكتب الرقم السري المكشوط للكرت في الحقل أدناه مع اسمك. '
                'سيصل طلبك للإدارة ويُفعّل اشتراكك خلال دقائق.',
                style: T.cairo(s: FS.sm, c: const Color(0xFFE8C9CB), h: 1.55))),
            ]),
          ] else if (m.liveNumber.isNotEmpty) ...[
            Text('رقم الحساب — اضغط للنسخ', style: T.caption(c: Colors.white38)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _copy(m.liveNumber),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(R.md),
                  border: Border.all(color: color.withOpacity(0.25),
                      style: BorderStyle.solid, width: 1)),
                child: Row(children: [
                  Expanded(child: Text(m.liveNumber,
                      style: T.cairo(s: FS.xl, w: FontWeight.w900, ls: 1))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(color: color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(R.sm)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('نسخ', style: T.cairo(s: FS.sm, w: FontWeight.w700, c: color)),
                      const SizedBox(width: 4),
                      Icon(Icons.copy_rounded, size: 13, color: color),
                    ])),
                ]),
              ),
            ),
            if (m.liveName.isNotEmpty) ...[
              const SizedBox(height: 11),
              Row(children: [
                const Icon(Icons.person_rounded, size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Text('الاسم: ', style: T.caption(c: Colors.white38)),
                Text(m.liveName, style: T.cairo(s: FS.md, w: FontWeight.w700)),
              ]),
            ],
          ],
        ]),
      ),
      const SizedBox(height: 14),
      // تلميحة
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.gold.withOpacity(0.07),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: C.gold.withOpacity(0.18))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lightbulb_rounded, color: C.gold, size: 16),
          const SizedBox(width: 9),
          Expanded(child: Text(
            'حوّل المبلغ كاملاً، ثم أرفق الإيصال أو أرسل بياناتك ليُفعّل اشتراكك خلال دقائق.',
            style: T.cairo(s: FS.sm, c: const Color(0xFFD8CDBB), h: 1.5))),
        ]),
      ),
      const SizedBox(height: 14),
      // الاسم
      _label('الاسم الكامل', auto: _nameCtrl.text.isNotEmpty),
      _input(_nameCtrl, 'اكتب اسمك', onChanged: (_) => setState(() {})),
      if (_isAsia) ...[
        // ★ رقم الهاتف
        _label('رقم الهاتف'),
        _input(_phoneCtrl, '07XX XXX XXXX',
            keyboard: TextInputType.phone, onChanged: (_) => setState(() {})),
        // ★ الرقم السري لكرت آسيا سيل
        _label('الرقم السري لكرت آسيا سيل'),
        _input(_cardCtrl, 'اكشط الكرت واكتب الرقم السري',
            keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
      ] else ...[
        // الهاتف
        _label('رقم الهاتف'),
        _input(_phoneCtrl, '07XX XXX XXXX',
            keyboard: TextInputType.phone, onChanged: (_) => setState(() {})),
        // ★ صورة الإيصال (للتأكيد) — بعد تعبئة البيانات
        const SizedBox(height: 14),
        _label('صورة إيصال التحويل (للتأكيد)'),
        const SizedBox(height: 6),
        _receiptCard(),
      ],
      if (_err.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(_err, style: T.cairo(s: FS.sm, c: C.red)),
      ],
      const SizedBox(height: 16),
      // إرسال
      GestureDetector(
        onTap: (_busy || !_canSubmit) ? null : _submit,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _canSubmit ? 1 : 0.45,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD98A), C.gold]),
              borderRadius: BorderRadius.circular(R.md),
              boxShadow: [BoxShadow(color: C.gold.withOpacity(0.25), blurRadius: 20)]),
            child: Center(child: _busy
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black))
                : Text('تأكيد وإرسال الطلب',
                    style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black))),
          ),
        ),
      ),
      const SizedBox(height: 11),
      // واتساب الدعم
      if (RC.whatsapp.isNotEmpty)
        GestureDetector(
          onTap: () {
            final wa = RC.whatsapp.replaceAll('+', '');
            launchUrl(Uri.parse('https://wa.me/$wa'), mode: LaunchMode.externalApplication);
          },
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: C.whatsapp.withOpacity(0.08),
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: C.whatsapp.withOpacity(0.3))),
            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.support_agent_rounded, color: C.whatsapp, size: 18),
              const SizedBox(width: 8),
              Text('تواصل مع الدعم عبر واتساب',
                  style: T.cairo(s: FS.md, c: C.whatsapp, w: FontWeight.w700)),
            ])),
          ),
        ),
    ]);
  }

  // ── بطاقة رفع الإيصال ────────────────────────────────────────────────
  Widget _receiptCard() => GestureDetector(
    onTap: _pickReceipt,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: (_receiptAttached ? C.green : C.gold).withOpacity(0.05),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(
            color: (_receiptAttached ? C.green : C.gold).withOpacity(0.4),
            width: 1.4)),
      child: Column(children: [
        if (_uploading)
          const SizedBox(width: 26, height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: C.gold))
        else if (_receiptAttached && _receiptB64.isNotEmpty)
          ClipRRect(borderRadius: BorderRadius.circular(R.sm),
            child: Image.memory(base64Decode(_receiptB64),
                height: 70, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.check_circle_rounded, color: C.green, size: 26)))
        else
          Icon(_receiptAttached ? Icons.check_circle_rounded : Icons.upload_file_rounded,
              color: _receiptAttached ? C.green : C.gold, size: 26),
        const SizedBox(height: 7),
        Text(_uploading ? 'جارٍ رفع الصورة…'
              : _receiptAttached ? 'تم إرفاق الإيصال ✓' : 'ارفع صورة إيصال التحويل',
            style: T.cairo(s: FS.md, w: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(_receiptAttached ? 'اضغط لتغيير الصورة' : 'PNG · JPG — يُسرّع التفعيل',
            style: T.caption(c: C.textSec), textAlign: TextAlign.center),
      ]),
    ),
  );

  bool _uploading = false;

  Future<void> _pickReceipt() async {
    Sound.hapticL();
    try {
      final picker = ImagePicker();
      // ضغط قوي ليناسب التخزين المباشر في الطلب (base64)
      final XFile? img = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 55, maxWidth: 1100);
      if (img == null) return;
      setState(() { _uploading = true; });
      var bytes = await img.readAsBytes();
      // حدّ أمان: إن كانت الصورة كبيرة جداً، أعد الضغط بجودة أقل
      if (bytes.lengthInBytes > 700 * 1024) {
        final XFile? img2 = await picker.pickImage(
            source: ImageSource.gallery, imageQuality: 35, maxWidth: 900);
        if (img2 != null) bytes = await img2.readAsBytes();
      }
      if (bytes.lengthInBytes > 900 * 1024) {
        if (mounted) {
          setState(() { _uploading = false; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('الصورة كبيرة جداً — اختر صورة أصغر')));
        }
        return;
      }
      _receiptB64 = base64Encode(bytes);
      // محاولة رفع إلى Storage أيضاً (اختياري — لا يُعطّل شيئاً إن فشل)
      _tryStorageUpload(bytes);
      if (mounted) setState(() { _uploading = false; _receiptAttached = true; });
    } catch (e) {
      debugPrint('[receipt] pick failed: $e');
      if (mounted) {
        setState(() { _uploading = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذّر إرفاق الصورة — حاول مجدداً')));
      }
    }
  }

  // رفع إلى Storage في الخلفية (إن كان مفعّلاً) — لا يؤثّر على نجاح الإرفاق
  Future<void> _tryStorageUpload(List<int> bytes) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final id  = 'receipt_${DateTime.now().millisecondsSinceEpoch}';
      final ref = FirebaseStorage.instance.ref('receipts/$uid/$id.jpg');
      await ref.putData(Uint8List.fromList(bytes),
          SettableMetadata(contentType: 'image/jpeg'));
      _receiptUrl = await ref.getDownloadURL();
    } catch (e) { debugPrint('[receipt] storage optional upload failed: $e'); }
  }

  // ════════════════════════════════════════════════════════════════════
  //  STEP 2 — نجاح + تتبّع الحالة
  // ════════════════════════════════════════════════════════════════════
  Widget _step2() => Column(key: const ValueKey('s2'), children: [
    const SizedBox(height: 8),
    TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (_, v, __) => Transform.scale(scale: v, child: Container(
        width: 84, height: 84,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [C.green.withOpacity(0.25), C.green.withOpacity(0.05)]),
          border: Border.all(color: C.green.withOpacity(0.5), width: 2)),
        child: const Icon(Icons.check_rounded, color: C.green, size: 42))),
    ),
    const SizedBox(height: 18),
    Text('تم إرسال طلبك 🎉', style: T.cairo(s: FS.xl, w: FontWeight.w900)),
    const SizedBox(height: 6),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text('حوّل المبلغ ثم أرسل صورة وصل الحوالة عبر واتساب.\n'
          'سيرسل لك فريقنا اسم المستخدم وكلمة المرور للتفعيل.',
          textAlign: TextAlign.center, style: T.cairo(s: FS.md, c: C.textSec, h: 1.6))),
    const SizedBox(height: 18),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('رقم الطلب  ', style: T.caption(c: C.textSec)),
        Text(_orderId, style: T.cairo(s: FS.md, w: FontWeight.w800, c: C.gold, ls: 0.5)),
      ]),
    ),
    const SizedBox(height: 14),
    // ★ الإيميل المسجّل — أرسله فقط لصاحب طريقة الدفع (قابل للنسخ)
    Builder(builder: (ctx) {
      final mail = FirebaseAuth.instance.currentUser?.email ?? '';
      if (mail.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: C.gold.withOpacity(0.06),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: C.gold.withOpacity(0.3))),
        child: Column(children: [
          Text('أرسل إيميلك المسجّل فقط لصاحب طريقة الدفع التي اخترتها',
              textAlign: TextAlign.center, style: T.caption(c: C.textSec)),
          const SizedBox(height: 9),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: mail));
              Sound.hapticL();
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text('تم نسخ الإيميل', style: T.cairo(s: FS.sm, c: Colors.black)),
                backgroundColor: C.gold, behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2)));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(R.sm),
                border: Border.all(color: C.gold.withOpacity(0.25))),
              child: Row(children: [
                Expanded(child: Directionality(textDirection: TextDirection.ltr,
                  child: Text(mail, style: T.cairo(s: FS.sm, w: FontWeight.w700, c: C.gold),
                      maxLines: 1, overflow: TextOverflow.ellipsis))),
                const SizedBox(width: 8),
                const Icon(Icons.copy_rounded, color: C.gold, size: 16),
              ]))),
          const SizedBox(height: 6),
          Text('✅ سيُفعّل الطلب بعد تأكيد الدفع وإرسال صورة الحوالة عبر واتساب',
              textAlign: TextAlign.center, style: T.caption(c: C.green)),
        ]));
    }),
    const SizedBox(height: 20),
    // تتبّع
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.timeline_rounded, color: C.gold, size: 16),
          const SizedBox(width: 7),
          Text('حالة الطلب', style: T.cairo(s: FS.md, w: FontWeight.w800, c: C.gold)),
        ]),
        const SizedBox(height: 14),
        _trackStep('تم استلام الطلب', 'الآن', done: true, first: true),
        _trackStep('قيد مراجعة الدفع', 'عادةً 2–10 دقائق', now: true),
        _trackStep('تفعيل الاشتراك', 'بانتظار التأكيد', last: true),
      ]),
    ),
    const SizedBox(height: 18),
    // ── زر إرسال الوصل عبر واتساب ──────────────────────────
    GestureDetector(
      onTap: () async {
        Sound.hapticM();
        final wa = RC.whatsapp.replaceAll('+', '').replaceAll(' ', '');
        final msg = Uri.encodeComponent(
          'مرحباً، أرسل وصل حوالة اشتراك TOTV+\n'
          'رقم الطلب: $_orderId\n'
          'الباقة: ${widget.plan.title} (${widget.plan.price} د.ع)');
        if (wa.isNotEmpty) {
          try { await launchUrl(Uri.parse('https://wa.me/$wa?text=$msg'),
              mode: LaunchMode.externalApplication); } catch (_) {}
        }
      },
      child: Container(height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF25D366),
          borderRadius: BorderRadius.circular(R.md)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 9),
          Text('أرسل وصل الحوالة عبر واتساب',
              style: T.cairo(s: FS.md, w: FontWeight.w800, c: Colors.white)),
        ])),
    ),
    const SizedBox(height: 10),
    GestureDetector(
      onTap: () { Sound.hapticM(); Navigator.pop(context); },
      child: Container(height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFD98A), C.gold]),
          borderRadius: BorderRadius.circular(R.md)),
        child: Center(child: Text('تم',
            style: T.cairo(s: FS.md, w: FontWeight.w900, c: Colors.black)))),
    ),
  ]);

  Widget _trackStep(String title, String sub,
      {bool done = false, bool now = false, bool first = false, bool last = false}) {
    final c = done ? C.green : now ? C.gold : C.textDim;
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(width: 24, height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(now || done ? 1 : 0.15),
            border: now || done ? null : Border.all(color: C.border)),
          child: Icon(done ? Icons.check_rounded : now ? Icons.hourglass_top_rounded : Icons.circle_outlined,
              size: 13, color: now || done ? Colors.black : C.textDim)),
        if (!last) Expanded(child: Container(width: 2, color: done ? C.green.withOpacity(0.4) : C.border)),
      ]),
      const SizedBox(width: 12),
      Padding(padding: EdgeInsets.only(bottom: last ? 0 : 16, top: 1),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.cairo(s: FS.md, w: FontWeight.w700,
              c: now || done ? C.textPri : C.textDim)),
          Text(sub, style: T.caption(c: C.textSec)),
        ])),
    ]));
  }

  // ════════════════════════════════════════════════════════════════════
  //  Submit — يكتب في orders + (اختياري) إشعار تلجرام
  // ════════════════════════════════════════════════════════════════════
  Future<void> _submit() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final card  = _cardCtrl.text.trim().replaceAll(RegExp(r'\s'), '');
    if (!_canSubmit) {
      setState(() => _err = _isAsia
          ? 'أدخل رقم هاتفك والرقم السري لكرت آسيا سيل'
          : 'أدخل اسماً ورقم هاتف صحيح');
      return;
    }
    setState(() { _busy = true; _err = ''; });

    final user = FirebaseAuth.instance.currentUser;
    final m    = _method!;
    _orderId   = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    final asiaAmt = PayMethod.asiaAmount(widget.plan.id);

    // ① Firestore — يقرؤه مركز العمليات مباشرةً
    try {
      await FirebaseFirestore.instance.collection('orders').doc(_orderId).set({
        'order_id':   _orderId,
        'uid':        user?.uid ?? 'guest',
        'email':      user?.email ?? '',
        'account_name': user?.displayName ?? '',
        'name':       name,
        'phone':      phone,
        'plan':       widget.plan.id,
        'plan_title': widget.plan.title,
        'price':      _isAsia ? asiaAmt : widget.plan.price,
        'price_num':  widget.plan.priceNum,
        'method':     m.label,
        'method_number': m.liveNumber,
        // ★ حقول خاصة باشتراك رصيد آسيا سيل
        'type':           _isAsia ? 'asiacell' : 'transfer',
        'asia_card_code': _isAsia ? card : '',
        'asia_amount':    _isAsia ? asiaAmt : '',
        'has_receipt': _receiptAttached,
        'receipt_url': _receiptUrl,
        'receipt_b64': _receiptB64,
        'status':     'pending',
        'created':    FieldValue.serverTimestamp(),
      });
    } catch (e) { debugPrint('[pay] firestore: $e'); }

    // ② Telegram (يُرسل الرقم السري + الإيميل إلى البوت)
    if (_tgBotToken.isNotEmpty) {
      final msg = _isAsia
          ? '🔴 *طلب اشتراك — رصيد آسيا سيل*\n\n'
            '🆔 `$_orderId`\n👤 $name\n📞 $phone\n'
            '📦 اشتراك ${widget.plan.title}\n💰 $asiaAmt رصيد آسيا\n'
            '💳 الرقم السري: `$card`\n'
            '📧 ${user?.email ?? 'ضيف'}'
          : '🔔 *طلب اشتراك جديد*\n\n'
            '🆔 `$_orderId`\n👤 $name\n📞 $phone\n'
            '📦 اشتراك ${widget.plan.title}\n💰 ${widget.plan.price} د.ع\n'
            '💳 ${m.label} (${m.liveNumber})\n'
            '📧 ${user?.email ?? 'ضيف'}\n'
            '🧾 إيصال: ${_receiptAttached ? 'نعم' : 'لا'}';
      try {
        await DioClient.telegram.post(
          'https://api.telegram.org/bot$_tgBotToken/sendMessage',
          data: {'chat_id': _tgChatId, 'text': msg, 'parse_mode': 'Markdown'},
        ).timeout(const Duration(seconds: 8));
      } catch (e) { debugPrint('[pay] telegram: $e'); }
    }

    await Sound.hapticOk();
    Sound.cash(); // ★ صوت كاش بعد إرسال الطلب
    if (mounted) setState(() { _busy = false; _step = 2; });
  }

  // ── أدوات ─────────────────────────────────────────────────────────────
  Future<void> _copy(String v) async {
    await Clipboard.setData(ClipboardData(text: v));
    Sound.hapticM();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('تم نسخ $v ✓', style: T.cairo(s: FS.sm, c: Colors.black)),
      backgroundColor: C.gold, behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2)));
  }

  Widget _label(String t, {bool auto = false}) => Padding(
    padding: const EdgeInsets.only(right: 2, bottom: 6, top: 2),
    child: Row(children: [
      Text(t, style: T.cairo(s: FS.sm, w: FontWeight.w600, c: C.textSec)),
      if (auto) ...[
        const SizedBox(width: 6),
        Text('● معبّأ تلقائياً', style: T.cairo(s: 9, w: FontWeight.w700, c: C.green)),
      ],
    ]),
  );

  Widget _input(TextEditingController c, String hint,
      {TextInputType? keyboard, ValueChanged<String>? onChanged}) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: TextField(
      controller: c, keyboardType: keyboard, onChanged: onChanged,
      style: T.cairo(s: FS.md, w: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint, hintStyle: T.cairo(s: FS.md, c: C.textDim),
        filled: true, fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(R.md),
            borderSide: BorderSide(color: _ac.withOpacity(0.7), width: 1)),
      ),
    ),
  );
}

// ── بطاقة طريقة دفع ───────────────────────────────────────────────────────
class _PayMethodCard extends StatelessWidget {
  final PayMethod method;
  final VoidCallback onTap;
  const _PayMethodCard({required this.method, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(method.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Row(children: [
          if (method.asset != null)
            Container(width: 62, height: 40, padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(R.sm)),
              child: Image.asset(method.asset!, fit: BoxFit.contain))
          else
            Container(width: 62, height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(R.sm),
                border: Border.all(color: color.withOpacity(0.35))),
              child: Icon(Icons.language_rounded, color: color, size: 20)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(method.label,
                  style: T.cairo(s: FS.md, w: FontWeight.w800), overflow: TextOverflow.ellipsis)),
              if (method.badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: C.gold.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(R.sm),
                    border: Border.all(color: C.gold.withOpacity(0.28))),
                  child: Text(method.badge!, style: T.cairo(s: 9, c: C.gold, w: FontWeight.w700))),
              ],
            ]),
            const SizedBox(height: 2),
            Text(method.sub, style: T.caption(c: C.textSec), overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.chevron_left_rounded, color: C.textDim),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  أدوات مشتركة
// ════════════════════════════════════════════════════════════════════════
Widget _glassSheet({required Widget child, bool posterBg = false}) => ClipRRect(
  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
  child: Stack(fit: StackFit.expand, children: [
    const ColoredBox(color: Color(0xFF0C0C0F)),
    if (posterBg) ...[
      const Positioned.fill(child: _PlansPosterBg()),
      Positioned.fill(child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [const Color(0xFF0C0C0F).withOpacity(0.78),
                       const Color(0xFF0C0C0F).withOpacity(0.94)]))))),
    ] else
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: const ColoredBox(color: Color(0xFF0C0C0F))),
    child,
  ]),
);

// خلفية بوسترات لصفحة الخطط (من المحتوى المخزّن أو الشائع)
class _PlansPosterBg extends StatefulWidget {
  const _PlansPosterBg();
  @override State<_PlansPosterBg> createState() => _PlansPosterBgState();
}
class _PlansPosterBgState extends State<_PlansPosterBg> {
  List<String> _posters = const [];
  @override
  void initState() {
    super.initState();
    final cached = [...AppState.allMovies, ...AppState.allSeries]
        .map((m) => (m['stream_icon'] ?? m['cover'] ?? '').toString())
        .where((u) => u.startsWith('http')).take(18).toList();
    if (cached.length >= 9) {
      _posters = cached;
    } else {
      TMDB.popularPosters().then((p) {
        if (mounted && p.isNotEmpty) setState(() => _posters = p);
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_posters.length < 6) return const SizedBox.shrink();
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 0.66),
      itemCount: _posters.length,
      itemBuilder: (_, i) => CachedNetworkImage(
        imageUrl: _posters[i], fit: BoxFit.cover,
        placeholder: (_, __) => const ColoredBox(color: Color(0xFF15151A)),
        errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF15151A))),
    );
  }
}

Widget _grabHandle() => Center(child: Container(
  margin: const EdgeInsets.only(top: 10, bottom: 4),
  width: 40, height: 4,
  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(R.tiny))));

Widget _pill(String text, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  decoration: BoxDecoration(
    color: c.withOpacity(0.13), borderRadius: BorderRadius.circular(R.pill),
    border: Border.all(color: c.withOpacity(0.35))),
  child: Text(text, style: T.cairo(s: FS.xs, c: c, w: FontWeight.w700)));
