part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — مركز عمليات الأدمن الكامل داخل التطبيق
//  نقل كامل لـ index.html (Admin v2): كل الأقسام، مربوطة بـ Firestore.
//  التركيب: ضع الملف في lib/ui/pages/admin_console.dart
//   main.dart:  part 'ui/pages/admin_console.dart';
//   routes:     '/ops': (_) => const AdminConsolePage(),
// ════════════════════════════════════════════════════════════════════════

class _AC {
  static const bg=Color(0xFF050508), bg2=Color(0xFF09090E), bg3=Color(0xFF0E0E16);
  static const card=Color(0xFF111118);
  static const bdr=Color(0xFF1E1E2E), bdr2=Color(0xFF252535);
  static const tx=Color(0xFFE8E8F0), t2=Color(0xFF8888A8), t3=Color(0xFF44445A);
  static const gold=Color(0xFFF0C040), gold2=Color(0xFFFFD060), gold3=Color(0xFFC89020);
  static const grn=Color(0xFF20D460), red=Color(0xFFF04040), blu=Color(0xFF4080F0);
  static const cyn=Color(0xFF20C0D0), prp=Color(0xFFA060F0), org=Color(0xFFF06020);

  static TextStyle t({double s=12, FontWeight w=FontWeight.w500, Color c=tx, double? ls}) =>
      GoogleFonts.ibmPlexSansArabic(fontSize:s, fontWeight:w, color:c, letterSpacing:ls);
  static TextStyle mono({double s=11, FontWeight w=FontWeight.w600, Color c=tx, double? ls}) =>
      GoogleFonts.jetBrainsMono(fontSize:s, fontWeight:w, color:c, letterSpacing:ls);

  static final db = FirebaseFirestore.instance;
  static String get adminEmail => FirebaseAuth.instance.currentUser?.email ?? 'admin';

  static Future<void> tg(String msg) async {
    try {
      final s = await db.collection('app_config').doc('settings').get();
      final d = s.data() ?? {};
      final bot = d['tg_bot']?.toString() ?? '';
      final chat = d['tg_chat']?.toString() ?? '';
      if (bot.isEmpty || chat.isEmpty) return;
      await DioClient.telegram.post('https://api.telegram.org/bot$bot/sendMessage',
        data: {'chat_id': chat, 'text': msg, 'parse_mode': 'Markdown'}).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }
}

// ════════════════════════════════════════════════════════════════════════
class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({super.key});
  @override State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  static const sections = <(String,String,IconData)>[
    ('dash','Dashboard',Icons.dashboard_rounded),
    ('users','المستخدمون',Icons.group_rounded),
    ('activate','تفعيل',Icons.bolt_rounded),
    ('subs','الاشتراكات',Icons.diamond_rounded),
    ('orders','الطلبات',Icons.receipt_long_rounded),
    ('complaints','الشكاوى',Icons.report_problem_rounded),
    ('credit','الرصيد',Icons.account_balance_wallet_rounded),
    ('servers','السيرفرات',Icons.dns_rounded),
    ('remote','تحكم',Icons.tune_rounded),
    ('version','الإصدارات',Icons.rocket_launch_rounded),
    ('notif','الإشعارات',Icons.notifications_rounded),
    ('banned','المحظورون',Icons.block_rounded),
    ('admins','المشرفون',Icons.shield_rounded),
    ('config','الإعدادات',Icons.settings_rounded),
  ];

  int _i = 0;
  bool _allowed = false, _checking = true;

  @override
  void initState() {
    super.initState();
    final e = (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();
    _allowed = e=='haedirasso@gmail.com' || e=='admin@totv.com' || e.endsWith('@totv.com');
    _checking = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return const Scaffold(backgroundColor:_AC.bg,
        body:Center(child:CircularProgressIndicator(color:_AC.gold)));
    if (!_allowed) return const _AccessDenied();
    return Scaffold(backgroundColor:_AC.bg,
      body: SafeArea(child: Column(children: [
        _topBar(),
        Expanded(child: IndexedStack(index:_i, children: const [
          _DashTab(), _UsersTab(), _ActivateTab(), _SubsTab(), _OrdersTab(),
          _ComplaintsTab(),
          _CreditTab(), _ServerStatsTab(), _RemoteTab(), _VersionTab(), _NotifTab(), _BannedTab(), _AdminsTab(), _ConfigTab(),
        ])),
        _bottomNav(),
      ])));
  }

  Widget _topBar() => Container(padding: const EdgeInsets.fromLTRB(16,12,16,12),
    decoration: const BoxDecoration(color:_AC.bg2, border:Border(bottom:BorderSide(color:_AC.bdr))),
    child: Row(children: [
      Text('TOTV+', style:_AC.mono(s:17,w:FontWeight.w700,c:_AC.gold,ls:3)),
      Container(width:7,height:7,margin:const EdgeInsets.only(right:8),
        decoration:const BoxDecoration(color:_AC.grn,shape:BoxShape.circle)),
      const SizedBox(width:10), Container(width:1,height:18,color:_AC.bdr2), const SizedBox(width:10),
      Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Text(sections[_i].$2, style:_AC.t(s:14,w:FontWeight.w700)),
        Text(_AC.adminEmail, style:_AC.mono(s:9,c:_AC.t2), overflow:TextOverflow.ellipsis),
      ])),
      GestureDetector(onTap: ()=>Navigator.maybePop(context),
        child: Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
          decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(8),border:Border.all(color:_AC.bdr)),
          child: Row(mainAxisSize:MainAxisSize.min,children:[
            const Icon(Icons.logout_rounded,size:13,color:_AC.t2), const SizedBox(width:5),
            Text('خروج',style:_AC.t(s:11,c:_AC.t2))]))),
    ]),
  );

  Widget _bottomNav() => Container(
    decoration: const BoxDecoration(color:_AC.bg2, border:Border(top:BorderSide(color:_AC.bdr))),
    child: SafeArea(top:false, child: SingleChildScrollView(scrollDirection:Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal:6,vertical:8),
      child: Row(children: List.generate(sections.length, (k) {
        final on = k==_i; final s = sections[k];
        return GestureDetector(onTap: () { Sound.hapticL(); setState(()=>_i=k); },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(width:64,
            child: Column(mainAxisSize:MainAxisSize.min, children:[
              Icon(s.$3, size:19, color:on?_AC.gold:_AC.t3), const SizedBox(height:3),
              Text(s.$2, style:_AC.t(s:8.5,w:on?FontWeight.w700:FontWeight.w500,c:on?_AC.gold:_AC.t3),
                  maxLines:1, overflow:TextOverflow.ellipsis),
            ])));
      })),
    )),
  );
}

// ════════════════════════════════════════════════════════════════════════
//  DASHBOARD
// ════════════════════════════════════════════════════════════════════════
class _DashTab extends StatefulWidget {
  const _DashTab();
  @override State<_DashTab> createState() => _DashTabState();
}
class _DashTabState extends State<_DashTab> {
  int? _total, _premium, _online, _pending, _expiringSoon;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = _AC.db.collection('users');
    final now = Timestamp.now();
    final soon = Timestamp.fromDate(DateTime.now().add(const Duration(days: 7)));

    // كل عدّاد مستقل — فشل أحدها لا يُصفّر الباقي
    Future<int?> safeCount(Query q) async {
      try { final r = await q.count().get(); return r.count; }
      catch (e) { debugPrint('[dash] count: $e'); return null; }
    }

    final r = await Future.wait([
      safeCount(users),
      safeCount(users.where('subscription.plan', isEqualTo: 'premium')),
      safeCount(users.where('is_online', isEqualTo: true)),
      safeCount(_AC.db.collection('orders').where('status', isEqualTo: 'pending')),
      safeCount(users.where('subscription.plan', isEqualTo: 'premium')
          .where('subscription.expiry_date', isGreaterThan: now)
          .where('subscription.expiry_date', isLessThan: soon)),
    ]);

    if (!mounted) return;
    setState(() {
      _total = r[0]; _premium = r[1]; _online = r[2]; _pending = r[3]; _expiringSoon = r[4];
      _loading = false;
    });

    // احتياط: إن فشل العدّ الكلي (count غير مدعوم/قاعدة)، اعدد يدوياً
    if (_total == null) {
      try {
        final snap = await users.limit(3000).get();
        if (mounted) setState(() => _total = snap.size);
      } catch (e) { debugPrint('[dash] fallback: $e'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _AC.gold, backgroundColor: _AC.card,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        if (_loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator(color: _AC.gold)))
        else
          _statGrid(context, [
            ('إجمالي المستخدمين', '${_total ?? '—'}', _AC.gold),
            ('مشتركون مدفوعون', '${_premium ?? '—'}', _AC.grn),
            ('متصلون الآن', '${_online ?? '—'}', _AC.blu),
            ('ينتهي خلال 7 أيام', '${_expiringSoon ?? '—'}', _AC.org),
            ('طلبات معلّقة', '${_pending ?? '—'}', _AC.red),
          ]),
        const SizedBox(height: 6),
        Center(child: TextButton.icon(onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 15, color: _AC.t2),
          label: Text('تحديث', style: _AC.t(s: 11, c: _AC.t2)))),
        const SizedBox(height: 8),
        const _OrdersPendingCard(),
        const SizedBox(height: 14),
        _acCard('⚡ إجراءات سريعة', Column(children: [
          _quick(context, '⚡ تفعيل اشتراك', _AC.gold, 2),
          _quick(context, '📥 الطلبات والحوالات', _AC.blu, 4),
          _quick(context, '💳 الرصيد والسيرفرات', _AC.prp, 5),
          _quick(context, '🎮 التحكم عن بعد', _AC.cyn, 6),
        ])),
      ]),
    );
  }

  Widget _statGrid(BuildContext ctx, List<(String,String,Color)> items) {
    final w = (MediaQuery.of(ctx).size.width - 28 - 10) / 2;
    return Wrap(spacing:10,runSpacing:10, children: items.map((it)=>SizedBox(width:w,
      child: Container(padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(12),border:Border.all(color:_AC.bdr)),
        child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(it.$2,style:_AC.mono(s:26,w:FontWeight.w700,c:it.$3)),
          const SizedBox(height:4), Text(it.$1,style:_AC.t(s:10.5,c:_AC.t2)),
        ])))).toList());
  }

  Widget _quick(BuildContext ctx, String t, Color c, int idx) => Padding(
    padding: const EdgeInsets.only(bottom:8),
    child: GestureDetector(
      onTap: () { Sound.hapticM(); final st=ctx.findAncestorStateOfType<_AdminConsolePageState>();
        if(st!=null) st.setState(()=>st._i=idx); },
      child: Container(width:double.infinity,padding:const EdgeInsets.symmetric(vertical:12),
        decoration:BoxDecoration(color:c.withOpacity(.12),borderRadius:BorderRadius.circular(9),border:Border.all(color:c.withOpacity(.3))),
        child: Center(child:Text(t,style:_AC.t(s:12.5,w:FontWeight.w700,c:c))))),
  );
}

class _OrdersPendingCard extends StatelessWidget {
  const _OrdersPendingCard();
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream:_AC.db.collection('orders').where('status',isEqualTo:'pending').snapshots(),
    builder:(_,snap){
      final n=snap.data?.docs.length ?? 0;
      return Container(padding:const EdgeInsets.all(16),
        decoration:BoxDecoration(gradient:LinearGradient(colors:[_AC.gold.withOpacity(.14),_AC.gold.withOpacity(.03)]),
          borderRadius:BorderRadius.circular(12),border:Border.all(color:_AC.gold.withOpacity(.3))),
        child:Row(children:[
          const Text('🔔',style:TextStyle(fontSize:22)), const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('$n طلب بانتظار التفعيل',style:_AC.t(s:14,w:FontWeight.w800,c:_AC.gold)),
            Text('طلبات شراء وحوالات جديدة',style:_AC.t(s:11,c:_AC.t2)),
          ])),
          if(n>0) Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),
            decoration:BoxDecoration(color:_AC.red,borderRadius:BorderRadius.circular(20)),
            child:Text('$n',style:_AC.mono(s:12,w:FontWeight.w700,c:Colors.white))),
        ]));
    });
}

// ════════════════════════════════════════════════════════════════════════
//  USERS
// ════════════════════════════════════════════════════════════════════════
class _UsersTab extends StatefulWidget { const _UsersTab(); @override State<_UsersTab> createState()=>_UsersTabState(); }
class _UsersTabState extends State<_UsersTab> {
  String _q=''; final _c=TextEditingController();
  @override void dispose(){_c.dispose();super.dispose();}
  @override
  Widget build(BuildContext context) => Column(children:[
    Padding(padding:const EdgeInsets.all(14),
      child:_ConsoleField(controller:_c,hint:'بحث: إيميل · اسم · هاتف · يوزر السيرفر · UID',icon:Icons.search_rounded,
        onChanged:(v)=>setState(()=>_q=v.trim().toLowerCase()))),
    Expanded(child:StreamBuilder<QuerySnapshot>(
      // عند البحث بالإيميل: استعلام مباشر بالبادئة (يجد أي مستخدم حتى مع آلاف الحسابات)
      // عند عدم البحث: أحدث 500 (للتصفّح فقط).
      stream: _q.contains('@')
        ? _AC.db.collection('users')
            .orderBy('email')
            .startAt([_q]).endAt(['$_q\uf8ff']).limit(60).snapshots()
        : _AC.db.collection('users').limit(800).snapshots(),
      builder:(_,snap){
        if(!snap.hasData) return const Center(child:CircularProgressIndicator(color:_AC.gold));
        var docs=snap.data!.docs.where((d){
          if(_q.isEmpty) return true;
          final m=d.data() as Map<String,dynamic>;
          final sub = (m['subscription'] as Map?) ?? const {};
          bool has(Object? v) => (v??'').toString().toLowerCase().contains(_q);
          return has(m['email']) || has(m['display_name']) || has(m['name']) ||
                 has(m['phone']) || has(sub['username']) || has(sub['host']) ||
                 d.id.toLowerCase().contains(_q);
        }).toList();
        if(docs.isEmpty) return Center(child:Text(_q.isEmpty?'لا مستخدمين':'لا نتائج — جرّب الإيميل كاملاً',style:_AC.t(c:_AC.t3)));
        return ListView.builder(padding:const EdgeInsets.symmetric(horizontal:14),itemCount:docs.length,cacheExtent:800,
          itemBuilder:(_,i){
            final m=docs[i].data() as Map<String,dynamic>;
            return RepaintBoundary(child:_UserRow(uid:docs[i].id,data:m,
              onTap:()=>_UserDetailPage.open(context, docs[i].id),
              onLong:()=>_userActions(context,docs[i].id,m)));
          });
      })),
  ]);

  void _userActions(BuildContext ctx, String uid, Map<String,dynamic> m) {
    final banned = m['status']?.toString()=='banned';
    showModalBottomSheet(context:ctx,backgroundColor:Colors.transparent,builder:(_)=>Container(
      padding:const EdgeInsets.fromLTRB(18,14,18,28),
      decoration:const BoxDecoration(color:_AC.bg2,borderRadius:BorderRadius.vertical(top:Radius.circular(22)),
        border:Border(top:BorderSide(color:_AC.bdr))),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(width:38,height:4,margin:const EdgeInsets.only(bottom:16),
          decoration:BoxDecoration(color:_AC.bdr2,borderRadius:BorderRadius.circular(3))),
        Text(m['display_name']?.toString()??m['email']?.toString()??uid,style:_AC.t(s:14,w:FontWeight.w700)),
        const SizedBox(height:16),
        _actTile(banned?'✅ رفع الحظر':'🚫 حظر المستخدم',banned?_AC.grn:_AC.red,()async{
          Navigator.pop(ctx);
          await _AC.db.collection('users').doc(uid).update({'status':banned?'active':'banned','updated_at':FieldValue.serverTimestamp()});
          _AC.tg('${banned?"✅ رفع حظر":"🚫 حظر"} مستخدم\n`$uid`'); if(mounted)_toast(context,'تم');
        }),
        _actTile('⏸ إيقاف الاشتراك (تحويل لمجاني)',_AC.org,()async{
          Navigator.pop(ctx);
          await _AC.db.collection('users').doc(uid).update({
            'subscription.plan':'free','subscription.host':FieldValue.delete(),
            'subscription.username':FieldValue.delete(),'subscription.password':FieldValue.delete(),
            'updated_at':FieldValue.serverTimestamp()});
          if(mounted)_toast(context,'تم إيقاف الاشتراك');
        }),
      ]),
    ));
  }
  Widget _actTile(String t,Color c,VoidCallback onTap)=>Padding(padding:const EdgeInsets.only(bottom:9),
    child:GestureDetector(onTap:onTap,child:Container(width:double.infinity,padding:const EdgeInsets.symmetric(vertical:13),
      decoration:BoxDecoration(color:c.withOpacity(.12),borderRadius:BorderRadius.circular(10),border:Border.all(color:c.withOpacity(.3))),
      child:Center(child:Text(t,style:_AC.t(s:13,w:FontWeight.w700,c:c))))));
}

class _UserRow extends StatelessWidget {
  final String uid; final Map<String,dynamic> data; final VoidCallback onTap; final VoidCallback? onLong;
  const _UserRow({required this.uid,required this.data,required this.onTap,this.onLong});
  @override
  Widget build(BuildContext context) {
    final name=data['display_name']?.toString()??'—';
    final email=data['email']?.toString()??uid;
    final plan=(data['subscription'] as Map<String,dynamic>?)?['plan']?.toString()??'free';
    final banned=data['status']?.toString()=='banned';
    final (bc,bt)= banned?(_AC.red,'🚫 محظور')
      : plan=='premium'?(_AC.gold,'💎 بريميوم')
      : plan=='trial'?(_AC.cyn,'🔵 تجريبي'):(_AC.t2,'⏱ مجاني');
    return GestureDetector(onTap:(){Sound.hapticL();onTap();}, onLongPress:onLong,
      child:Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(11),border:Border.all(color:_AC.bdr)),
        child:Row(children:[
          Container(width:36,height:36,decoration:BoxDecoration(color:bc.withOpacity(.12),borderRadius:BorderRadius.circular(9)),
            child:Center(child:Text(name.isNotEmpty?name[0].toUpperCase():'?',style:_AC.t(s:14,w:FontWeight.w800,c:bc)))),
          const SizedBox(width:11),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(name,style:_AC.t(s:12.5,w:FontWeight.w600)),
            Text(email,style:_AC.mono(s:9.5,c:_AC.t2),overflow:TextOverflow.ellipsis),
          ])),
          Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),
            decoration:BoxDecoration(color:bc.withOpacity(.12),borderRadius:BorderRadius.circular(8)),
            child:Text(bt,style:_AC.t(s:10,w:FontWeight.w700,c:bc))),
        ])));
  }
}

// ════════════════════════════════════════════════════════════════════════
//  ACTIVATE
// ════════════════════════════════════════════════════════════════════════
class _ActivateTab extends StatefulWidget { const _ActivateTab(); @override State<_ActivateTab> createState()=>_ActivateTabState(); }
class _ActivateTabState extends State<_ActivateTab> {
  String _q=''; final _c=TextEditingController();
  @override void dispose(){_c.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Column(children:[
    Padding(padding:const EdgeInsets.all(14),
      child:_ConsoleField(controller:_c,hint:'ابحث عن مستخدم لتفعيله...',icon:Icons.search_rounded,
        onChanged:(v)=>setState(()=>_q=v.trim().toLowerCase()))),
    Expanded(child:_q.isEmpty
      ?Center(child:Text('اكتب للبحث عن مستخدم',style:_AC.t(c:_AC.t3)))
      :StreamBuilder<QuerySnapshot>(stream:_AC.db.collection('users').limit(500).snapshots(),
        builder:(_,snap){
          final docs=(snap.data?.docs??[]).where((d){
            final m=d.data() as Map<String,dynamic>;
            return (m['email']??'').toString().toLowerCase().contains(_q)||
                   (m['display_name']??'').toString().toLowerCase().contains(_q);
          }).take(40).toList();
          if(docs.isEmpty) return Center(child:Text('لا نتائج',style:_AC.t(c:_AC.t3)));
          return ListView.builder(padding:const EdgeInsets.symmetric(horizontal:14),itemCount:docs.length,
            itemBuilder:(_,i){
              final m=docs[i].data() as Map<String,dynamic>;
              return _UserRow(uid:docs[i].id,data:m,onTap:()=>_ActivateSheet.show(context,uid:docs[i].id,
                email:m['email']?.toString()??'',name:m['display_name']?.toString()??'',presetDays:30));
            });
        })),
  ]);
}

class _ActivateSheet extends StatefulWidget {
  final String uid,email,name; final int presetDays; final String? orderId;
  const _ActivateSheet({required this.uid,required this.email,required this.name,required this.presetDays,this.orderId});
  static void show(BuildContext ctx,{required String uid,required String email,required String name,required int presetDays,String? orderId})=>
    showModalBottomSheet(context:ctx,isScrollControlled:true,backgroundColor:Colors.transparent,
      builder:(_)=>_ActivateSheet(uid:uid,email:email,name:name,presetDays:presetDays,orderId:orderId));
  @override State<_ActivateSheet> createState()=>_ActivateSheetState();
}
class _ActivateSheetState extends State<_ActivateSheet> {
  String _plan='premium'; late int _days=widget.presetDays;
  bool _useCredit=true; // الافتراضي: اسحب بيانات السيرفر من الرصيد تلقائياً
  final _host=TextEditingController(),_xuser=TextEditingController(),_xpass=TextEditingController(),_note=TextEditingController();
  bool _busy=false;
  @override void dispose(){_host.dispose();_xuser.dispose();_xpass.dispose();_note.dispose();super.dispose();}

  @override
  Widget build(BuildContext context)=>Container(
    padding:EdgeInsets.fromLTRB(18,16,18,MediaQuery.of(context).viewInsets.bottom+24),
    decoration:const BoxDecoration(color:_AC.bg2,borderRadius:BorderRadius.vertical(top:Radius.circular(22)),
      border:Border(top:BorderSide(color:_AC.bdr))),
    child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Center(child:Container(width:38,height:4,margin:const EdgeInsets.only(bottom:16),
        decoration:BoxDecoration(color:_AC.bdr2,borderRadius:BorderRadius.circular(3)))),
      Text('تفعيل اشتراك',style:_AC.t(s:16,w:FontWeight.w800)),
      const SizedBox(height:4),
      Text('${widget.name.isNotEmpty?widget.name:"—"} · ${widget.email}',style:_AC.mono(s:10.5,c:_AC.t2)),
      const SizedBox(height:18),
      Text('الخطة',style:_AC.t(s:11,c:_AC.t2)), const SizedBox(height:7),
      Row(children:[ _pc('premium','💎 بريميوم',_AC.gold), _pc('trial','🔵 تجريبي',_AC.cyn), _pc('free','⏱ مجاني',_AC.t2) ]),
      const SizedBox(height:14),
      Text('المدة (أيام)',style:_AC.t(s:11,c:_AC.t2)), const SizedBox(height:7),
      Wrap(spacing:8,children:[7,30,90,365].map((d)=>GestureDetector(
        onTap:(){Sound.hapticL();setState(()=>_days=d);},
        child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:9),
          decoration:BoxDecoration(color:_days==d?_AC.gold.withOpacity(.15):_AC.card,
            borderRadius:BorderRadius.circular(9),border:Border.all(color:_days==d?_AC.gold:_AC.bdr)),
          child:Text('$d',style:_AC.mono(s:13,w:FontWeight.w700,c:_days==d?_AC.gold:_AC.t2))))).toList()),
      if(_plan=='premium')...[
        const SizedBox(height:14),
        // مفتاح: استخدام الرصيد (تخصيص سيرفر تلقائياً) أو إدخال يدوي
        Container(padding: const EdgeInsets.symmetric(horizontal:12,vertical:6),
          decoration: BoxDecoration(color:_AC.bg3,borderRadius:BorderRadius.circular(10),border:Border.all(color:_AC.bdr)),
          child: Row(children:[
            const Icon(Icons.account_balance_wallet_rounded,size:16,color:_AC.gold),
            const SizedBox(width:9),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('تخصيص من الرصيد',style:_AC.t(s:12.5,w:FontWeight.w600)),
              Text('يسحب سيرفراً متاحاً تلقائياً (نقطة واحدة)',style:_AC.t(s:9.5,c:_AC.t2)),
            ])),
            Switch(value:_useCredit,activeColor:_AC.gold,onChanged:(v){Sound.hapticL();setState(()=>_useCredit=v);}),
          ])),
        if(!_useCredit)...[
          const SizedBox(height:8),
          _ConsoleField(controller:_host,hint:'http://server.com:8080',ltr:true), const SizedBox(height:8),
          _ConsoleField(controller:_xuser,hint:'xtream_username',ltr:true), const SizedBox(height:8),
          _ConsoleField(controller:_xpass,hint:'xtream_password',ltr:true),
        ],
      ],
      const SizedBox(height:8),
      _ConsoleField(controller:_note,hint:'ملاحظة (مثال: دفع كاش عبر FIB)'),
      const SizedBox(height:18),
      GestureDetector(onTap:_busy?null:_activate,
        child:Container(height:50,alignment:Alignment.center,
          decoration:BoxDecoration(gradient:const LinearGradient(colors:[_AC.gold2,_AC.gold3]),borderRadius:BorderRadius.circular(11)),
          child:_busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2.4,color:Colors.black))
            :Text('⚡ تفعيل الآن — $_days يوم',style:_AC.t(s:14,w:FontWeight.w800,c:Colors.black)))),
    ])),
  );

  Widget _pc(String id,String label,Color c)=>Expanded(child:Padding(padding:const EdgeInsets.only(left:7),
    child:GestureDetector(onTap:(){Sound.hapticL();setState(()=>_plan=id);},
      child:Container(padding:const EdgeInsets.symmetric(vertical:11),alignment:Alignment.center,
        decoration:BoxDecoration(color:_plan==id?c.withOpacity(.15):_AC.card,borderRadius:BorderRadius.circular(9),
          border:Border.all(color:_plan==id?c:_AC.bdr)),
        child:Text(label,style:_AC.t(s:11.5,w:FontWeight.w700,c:_plan==id?c:_AC.t2))))));

  Future<void> _activate() async {
    if(widget.uid.isEmpty){_toast(context,'⚠ المستخدم غير صالح');return;}
    // تحقق المدخلات حسب وضع التخصيص
    if(_plan=='premium' && !_useCredit &&
       (_host.text.trim().isEmpty||_xuser.text.trim().isEmpty||_xpass.text.trim().isEmpty)){
      _toast(context,'⚠ أدخل بيانات السيرفر الخاص');return;}
    setState(()=>_busy=true);
    final admin=_AC.adminEmail; final expiry=DateTime.now().add(Duration(days:_days)); final note=_note.text.trim();
    final sub=<String,dynamic>{
      'plan':_plan,'expiry_date':Timestamp.fromDate(expiry),
      'duration_days':_days,
      'tier': _days<=45?'monthly':(_days<=135?'quarterly':'yearly'),
      'activated_at':FieldValue.serverTimestamp(),'updated_at':FieldValue.serverTimestamp(),
      'activated_by':admin, if(note.isNotEmpty)'note':note,
    };
    String? serverId;
    try{
      if(_plan=='premium'){
        if(_useCredit){
          // اسحب نقطة من الرصيد (transaction آمن)
          final alloc = await _CreditEngine.allocate(uid:widget.uid,email:widget.email);
          sub['host']=alloc['host']; sub['server_host']=alloc['host'];
          sub['username']=alloc['username']; sub['password']=alloc['password'];
          sub['server_id']=alloc['server_id'];
          serverId=alloc['server_id'];
        }else{
          sub['host']=_host.text.trim(); sub['server_host']=_host.text.trim();
          sub['username']=_xuser.text.trim(); sub['password']=_xpass.text.trim();
        }
      }
      await _AC.db.collection('users').doc(widget.uid).update({'subscription':sub,'status':'active','updated_at':FieldValue.serverTimestamp()});
      if(widget.orderId!=null){
        await _AC.db.collection('orders').doc(widget.orderId).update({
          'status':'active','duration_days':_days,'expiry_date':Timestamp.fromDate(expiry),
          if(serverId!=null)'server_id':serverId,
          'activated_by':admin,'activated_at':FieldValue.serverTimestamp(),
          'updated_at':FieldValue.serverTimestamp()});
      }else{
        await _AC.db.collection('orders').add({
          'uid':widget.uid,'email':widget.email,'display_name':widget.name,'plan':_plan,
          'duration_days':_days,'note':note,'status':'active','activated_by':admin,
          if(serverId!=null)'server_id':serverId,
          'created':FieldValue.serverTimestamp(),'expiry_date':Timestamp.fromDate(expiry)});
      }
      _AC.tg('⚡ *تفعيل اشتراك*\n👤 ${widget.name}\n📧 ${widget.email}\n💎 $_plan\n📅 $_days يوم'
          '${serverId!=null?"\n🖥 رصيد: ${sub['server_name']??serverId}":""}\n👮 $admin');
      if(mounted){Navigator.pop(context);_toast(context,'✅ تم تفعيل ${widget.name.isNotEmpty?widget.name:widget.email} — $_days يوم');}
    }catch(e){if(mounted){setState(()=>_busy=false);_toast(context,'⚠ $e');}}
  }
}

// ════════════════════════════════════════════════════════════════════════
//  SUBS
// ════════════════════════════════════════════════════════════════════════
class _SubsTab extends StatelessWidget {
  const _SubsTab();
  @override
  Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
    stream:_AC.db.collection('users').limit(500).snapshots(),
    builder:(_,snap){
      if(!snap.hasData) return const Center(child:CircularProgressIndicator(color:_AC.gold));
      final now=DateTime.now();
      final subs=snap.data!.docs.where((d){
        final plan=((d.data() as Map<String,dynamic>)['subscription'] as Map<String,dynamic>?)?['plan']?.toString()??'free';
        return plan=='premium'||plan=='trial';
      }).toList();
      if(subs.isEmpty) return Center(child:Text('لا اشتراكات نشطة',style:_AC.t(c:_AC.t3)));
      return ListView.builder(padding:const EdgeInsets.all(14),itemCount:subs.length,cacheExtent:800,
        itemBuilder:(_,i){
          final m=subs[i].data() as Map<String,dynamic>;
          final sub=(m['subscription'] as Map<String,dynamic>?)??{};
          final exp=(sub['expiry_date'] as Timestamp?)?.toDate();
          final left=exp==null?0:exp.difference(now).inDays; final soon=left>=0&&left<=7;
          return RepaintBoundary(child:Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(13),
            decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(11),
              border:Border.all(color:left<0?_AC.red.withOpacity(.3):_AC.bdr)),
            child:Row(children:[
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(m['display_name']?.toString()??'—',style:_AC.t(s:12.5,w:FontWeight.w600)),
                Text(m['email']?.toString()??'',style:_AC.mono(s:9.5,c:_AC.t2),overflow:TextOverflow.ellipsis),
              ])),
              Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                decoration:BoxDecoration(color:(left<0?_AC.red:soon?_AC.gold:_AC.grn).withOpacity(.13),borderRadius:BorderRadius.circular(8)),
                child:Text(left<0?'منتهي':'$left يوم',style:_AC.t(s:10.5,w:FontWeight.w700,c:left<0?_AC.red:soon?_AC.gold:_AC.grn))),
            ])));
        });
    });
}

// ════════════════════════════════════════════════════════════════════════
//  ORDERS
// ════════════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════════════
//  تبويب الشكاوى — يعرض شكاوى المستخدمين (مع الفئة والإيميل والتفاصيل)
// ════════════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════════════
//  تبويب السيرفرات — سحب وتحليل عند الطلب (بلا مستمع دائم)
//  يجمع كل الهوستات التي يتصل بها المستخدمون + عدد المشتركين لكل سيرفر
//  + عدد بيانات الدخول المختلفة (يوزر/باس) لكل هوست.
// ════════════════════════════════════════════════════════════════════════
class _ServerStatsTab extends StatefulWidget {
  const _ServerStatsTab();
  @override State<_ServerStatsTab> createState()=>_ServerStatsTabState();
}
class _ServerStatsTabState extends State<_ServerStatsTab> {
  bool _loading=false; bool _done=false; int _scanned=0; int _premium=0;
  // host → {subs, creds:Set<"user|pass">}
  final Map<String,_HostAgg> _hosts={};
  String _err='';

  Future<void> _scan() async {
    setState((){_loading=true;_done=false;_err='';_hosts.clear();_scanned=0;_premium=0;});
    try{
      // سحب على دفعات (pagination) — بلا مستمع دائم، يقلّل المراسلة
      const pageSize=500;
      DocumentSnapshot? cursor;
      var more=true; var safety=0;
      while(more && safety<200){
        safety++;
        Query<Map<String,dynamic>> q=_AC.db.collection('users')
            .orderBy(FieldPath.documentId).limit(pageSize);
        if(cursor!=null) q=q.startAfterDocument(cursor);
        final snap=await q.get().timeout(const Duration(seconds:20));
        if(snap.docs.isEmpty){more=false;break;}
        for(final d in snap.docs){
          _scanned++;
          final m=d.data();
          final sub=(m['subscription'] as Map?) ?? const {};
          final plan=(sub['plan']??'').toString();
          final host=(sub['host']??sub['server_host']??'').toString().trim();
          final user=(sub['username']??'').toString().trim();
          final pass=(sub['password']??'').toString().trim();
          if(plan=='premium') _premium++;
          if(host.isEmpty||user.isEmpty) continue;
          final agg=_hosts.putIfAbsent(host,()=>_HostAgg());
          agg.subs++;
          agg.creds.add('$user|$pass');
        }
        cursor=snap.docs.last;
        if(mounted) setState((){}); // ★ تحديث العداد مباشرة
        if(snap.docs.length<pageSize){more=false;}
      }
      setState((){_loading=false;_done=true;});
    }catch(e){
      setState((){_loading=false;_err=e.toString();});
    }
  }

  @override
  Widget build(BuildContext context){
    final sorted=_hosts.entries.toList()
      ..sort((a,b)=>b.value.subs.compareTo(a.value.subs));
    return ListView(padding:const EdgeInsets.all(14),children:[
      _acCard('🖥️ تحليل السيرفرات',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('يسحب كل الهوستات التي يتصل بها المستخدمون ويجمّعها — عند الطلب فقط لتقليل المراسلة مع قاعدة البيانات.',
            style:_AC.t(s:11,c:_AC.t2)),
        const SizedBox(height:12),
        _goldBtn(_loading?'جارٍ السحب… ($_scanned)':'🔄 اسحب وحلّل السيرفرات', _loading?(){}:_scan),
      ])),
      if(_err.isNotEmpty)...[
        const SizedBox(height:12),
        Container(padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:_AC.red.withOpacity(.1),borderRadius:BorderRadius.circular(10),
            border:Border.all(color:_AC.red.withOpacity(.3))),
          child:Text('خطأ: $_err',style:_AC.t(s:11,c:_AC.red))),
      ],
      if(_done)...[
        const SizedBox(height:14),
        Row(children:[
          Expanded(child:_statBox('المستخدمون','$_scanned',_AC.blu)),
          const SizedBox(width:10),
          Expanded(child:_statBox('بريميوم','$_premium',_AC.gold)),
          const SizedBox(width:10),
          Expanded(child:_statBox('السيرفرات','${_hosts.length}',_AC.grn)),
        ]),
        const SizedBox(height:14),
        _acSec('السيرفرات حسب عدد المشتركين'),
        if(sorted.isEmpty) Padding(padding:const EdgeInsets.all(10),
          child:Text('لا توجد بيانات سيرفرات لدى المستخدمين',style:_AC.t(c:_AC.t3))),
        ...sorted.map((e)=>_HostCard(host:e.key,agg:e.value)),
      ],
    ]);
  }

  Widget _statBox(String label,String val,Color c)=>Container(
    padding:const EdgeInsets.symmetric(vertical:14),
    decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(12),
      border:Border.all(color:c.withOpacity(.3))),
    child:Column(children:[
      Text(val,style:_AC.t(s:19,w:FontWeight.w900,c:c)),
      const SizedBox(height:3),
      Text(label,style:_AC.t(s:10.5,c:_AC.t2)),
    ]));
}

class _HostAgg { int subs=0; final Set<String> creds={}; }

class _HostCard extends StatelessWidget {
  final String host; final _HostAgg agg;
  const _HostCard({required this.host,required this.agg});
  @override
  Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(12),border:Border.all(color:_AC.bdr)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Icon(Icons.dns_rounded,color:_AC.gold,size:16),
        const SizedBox(width:8),
        Expanded(child:Directionality(textDirection:TextDirection.ltr,
          child:Text(host,style:_AC.mono(s:11.5,c:_AC.tx),maxLines:1,overflow:TextOverflow.ellipsis))),
        GestureDetector(onTap:(){Clipboard.setData(ClipboardData(text:host));Sound.hapticL();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('نُسخ الهوست',style:_AC.t(s:11,c:Colors.black)),
            backgroundColor:_AC.gold,behavior:SnackBarBehavior.floating,duration:const Duration(seconds:1)));},
          child:const Icon(Icons.copy_rounded,size:14,color:_AC.t3)),
      ]),
      const SizedBox(height:11),
      Row(children:[
        _miniStat('👥 المشتركون','${agg.subs}',_AC.blu),
        const SizedBox(width:9),
        _miniStat('🔑 بيانات مختلفة','${agg.creds.length}',_AC.prp),
      ]),
    ]));
  Widget _miniStat(String l,String v,Color c)=>Expanded(child:Container(
    padding:const EdgeInsets.symmetric(vertical:9,horizontal:10),
    decoration:BoxDecoration(color:_AC.bg3,borderRadius:BorderRadius.circular(9)),
    child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      Text(l,style:_AC.t(s:10.5,c:_AC.t2)),
      Text(v,style:_AC.t(s:13,w:FontWeight.w800,c:c)),
    ])));
}

class _ComplaintsTab extends StatelessWidget {
  const _ComplaintsTab();
  @override
  Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
    stream:_AC.db.collection('complaints').orderBy('created',descending:true).limit(100).snapshots(),
    builder:(_,snap){
      if(!snap.hasData) return const Center(child:CircularProgressIndicator(color:_AC.gold));
      final docs=snap.data!.docs;
      if(docs.isEmpty) return Center(child:Text('لا توجد شكاوى',style:_AC.t(c:_AC.t3)));
      return ListView.builder(padding:const EdgeInsets.all(14),itemCount:docs.length,cacheExtent:800,
        itemBuilder:(_,i)=>RepaintBoundary(child:_ComplaintCard(id:docs[i].id,data:docs[i].data() as Map<String,dynamic>)));
    });
}

class _ComplaintCard extends StatelessWidget {
  final String id; final Map<String,dynamic> data;
  const _ComplaintCard({required this.id,required this.data});
  @override
  Widget build(BuildContext context){
    final ticket=data['ticket']?.toString()??id;
    final cat=data['category']?.toString()??'عام';
    final name=data['name']?.toString()??'—';
    final email=data['email']?.toString()??'';
    final body=data['body']?.toString()??'';
    final status=data['status']?.toString()??'open';
    final open=status=='open';
    final catColor=switch(cat){'الدفع'=>_AC.grn,'الجودة'=>_AC.blu,'التفعيل'=>_AC.gold,_=>_AC.prp};
    return Container(margin:const EdgeInsets.only(bottom:11),padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(12),
        border:Border.all(color:open?catColor.withOpacity(.35):_AC.bdr)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:3),
            decoration:BoxDecoration(color:catColor.withOpacity(.14),borderRadius:BorderRadius.circular(20),
              border:Border.all(color:catColor.withOpacity(.4))),
            child:Text(cat,style:_AC.t(s:10.5,w:FontWeight.w800,c:catColor))),
          const Spacer(),
          Text(ticket,style:_AC.mono(s:11,c:_AC.t2)),
        ]),
        const SizedBox(height:10),
        _docRow(context,'الاسم',name),
        if(email.isNotEmpty)_docRow(context,'الإيميل',email),
        const SizedBox(height:8),
        Container(width:double.infinity,padding:const EdgeInsets.all(11),
          decoration:BoxDecoration(color:_AC.bg3,borderRadius:BorderRadius.circular(9),border:Border.all(color:_AC.bdr)),
          child:Text(body,style:_AC.t(s:12.5,c:_AC.tx))),
        const SizedBox(height:10),
        Row(children:[
          if(open)Expanded(child:GestureDetector(
            onTap:()=>_AC.db.collection('complaints').doc(id).update({'status':'resolved','resolved_at':FieldValue.serverTimestamp()}),
            child:Container(height:38,alignment:Alignment.center,
              decoration:BoxDecoration(color:_AC.grn.withOpacity(.14),borderRadius:BorderRadius.circular(9),
                border:Border.all(color:_AC.grn.withOpacity(.4))),
              child:Text('✓ تم الحل',style:_AC.t(s:12,w:FontWeight.w800,c:_AC.grn)))))
          else Expanded(child:Container(height:38,alignment:Alignment.center,
            decoration:BoxDecoration(color:_AC.bg3,borderRadius:BorderRadius.circular(9)),
            child:Text('تم الحل ✓',style:_AC.t(s:12,c:_AC.t2)))),
          const SizedBox(width:8),
          GestureDetector(
            onTap:()=>_AC.db.collection('complaints').doc(id).delete(),
            child:Container(width:42,height:38,alignment:Alignment.center,
              decoration:BoxDecoration(color:_AC.red.withOpacity(.1),borderRadius:BorderRadius.circular(9),
                border:Border.all(color:_AC.red.withOpacity(.3))),
              child:const Icon(Icons.delete_outline_rounded,color:_AC.red,size:18))),
        ]),
      ]));
  }

  Widget _docRow(BuildContext context,String k,String v)=>Padding(padding:const EdgeInsets.only(bottom:5),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(width:78,child:Text(k,style:_AC.t(s:10.5,c:_AC.t2))),
      Expanded(child:Text(v,style:_AC.mono(s:10.5,c:_AC.tx))),
      GestureDetector(onTap:(){Clipboard.setData(ClipboardData(text:v));Sound.hapticL();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('نُسخ: $v',style:_AC.t(s:11,c:Colors.black)),
          backgroundColor:_AC.gold,behavior:SnackBarBehavior.floating,duration:const Duration(seconds:1)));},
        child:const Icon(Icons.copy_rounded,size:13,color:_AC.t3)),
    ]));
}

class _OrdersTab extends StatefulWidget {
  const _OrdersTab();
  @override State<_OrdersTab> createState()=>_OrdersTabState();
}
class _OrdersTabState extends State<_OrdersTab> {
  bool _newest=true;
  String _method=''; // فلتر طريقة الدفع
  String _status=''; // '' كل · pending · activated
  static const _methodFilters=['الكل','FIB','Zain','Qi','واتساب','رصيد آسيا'];

  @override
  Widget build(BuildContext context){
    return Column(children:[
      // شريط الفلاتر
      Container(padding:const EdgeInsets.fromLTRB(12,12,12,8),
        decoration:const BoxDecoration(color:_AC.bg2,border:Border(bottom:BorderSide(color:_AC.bdr))),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            _filterChip(_newest?'⬇ الأحدث':'⬆ الأقدم',true,()=>setState(()=>_newest=!_newest)),
            const SizedBox(width:7),
            _filterChip('قيد الانتظار',_status=='pending',()=>setState(()=>_status=_status=='pending'?'':'pending')),
            const SizedBox(width:7),
            _filterChip('مُفعّل',_status=='activated',()=>setState(()=>_status=_status=='activated'?'':'activated')),
          ]),
          const SizedBox(height:8),
          SizedBox(height:32,child:ListView(scrollDirection:Axis.horizontal,children:[
            for(final mth in _methodFilters)
              Padding(padding:const EdgeInsets.only(left:7),
                child:_filterChip(mth,(mth=='الكل'&&_method=='')||_method==mth,
                  ()=>setState(()=>_method=mth=='الكل'?'':mth))),
          ])),
        ])),
      Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:_AC.db.collection('orders').orderBy('created',descending:_newest).limit(200).snapshots(),
        builder:(_,snap){
          if(!snap.hasData) return const Center(child:CircularProgressIndicator(color:_AC.gold));
          var docs=snap.data!.docs;
          // فلترة العميل: الطريقة + الحالة
          docs=docs.where((d){
            final m=d.data() as Map<String,dynamic>;
            if(_method.isNotEmpty){
              final meth=(m['method']??'').toString().toLowerCase();
              final key=_method.toLowerCase()
                .replaceAll('واتساب','whatsapp').replaceAll('رصيد آسيا','asia');
              if(!meth.contains(key) && !(m['method']??'').toString().contains(_method)) return false;
            }
            if(_status.isNotEmpty){
              final st=(m['status']??'pending').toString();
              if(_status=='activated' && st!='activated' && st!='resolved' && st!='approved') return false;
              if(_status=='pending' && st!='pending') return false;
            }
            return true;
          }).toList();
          if(docs.isEmpty) return Center(child:Text('لا توجد طلبات مطابقة',style:_AC.t(c:_AC.t3)));
          return ListView.builder(padding:const EdgeInsets.all(14),itemCount:docs.length,cacheExtent:800,
            itemBuilder:(_,i)=>RepaintBoundary(child:_OrderCard(id:docs[i].id,data:docs[i].data() as Map<String,dynamic>)));
        })),
    ]);
  }

  Widget _filterChip(String label,bool active,VoidCallback onTap)=>GestureDetector(
    onTap:(){Sound.hapticL();onTap();},
    child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),
      decoration:BoxDecoration(
        color:active?_AC.gold.withOpacity(.16):_AC.bg3,
        borderRadius:BorderRadius.circular(20),
        border:Border.all(color:active?_AC.gold:_AC.bdr,width:active?1.3:1)),
      child:Text(label,style:_AC.t(s:11,w:active?FontWeight.w800:FontWeight.w600,c:active?_AC.gold:_AC.t2))));
}

class _OrderCard extends StatelessWidget {
  final String id; final Map<String,dynamic> data;
  const _OrderCard({required this.id,required this.data});
  @override
  Widget build(BuildContext context){
    final status=data['status']?.toString()??'pending';
    final name=data['name']?.toString()??data['display_name']?.toString()??'—';
    final email=data['email']?.toString()??'';
    final accountName=data['account_name']?.toString()??'';
    final phone=data['phone']?.toString()??'';
    final orderId=data['order_id']?.toString()??id;
    final planT=data['plan_title']?.toString()??data['plan']?.toString()??'';
    final price=data['price']?.toString()??'';
    final method=data['method']?.toString()??'';
    final methodNum=data['method_number']?.toString()??'';
    final receipt=data['receipt_url']?.toString()??'';
    final receiptB64=data['receipt_b64']?.toString()??'';
    final hasReceipt=receipt.isNotEmpty||receiptB64.isNotEmpty;
    final isAsia=data['type']?.toString()=='asiacell';
    final asiaCode=data['asia_card_code']?.toString()??'';
    final asiaAmt=data['asia_amount']?.toString()??'';
    final created=(data['created'] is Timestamp)?(data['created'] as Timestamp).toDate():null;
    final activatedAt=(data['activated_at'] is Timestamp)?(data['activated_at'] as Timestamp).toDate():null;
    final pending=status=='pending';
    final (sc,st)=switch(status){'active'=>(_AC.grn,'مُفعّل ✓'),'rejected'=>(_AC.red,'مرفوض'),_=>(_AC.gold,'بانتظار')};
    return Container(margin:const EdgeInsets.only(bottom:11),padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(12),
        border:Border.all(color:pending?_AC.gold.withOpacity(.3):_AC.bdr)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Container(width:38,height:38,decoration:BoxDecoration(color:_AC.gold.withOpacity(.12),borderRadius:BorderRadius.circular(10)),
            child:Center(child:Text(name.isNotEmpty?name[0]:'?',style:_AC.t(s:16,w:FontWeight.w800,c:_AC.gold)))),
          const SizedBox(width:11),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(name,style:_AC.t(s:13,w:FontWeight.w700)),
            Text(email,style:_AC.mono(s:10,c:_AC.t2),overflow:TextOverflow.ellipsis),
          ])),
          Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),
            decoration:BoxDecoration(color:sc.withOpacity(.13),borderRadius:BorderRadius.circular(8),border:Border.all(color:sc.withOpacity(.3))),
            child:Text(st,style:_AC.t(s:10,w:FontWeight.w800,c:sc))),
        ]),
        const SizedBox(height:11),
        // ── مستند معلومات الطلب (قابل للنسخ) ──
        Container(padding:const EdgeInsets.all(11),
          decoration:BoxDecoration(color:_AC.bg3,borderRadius:BorderRadius.circular(10)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            _docRow(context,'رقم الطلب',orderId),
            _docRow(context,'الإيميل',email),
            if(accountName.isNotEmpty)_docRow(context,'اسم الحساب',accountName),
            _docRow(context,'الاسم',name),
            if(phone.isNotEmpty)_docRow(context,'الهاتف',phone),
            _docRow(context,'طريقة الدفع',method+(methodNum.isNotEmpty?' — $methodNum':'')),
            if(isAsia)...[
              _docRow(context,'🔴 الرقم السري للكرت',asiaCode),
              if(asiaAmt.isNotEmpty)_docRow(context,'قيمة الكرت','$asiaAmt رصيد آسيا'),
            ],
            if(price.isNotEmpty)_docRow(context,'المبلغ','$price${isAsia?' رصيد آسيا':' د.ع'}'),
            _docRow(context,'الباقة',planT),
            _docRow(context,'تاريخ الإرسال',_fmtTs(created)),
            if(activatedAt!=null)_docRow(context,'تاريخ التفعيل',_fmtTs(activatedAt)),
          ])),
        const SizedBox(height:10),
        Wrap(spacing:7,runSpacing:7,children:[
          if(isAsia)_chip('🔴 رصيد آسيا سيل'),
          _chip('📦 $planT'), if(price.isNotEmpty)_chip('💰 $price${isAsia?' رصيد':' د.ع'}'), if(method.isNotEmpty&&!isAsia)_chip('💳 $method'),
        ]),
        if(hasReceipt)...[
          const SizedBox(height:12),
          Row(children:[
            const Icon(Icons.attach_file_rounded,color:_AC.grn,size:14),
            const SizedBox(width:5),
            Text('صورة الإيصال — اضغط للتكبير والتحقق',style:_AC.t(s:11,w:FontWeight.w700,c:_AC.grn)),
          ]),
          const SizedBox(height:7),
          Builder(builder:(_){
            final full = receiptB64.isNotEmpty
              ? Image.memory(base64Decode(receiptB64),fit:BoxFit.contain)
              : Image.network(receipt,fit:BoxFit.contain);
            final thumb = receiptB64.isNotEmpty
              ? Image.memory(base64Decode(receiptB64),height:150,width:double.infinity,fit:BoxFit.cover,
                  errorBuilder:(_,__,___)=>Container(height:70,color:_AC.bg3,child:Center(child:Text('تعذّر عرض الإيصال',style:_AC.t(s:11,c:_AC.t3)))))
              : Image.network(receipt,height:150,width:double.infinity,fit:BoxFit.cover,
                  loadingBuilder:(_,c,p)=>p==null?c:Container(height:150,color:_AC.bg3,child:const Center(child:CircularProgressIndicator(strokeWidth:2,color:_AC.gold))),
                  errorBuilder:(_,__,___)=>Container(height:70,color:_AC.bg3,child:Center(child:Text('تعذّر تحميل الإيصال',style:_AC.t(s:11,c:_AC.t3)))));
            return GestureDetector(onTap:()=>showDialog(context:context,builder:(_)=>Dialog(backgroundColor:Colors.transparent,
              insetPadding:const EdgeInsets.all(12),
              child:Stack(children:[
                InteractiveViewer(minScale:0.5,maxScale:5,child:ClipRRect(borderRadius:BorderRadius.circular(12),child:full)),
                Positioned(top:8,right:8,child:GestureDetector(onTap:()=>Navigator.pop(context),
                  child:Container(padding:const EdgeInsets.all(7),decoration:const BoxDecoration(color:Colors.black54,shape:BoxShape.circle),
                    child:const Icon(Icons.close_rounded,color:Colors.white,size:20)))),
              ]))),
              child:ClipRRect(borderRadius:BorderRadius.circular(10),
                child:Stack(children:[thumb,
                  Positioned(bottom:6,right:6,child:Container(padding:const EdgeInsets.all(5),
                    decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(7)),
                    child:const Icon(Icons.zoom_in_rounded,color:Colors.white,size:16))),
                ])));
          }),
        ] else ...[
          const SizedBox(height:10),
          Container(width:double.infinity,padding:const EdgeInsets.symmetric(vertical:9,horizontal:11),
            decoration:BoxDecoration(color:_AC.org.withOpacity(.1),borderRadius:BorderRadius.circular(9),
              border:Border.all(color:_AC.org.withOpacity(.35))),
            child:Row(children:[
              const Icon(Icons.warning_amber_rounded,color:_AC.org,size:15),
              const SizedBox(width:7),
              Expanded(child:Text('لا يوجد إيصال مرفق — تحقّق عبر واتساب قبل التفعيل',
                style:_AC.t(s:11,c:_AC.org))),
            ])),
        ],
        if(pending)...[
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:_btn('⚡ تفعيل فوري',_AC.gold,Colors.black,(){
              _ActivateSheet.show(context,uid:data['uid']?.toString()??'',email:email,name:name,
                presetDays:{'monthly':30,'quarterly':90,'yearly':365}[data['plan']?.toString()]??30,orderId:id);
            })),
            const SizedBox(width:9),
            _btn('✕',_AC.red.withOpacity(.12),_AC.red,()async{
              await _AC.db.collection('orders').doc(id).update({'status':'rejected','updated_at':FieldValue.serverTimestamp()});
              _toast(context,'تم رفض الطلب');
            },w:46),
          ]),
        ],
      ]));
  }
  String _fmtTs(DateTime? d){
    if(d==null) return '—';
    final l=d.toLocal();
    String two(int x)=>x.toString().padLeft(2,'0');
    return '${l.year}/${two(l.month)}/${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
  Widget _docRow(BuildContext context,String k,String v)=>Padding(padding:const EdgeInsets.only(bottom:5),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(width:78,child:Text(k,style:_AC.t(s:10.5,c:_AC.t2))),
      Expanded(child:Text(v,style:_AC.mono(s:10.5,c:_AC.tx))),
      GestureDetector(onTap:(){Clipboard.setData(ClipboardData(text:v));Sound.hapticL();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('نُسخ: $v',style:_AC.t(s:11,c:Colors.black)),
          backgroundColor:_AC.gold,behavior:SnackBarBehavior.floating,duration:const Duration(seconds:1)));},
        child:const Icon(Icons.copy_rounded,size:13,color:_AC.t3)),
    ]));
  Widget _chip(String t)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
    decoration:BoxDecoration(color:_AC.bg3,borderRadius:BorderRadius.circular(8)),child:Text(t,style:_AC.t(s:10.5)));
  Widget _btn(String t,Color bg,Color fg,VoidCallback onTap,{double? w})=>GestureDetector(
    onTap:(){Sound.hapticM();onTap();},
    child:Container(width:w,height:42,alignment:Alignment.center,
      decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(10)),
      child:Text(t,style:_AC.t(s:12.5,w:FontWeight.w800,c:fg))));
}

// ════════════════════════════════════════════════════════════════════════
//  REMOTE CONTROL
// ════════════════════════════════════════════════════════════════════════
class _RemoteTab extends StatelessWidget {
  const _RemoteTab();
  @override
  Widget build(BuildContext context)=>StreamBuilder<DocumentSnapshot>(
    stream:_AC.db.collection('app_config').doc('remote_control').snapshots(),
    builder:(_,snap){
      final d=(snap.data?.data() as Map<String,dynamic>?)??{};
      return ListView(padding:const EdgeInsets.all(14),children:[
        _acCard('🎮 التحكم عن بعد',Column(children:[
          _toggle('الصيانة','إيقاف التطبيق مؤقتاً',d['maintenance']==true,(v)=>_set('maintenance',v)),
          _toggle('قفل التطبيق','منع الدخول',d['locked']==true,(v)=>_set('locked',v)),
          _toggle('وضع الضيف فقط','منع الحسابات',d['guest_only']==true,(v)=>_set('guest_only',v)),
        ])),
        const SizedBox(height:14),
        const _RemoteMsgsCard(),
        const SizedBox(height:14),
        const _AppConfigCard(),
      ]);
    });
  Widget _toggle(String t,String s,bool v,ValueChanged<bool> on)=>Padding(padding:const EdgeInsets.only(bottom:6),
    child:Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(t,style:_AC.t(s:13,w:FontWeight.w600)),Text(s,style:_AC.t(s:10.5,c:_AC.t2))])),
      Switch(value:v,activeColor:_AC.gold,onChanged:(nv){Sound.hapticL();on(nv);}),
    ]));
  void _set(String k,dynamic val)=>_AC.db.collection('app_config').doc('remote_control')
    .set({k:val,'updated_at':FieldValue.serverTimestamp()},SetOptions(merge:true));
}

class _RemoteMsgsCard extends StatefulWidget { const _RemoteMsgsCard(); @override State<_RemoteMsgsCard> createState()=>_RemoteMsgsCardState(); }
class _RemoteMsgsCardState extends State<_RemoteMsgsCard> {
  final _maint=TextEditingController(),_lock=TextEditingController(); bool _loaded=false;
  @override void dispose(){_maint.dispose();_lock.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    if(!_loaded){_loaded=true; _AC.db.collection('app_config').doc('remote_control').get().then((s){
      final d=s.data()??{}; _maint.text=d['maint_msg']?.toString()??''; _lock.text=d['lock_msg']?.toString()??''; if(mounted)setState((){});
    });}
    return _acCard('💬 الرسائل',Column(children:[
      _ConsoleField(controller:_maint,hint:'رسالة الصيانة...'),const SizedBox(height:8),
      _ConsoleField(controller:_lock,hint:'رسالة القفل...'),const SizedBox(height:12),
      _goldBtn('💾 حفظ الرسائل',()async{
        await _AC.db.collection('app_config').doc('remote_control').set(
          {'maint_msg':_maint.text.trim(),'lock_msg':_lock.text.trim(),'updated_at':FieldValue.serverTimestamp()},SetOptions(merge:true));
        if(mounted)_toast(context,'✅ حُفظت');
      }),
    ]));
  }
}

// ── إعدادات التطبيق الكاملة: السيرفر الافتراضي + السوبر كي + الدعم ──
class _AppConfigCard extends StatefulWidget { const _AppConfigCard(); @override State<_AppConfigCard> createState()=>_AppConfigCardState(); }
class _AppConfigCardState extends State<_AppConfigCard> {
  final _host=TextEditingController(),_user=TextEditingController(),_pass=TextEditingController();
  final _wa=TextEditingController(),_tg=TextEditingController(),_buy=TextEditingController(),_superKey=TextEditingController();
  bool _loaded=false;
  @override void dispose(){for(final c in [_host,_user,_pass,_wa,_tg,_buy,_superKey])c.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    if(!_loaded){_loaded=true; _AC.db.collection('app_config').doc('remote_config').get().then((s){
      final d=s.data()??{};
      _host.text=d['default_server_host']?.toString()??'';
      _user.text=d['username']?.toString()??'';
      _pass.text=d['password']?.toString()??'';
      _wa.text=d['whatsapp']?.toString()??'';
      _tg.text=d['telegram']?.toString()??'';
      _buy.text=d['buy_url']?.toString()??'';
      _superKey.text=d['super_key']?.toString()??'';
      if(mounted)setState((){});
    });}
    return _acCard('🛠 إعدادات التطبيق', Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _lbl('السيرفر الافتراضي (للحسابات الجديدة)'),
      _ConsoleField(controller:_host,hint:'http://server.com:8080',ltr:true),const SizedBox(height:7),
      _ConsoleField(controller:_user,hint:'username',ltr:true),const SizedBox(height:7),
      _ConsoleField(controller:_pass,hint:'password',ltr:true),const SizedBox(height:12),
      _lbl('السوبر كي (مفتاح الوصول السرّي)'),
      _ConsoleField(controller:_superKey,hint:'super_key',ltr:true),const SizedBox(height:12),
      _lbl('أرقام التواصل والروابط'),
      _ConsoleField(controller:_wa,hint:'واتساب الدعم: 9647xxxxxxxxx',ltr:true),const SizedBox(height:7),
      _ConsoleField(controller:_tg,hint:'قناة/معرّف تلجرام',ltr:true),const SizedBox(height:7),
      _ConsoleField(controller:_buy,hint:'رابط الشراء (اختياري)',ltr:true),const SizedBox(height:14),
      _goldBtn('💾 حفظ كل الإعدادات',()async{
        await _AC.db.collection('app_config').doc('remote_config').set({
          'default_server_host':_host.text.trim(),'username':_user.text.trim(),'password':_pass.text.trim(),
          'whatsapp':_wa.text.trim(),'telegram':_tg.text.trim(),'buy_url':_buy.text.trim(),
          'super_key':_superKey.text.trim(),'updated_at':FieldValue.serverTimestamp(),
        },SetOptions(merge:true));
        if(mounted)_toast(context,'✅ حُفظت كل الإعدادات');
      }),
    ]));
  }
  Widget _lbl(String t)=>Padding(padding:const EdgeInsets.only(bottom:7,top:2),
    child:Text(t,style:_AC.t(s:11,w:FontWeight.w700,c:_AC.gold)));
}

// ════════════════════════════════════════════════════════════════════════
//  VERSION
// ════════════════════════════════════════════════════════════════════════
class _VersionTab extends StatefulWidget { const _VersionTab(); @override State<_VersionTab> createState()=>_VersionTabState(); }
class _VersionTabState extends State<_VersionTab> {
  final _min=TextEditingController(),_url=TextEditingController(),_msg=TextEditingController();
  bool _force=false,_loaded=false;
  @override void dispose(){_min.dispose();_url.dispose();_msg.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    if(!_loaded){_loaded=true; _AC.db.collection('app_config').doc('version').get().then((s){
      final d=s.data()??{}; _min.text='${d['min_version']??1}'; _url.text=d['store_url']?.toString()??'';
      _msg.text=d['update_msg']?.toString()??''; _force=d['force_update']==true; if(mounted)setState((){});
    });}
    return ListView(padding:const EdgeInsets.all(14),children:[
      _acCard('🚀 الإصدارات',Column(children:[
        _ConsoleField(controller:_min,hint:'أدنى إصدار مطلوب (رقم)',ltr:true),const SizedBox(height:8),
        _ConsoleField(controller:_url,hint:'رابط التحديث https://...',ltr:true),const SizedBox(height:8),
        _ConsoleField(controller:_msg,hint:'رسالة التحديث'),const SizedBox(height:8),
        Row(children:[
          Expanded(child:Text('تحديث إجباري',style:_AC.t(s:13,w:FontWeight.w600))),
          Switch(value:_force,activeColor:_AC.gold,onChanged:(v){Sound.hapticL();setState(()=>_force=v);}),
        ]),
        const SizedBox(height:6),
        _goldBtn('💾 حفظ الإصدار',()async{
          await _AC.db.collection('app_config').doc('version').set({
            'min_version':int.tryParse(_min.text)??1,'store_url':_url.text.trim(),
            'update_msg':_msg.text.trim(),'force_update':_force,'updated_at':FieldValue.serverTimestamp()},SetOptions(merge:true));
          if(mounted)_toast(context,'✅ حُفظ');
        }),
      ])),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════
//  NOTIFICATIONS
// ════════════════════════════════════════════════════════════════════════
class _NotifTab extends StatefulWidget { const _NotifTab(); @override State<_NotifTab> createState()=>_NotifTabState(); }
class _NotifTabState extends State<_NotifTab> {
  final _title=TextEditingController(),_body=TextEditingController();
  @override void dispose(){_title.dispose();_body.dispose();super.dispose();}

  // قوالب احترافية جاهزة
  static const _templates = <(String,String)>[
    ('🎬 أفلام جديدة','أضفنا أحدث الأفلام والمسلسلات — شاهدها الآن على TOTV+!'),
    ('🔥 محتوى مميّز','لا تفوّت الإضافات الحصرية هذا الأسبوع على TOTV+'),
    ('⏰ تذكير','هل شاهدت الجديد اليوم؟ افتح التطبيق واستمتع!'),
    ('💎 جدّد اشتراكك','اشتراكك يقترب من الانتهاء — جدّد الآن لتبقى متصلاً.'),
    ('🎉 عرض خاص','عرض لفترة محدودة على باقات TOTV+ — اشترك الآن ووفّر!'),
  ];

  Future<void> _send(String title, String body) async {
    if(title.trim().isEmpty||body.trim().isEmpty){_toast(context,'⚠ العنوان والنص مطلوبان');return;}
    // الكتابة في notifications → Cloud Function تدفعها لكل الأجهزة فوراً
    await _AC.db.collection('notifications').add({
      'title':title.trim(),'body':body.trim(),'target':'all','active':true,
      'pushed':false,'sent_at':FieldValue.serverTimestamp()});
    _AC.tg('📡 *إشعار جديد*\n*${title.trim()}*\n${body.trim()}');
    if(mounted)_toast(context,'📡 أُرسل — سيصل لكل الأجهزة');
  }

  @override
  Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(14),children:[
    _acCard('🔔 إرسال إشعار فوري',Column(children:[
      _ConsoleField(controller:_title,hint:'عنوان الإشعار'),const SizedBox(height:8),
      _ConsoleField(controller:_body,hint:'نص الإشعار...'),const SizedBox(height:12),
      _goldBtn('📡 إرسال للجميع',()async{ await _send(_title.text,_body.text); _title.clear();_body.clear(); }),
    ])),
    const SizedBox(height:14),
    _acCard('⚡ قوالب جاهزة (اضغط للإرسال)',Column(children:_templates.map((t)=>Padding(
      padding:const EdgeInsets.only(bottom:8),
      child:GestureDetector(onTap:()=>_send(t.$1,t.$2),
        child:Container(width:double.infinity,padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:_AC.bg3,borderRadius:BorderRadius.circular(10),border:Border.all(color:_AC.bdr)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(t.$1,style:_AC.t(s:12.5,w:FontWeight.w700,c:_AC.gold)),
            Text(t.$2,style:_AC.t(s:10.5,c:_AC.t2)),
          ]))))).toList())),
    const SizedBox(height:14),
    const _DailyMsgCard(),
    const SizedBox(height:14),
    _acSec('السجل'),
    StreamBuilder<QuerySnapshot>(stream:_AC.db.collection('notifications').orderBy('sent_at',descending:true).limit(20).snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        if(docs.isEmpty) return Padding(padding:const EdgeInsets.all(10),child:Text('لا إشعارات',style:_AC.t(c:_AC.t3)));
        return Column(children:docs.map((d){
          final m=d.data() as Map<String,dynamic>;
          final pushed=m['pushed']==true;
          return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(11),border:Border.all(color:_AC.bdr)),
            child:Row(children:[
              Icon(pushed?Icons.check_circle_rounded:Icons.schedule_rounded,size:15,color:pushed?_AC.grn:_AC.t3),
              const SizedBox(width:9),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(m['title']?.toString()??'',style:_AC.t(s:12.5,w:FontWeight.w700)),
                Text(m['body']?.toString()??'',style:_AC.t(s:11,c:_AC.t2)),
              ])),
              GestureDetector(onTap:()async{await _AC.db.collection('notifications').doc(d.id).delete();if(context.mounted)_toast(context,'🗑');},
                child:const Icon(Icons.delete_outline_rounded,color:_AC.red,size:20)),
            ]));
        }).toList());
      }),
  ]);
}

// رسالة يومية مجدولة (تقرؤها Cloud Function dailyMessage)
class _DailyMsgCard extends StatefulWidget { const _DailyMsgCard(); @override State<_DailyMsgCard> createState()=>_DailyMsgCardState(); }
class _DailyMsgCardState extends State<_DailyMsgCard> {
  final _title=TextEditingController(),_body=TextEditingController();
  bool _enabled=false,_loaded=false;
  @override void dispose(){_title.dispose();_body.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    if(!_loaded){_loaded=true; _AC.db.collection('app_config').doc('daily_message').get().then((s){
      final d=s.data()??{}; _title.text=d['title']?.toString()??'TOTV+'; _body.text=d['body']?.toString()??'';
      _enabled=d['enabled']==true; if(mounted)setState((){});
    });}
    return _acCard('📅 الرسالة اليومية (تلقائية 7 مساءً)',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        Expanded(child:Text('تفعيل الإرسال اليومي',style:_AC.t(s:12.5,w:FontWeight.w600))),
        Switch(value:_enabled,activeColor:_AC.gold,onChanged:(v){Sound.hapticL();setState(()=>_enabled=v);}),
      ]),
      const SizedBox(height:8),
      _ConsoleField(controller:_title,hint:'عنوان الرسالة اليومية'),const SizedBox(height:8),
      _ConsoleField(controller:_body,hint:'نص الرسالة اليومية...'),const SizedBox(height:12),
      _goldBtn('💾 حفظ الرسالة اليومية',()async{
        await _AC.db.collection('app_config').doc('daily_message').set({
          'enabled':_enabled,'title':_title.text.trim(),'body':_body.text.trim(),
          'updated_at':FieldValue.serverTimestamp()},SetOptions(merge:true));
        if(mounted)_toast(context,'✅ حُفظت');
      }),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════════
//  BANNED
// ════════════════════════════════════════════════════════════════════════
class _BannedTab extends StatelessWidget {
  const _BannedTab();
  @override
  Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
    stream:_AC.db.collection('users').where('status',isEqualTo:'banned').limit(200).snapshots(),
    builder:(_,snap){
      if(!snap.hasData) return const Center(child:CircularProgressIndicator(color:_AC.gold));
      final docs=snap.data!.docs;
      if(docs.isEmpty) return Center(child:Text('لا مستخدمين محظورين',style:_AC.t(c:_AC.t3)));
      return ListView.builder(padding:const EdgeInsets.all(14),itemCount:docs.length,
        itemBuilder:(_,i){
          final m=docs[i].data() as Map<String,dynamic>;
          return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(11),border:Border.all(color:_AC.red.withOpacity(.3))),
            child:Row(children:[
              const Icon(Icons.block_rounded,color:_AC.red,size:20),const SizedBox(width:11),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(m['display_name']?.toString()??'—',style:_AC.t(s:12.5,w:FontWeight.w600)),
                Text(m['email']?.toString()??docs[i].id,style:_AC.mono(s:9.5,c:_AC.t2),overflow:TextOverflow.ellipsis),
              ])),
              GestureDetector(onTap:()async{
                await _AC.db.collection('users').doc(docs[i].id).update({'status':'active','updated_at':FieldValue.serverTimestamp()});
                _AC.tg('✅ رفع حظر\n`${docs[i].id}`'); if(context.mounted)_toast(context,'✅ رُفع الحظر');
              },child:Container(padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
                decoration:BoxDecoration(color:_AC.grn.withOpacity(.12),borderRadius:BorderRadius.circular(8),border:Border.all(color:_AC.grn.withOpacity(.3))),
                child:Text('رفع الحظر',style:_AC.t(s:11,w:FontWeight.w700,c:_AC.grn)))),
            ]));
        });
    });
}

// ════════════════════════════════════════════════════════════════════════
//  CONFIG
// ════════════════════════════════════════════════════════════════════════
class _ConfigTab extends StatefulWidget { const _ConfigTab(); @override State<_ConfigTab> createState()=>_ConfigTabState(); }
class _ConfigTabState extends State<_ConfigTab> {
  final _bot=TextEditingController(),_chat=TextEditingController(); bool _loaded=false;
  @override void dispose(){_bot.dispose();_chat.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    if(!_loaded){_loaded=true; _AC.db.collection('app_config').doc('settings').get().then((s){
      final d=s.data()??{}; _bot.text=d['tg_bot']?.toString()??''; _chat.text=d['tg_chat']?.toString()??''; if(mounted)setState((){});
    });}
    return ListView(padding:const EdgeInsets.all(14),children:[
      const _PaymentNumbersCard(),
      const SizedBox(height:12),
      _acCard('🤖 إشعارات تلجرام',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('يُخزَّن في app_config/settings (وليس في كود التطبيق) — أكثر أماناً.',style:_AC.t(s:10.5,c:_AC.t2)),
        const SizedBox(height:10),
        _ConsoleField(controller:_bot,hint:'bot_token',ltr:true),const SizedBox(height:8),
        _ConsoleField(controller:_chat,hint:'chat_id',ltr:true),const SizedBox(height:12),
        _goldBtn('💾 حفظ',()async{
          await _AC.db.collection('app_config').doc('settings').set(
            {'tg_bot':_bot.text.trim(),'tg_chat':_chat.text.trim(),'updated_at':FieldValue.serverTimestamp()},SetOptions(merge:true));
          if(mounted)_toast(context,'✅ حُفظ');
        }),
      ])),
      const SizedBox(height:12),
      _acCard('ℹ️ معلومات',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _kv('الأدمن',_AC.adminEmail), _kv('النسخة','TOTV+ Admin (in-app)'),
      ])),
    ]);
  }
  Widget _kv(String k,String v)=>Padding(padding:const EdgeInsets.only(bottom:8),
    child:Row(children:[Text('$k: ',style:_AC.t(s:11.5,c:_AC.t2)),
      Expanded(child:Text(v,style:_AC.mono(s:10.5),overflow:TextOverflow.ellipsis))]));
}

// ── بطاقة أرقام الدفع — تُحفظ في app_config/payment_numbers ──────────────
class _PaymentNumbersCard extends StatefulWidget {
  const _PaymentNumbersCard();
  @override State<_PaymentNumbersCard> createState()=>_PaymentNumbersCardState();
}
class _PaymentNumbersCardState extends State<_PaymentNumbersCard> {
  final _fibNum=TextEditingController(),_fibName=TextEditingController();
  final _zainNum=TextEditingController(),_zainName=TextEditingController();
  final _qiNum=TextEditingController(),_qiName=TextEditingController();
  bool _loaded=false;
  @override void dispose(){for(final c in [_fibNum,_fibName,_zainNum,_zainName,_qiNum,_qiName])c.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    if(!_loaded){_loaded=true; _AC.db.collection('app_config').doc('payment_numbers').get().then((s){
      final d=s.data()??{};
      Map g(String k)=>(d[k] as Map?)??{};
      _fibNum.text=g('fib')['number']?.toString()??''; _fibName.text=g('fib')['name']?.toString()??'';
      _zainNum.text=g('zain')['number']?.toString()??''; _zainName.text=g('zain')['name']?.toString()??'';
      _qiNum.text=g('qi')['number']?.toString()??''; _qiName.text=g('qi')['name']?.toString()??'';
      if(mounted)setState((){});
    });}
    return _acCard('💳 أرقام الدفع (تظهر للمستخدم فوراً)',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _payLbl('FIB'),
      _ConsoleField(controller:_fibNum,hint:'رقم حساب FIB',ltr:true),const SizedBox(height:6),
      _ConsoleField(controller:_fibName,hint:'اسم صاحب الحساب'),const SizedBox(height:12),
      _payLbl('Zain Cash'),
      _ConsoleField(controller:_zainNum,hint:'رقم زين كاش',ltr:true),const SizedBox(height:6),
      _ConsoleField(controller:_zainName,hint:'اسم صاحب الحساب'),const SizedBox(height:12),
      _payLbl('Qi Card'),
      _ConsoleField(controller:_qiNum,hint:'رقم بطاقة كي',ltr:true),const SizedBox(height:6),
      _ConsoleField(controller:_qiName,hint:'اسم صاحب الحساب'),const SizedBox(height:14),
      _goldBtn('💾 حفظ أرقام الدفع',()async{
        await _AC.db.collection('app_config').doc('payment_numbers').set({
          'fib':{'number':_fibNum.text.trim(),'name':_fibName.text.trim()},
          'zain':{'number':_zainNum.text.trim(),'name':_zainName.text.trim()},
          'qi':{'number':_qiNum.text.trim(),'name':_qiName.text.trim()},
          'updated_at':FieldValue.serverTimestamp(),
        },SetOptions(merge:true));
        if(mounted)_toast(context,'✅ حُفظت أرقام الدفع');
      }),
    ]));
  }
  Widget _payLbl(String t)=>Padding(padding:const EdgeInsets.only(bottom:7),
    child:Text(t,style:_AC.t(s:12,w:FontWeight.w800,c:_AC.gold)));
}

// ════════════════════════════════════════════════════════════════════════
//  مشترَكات
// ════════════════════════════════════════════════════════════════════════
class _AccessDenied extends StatelessWidget {
  const _AccessDenied();
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:_AC.bg,
    body:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      const Icon(Icons.lock_rounded,color:_AC.red,size:44),const SizedBox(height:14),
      Text('وصول مرفوض',style:_AC.t(s:16,w:FontWeight.w800)),const SizedBox(height:6),
      Text('هذه الصفحة لحساب الأدمن فقط',style:_AC.t(s:12,c:_AC.t2)),const SizedBox(height:18),
      GestureDetector(onTap:()=>Navigator.maybePop(context),
        child:Container(padding:const EdgeInsets.symmetric(horizontal:22,vertical:11),
          decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(10),border:Border.all(color:_AC.bdr)),
          child:Text('رجوع',style:_AC.t(s:13,c:_AC.tx)))),
    ])));
}

class _ConsoleField extends StatelessWidget {
  final TextEditingController controller; final String hint; final IconData? icon;
  final bool ltr; final ValueChanged<String>? onChanged;
  const _ConsoleField({required this.controller,required this.hint,this.icon,this.ltr=false,this.onChanged});
  @override
  Widget build(BuildContext context)=>TextField(
    controller:controller,onChanged:onChanged,textDirection:ltr?TextDirection.ltr:null,style:_AC.t(s:13),
    decoration:InputDecoration(hintText:hint,hintStyle:_AC.t(s:12.5,c:_AC.t3),
      prefixIcon:icon!=null?Icon(icon,size:18,color:_AC.t3):null,filled:true,fillColor:_AC.bg3,
      contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
      enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(9),borderSide:const BorderSide(color:_AC.bdr)),
      focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(9),borderSide:const BorderSide(color:_AC.gold3,width:1.2))));
}

Widget _acCard(String title,Widget child)=>Container(padding:const EdgeInsets.all(15),
  decoration:BoxDecoration(color:_AC.card,borderRadius:BorderRadius.circular(12),border:Border.all(color:_AC.bdr)),
  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:_AC.t(s:13,w:FontWeight.w700,c:_AC.gold)),const SizedBox(height:12),child]));

Widget _acSec(String t)=>Padding(padding:const EdgeInsets.only(right:2,bottom:10),
  child:Text(t,style:_AC.t(s:12,w:FontWeight.w700,c:_AC.t2)));

Widget _goldBtn(String t,VoidCallback onTap)=>GestureDetector(onTap:(){Sound.hapticM();onTap();},
  child:Container(width:double.infinity,height:46,alignment:Alignment.center,
    decoration:BoxDecoration(gradient:const LinearGradient(colors:[_AC.gold2,_AC.gold3]),borderRadius:BorderRadius.circular(10)),
    child:Text(t,style:_AC.t(s:13,w:FontWeight.w800,c:Colors.black))));

void _toast(BuildContext ctx,String msg)=>ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
  content:Text(msg,style:_AC.t(s:12,c:Colors.black)),backgroundColor:_AC.gold,
  behavior:SnackBarBehavior.floating,duration:const Duration(seconds:2)));
