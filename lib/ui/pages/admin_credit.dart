part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — نظام الرصيد (Credit / Servers)
//  ────────────────────────────────────────────────────────────────────────
//  القاعدة:
//   • كل سيرفر (host+user+pass) = وحدة رصيد = نقطتان (slots = 2).
//   • كل تفعيل يستهلك نقطة واحدة (used += 1) ويُسند بيانات السيرفر للمشترك.
//   • عند used == 2 → status = 'full' (يبقى أرشيفاً، المشتركان يعملان، لا يقبل جدداً).
//   • التخصيص داخل transaction = لا تعارض حتى مع تفعيلين متزامنين.
//
//  مجموعة Firestore:  servers/{id}
//   { name, host, username, password, slots:2, used:0,
//     status:'available'|'full', assignments:[{uid,email,at}],
//     priority, created_at }
//
//  التركيب:  part 'ui/pages/admin_credit.dart';  (في main.dart)
//  يُستدعى تلقائياً من تبويب «الرصيد» في AdminConsolePage.
// ════════════════════════════════════════════════════════════════════════

class _CreditEngine {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String,dynamic>> get _col => _db.collection('servers');

  /// يخصّص نقطة من أول سيرفر متاح (داخل transaction) ويعيد بياناته.
  /// يرمي استثناءً إذا لا يوجد رصيد.
  static Future<Map<String,String>> allocate({required String uid, required String email}) async {
    // استعلام بسيط (بلا orderBy) — لا يحتاج فهرساً مركّباً، ثم نرتّب محلياً
    final snapAll = await _col.where('status', isEqualTo: 'available').limit(25).get();
    final cands = snapAll.docs.toList()
      ..sort((a, b) {
        final pa = (a.data()['priority'] as num?)?.toInt() ?? 1;
        final pb = (b.data()['priority'] as num?)?.toInt() ?? 1;
        return pa.compareTo(pb);
      });
    if (cands.isEmpty) throw 'لا يوجد رصيد متاح — أضف سيرفرات جديدة';

    for (final cand in cands) {
      final ref = cand.reference;
      try {
        final result = await _db.runTransaction<Map<String,String>?>((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists) return null;
          final m = snap.data()!;
          final slots = (m['slots'] as num?)?.toInt() ?? 2;
          final used  = (m['used']  as num?)?.toInt() ?? 0;
          if (used >= slots) return null; // امتلأ بين القراءتين — جرّب التالي
          final assignments = List<Map<String,dynamic>>.from(m['assignments'] ?? []);
          assignments.add({'uid': uid, 'email': email, 'at': Timestamp.now()});
          final newUsed = used + 1;
          tx.update(ref, {
            'used': newUsed,
            'assignments': assignments,
            'status': newUsed >= slots ? 'full' : 'available',
            'updated_at': FieldValue.serverTimestamp(),
          });
          return {
            'host': (m['host'] ?? '').toString(),
            'username': (m['username'] ?? '').toString(),
            'password': (m['password'] ?? '').toString(),
            'server_id': ref.id,
            'server_name': (m['name'] ?? '').toString(),
          };
        });
        if (result != null) return result; // نجح التخصيص
      } catch (_) { /* جرّب المرشّح التالي */ }
    }
    throw 'تعذّر التخصيص — حاول مجدداً';
  }

  /// يحرّر نقطة (عند إلغاء/إيقاف اشتراك) ويعيد السيرفر إلى available.
  static Future<void> release({required String serverId, required String uid}) async {
    final ref = _col.doc(serverId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final m = snap.data()!;
      final assignments = List<Map<String,dynamic>>.from(m['assignments'] ?? [])
          ..removeWhere((a) => a['uid'] == uid);
      tx.update(ref, {
        'used': assignments.length,
        'assignments': assignments,
        'status': 'available',
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  /// إضافة سيرفر واحد.
  static Future<void> addOne({required String name, required String host,
      required String user, required String pass, int priority = 1}) =>
    _col.add({
      'name': name, 'host': host, 'username': user, 'password': pass,
      'slots': 2, 'used': 0, 'status': 'available', 'assignments': [],
      'priority': priority, 'created_at': FieldValue.serverTimestamp(),
    });

  /// إضافة دفعة (bulk) — كل سطر: host,user,pass  أو  host|user|pass
  static Future<int> addBulk(String raw) async {
    final lines = raw.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty);
    final batch = _db.batch(); int n = 0;
    for (final line in lines) {
      final parts = line.split(RegExp(r'[,|\t]')).map((e)=>e.trim()).toList();
      if (parts.length < 3) continue;
      batch.set(_col.doc(), {
        'name': parts.length > 3 ? parts[3] : 'سيرفر ${n+1}',
        'host': parts[0], 'username': parts[1], 'password': parts[2],
        'slots': 2, 'used': 0, 'status': 'available', 'assignments': [],
        'priority': 1, 'created_at': FieldValue.serverTimestamp(),
      });
      n++;
      if (n % 400 == 0) { await batch.commit(); } // حد الدفعة
    }
    if (n % 400 != 0) await batch.commit();
    return n;
  }
}

// ════════════════════════════════════════════════════════════════════════
//  تبويب الرصيد — إحصاءات + إضافة (مفرد/دفعة) + قائمة السيرفرات
// ════════════════════════════════════════════════════════════════════════
class _CreditTab extends StatelessWidget {
  const _CreditTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _CreditEngine._col.orderBy('created_at', descending: true).limit(300).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        int totalSlots=0, usedSlots=0, fullCount=0, availCount=0;
        for (final d in docs) {
          final m = d.data() as Map<String,dynamic>;
          final slots=(m['slots'] as num?)?.toInt()??2;
          final used =(m['used']  as num?)?.toInt()??0;
          totalSlots+=slots; usedSlots+=used;
          if((m['status']?.toString()??'available')=='full') fullCount++; else availCount++;
        }
        final freeSlots = totalSlots - usedSlots;
        return ListView(padding: const EdgeInsets.all(14), children: [
          // إحصاءات الرصيد
          Row(children: [
            Expanded(child: _creditStat('الرصيد المتاح','$freeSlots', 'نقطة', _AC.grn, big:true)),
            const SizedBox(width:10),
            Expanded(child: _creditStat('مستهلك','$usedSlots','نقطة',_AC.org)),
          ]),
          const SizedBox(height:10),
          Row(children: [
            Expanded(child: _creditStat('سيرفرات متاحة','$availCount','',_AC.gold)),
            const SizedBox(width:10),
            Expanded(child: _creditStat('ممتلئة','$fullCount','',_AC.t2)),
            const SizedBox(width:10),
            Expanded(child: _creditStat('إجمالي','${docs.length}','',_AC.blu)),
          ]),
          const SizedBox(height:8),
          // شريط الاستهلاك
          _usageBar(usedSlots, totalSlots),
          const SizedBox(height:14),
          _addServersCard(context),
          const SizedBox(height:14),
          _acSec('السيرفرات (${docs.length})'),
          if (docs.isEmpty)
            Padding(padding: const EdgeInsets.all(12),
              child: Text('لا سيرفرات — أضف رصيداً بالأعلى', style: _AC.t(c:_AC.t3)))
          else
            ...docs.map((d) => _ServerCard(id: d.id, data: d.data() as Map<String,dynamic>)),
        ]);
      },
    );
  }

  Widget _creditStat(String label, String val, String unit, Color c, {bool big=false}) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: big ? c.withOpacity(.1) : _AC.card,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: big ? c.withOpacity(.35) : _AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(val, style: _AC.mono(s: big?28:20, w: FontWeight.w700, c: c)),
        if(unit.isNotEmpty) ...[const SizedBox(width:4), Text(unit, style:_AC.t(s:10,c:_AC.t2))],
      ]),
      const SizedBox(height:3),
      Text(label, style: _AC.t(s:10.5, c:_AC.t2)),
    ]),
  );

  Widget _usageBar(int used, int total) {
    final pct = total==0 ? 0.0 : (used/total).clamp(0.0,1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: BorderRadius.circular(20),
        child: LinearProgressIndicator(value: pct, minHeight: 8,
          backgroundColor: _AC.card, color: pct>0.85?_AC.red:pct>0.6?_AC.org:_AC.grn)),
      const SizedBox(height:5),
      Text('${(pct*100).toStringAsFixed(0)}% مستهلك · $used من $total نقطة',
          style: _AC.t(s:10, c:_AC.t2)),
    ]);
  }

  Widget _addServersCard(BuildContext ctx) => _acCard('➕ إضافة رصيد (سيرفرات)', Column(children: [
    Row(children: [
      Expanded(child: _miniAction(ctx, '➕ سيرفر واحد', _AC.gold, () => _AddOneSheet.show(ctx))),
      const SizedBox(width:10),
      Expanded(child: _miniAction(ctx, '📋 دفعة (50–100)', _AC.blu, () => _BulkSheet.show(ctx))),
    ]),
  ]));

  Widget _miniAction(BuildContext ctx, String t, Color c, VoidCallback onTap) => GestureDetector(
    onTap: () { Sound.hapticM(); onTap(); },
    child: Container(height: 46, alignment: Alignment.center,
      decoration: BoxDecoration(color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(.3))),
      child: Text(t, style: _AC.t(s:12.5, w: FontWeight.w700, c: c))),
  );
}

// ── بطاقة سيرفر مع مؤشّر النقاط ──────────────────────────────────────────
class _ServerCard extends StatelessWidget {
  final String id; final Map<String,dynamic> data;
  const _ServerCard({required this.id, required this.data});
  @override
  Widget build(BuildContext context) {
    final name=data['name']?.toString()??'سيرفر';
    final host=data['host']?.toString()??'';
    final slots=(data['slots'] as num?)?.toInt()??2;
    final used =(data['used']  as num?)?.toInt()??0;
    final full =(data['status']?.toString()??'available')=='full';
    final assignments=List<Map<String,dynamic>>.from(data['assignments']??[]);
    final c = full ? _AC.t2 : (slots-used)==1 ? _AC.org : _AC.grn;

    return Container(margin: const EdgeInsets.only(bottom:9), padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: _AC.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: full ? _AC.bdr : c.withOpacity(.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // مؤشّر النقاط (نقطتان)
          Row(children: List.generate(slots, (i) => Container(
            width: 11, height: 11, margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: i < used ? c : Colors.transparent,
              border: Border.all(color: c, width: 1.5))))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: _AC.t(s: 12.5, w: FontWeight.w700)),
            Text(host, style: _AC.mono(s: 9.5, c: _AC.t2), overflow: TextOverflow.ellipsis),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: c.withOpacity(.13), borderRadius: BorderRadius.circular(8)),
            child: Text(full ? 'ممتلئ' : '$used/$slots', style: _AC.t(s: 10.5, w: FontWeight.w700, c: c))),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _confirmDelete(context),
            child: const Icon(Icons.delete_outline_rounded, color: _AC.red, size: 19)),
        ]),
        if (assignments.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...assignments.map((a) => Padding(padding: const EdgeInsets.only(top: 5),
            child: Row(children: [
              const Icon(Icons.person_rounded, size: 13, color: _AC.t3),
              const SizedBox(width: 6),
              Expanded(child: Text(a['email']?.toString() ?? a['uid']?.toString() ?? '—',
                  style: _AC.mono(s: 9.5, c: _AC.t2), overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: () async {
                  await _CreditEngine.release(serverId: id, uid: a['uid']?.toString() ?? '');
                  if (context.mounted) _toast(context, 'حُرّرت نقطة');
                },
                child: Text('تحرير', style: _AC.t(s: 9.5, w: FontWeight.w700, c: _AC.org))),
            ]))),
        ],
      ]),
    );
  }

  void _confirmDelete(BuildContext ctx) => showDialog(context: ctx, builder: (_) => AlertDialog(
    backgroundColor: _AC.bg2,
    title: Text('حذف السيرفر؟', style: _AC.t(s: 14, w: FontWeight.w700)),
    content: Text('سيُحذف نهائياً من قسم الرصيد.', style: _AC.t(s: 12, c: _AC.t2)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: _AC.t(c: _AC.t2))),
      TextButton(onPressed: () async {
        Navigator.pop(ctx);
        await _CreditEngine._col.doc(id).delete();
        if (ctx.mounted) _toast(ctx, '🗑 حُذف');
      }, child: Text('حذف', style: _AC.t(c: _AC.red, w: FontWeight.w700))),
    ],
  ));
}

// ── ورقة: إضافة سيرفر واحد ────────────────────────────────────────────────
class _AddOneSheet extends StatefulWidget {
  const _AddOneSheet();
  static void show(BuildContext ctx) => showModalBottomSheet(context: ctx,
    isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _AddOneSheet());
  @override State<_AddOneSheet> createState() => _AddOneSheetState();
}
class _AddOneSheetState extends State<_AddOneSheet> {
  final _name=TextEditingController(),_host=TextEditingController(),_user=TextEditingController(),_pass=TextEditingController();
  bool _busy=false;
  @override void dispose(){_name.dispose();_host.dispose();_user.dispose();_pass.dispose();super.dispose();}
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(18,16,18,MediaQuery.of(context).viewInsets.bottom+24),
    decoration: const BoxDecoration(color:_AC.bg2,
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)), border: Border(top: BorderSide(color:_AC.bdr))),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Container(width:38,height:4,margin:const EdgeInsets.only(bottom:16),
        decoration: BoxDecoration(color:_AC.bdr2,borderRadius:BorderRadius.circular(3)))),
      Text('➕ إضافة سيرفر (= نقطتان)', style: _AC.t(s:15, w: FontWeight.w800)),
      const SizedBox(height:16),
      _ConsoleField(controller:_name,hint:'الاسم (اختياري)'), const SizedBox(height:8),
      _ConsoleField(controller:_host,hint:'http://server.com:8080',ltr:true), const SizedBox(height:8),
      _ConsoleField(controller:_user,hint:'username',ltr:true), const SizedBox(height:8),
      _ConsoleField(controller:_pass,hint:'password',ltr:true), const SizedBox(height:16),
      GestureDetector(onTap: _busy?null:() async {
        if(_host.text.trim().isEmpty||_user.text.trim().isEmpty||_pass.text.trim().isEmpty){
          _toast(context,'⚠ الهوست واليوزر والباس مطلوبة'); return; }
        setState(()=>_busy=true);
        await _CreditEngine.addOne(name:_name.text.trim().isEmpty?'سيرفر':_name.text.trim(),
          host:_host.text.trim(),user:_user.text.trim(),pass:_pass.text.trim());
        if(mounted){Navigator.pop(context);_toast(context,'✅ أُضيف سيرفر (+نقطتان)');}
      }, child: Container(height:50,alignment:Alignment.center,
        decoration:BoxDecoration(gradient:const LinearGradient(colors:[_AC.gold2,_AC.gold3]),borderRadius:BorderRadius.circular(11)),
        child:_busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2.4,color:Colors.black))
          :Text('إضافة',style:_AC.t(s:14,w:FontWeight.w800,c:Colors.black)))),
    ]),
  );
}

// ── ورقة: إضافة دفعة (50–100) ─────────────────────────────────────────────
class _BulkSheet extends StatefulWidget {
  const _BulkSheet();
  static void show(BuildContext ctx) => showModalBottomSheet(context: ctx,
    isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _BulkSheet());
  @override State<_BulkSheet> createState() => _BulkSheetState();
}
class _BulkSheetState extends State<_BulkSheet> {
  final _raw=TextEditingController(); bool _busy=false;
  @override void dispose(){_raw.dispose();super.dispose();}
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(18,16,18,MediaQuery.of(context).viewInsets.bottom+24),
    decoration: const BoxDecoration(color:_AC.bg2,
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)), border: Border(top: BorderSide(color:_AC.bdr))),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Container(width:38,height:4,margin:const EdgeInsets.only(bottom:16),
        decoration: BoxDecoration(color:_AC.bdr2,borderRadius:BorderRadius.circular(3)))),
      Text('📋 إضافة دفعة سيرفرات', style: _AC.t(s:15, w: FontWeight.w800)),
      const SizedBox(height:6),
      Text('سطر لكل سيرفر:  host,user,pass  (أو افصل بـ | )\nمثال: http://srv.com:8080,user1,pass1',
          style: _AC.t(s:10.5, c:_AC.t2)),
      const SizedBox(height:12),
      Container(decoration: BoxDecoration(color:_AC.bg3,borderRadius:BorderRadius.circular(10),border:Border.all(color:_AC.bdr)),
        child: TextField(controller:_raw, maxLines:9, textDirection: TextDirection.ltr,
          style:_AC.mono(s:11), decoration: const InputDecoration(border:InputBorder.none,
            contentPadding: EdgeInsets.all(12), hintText:'http://...,user,pass\nhttp://...,user,pass'))),
      const SizedBox(height:16),
      GestureDetector(onTap: _busy?null:() async {
        if(_raw.text.trim().isEmpty){_toast(context,'⚠ ألصق قائمة السيرفرات');return;}
        setState(()=>_busy=true);
        try{
          final n = await _CreditEngine.addBulk(_raw.text);
          if(mounted){Navigator.pop(context);_toast(context,'✅ أُضيف $n سيرفر (+${n*2} نقطة)');}
        }catch(e){if(mounted){setState(()=>_busy=false);_toast(context,'خطأ: $e');}}
      }, child: Container(height:50,alignment:Alignment.center,
        decoration:BoxDecoration(gradient:const LinearGradient(colors:[_AC.gold2,_AC.gold3]),borderRadius:BorderRadius.circular(11)),
        child:_busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2.4,color:Colors.black))
          :Text('استيراد الدفعة',style:_AC.t(s:14,w:FontWeight.w800,c:Colors.black)))),
    ]),
  );
}
