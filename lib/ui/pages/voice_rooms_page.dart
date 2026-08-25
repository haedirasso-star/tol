part of '../../main.dart';

// ════════════════════════════════════════════════════════════════
//  واجهات الغرف الصوتية — بلغة تصميم TOTV+ نفسها
//    VoiceRoomsPage  : قائمة الغرف
//    VoiceRoomPage   : داخل الغرفة
// ════════════════════════════════════════════════════════════════

class VoiceRoomsPage extends StatefulWidget {
  const VoiceRoomsPage({super.key});
  @override
  State<VoiceRoomsPage> createState() => _VoiceRoomsPageState();
}

class _VoiceRoomsPageState extends State<VoiceRoomsPage> {
  List<VRoomInfo> _rooms = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final list = await VoiceService.fetchRooms();
    if (!mounted) return;
    setState(() {
      _rooms = list;
      _loading = false;
    });
  }

  Future<void> _create() async {
    if (FirebaseAuth.instance.currentUser == null) {
      _snack('سجّل الدخول أولاً لإنشاء غرفة');
      return;
    }
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _NewRoomDialog(),
    );
    if (title == null || title.trim().length < 3) return;

    try {
      final id = await VoiceService.createRoom(title);
      if (id != null && mounted) {
        await _load();
        _open(id, title);
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _open(String id, String title) {
    Sound.hapticM();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => VoiceRoomPage(roomId: id, title: title),
    ));
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m, style: GoogleFonts.cairo()),
        backgroundColor: C.red,
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        title: Text('الغرف الصوتية',
            style: GoogleFonts.cairo(
                color: C.textPri, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: C.textSec),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: C.gold,
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: Text('غرفة جديدة',
            style: GoogleFonts.cairo(
                color: Colors.black, fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: C.gold,
        backgroundColor: C.card,
        onRefresh: _load,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: C.gold));
    }
    if (_rooms.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 150),
        Icon(Icons.forum_outlined, size: 56, color: C.textDim),
        const SizedBox(height: 16),
        Text('لا توجد غرف مفتوحة الآن\nكن أول من يبدأ نقاشاً',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: C.textSec, fontSize: 14, height: 1.8)),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
      itemCount: _rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = _rooms[i];
        return InkWell(
          onTap: () => _open(r.id, r.title),
          borderRadius: R.rMd,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: R.rMd,
              border: Border.all(
                  color: r.live ? C.green.withOpacity(0.35) : C.border),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (r.live) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: C.green, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(r.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                                color: C.textPri,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (r.locked)
                        Icon(Icons.lock_rounded, size: 15, color: C.textDim),
                    ]),
                    const SizedBox(height: 7),
                    Text('${r.hostName} · ${r.count} مشارك',
                        style: GoogleFonts.cairo(
                            color: C.textSec, fontSize: 12.5)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: C.textDim),
            ]),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  داخل الغرفة
// ════════════════════════════════════════════════════════════════
class VoiceRoomPage extends StatefulWidget {
  final String roomId;
  final String title;
  const VoiceRoomPage({super.key, required this.roomId, this.title = ''});
  @override
  State<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends State<VoiceRoomPage>
    with WidgetsBindingObserver {
  List<VParticipant> _parts = const [];
  Map<String, double> _levels = const {};
  lk.ConnectionState _conn = lk.ConnectionState.connecting;
  bool _mic = false;
  bool _speaker = true;
  bool _hand = false;
  bool _busy = true;
  String? _err;

  StreamSubscription? _pSub, _lSub, _cSub;
  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  VParticipant? get _me {
    for (final p in _parts) {
      if (p.uid == _myUid) return p;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pSub = VoiceService.participants.listen((list) {
      if (!mounted) return;
      setState(() {
        _parts = list;
        // زامن حالة المايك مع ما يبلّغه الخادم — مهم عندما يكتمك المضيف
        for (final p in list) {
          if (p.uid == _myUid) _mic = p.micOn;
        }
      });
    });

    // ★ تيار منفصل — لا يعيد بناء قائمة المشاركين
    _lSub = VoiceService.audioLevels.listen((m) {
      if (mounted) setState(() => _levels = m);
    });

    _cSub = VoiceService.connState.listen((s) {
      if (mounted) setState(() => _conn = s);
    });

    _join();
  }

  Future<void> _join() async {
    try {
      await VoiceService.join(widget.roomId);
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _toggleMic() async {
    final me = _me;
    if (me == null) return;
    if (!me.canSpeak) {
      _snack(me.mutedByHost
          ? 'المضيف كتم المايك الخاص بك'
          : 'أنت مستمع — ارفع يدك لطلب التحدث');
      return;
    }
    Sound.hapticM();
    final target = !_mic;
    setState(() => _mic = target); // تحديث متفائل — الزر يستجيب فوراً
    try {
      await VoiceService.setMic(target);
    } catch (e) {
      if (mounted) setState(() => _mic = !target);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleHand() async {
    Sound.hapticM();
    final t = !_hand;
    setState(() => _hand = t);
    try {
      await VoiceService.raiseHand(t);
    } catch (e) {
      if (mounted) setState(() => _hand = !t);
    }
  }

  Future<void> _toggleSpeaker() async {
    Sound.hapticL();
    final t = !_speaker;
    setState(() => _speaker = t);
    await VoiceService.setSpeakerphone(t);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m, style: GoogleFonts.cairo()),
        backgroundColor: C.raised,
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ══ 🔋 اكتم المايك عند الخروج للخلفية ════════════════════════
  // لا نقطع الاتصال (المستخدم يريد مواصلة الاستماع)، لكن إبقاء
  // المايك مفتوحاً يشغّل مُرمِّزاً و AEC بلا فائدة — ويبثّ صوت
  // محيط المستخدم دون أن يدري.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused && _mic) {
      unawaited(VoiceService.setMic(false).catchError((_) {}));
      if (mounted) setState(() => _mic = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pSub?.cancel();
    _lSub?.cancel();
    _cSub?.cancel();
    unawaited(VoiceService.leave());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speakers = _parts.where((p) => p.role != VRole.listener).toList();
    final listeners = _parts.length - speakers.length;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(children: [
          if (_conn != lk.ConnectionState.connected) _banner(),
          _header(listeners),
          Expanded(child: _err != null ? _error() : _grid(speakers)),
          _controls(),
        ]),
      ),
    );
  }

  Widget _banner() {
    final (txt, col) = switch (_conn) {
      lk.ConnectionState.connecting => ('جارٍ الاتصال…', C.blue),
      lk.ConnectionState.reconnecting =>
        ('انقطع الاتصال — جارٍ إعادة المحاولة…', C.gold),
      _ => ('غير متصل', C.red),
    };
    return Container(
      width: double.infinity,
      color: col.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: col)),
        const SizedBox(width: 10),
        Text(txt, style: GoogleFonts.cairo(color: col, fontSize: 12.5)),
      ]),
    );
  }

  Widget _header(int listeners) {
    final title = VoiceService.roomTitle.isNotEmpty
        ? VoiceService.roomTitle
        : widget.title;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                    color: C.textPri, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('$listeners مستمع · أنت ${VoiceService.myRole.label}',
                style: GoogleFonts.cairo(color: C.textDim, fontSize: 12.5)),
          ]),
        ),
        IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: C.textSec),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ]),
    );
  }

  Widget _error() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, size: 48, color: C.red),
            const SizedBox(height: 14),
            Text(_err!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(color: C.textSec, height: 1.7)),
          ]),
        ),
      );

  Widget _grid(List<VParticipant> speakers) {
    if (_busy) {
      return Center(child: CircularProgressIndicator(color: C.gold));
    }
    if (speakers.isEmpty) {
      return Center(
        child: Text('لا يوجد متحدثون بعد',
            style: GoogleFonts.cairo(color: C.textDim, fontSize: 14)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 8,
        childAspectRatio: .76,
      ),
      itemCount: speakers.length,
      itemBuilder: (_, i) => _tile(speakers[i]),
    );
  }

  Widget _tile(VParticipant p) {
    final lvl = (_levels[p.uid] ?? 0.0).clamp(0.0, 1.0);
    final speaking = p.micOn && lvl > 0.05;
    final amHost = _me?.isHost ?? false;

    return GestureDetector(
      onLongPress: amHost && !p.isLocal ? () => _hostSheet(p) : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.all(speaking ? 3 + lvl * 3 : 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: speaking ? C.green : Colors.transparent, width: 2.5),
          ),
          child: CircleAvatar(
            radius: 29,
            backgroundColor: C.raised,
            backgroundImage:
                p.avatar.isNotEmpty ? NetworkImage(p.avatar) : null,
            child: p.avatar.isEmpty
                ? Text(p.name.isNotEmpty ? p.name.substring(0, 1) : '؟',
                    style: GoogleFonts.cairo(
                        color: C.textSec,
                        fontSize: 21,
                        fontWeight: FontWeight.w800))
                : null,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 74,
          child: Text(p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(color: C.textPri, fontSize: 11.5)),
        ),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (p.isHost)
            Icon(Icons.star_rounded, size: 13, color: C.gold),
          if (p.mutedByHost)
            Icon(Icons.volume_off_rounded, size: 13, color: C.gold)
          else if (!p.micOn)
            Icon(Icons.mic_off_rounded, size: 13, color: C.textDim),
        ]),
      ]),
    );
  }

  void _hostSheet(VParticipant p) {
    Sound.hapticM();
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text(p.name,
              style: GoogleFonts.cairo(
                  color: C.textPri, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (p.role == VRole.listener)
            ListTile(
              leading: Icon(Icons.record_voice_over_rounded, color: C.green),
              title: Text('ترقية إلى متحدث',
                  style: GoogleFonts.cairo(color: C.textPri)),
              subtitle: Text('يبدأ التحدث فوراً بلا إعادة اتصال',
                  style: GoogleFonts.cairo(color: C.textDim, fontSize: 11.5)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _run(() => VoiceService.promote(p.uid));
              },
            )
          else
            ListTile(
              leading: Icon(Icons.mic_off_rounded, color: C.gold),
              title:
                  Text('كتم المتحدث', style: GoogleFonts.cairo(color: C.textPri)),
              subtitle: Text('لن يستطيع فتح المايك بنفسه',
                  style: GoogleFonts.cairo(color: C.textDim, fontSize: 11.5)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _run(() => VoiceService.muteUser(p.uid));
              },
            ),
          ListTile(
            leading: Icon(Icons.person_remove_rounded, color: C.red),
            title: Text('طرد من الغرفة',
                style: GoogleFonts.cairo(color: C.textPri)),
            onTap: () {
              Navigator.pop(sheetCtx);
              _run(() => VoiceService.kick(p.uid));
            },
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _controls() {
    final canSpeak = _me?.canSpeak ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _btn(
            icon: _speaker
                ? Icons.volume_up_rounded
                : Icons.phone_in_talk_rounded,
            label: _speaker ? 'مكبّر' : 'سماعة',
            onTap: _toggleSpeaker,
          ),
          if (canSpeak)
            _micBtn()
          else
            _btn(
              icon: Icons.pan_tool_rounded,
              label: _hand ? 'يدك مرفوعة' : 'اطلب التحدث',
              color: _hand ? C.gold : null,
              big: true,
              onTap: _toggleHand,
            ),
          _btn(
            icon: Icons.call_end_rounded,
            label: 'خروج',
            color: C.red,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _micBtn() => GestureDetector(
        onTap: _toggleMic,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _mic ? C.green : Colors.white12,
              boxShadow: _mic
                  ? [
                      BoxShadow(
                          color: C.green.withOpacity(0.42),
                          blurRadius: 18,
                          spreadRadius: 2)
                    ]
                  : null,
            ),
            child: Icon(_mic ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(height: 6),
          Text(_mic ? 'تتحدث الآن' : 'مكتوم',
              style: GoogleFonts.cairo(color: C.textSec, fontSize: 11)),
        ]),
      );

  Widget _btn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool big = false,
  }) {
    final size = big ? 68.0 : 52.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (color ?? Colors.white).withOpacity(0.14),
          ),
          child: Icon(icon, color: color ?? C.textPri, size: big ? 28 : 22),
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.cairo(color: C.textSec, fontSize: 11)),
      ]),
    );
  }
}

// ── حوار إنشاء غرفة ─────────────────────────────────────────────
class _NewRoomDialog extends StatefulWidget {
  const _NewRoomDialog();
  @override
  State<_NewRoomDialog> createState() => _NewRoomDialogState();
}

class _NewRoomDialogState extends State<_NewRoomDialog> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: R.rMd),
        title: Text('غرفة جديدة',
            style: GoogleFonts.cairo(
                color: C.textPri, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: _c,
          autofocus: true,
          maxLength: 60,
          style: GoogleFonts.cairo(color: C.textPri),
          decoration: InputDecoration(
            hintText: 'عن ماذا تريد التحدث؟',
            hintStyle: GoogleFonts.cairo(color: C.textDim),
            counterStyle: TextStyle(color: C.textDim),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: C.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _c.text),
            child: Text('إنشاء',
                style: GoogleFonts.cairo(
                    color: C.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      );
}
