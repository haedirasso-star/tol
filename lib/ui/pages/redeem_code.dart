part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — شاشة إدخال كود التفعيل
//  المستخدم يدخل الكود مرة واحدة فقط → يُجلب السيرفر تلقائياً ويُحفظ.
//  الدخول:  RedeemCodeSheet.show(context)   أو   const RedeemCodeButton()
// ════════════════════════════════════════════════════════════════════════

class RedeemCodeSheet extends StatefulWidget {
  const RedeemCodeSheet({super.key});

  static Future<bool?> show(BuildContext ctx) => showModalBottomSheet<bool>(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        builder: (_) => const RedeemCodeSheet(),
      );

  @override
  State<RedeemCodeSheet> createState() => _RedeemCodeSheetState();
}

class _RedeemCodeSheetState extends State<RedeemCodeSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  bool   _busy    = false;
  bool   _done    = false;
  String _err     = '';
  String _okMsg   = '';
  String _okPlan  = '';
  DateTime? _okExpiry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy && ActivationService.looksValid(_ctrl.text);

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final txt  = data?.text ?? '';
      if (txt.trim().isEmpty) return;
      _ctrl.text = ActivationService.pretty(txt);
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
      Sound.hapticM();
      setState(() => _err = '');
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _err = ''; });

    final res = await ActivationService.redeem(_ctrl.text);

    if (!mounted) return;
    if (res.ok) {
      Sound.check();
      await Sound.hapticOk();
      if (!mounted) return;
      setState(() {
        _busy     = false;
        _done     = true;
        _okMsg    = res.msg;
        _okPlan   = res.plan;
        _okExpiry = res.expiry;
      });
    } else {
      Sound.hapticM();
      setState(() { _busy = false; _err = res.msg; });
    }
  }

  void _finish() {
    Navigator.of(context).pop(true);
    AppState.notifyContent();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: C.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (_done) _successView() else _formView(),
            ],
          ),
        ),
      ),
    );
  }

  // ── نموذج الإدخال ──────────────────────────────────────────────────
  Widget _formView() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── هيرو ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [C.gold.withOpacity(0.16), C.gold.withOpacity(0.02)],
              ),
              borderRadius: BorderRadius.circular(R.xl),
              border: Border.all(color: C.gold.withOpacity(0.22)),
            ),
            child: Column(children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [C.gold.withOpacity(0.22), C.gold.withOpacity(0.06)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: C.gold.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.vpn_key_rounded, color: C.gold, size: 30),
              ),
              const SizedBox(height: 12),
              Text('تفعيل بكود الاشتراك',
                  style: T.cairo(s: FS.xl, w: FontWeight.w900)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'أدخل الكود الذي حصلت عليه — سيتم الاتصال بسيرفرك وتحميل\n'
                  'كل القنوات والأفلام تلقائياً. لن يُطلب منك الكود مرة أخرى.',
                  textAlign: TextAlign.center,
                  style: T.cairo(s: FS.sm, c: C.textSec, h: 1.6),
                ),
              ),
            ]),
          ),

          // ── حقل الكود ──
          Text('كود التفعيل',
              style: T.cairo(s: FS.sm, w: FontWeight.w600, c: C.textSec)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            enabled: !_busy,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (v) {
              final formatted = ActivationService.pretty(v);
              if (formatted != v) {
                _ctrl.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
              if (_err.isNotEmpty) setState(() => _err = '');
              else setState(() {});
            },
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: 'TOTV-XXXX-XXXX',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                letterSpacing: 3,
                color: Colors.white.withOpacity(0.18),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(R.md),
                borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.1), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(R.md),
                borderSide: BorderSide(color: C.gold.withOpacity(0.7), width: 1.2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(R.md),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
              suffixIcon: IconButton(
                tooltip: 'لصق',
                icon: const Icon(Icons.content_paste_rounded,
                    color: C.gold, size: 20),
                onPressed: _busy ? null : _paste,
              ),
            ),
          ),

          // ── رسالة خطأ ──
          if (_err.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFE05252).withOpacity(0.08),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(
                    color: const Color(0xFFE05252).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFE05252), size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(_err,
                      style: T.cairo(
                          s: FS.sm,
                          c: const Color(0xFFE05252),
                          w: FontWeight.w600)),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 18),

          // ── زر التفعيل ──
          GestureDetector(
            onTap: _canSubmit ? _submit : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 54,
              decoration: BoxDecoration(
                gradient: _canSubmit
                    ? const LinearGradient(colors: [Color(0xFFFFE27A), C.gold])
                    : null,
                color: _canSubmit ? null : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(R.md),
                boxShadow: _canSubmit
                    ? [
                        BoxShadow(
                            color: C.gold.withOpacity(0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 5))
                      ]
                    : null,
              ),
              child: Center(
                child: _busy
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.black))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.bolt_rounded,
                            size: 20,
                            color: _canSubmit ? Colors.black : C.textDim),
                        const SizedBox(width: 8),
                        Text('تفعيل الآن',
                            style: T.cairo(
                                s: FS.lg,
                                w: FontWeight.w900,
                                c: _canSubmit ? Colors.black : C.textDim)),
                      ]),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── الحصول على كود ──
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              PayPlansSheet.show(context);
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Center(
                child: Text('ليس لديك كود؟ اشترِ اشتراكاً',
                    style: T.cairo(s: FS.md, w: FontWeight.w700, c: C.gold)),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── دعم ──
          if (RC.whatsapp.isNotEmpty)
            TextButton(
              onPressed: () {
                final wa = RC.whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
                if (wa.isEmpty) return;
                launchUrl(
                  Uri.parse(AppUrls.whatsapp(wa, 'مرحباً، لدي مشكلة في كود التفعيل')),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Text('تواجه مشكلة؟ تواصل مع الدعم',
                  style: T.cairo(s: FS.sm, c: C.whatsapp, w: FontWeight.w600)),
            ),
        ],
      );

  // ── شاشة النجاح ────────────────────────────────────────────────────
  Widget _successView() {
    final expStr = _okExpiry == null
        ? '—'
        : '${_okExpiry!.day.toString().padLeft(2, '0')}/'
          '${_okExpiry!.month.toString().padLeft(2, '0')}/'
          '${_okExpiry!.year}';
    final daysLeft = _okExpiry == null
        ? 0
        : _okExpiry!.difference(DateTime.now()).inDays;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (_, v, __) => Transform.scale(
              scale: v,
              child: Container(
                width: 92, height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    C.green.withOpacity(0.28),
                    C.green.withOpacity(0.05),
                  ]),
                  border: Border.all(color: C.green.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: C.green, size: 46),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(_okMsg,
            textAlign: TextAlign.center,
            style: T.cairo(s: FS.xl, w: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('جارٍ تحميل القنوات والأفلام الآن…',
            textAlign: TextAlign.center,
            style: T.cairo(s: FS.sm, c: C.textSec, h: 1.6)),
        const SizedBox(height: 20),

        // ── ملخص الاشتراك ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(color: C.gold.withOpacity(0.25)),
          ),
          child: Column(children: [
            _sumRow('الباقة', ActivationService.planLabel(_okPlan)),
            const SizedBox(height: 10),
            _sumRow('تاريخ الانتهاء', expStr),
            const SizedBox(height: 10),
            _sumRow('المتبقي', '$daysLeft يوم'),
          ]),
        ),

        const SizedBox(height: 20),
        GestureDetector(
          onTap: _finish,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFE27A), C.gold]),
              borderRadius: BorderRadius.circular(R.md),
            ),
            child: Center(
              child: Text('ابدأ المشاهدة',
                  style: T.cairo(
                      s: FS.lg, w: FontWeight.w900, c: Colors.black)),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _sumRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: T.cairo(s: FS.sm, c: C.textSec)),
          Text(value,
              style: T.cairo(s: FS.md, w: FontWeight.w800, c: C.gold)),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════════
//  زر جاهز — ضَعه في أي صفحة (الحساب / الاشتراك / القفل)
// ════════════════════════════════════════════════════════════════════════
class RedeemCodeButton extends StatelessWidget {
  final bool compact;
  const RedeemCodeButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return GestureDetector(
        onTap: () { Sound.hapticM(); RedeemCodeSheet.show(context); },
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: C.gold.withOpacity(0.10),
            borderRadius: BorderRadius.circular(R.md),
            border: Border.all(color: C.gold.withOpacity(0.35)),
          ),
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.vpn_key_rounded, color: C.gold, size: 17),
              const SizedBox(width: 8),
              Text('لدي كود تفعيل',
                  style: T.cairo(s: FS.md, w: FontWeight.w800, c: C.gold)),
            ]),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () { Sound.hapticM(); RedeemCodeSheet.show(context); },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [C.gold.withOpacity(0.16), C.gold.withOpacity(0.04)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: C.gold.withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: C.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(R.sm),
            ),
            child: const Icon(Icons.vpn_key_rounded, color: C.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لدي كود تفعيل',
                    style: T.cairo(s: FS.md, w: FontWeight.w800)),
                Text('فعّل اشتراكك فوراً خلال ثوانٍ',
                    style: T.caption(c: C.textSec)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: C.gold),
        ]),
      ),
    );
  }
}
