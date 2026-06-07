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
const bool kReceiptUploadInApp = false;

// ── نموذج الباقة ──────────────────────────────────────────────────────────
class PayPlan {
  final String id, title, price, period, badge;
  final int priceNum, devices, accent;
  const PayPlan({
    required this.id, required this.title, required this.price,
    required this.priceNum, required this.period, required this.devices,
    required this.badge, required this.accent,
  });

  static const all = <PayPlan>[
    PayPlan(id: 'monthly',   title: 'شهري',  price: '5,000',  priceNum: 5000,
        period: '/شهر',    devices: 1, badge: 'الأكثر شيوعاً', accent: 0xFFFFD740),
    PayPlan(id: 'quarterly', title: '3 أشهر', price: '13,000', priceNum: 13000,
        period: '/3 أشهر', devices: 2, badge: 'وفّر 13%',       accent: 0xFF00D2FF),
    PayPlan(id: 'yearly',    title: 'سنوي',   price: '45,000', priceNum: 45000,
        period: '/سنة',    devices: 2, badge: 'أفضل قيمة',      accent: 0xFFFF6B35),
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
    PayMethod(id: 'website', label: 'الموقع الإلكتروني',
        sub: 'ادفع مباشرة عبر بوابتنا الرسمية',
        badge: 'آمن 🔒', color: 0xFF4CAF50, bg: 0xFF0A1F0A),
  ];
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

  static void show(BuildContext ctx) => showModalBottomSheet(
        context: ctx, isScrollControlled: true,
        backgroundColor: Colors.transparent, useSafeArea: true,
        builder: (_) => const PayPlansSheet());

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.90, minChildSize: 0.5, maxChildSize: 0.96,
      builder: (_, sc) => _glassSheet(child: Column(children: [
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
                _PayPaymentSheet.show(context, p);
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

// ── بطاقة باقة ──────────────────────────────────────────────────────────
class _PayPlanCard extends StatelessWidget {
  final PayPlan plan;
  final VoidCallback onTap;
  const _PayPlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color   = Color(plan.accent);
    final popular = plan.id == 'monthly';
    return GestureDetector(
      onTap: () { Sound.hapticM(); onTap(); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: popular
                ? [color.withOpacity(0.12), color.withOpacity(0.04)]
                : [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(
              color: color.withOpacity(popular ? 0.55 : 0.18),
              width: popular ? 1.4 : 0.8),
          boxShadow: popular
              ? [BoxShadow(color: color.withOpacity(0.12), blurRadius: 18)]
              : null,
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: color.withOpacity(0.3), width: 0.8)),
            child: Center(child: Text(plan.title,
                style: T.cairo(s: FS.sm, w: FontWeight.w900, c: color),
                textAlign: TextAlign.center))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('اشتراك ${plan.title}',
                  style: T.cairo(s: FS.md, w: FontWeight.w800), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(R.sm),
                  border: Border.all(color: color.withOpacity(0.35))),
                child: Text(plan.badge, style: T.cairo(s: 9, c: color, w: FontWeight.w700))),
            ]),
            const SizedBox(height: 3),
            Text('${plan.devices} ${plan.devices == 1 ? "جهاز" : "جهازان"} • كل المنصّات',
                style: T.caption(c: C.textSec)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ShaderMask(
              shaderCallback: (r) =>
                  LinearGradient(colors: [color, color.withOpacity(0.7)]).createShader(r),
              child: Text(plan.price,
                  style: T.cairo(s: FS.lg, w: FontWeight.w900, c: C.textPri))),
            Text('د.ع${plan.period}',
                style: T.cairo(s: FS.xs, c: color.withOpacity(0.8))),
          ]),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  PAYMENT SHEET — التدفّق: 0 طريقة · 1 تفاصيل · 2 نجاح + تتبّع
// ════════════════════════════════════════════════════════════════════════
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
  static const _tgBotToken = ''; // ضع توكن البوت أو اتركه فارغاً لتعطيل تلجرام
  static const _tgChatId   = '1418184484';

  int     _step = 0;          // 0 method · 1 details · 2 success
  PayMethod? _method;
  bool    _busy = false;
  String  _err  = '';
  String  _orderId = '';
  bool    _receiptAttached = false;
  String  _receiptUrl = '';

  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ── تعبئة تلقائية من حساب Firebase ──
    final u = FirebaseAuth.instance.currentUser;
    if ((u?.displayName ?? '').isNotEmpty) _nameCtrl.text = u!.displayName!;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Color get _ac => Color(widget.plan.accent);

  bool get _canSubmit =>
      _nameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '').length >= 10;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _step == 2 ? 0.78 : 0.90,
      minChildSize: 0.4, maxChildSize: 0.96,
      builder: (_, sc) => _glassSheet(child: Column(children: [
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
        if (m.id == 'website') {
          Navigator.pop(context);
          final base = RC.buyUrl.isNotEmpty ? RC.buyUrl : 'https://payment-totv.vercel.app/';
          launchUrl(Uri.parse('$base?plan=${widget.plan.id}'),
              mode: LaunchMode.externalApplication);
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
              Text('حوّل المبلغ إلى الرقم أدناه', style: T.caption(c: Colors.white38)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(widget.plan.price, style: T.cairo(s: FS.xl, w: FontWeight.w900, c: color)),
              Text('د.ع', style: T.caption(c: color.withOpacity(0.7))),
            ]),
          ]),
          const SizedBox(height: 18),
          Container(height: 0.5, color: color.withOpacity(0.2)),
          const SizedBox(height: 14),
          if (m.number != null) ...[
            Text('رقم الحساب — اضغط للنسخ', style: T.caption(c: Colors.white38)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _copy(m.number!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(R.md),
                  border: Border.all(color: color.withOpacity(0.25),
                      style: BorderStyle.solid, width: 1)),
                child: Row(children: [
                  Expanded(child: Text(m.number!,
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
            if (m.name != null) ...[
              const SizedBox(height: 11),
              Row(children: [
                const Icon(Icons.person_rounded, size: 14, color: Colors.white38),
                const SizedBox(width: 6),
                Text('الاسم: ', style: T.caption(c: Colors.white38)),
                Text(m.name!, style: T.cairo(s: FS.md, w: FontWeight.w700)),
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
      // رفع الإيصال
      _receiptCard(),
      const SizedBox(height: 16),
      // الاسم
      _label('الاسم الكامل', auto: _nameCtrl.text.isNotEmpty),
      _input(_nameCtrl, 'اكتب اسمك', onChanged: (_) => setState(() {})),
      // الهاتف
      _label('رقم الهاتف'),
      _input(_phoneCtrl, '07XX XXX XXXX',
          keyboard: TextInputType.phone, onChanged: (_) => setState(() {})),
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
        Icon(_receiptAttached ? Icons.check_circle_rounded : Icons.upload_file_rounded,
            color: _receiptAttached ? C.green : C.gold, size: 26),
        const SizedBox(height: 7),
        Text(_receiptAttached ? 'تم إرفاق الإيصال ✓' : 'ارفع صورة إيصال التحويل',
            style: T.cairo(s: FS.md, w: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(kReceiptUploadInApp
            ? 'PNG · JPG — يُسرّع التفعيل'
            : 'سيُفتح واتساب لإرسال الإيصال (الأسرع للتفعيل)',
            style: T.caption(c: C.textSec), textAlign: TextAlign.center),
      ]),
    ),
  );

  Future<void> _pickReceipt() async {
    Sound.hapticL();
    // مسار الواتساب (يعمل بلا أي حزمة إضافية)
    final wa = RC.whatsapp.replaceAll('+', '');
    final msg = Uri.encodeComponent(
        'مرحباً، أرفق إيصال دفع اشتراك ${widget.plan.title} (${widget.plan.price} د.ع)');
    if (wa.isNotEmpty) {
      await launchUrl(Uri.parse('https://wa.me/$wa?text=$msg'),
          mode: LaunchMode.externalApplication);
    }
    setState(() => _receiptAttached = true);
    // ملاحظة: لتفعيل الرفع داخل التطبيق لاحقاً، أضِف image_picker + firebase_storage
    // إلى pubspec وشغّل `flutter pub get`، ثم أعِد منطق الرفع هنا.
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
    Text('تم استلام طلبك 🎉', style: T.cairo(s: FS.xl, w: FontWeight.w900)),
    const SizedBox(height: 6),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text('يتم الآن مراجعة دفعتك، وسيُفعّل اشتراكك فور التأكيد. ستصلك إشعار.',
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
    if (!_canSubmit) { setState(() => _err = 'أدخل اسماً ورقم هاتف صحيح'); return; }
    setState(() { _busy = true; _err = ''; });

    final user = FirebaseAuth.instance.currentUser;
    final m    = _method!;
    _orderId   = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

    // ① Firestore — يقرؤه مركز العمليات مباشرةً
    try {
      await FirebaseFirestore.instance.collection('orders').doc(_orderId).set({
        'order_id':   _orderId,
        'uid':        user?.uid ?? 'guest',
        'email':      user?.email ?? '',
        'name':       name,
        'phone':      phone,
        'plan':       widget.plan.id,
        'plan_title': widget.plan.title,
        'price':      widget.plan.price,
        'price_num':  widget.plan.priceNum,
        'method':     m.label,
        'has_receipt': _receiptAttached,
        'receipt_url': _receiptUrl,
        'status':     'pending',
        'created':    FieldValue.serverTimestamp(),
      });
    } catch (e) { debugPrint('[pay] firestore: $e'); }

    // ② Telegram (اختياري — اتركه فارغاً لتعطيله)
    if (_tgBotToken.isNotEmpty) {
      final msg =
          '🔔 *طلب اشتراك جديد*\n\n'
          '🆔 `$_orderId`\n👤 $name\n📞 $phone\n'
          '📦 اشتراك ${widget.plan.title}\n💰 ${widget.plan.price} د.ع\n'
          '💳 ${m.label} (${m.number ?? '—'})\n'
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
Widget _glassSheet({required Widget child}) => ClipRRect(
  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
    child: Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: child,
    ),
  ),
);

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
