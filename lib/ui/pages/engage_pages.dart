part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════
//  المحادثة مع الإدارة · ادعُ صديقك
//  تصميم أبيض/أسود هادئ، خط واضح، بلا قراءة دورية للقاعدة.
// ════════════════════════════════════════════════════════════════════

const _kInk = Color(0xFF0A0A0B);
const _kPanel = Color(0xFF141416);
const _kStroke = Color(0xFF26262A);

String _two(int v) => v.toString().padLeft(2, '0');
String _hm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
String _dayName(DateTime d) {
  final now = DateTime.now();
  if (DateUtils.isSameDay(d, now)) return 'اليوم';
  if (DateUtils.isSameDay(d, now.subtract(const Duration(days: 1)))) return 'أمس';
  return '${d.day}/${d.month}/${d.year}';
}

// ════════════════════════════════════════════════════════════════════
//  المحادثة
// ════════════════════════════════════════════════════════════════════
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMsg> _list = [];
  bool _loading = true, _sending = false, _more = true, _loadingMore = false;
  String _err = '';

  static const _quick = ['مشكلة في البث', 'أريد تجديد اشتراكي', 'استفسار عن الدفع', 'لم يُفعّل اشتراكي'];

  @override
  void initState() {
    super.initState();
    ChatInbox.pageOpen = true;
    ChatInbox.clear();
    ChatInbox.rev.addListener(_onNew);
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    ChatInbox.pageOpen = false;
    ChatInbox.rev.removeListener(_onNew);
    WidgetsBinding.instance.removeObserver(this);
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load(silent: true);
  }

  void _onNew() => _load(silent: true);

  void _onScroll() {
    if (!_more || _loadingMore || _list.isEmpty) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) _older();
  }

  Future<void> _load({bool silent = false}) async {
    if (AuthService.currentUser == null) { setState(() { _loading = false; _err = 'login'; }); return; }
    if (!silent) setState(() { _loading = true; _err = ''; });
    try {
      final l = await ChatInbox.list();
      if (!mounted) return;
      setState(() { _list = l; _more = l.length >= 40; _err = ''; });
      ChatInbox.clear();
    } catch (e) {
      if (mounted && !silent) setState(() => _err = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _older() async {
    _loadingMore = true;
    try {
      final l = await ChatInbox.list(before: _list.last.id);
      if (mounted) setState(() { _list.addAll(l); _more = l.length >= 40; });
    } catch (_) {}
    _loadingMore = false;
  }

  Future<void> _send([String? preset]) async {
    final t = (preset ?? _ctl.text).trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await ChatInbox.send(t);
      Sound.hapticL();
      if (!mounted) return;
      _ctl.clear();
      setState(() => _list.insert(0, m));
      if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF1C1C21),
          content: Text('$e', textDirection: TextDirection.rtl, style: T.cairo(s: 13.5, c: Colors.white, w: FontWeight.w600))));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black, elevation: 0, scrolledUnderElevation: 0,
          leading: IconButton(onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white)),
          titleSpacing: 0,
          title: Row(children: [
            Container(
              width: 40, height: 40, alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Text('T+', style: T.cairo(s: 15, w: FontWeight.w900, c: Colors.black)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('إدارة TOTV+', style: T.cairo(s: 17, w: FontWeight.w800, c: Colors.white)),
              Text('نرد عليك بأسرع وقت', style: T.cairo(s: 12, w: FontWeight.w500, c: Colors.white54)),
            ])),
          ]),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: _kStroke)),
        ),
        body: Column(children: [
          Expanded(child: _body()),
          if (_err != 'login') _composer(),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: SizedBox(width: 26, height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)));
    }
    if (_err == 'login') {
      return _center(Icons.lock_outline_rounded, 'سجّل الدخول لمراسلة الإدارة', null,
          action: ('تسجيل الدخول', () => Navigator.push(context, _fade(const FirebaseLoginPage()))));
    }
    if (_err.isNotEmpty && _list.isEmpty) {
      return _center(Icons.wifi_off_rounded, 'تعذّر تحميل الرسائل', _err, action: ('إعادة المحاولة', _load));
    }
    if (_list.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(20, 40, 20, 20), children: [
        const Icon(Icons.forum_outlined, color: Colors.white38, size: 54),
        const SizedBox(height: 14),
        Text('ابدأ المحادثة', textAlign: TextAlign.center,
            style: T.cairo(s: 19, w: FontWeight.w800, c: Colors.white)),
        const SizedBox(height: 6),
        Text('اكتب رسالتك وستصلك الإجابة هنا مع إشعار فوري', textAlign: TextAlign.center,
            style: T.cairo(s: 13.5, w: FontWeight.w500, c: Colors.white60, h: 1.6)),
        const SizedBox(height: 22),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (final q in _quick) ActionChip(
            backgroundColor: _kPanel, side: const BorderSide(color: _kStroke),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            label: Text(q, style: T.cairo(s: 13.5, w: FontWeight.w700, c: Colors.white)),
            onPressed: () => _send(q),
          ),
        ]),
      ]);
    }
    return RefreshIndicator(
      color: Colors.black, backgroundColor: Colors.white,
      onRefresh: () => _load(silent: true),
      child: ListView.builder(
        controller: _scroll,
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        itemCount: _list.length,
        itemBuilder: (_, i) {
          final m = _list[i];
          final older = i + 1 < _list.length ? _list[i + 1] : null;
          final newDay = older == null || !DateUtils.isSameDay(older.at, m.at);
          return Column(children: [
            if (newDay) _daySep(m.at),
            m.sender == 'auto' ? _autoCard(m) : _bubble(m, older),
          ]);
        },
      ),
    );
  }

  Widget _daySep(DateTime d) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: _kPanel, borderRadius: BorderRadius.circular(10)),
      child: Text(_dayName(d), style: T.cairo(s: 12, w: FontWeight.w700, c: Colors.white60)),
    )),
  );

  Widget _bubble(ChatMsg m, ChatMsg? prev) {
    final mine = m.mine;
    final tight = prev != null && prev.sender == m.sender && m.at.difference(prev.at).inMinutes < 3;
    return Padding(
      padding: EdgeInsets.only(top: tight ? 3 : 10),
      child: Align(
        alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 7),
            decoration: BoxDecoration(
              color: mine ? Colors.white : _kPanel,
              border: mine ? null : Border.all(color: _kStroke),
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(18), topEnd: const Radius.circular(18),
                bottomStart: Radius.circular(mine ? 4 : 18), bottomEnd: Radius.circular(mine ? 18 : 4),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              SelectableText(m.body, style: T.cairo(s: 15, w: FontWeight.w500, c: mine ? Colors.black : Colors.white, h: 1.55)),
              const SizedBox(height: 2),
              Align(alignment: AlignmentDirectional.centerEnd,
                child: Text(_hm(m.at), textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 11, color: mine ? Colors.black45 : Colors.white38,
                        fontFeatures: const [FontFeature.tabularFigures()]))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _autoCard(ChatMsg m) {
    final (icon, color) = switch (m.kind) {
      'prize' => (Icons.emoji_events_rounded, C.gold),
      'expiring' => (Icons.schedule_rounded, const Color(0xFFF97316)),
      'complaint' => (Icons.support_agent_rounded, const Color(0xFF4A9EDA)),
      _ => (Icons.notifications_active_rounded, Colors.white),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _kInk, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.45))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText(m.body, style: T.cairo(s: 14.5, w: FontWeight.w600, c: Colors.white, h: 1.6)),
            const SizedBox(height: 4),
            Text('رسالة تلقائية • ${_hm(m.at)}', style: T.cairo(s: 11.5, w: FontWeight.w500, c: Colors.white38)),
          ])),
        ]),
      ),
    );
  }

  Widget _composer() => Container(
    padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
    decoration: const BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: _kStroke))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: _kPanel, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kStroke)),
        child: TextField(
          controller: _ctl,
          minLines: 1, maxLines: 5, maxLength: 1500,
          textInputAction: TextInputAction.newline,
          style: T.cairo(s: 15, w: FontWeight.w500, c: Colors.white, h: 1.5),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            border: InputBorder.none, counterText: '', isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            hintText: 'اكتب رسالتك…',
            hintStyle: T.cairo(s: 15, w: FontWeight.w500, c: Colors.white38),
          ),
        ),
      )),
      const SizedBox(width: 8),
      SizedBox(width: 48, height: 48, child: Material(
        color: Colors.white, shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _sending ? null : () => _send(),
          child: Center(child: _sending
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
              : const Icon(Icons.send_rounded, color: Colors.black, size: 22, textDirection: TextDirection.rtl)),
        ),
      )),
    ]),
  );

  Widget _center(IconData icon, String title, String? sub, {(String, VoidCallback)? action}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white38, size: 50),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: T.cairo(s: 17, w: FontWeight.w800, c: Colors.white)),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub, textAlign: TextAlign.center, style: T.cairo(s: 13, c: Colors.white54)),
        ],
        if (action != null) ...[
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: action.$2,
            child: Text(action.$1, style: T.cairo(s: 14.5, w: FontWeight.w800, c: Colors.black)),
          ),
        ],
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  ادعُ صديقك واربح 16 يوماً + توقّع واربح
// ════════════════════════════════════════════════════════════════════
class InvitePage extends StatefulWidget {
  const InvitePage({super.key});
  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  final _code = TextEditingController();
  String _mine = '', _used = '', _err = '', _applyMsg = '';
  int _joined = 0, _subs = 0, _rewarded = 0;
  bool _loading = true, _applying = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _code.dispose(); super.dispose(); }

  Future<void> _load() async {
    _mine = await Referral.cached();
    if (mounted) setState(() {});
    if (AuthService.currentUser == null) { setState(() { _loading = false; _err = 'login'; }); return; }
    try {
      final r = await Referral.me();
      if (!mounted) return;
      setState(() {
        _mine = '${r['code'] ?? _mine}';
        _used = '${r['used_code'] ?? ''}';
        _joined = (r['joined'] as num?)?.toInt() ?? 0;
        _subs = (r['subscribed'] as num?)?.toInt() ?? 0;
        _rewarded = (r['rewarded'] as num?)?.toInt() ?? 0;
        _err = '';
      });
    } catch (e) {
      if (mounted && _mine.isEmpty) setState(() => _err = '$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _apply() async {
    final c = _code.text.trim();
    if (c.isEmpty || _applying) return;
    setState(() { _applying = true; _applyMsg = ''; });
    try {
      final who = await Referral.apply(c);
      Sound.hapticOk();
      if (!mounted) return;
      setState(() { _used = c.toUpperCase(); _applyMsg = who.isEmpty ? 'تم ✅' : 'تم ✅ دعاك $who'; });
    } catch (e) {
      if (mounted) setState(() => _applyMsg = '$e');
    }
    if (mounted) setState(() => _applying = false);
  }

  void _share(String where) {
    if (_mine.isEmpty) return;
    final t = Referral.shareText(_mine);
    final u = where == 'wa'
        ? 'https://wa.me/?text=${Uri.encodeComponent(t)}'
        : 'https://t.me/share/url?url=${Uri.encodeComponent(RC.telegram)}&text=${Uri.encodeComponent(t)}';
    launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
  }

  Future<void> _copy(String v) async {
    await Clipboard.setData(ClipboardData(text: v));
    Sound.hapticM();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating, backgroundColor: Colors.white,
      content: Text('تم النسخ', textDirection: TextDirection.rtl, style: T.cairo(s: 14, c: Colors.black, w: FontWeight.w800))));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black, elevation: 0, scrolledUnderElevation: 0,
          leading: IconButton(onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white)),
          title: Text('ادعُ صديقك واربح', style: T.cairo(s: 18, w: FontWeight.w800, c: Colors.white)),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 6, 18, 40), children: [
          // ── البطاقة الرئيسية ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.card_giftcard_rounded, color: Colors.black, size: 34),
              const SizedBox(height: 10),
              Text('احصل على ${Referral.days} يوماً مجاناً', style: T.cairo(s: 24, w: FontWeight.w900, c: Colors.black, h: 1.3)),
              const SizedBox(height: 4),
              Text('عن كل صديق يشترك بكود دعوتك', style: T.cairo(s: 15, w: FontWeight.w600, c: Colors.black54)),
              const SizedBox(height: 18),
              _codeBox(),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _shareBtn('واتساب', Icons.chat_rounded, () => _share('wa'))),
                const SizedBox(width: 8),
                Expanded(child: _shareBtn('تيليجرام', Icons.send_rounded, () => _share('tg'))),
                const SizedBox(width: 8),
                Expanded(child: _shareBtn('نسخ الرسالة', Icons.copy_rounded,
                    () => _mine.isEmpty ? null : _copy(Referral.shareText(_mine)))),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          // ── الأرقام ──
          Row(children: [
            _stat('$_joined', 'سجّلوا بكودك'),
            const SizedBox(width: 8),
            _stat('$_subs', 'اشتركوا'),
            const SizedBox(width: 8),
            _stat('${_rewarded * Referral.days}', 'يوماً ربحتها'),
          ]),
          const SizedBox(height: 24),
          _title('كيف تعمل؟'),
          _step('1', 'شارك كودك مع أصدقائك'),
          _step('2', 'صديقك يكتب الكود في «المزيد ← ادعُ صديقك» قبل أول اشتراك'),
          _step('3', 'عند تفعيل اشتراكه تُضاف لك ${Referral.days} يوماً، وتصلك رسالة بذلك'),
          const SizedBox(height: 24),
          // ── كود صديق ──
          if (_err != 'login') ...[
            _title('هل دعاك صديق؟'),
            if (_used.isNotEmpty)
              _note(Icons.verified_rounded, 'استخدمت كود الدعوة $_used')
            else ...[
              Row(children: [
                Expanded(child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: _kPanel, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kStroke)),
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textDirection: TextDirection.ltr, textAlign: TextAlign.center,
                    maxLength: 8,
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 3),
                    cursorColor: Colors.white,
                    decoration: InputDecoration(border: InputBorder.none, counterText: '',
                        hintText: 'كود الدعوة', hintStyle: T.cairo(s: 15, c: Colors.white38)),
                  ),
                )),
                const SizedBox(width: 8),
                SizedBox(height: 52, child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _applying ? null : _apply,
                  child: _applying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
                      : Text('تأكيد', style: T.cairo(s: 15, w: FontWeight.w800, c: Colors.black)),
                )),
              ]),
              if (_applyMsg.isNotEmpty) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_applyMsg, style: T.cairo(s: 13.5, w: FontWeight.w700,
                    c: _applyMsg.startsWith('تم') ? const Color(0xFF4ADE80) : C.red)),
              ),
            ],
            const SizedBox(height: 24),
          ],
          // ── التوقعات ──
          _title('توقّع واربح يوماً مجانياً'),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () { Navigator.maybePop(context); ShellNav.go(3); },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _kPanel, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kStroke)),
              child: Row(children: [
                const Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 30),
                const SizedBox(width: 12),
                Expanded(child: Text(
                    'افتح أي مباراة، واكتب النتيجة تحت شعار كل نادٍ قبل الانطلاق بـ 30 دقيقة. النتيجة الدقيقة = يوم مجاني.',
                    style: T.cairo(s: 14, w: FontWeight.w600, c: Colors.white, h: 1.6))),
                const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 16),
              ]),
            ),
          ),
          if (_err.isNotEmpty && _err != 'login') Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_err, textAlign: TextAlign.center, style: T.cairo(s: 13, c: C.red)),
          ),
        ]),
      ),
    );
  }

  Widget _codeBox() {
    if (_err == 'login') {
      return SizedBox(height: 54, width: double.infinity, child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: () => Navigator.push(context, _fade(const FirebaseLoginPage())),
        child: Text('سجّل الدخول لتحصل على كودك', style: T.cairo(s: 15, w: FontWeight.w800, c: Colors.white)),
      ));
    }
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _mine.isEmpty ? null : () => _copy(_mine),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xFFF2F2F3), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12)),
        child: Row(children: [
          Text('كودك', style: T.cairo(s: 14, w: FontWeight.w700, c: Colors.black54)),
          const Spacer(),
          if (_mine.isEmpty && _loading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black))
          else
            Text(_mine.isEmpty ? '——' : _mine, textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4)),
          const Spacer(),
          const Icon(Icons.copy_rounded, color: Colors.black54, size: 20),
        ]),
      ),
    );
  }

  Widget _shareBtn(String l, IconData i, VoidCallback? f) => SizedBox(height: 46, child: FilledButton.icon(
    style: FilledButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
    onPressed: f,
    icon: Icon(i, size: 17),
    label: FittedBox(child: Text(l, style: T.cairo(s: 13, w: FontWeight.w800, c: Colors.white))),
  ));

  Widget _stat(String v, String l) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: _kPanel, borderRadius: BorderRadius.circular(14), border: Border.all(color: _kStroke)),
    child: Column(children: [
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(l, style: T.cairo(s: 12, w: FontWeight.w600, c: Colors.white60)),
    ]),
  ));

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: T.cairo(s: 17.5, w: FontWeight.w900, c: Colors.white)),
  );

  Widget _step(String n, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(width: 30, height: 30, alignment: Alignment.center,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Text(n, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15))),
      const SizedBox(width: 12),
      Expanded(child: Text(t, style: T.cairo(s: 14.5, w: FontWeight.w600, c: Colors.white, h: 1.55))),
    ]),
  );

  Widget _note(IconData i, String t) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _kPanel, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kStroke)),
    child: Row(children: [
      Icon(i, color: const Color(0xFF4ADE80)),
      const SizedBox(width: 10),
      Expanded(child: Text(t, style: T.cairo(s: 14.5, w: FontWeight.w700, c: Colors.white))),
    ]),
  );
}
