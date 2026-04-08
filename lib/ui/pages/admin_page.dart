part of '../../main.dart';

// ════════════════════════════════════════════════════════════════
//  ADMIN DASHBOARD — لوحة تحكم احترافية متكاملة
//  تشمل: إحصائيات، إدارة مستخدمين، إشعارات، إعدادات
// ════════════════════════════════════════════════════════════════
class AdminWebPage extends StatefulWidget {
  const AdminWebPage({super.key});
  @override State<AdminWebPage> createState() => _AdminWebPageState();
}

class _AdminWebPageState extends State<AdminWebPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this)
      ..addListener(() { if (!_tc.indexIsChanging && mounted) setState(() => _tab = _tc.index); });
  }

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop()),
        title: Row(children: [
          Container(width: 28, height: 28,
            decoration: BoxDecoration(color: C.gold.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.admin_panel_settings_rounded, color: C.gold, size: 15)),
          const SizedBox(width: 8),
          Text('لوحة التحكم', style: T.cairo(s: 15, w: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white38),
            onPressed: () async {
              await AuthService.signOut();
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
            }),
        ],
        bottom: TabBar(
          controller: _tc,
          labelColor: C.gold,
          unselectedLabelColor: Colors.white38,
          indicatorColor: C.gold,
          indicatorWeight: 2,
          labelStyle: T.cairo(s: 11, w: FontWeight.w700),
          unselectedLabelStyle: T.cairo(s: 11),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'الرئيسية'),
            Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'المستخدمون'),
            Tab(icon: Icon(Icons.notifications_rounded, size: 18), text: 'الإشعارات'),
            Tab(icon: Icon(Icons.settings_rounded, size: 18), text: 'الإعدادات'),
          ]),
      ),
      body: TabBarView(controller: _tc, children: const [
        _AdminDashboard(),
        _AdminUsers(),
        _AdminNotifications(),
        _AdminSettings(),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  TAB 1 — DASHBOARD STATISTICS
// ════════════════════════════════════════════════════════════════
class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard();
  @override State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  bool _loading = true;
  int _totalUsers = 0, _activeUsers = 0, _premiumUsers = 0, _expiringSoon = 0;
  int _bannedUsers = 0;
  List<Map<String, dynamic>> _recentUsers = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .get()
          .timeout(const Duration(seconds: 15));

      int total = 0, active = 0, premium = 0, expiring = 0, banned = 0;
      final recent = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (final doc in snap.docs) {
        total++;
        final d = doc.data();
        final status = d['status']?.toString() ?? 'active';
        if (status == 'banned') { banned++; continue; }

        final sub = d['subscription'] as Map<String, dynamic>?;
        if (sub != null) {
          final expiry = (sub['expiry_date'] as Timestamp?)?.toDate();
          if (expiry != null && expiry.isAfter(now)) {
            active++; premium++;
            if (expiry.difference(now).inDays <= 7) expiring++;
          }
        }
        if (recent.length < 5) {
          recent.add({'id': doc.id, 'email': d['email'] ?? '', 'name': d['display_name'] ?? d['email'] ?? '',
            'plan': sub?['plan'] ?? 'free', 'last_seen': d['last_seen']});
        }
      }
      if (mounted) setState(() {
        _totalUsers = total; _activeUsers = active;
        _premiumUsers = premium; _expiringSoon = expiring;
        _bannedUsers = banned; _recentUsers = recent;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: C.gold));
    return RefreshIndicator(
      color: C.gold, backgroundColor: C.surface,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Stats Grid
          GridView.count(crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
            children: [
              _statCard('إجمالي المستخدمين', '$_totalUsers', Icons.people_rounded, CC.info),
              _statCard('مشتركون نشطون', '$_activeUsers', Icons.check_circle_rounded, CC.success),
              _statCard('Premium', '$_premiumUsers', Icons.workspace_premium_rounded, C.gold),
              _statCard('ينتهون قريباً', '$_expiringSoon', Icons.timer_rounded, Colors.orange),
            ]),
          const SizedBox(height: 16),
          // Banned banner
          if (_bannedUsers > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.block_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Text('$_bannedUsers حساب موقوف', style: T.cairo(s: 13, c: Colors.red, w: FontWeight.w700)),
              ])),
          const SizedBox(height: 16),
          // Recent users
          _sectionTitle('آخر المستخدمين المسجّلين'),
          const SizedBox(height: 10),
          ..._recentUsers.map((u) => _userRow(u)),
          const SizedBox(height: 16),
          // App config quick view
          _sectionTitle('حالة التطبيق'),
          const SizedBox(height: 10),
          _configRow('السيرفر', RC.serverHost.isNotEmpty ? RC.serverHost : 'غير محدد',
              RC.serverHost.isNotEmpty ? CC.success : Colors.red),
          _configRow('الصيانة', RC.maintenance ? 'مفعّل ⚠' : 'معطّل ✓',
              RC.maintenance ? Colors.orange : CC.success),
          _configRow('إصدار التطبيق', AppVersion.version, C.gold),
        ]),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const Spacer(),
        Text(value, style: TExtra.mont(s: 24, w: FontWeight.w700, c: color)),
        Text(label, style: T.caption(c: CC.textSec), maxLines: 1),
      ]));

  Widget _sectionTitle(String t) => Align(alignment: Alignment.centerRight,
    child: Text(t, style: T.cairo(s: 13, w: FontWeight.w700, c: C.gold)));

  Widget _userRow(Map u) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      CircleAvatar(radius: 18, backgroundColor: C.card,
        child: Text((u['name'].toString().isEmpty ? 'U' : u['name'].toString()[0]).toUpperCase(),
          style: T.cairo(s: 12, w: FontWeight.w700, c: C.gold))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(u['name'].toString(), style: T.cairo(s: 12, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(u['email'].toString(), style: T.caption(c: CC.textSec), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: u['plan'] == 'premium' ? C.gold.withOpacity(0.15) : Colors.white10,
          borderRadius: BorderRadius.circular(20)),
        child: Text(u['plan'] == 'premium' ? 'Premium' : 'مجاني',
          style: T.caption(c: u['plan'] == 'premium' ? C.gold : Colors.white38))),
    ]));

  Widget _configRow(String label, String val, Color c) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Text(label, style: T.cairo(s: 12, w: FontWeight.w600)),
      const Spacer(),
      Text(val, style: T.cairo(s: 12, c: c), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]));
}

// ════════════════════════════════════════════════════════════════
//  TAB 2 — USER MANAGEMENT
// ════════════════════════════════════════════════════════════════
class _AdminUsers extends StatefulWidget {
  const _AdminUsers();
  @override State<_AdminUsers> createState() => _AdminUsersState();
}

class _AdminUsersState extends State<_AdminUsers> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();
  String _filterPlan = 'all';

  @override void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('users')
          .orderBy('last_seen', descending: true).limit(100).get()
          .timeout(const Duration(seconds: 15));
      final list = snap.docs.map((d) {
        final data = d.data();
        final sub = data['subscription'] as Map<String, dynamic>?;
        final expiry = (sub?['expiry_date'] as Timestamp?)?.toDate();
        return {
          'uid': d.id, 'email': data['email'] ?? '',
          'name': data['display_name'] ?? data['email'] ?? 'مجهول',
          'plan': sub?['plan'] ?? 'free',
          'status': data['status'] ?? 'active',
          'expiry': expiry?.toIso8601String() ?? '',
          'expiry_dt': expiry,
          'platform': data['platform'] ?? '',
          'last_seen': (data['last_seen'] as Timestamp?)?.toDate(),
          'device_id': data['device_id'] ?? '',
        };
      }).toList();
      if (mounted) { setState(() { _users = list; _loading = false; }); _filter(); }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _filtered = _users.where((u) {
        final matchQ = q.isEmpty ||
            u['email'].toString().toLowerCase().contains(q) ||
            u['name'].toString().toLowerCase().contains(q);
        final matchP = _filterPlan == 'all' || u['plan'] == _filterPlan;
        return matchQ && matchP;
      }).toList();
    });
  }

  Future<void> _updateUser(String uid, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update(data);
    await _load();
  }

  Future<void> _showUserActions(Map u) async {
    final isBanned = u['status'] == 'banned';
    await showModalBottomSheet(
      context: context, backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: C.dim, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(u['name'].toString(), style: T.cairo(s: 15, w: FontWeight.w700)),
          Text(u['email'].toString(), style: T.caption(c: CC.textSec)),
          const SizedBox(height: 20),
          // Set Premium
          _actionTile(Icons.workspace_premium_rounded, 'منح اشتراك Premium', C.gold, () async {
            Navigator.pop(context);
            await _showSetSubscription(u);
          }),
          _actionTile(Icons.delete_sweep_rounded, 'إلغاء الاشتراك', Colors.orange, () async {
            Navigator.pop(context);
            await _updateUser(u['uid'], {
              'subscription': {'plan': 'free', 'expiry_date': null, 'updated_at': FieldValue.serverTimestamp()}
            });
          }),
          _actionTile(
            isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
            isBanned ? 'رفع الحظر' : 'حظر المستخدم',
            isBanned ? CC.success : Colors.red,
            () async {
              Navigator.pop(context);
              await _updateUser(u['uid'], {'status': isBanned ? 'active' : 'banned'});
            }),
          _actionTile(Icons.notifications_outlined, 'إرسال إشعار لهذا المستخدم', CC.info, () async {
            Navigator.pop(context);
            await _showSendNotification(uid: u['uid']);
          }),
        ])));
  }

  Future<void> _showSetSubscription(Map u) async {
    DateTime expiry = DateTime.now().add(const Duration(days: 30));
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          backgroundColor: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('منح اشتراك', style: T.cairo(s: 15, w: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('المستخدم: ${u['email']}', style: T.caption(c: CC.textSec)),
            const SizedBox(height: 16),
            Text('تاريخ الانتهاء: ${expiry.day}/${expiry.month}/${expiry.year}',
                style: T.cairo(s: 13, c: C.gold)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              _daysBtn(ctx, ss, '7 أيام', 7, expiry, (d) => expiry = d),
              _daysBtn(ctx, ss, 'شهر', 30, expiry, (d) => expiry = d),
              _daysBtn(ctx, ss, '3 أشهر', 90, expiry, (d) => expiry = d),
              _daysBtn(ctx, ss, 'سنة', 365, expiry, (d) => expiry = d),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('إلغاء', style: T.cairo(s: 13, c: C.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: C.gold, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                await _updateUser(u['uid'], {
                  'subscription': {
                    'plan': 'premium', 'expiry_date': Timestamp.fromDate(expiry),
                    'updated_at': FieldValue.serverTimestamp(),
                  },
                  'status': 'active',
                });
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم منح الاشتراك ✓', style: T.cairo(s: 12, c: Colors.black)),
                    backgroundColor: C.gold, behavior: SnackBarBehavior.floating));
              },
              child: Text('منح الاشتراك', style: T.cairo(s: 13, w: FontWeight.w700))),
          ])));
  }

  Widget _daysBtn(ctx, ss, String label, int days, DateTime current, Function(DateTime) onSet) =>
    GestureDetector(
      onTap: () => ss(() => onSet(DateTime.now().add(Duration(days: days)))),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: C.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.gold.withOpacity(0.4))),
        child: Text(label, style: T.caption(c: C.gold))));

  Future<void> _showSendNotification({String? uid}) async {
    final titleC = TextEditingController();
    final bodyC  = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(uid != null ? 'إشعار لمستخدم' : 'إشعار لجميع المستخدمين',
            style: T.cairo(s: 15, w: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleC, style: T.cairo(s: 13),
            decoration: _inputDec('عنوان الإشعار')),
          const SizedBox(height: 10),
          TextField(controller: bodyC, maxLines: 3, style: T.cairo(s: 13),
            decoration: _inputDec('نص الإشعار')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: T.cairo(s: 13, c: C.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.gold, foregroundColor: Colors.black),
            onPressed: () async {
              if (titleC.text.trim().isEmpty) return;
              Navigator.pop(context);
              await _saveNotification(titleC.text.trim(), bodyC.text.trim(), uid: uid);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم إرسال الإشعار ✓', style: T.cairo(s: 12, c: Colors.black)),
                  backgroundColor: C.gold, behavior: SnackBarBehavior.floating));
            },
            child: Text('إرسال', style: T.cairo(s: 13, w: FontWeight.w700))),
        ]));
  }

  Future<void> _saveNotification(String title, String body, {String? uid}) async {
    final col = FirebaseFirestore.instance.collection('notifications');
    await col.add({'title': title, 'body': body, 'active': true,
      'target_uid': uid, 'sent_at': FieldValue.serverTimestamp()});
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint, hintStyle: T.cairo(s: 12, c: Colors.white38),
    filled: true, fillColor: C.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CExtra.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CExtra.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: C.gold)));

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) =>
    ListTile(leading: Icon(icon, color: color), title: Text(label, style: T.cairo(s: 13, c: color)), onTap: onTap);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(children: [
          // Search bar
          TextField(controller: _search, style: T.cairo(s: 13),
            decoration: _inputDec('ابحث بالاسم أو البريد...').copyWith(
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
              suffixIcon: _search.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white38),
                      onPressed: () { _search.clear(); _filter(); }) : null)),
          const SizedBox(height: 8),
          // Filter chips
          Row(children: [
            _chip('الكل', 'all'), _chip('Premium', 'premium'),
            _chip('مجاني', 'free'), const Spacer(),
            Text('${_filtered.length} مستخدم', style: T.caption(c: CC.textSec)),
          ]),
        ])),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: C.gold))
          : RefreshIndicator(color: C.gold, backgroundColor: C.surface, onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: _filtered.length,
                itemBuilder: (ctx, i) {
                  final u = _filtered[i];
                  final isBanned = u['status'] == 'banned';
                  final isPremium = u['plan'] == 'premium';
                  final expDt = u['expiry_dt'] as DateTime?;
                  final isExpiring = expDt != null && expDt.isAfter(DateTime.now()) &&
                      expDt.difference(DateTime.now()).inDays <= 7;
                  return GestureDetector(
                    onTap: () => _showUserActions(u),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isBanned ? Colors.red.withOpacity(0.05) : C.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isBanned ? Colors.red.withOpacity(0.2)
                            : isExpiring ? Colors.orange.withOpacity(0.3)
                            : CExtra.border, width: 0.5)),
                      child: Row(children: [
                        CircleAvatar(radius: 20, backgroundColor: C.card,
                          child: Text((u['name'].toString().isEmpty ? 'U' : u['name'].toString()[0]).toUpperCase(),
                            style: T.cairo(s: 13, w: FontWeight.w700, c: C.gold))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u['name'].toString(), style: T.cairo(s: 13, w: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(u['email'].toString(), style: T.caption(c: CC.textSec),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (expDt != null)
                            Text('ينتهي: ${expDt.day}/${expDt.month}/${expDt.year}',
                                style: T.caption(c: isExpiring ? Colors.orange : C.dim)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isBanned ? Colors.red.withOpacity(0.15)
                                  : isPremium ? C.gold.withOpacity(0.15) : Colors.white10,
                              borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              isBanned ? 'محظور' : isPremium ? 'Premium' : 'مجاني',
                              style: T.caption(c: isBanned ? Colors.red : isPremium ? C.gold : Colors.white38))),
                          if (u['platform'].toString().isNotEmpty)
                            Text(u['platform'].toString(), style: T.caption(c: C.dim)),
                        ]),
                      ])));
                },
              ),
            ),
          ),
    ]);
  }

  Widget _chip(String label, String val) => GestureDetector(
    onTap: () { setState(() => _filterPlan = val); _filter(); },
    child: Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _filterPlan == val ? C.gold.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _filterPlan == val ? C.gold.withOpacity(0.5) : Colors.transparent)),
      child: Text(label, style: T.caption(c: _filterPlan == val ? C.gold : Colors.white38))));
}

// ════════════════════════════════════════════════════════════════
//  TAB 3 — NOTIFICATIONS
// ════════════════════════════════════════════════════════════════
class _AdminNotifications extends StatefulWidget {
  const _AdminNotifications();
  @override State<_AdminNotifications> createState() => _AdminNotificationsState();
}

class _AdminNotificationsState extends State<_AdminNotifications> {
  List<Map<String, dynamic>> _notifs = [];
  bool _loading = true;
  final _titleC = TextEditingController();
  final _bodyC  = TextEditingController();
  bool _sending = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _titleC.dispose(); _bodyC.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('notifications')
          .orderBy('sent_at', descending: true).limit(30).get();
      if (mounted) setState(() {
        _notifs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _send() async {
    if (_titleC.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': _titleC.text.trim(), 'body': _bodyC.text.trim(),
        'active': true, 'sent_at': FieldValue.serverTimestamp(),
        'sent_by': AuthService.currentUser?.email ?? 'admin',
      });
      _titleC.clear(); _bodyC.clear();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم إرسال الإشعار ✓', style: T.cairo(s: 12, c: Colors.black)),
        backgroundColor: C.gold, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطأ: $e', style: T.cairo(s: 12)),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _sending = false);
  }

  InputDecoration _dec(String h) => InputDecoration(hintText: h, hintStyle: T.cairo(s: 12, c: Colors.white38),
    filled: true, fillColor: C.bg, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CExtra.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CExtra.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.gold)));

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Send notification form
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CExtra.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.send_rounded, color: C.gold, size: 16),
            const SizedBox(width: 8),
            Text('إرسال إشعار جديد', style: T.cairo(s: 13, w: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _titleC, style: T.cairo(s: 13), decoration: _dec('عنوان الإشعار *')),
          const SizedBox(height: 8),
          TextField(controller: _bodyC, maxLines: 2, style: T.cairo(s: 13), decoration: _dec('نص الإشعار')),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(height: 44,
              decoration: BoxDecoration(gradient: _sending ? null : C.playGrad,
                color: _sending ? C.surface : null, borderRadius: BorderRadius.circular(10)),
              child: Center(child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: C.gold, strokeWidth: 2))
                  : Text('إرسال للجميع', style: T.cairo(s: 13, c: Colors.black, w: FontWeight.w700))))),
        ])),
      // History
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(alignment: Alignment.centerRight,
          child: Text('آخر الإشعارات', style: T.cairo(s: 12, w: FontWeight.w700, c: C.gold)))),
      const SizedBox(height: 8),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: C.gold))
          : _notifs.isEmpty
              ? Center(child: Text('لا توجد إشعارات', style: T.body(c: CC.textSec)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: _notifs.length,
                  itemBuilder: (_, i) {
                    final n = _notifs[i];
                    final ts = (n['sent_at'] as Timestamp?)?.toDate();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CExtra.border, width: 0.5)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 36, height: 36, decoration: BoxDecoration(color: C.gold.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_rounded, color: C.gold, size: 18)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n['title']?.toString() ?? '', style: T.cairo(s: 13, w: FontWeight.w700)),
                          if ((n['body']?.toString() ?? '').isNotEmpty)
                            Text(n['body'].toString(), style: T.caption(c: CC.textSec)),
                          if (ts != null)
                            Text('${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2,'0')}',
                                style: T.caption(c: C.dim)),
                        ])),
                      ]));
                  })),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
//  TAB 4 — APP SETTINGS
// ════════════════════════════════════════════════════════════════
class _AdminSettings extends StatefulWidget {
  const _AdminSettings();
  @override State<_AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<_AdminSettings> {
  // remote_control
  bool _maintenance = false, _locked = false;
  final _maintMsgC  = TextEditingController();
  final _lockMsgC   = TextEditingController();
  // remote_config
  final _serverC    = TextEditingController();
  final _waC        = TextEditingController();
  final _tgC        = TextEditingController();
  final _updateUrlC = TextEditingController();
  // version
  final _minVerC    = TextEditingController();
  bool _loading = true, _saving = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() {
    _maintMsgC.dispose(); _lockMsgC.dispose();
    _serverC.dispose(); _waC.dispose(); _tgC.dispose();
    _updateUrlC.dispose(); _minVerC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('app_config').doc('remote_control').get(),
        db.collection('app_config').doc('remote_config').get(),
        db.collection('app_config').doc('version').get(),
      ]);
      final ctrl = results[0].data() ?? {};
      final conf = results[1].data() ?? {};
      final ver  = results[2].data() ?? {};
      if (mounted) setState(() {
        _maintenance = ctrl['maintenance'] == true;
        _locked      = ctrl['locked']      == true;
        _maintMsgC.text  = ctrl['maint_msg']?.toString() ?? '';
        _lockMsgC.text   = ctrl['lock_msg']?.toString()  ?? '';
        _serverC.text    = conf['server_host']?.toString()    ?? '';
        _waC.text        = conf['whatsapp']?.toString()       ?? '';
        _tgC.text        = conf['telegram']?.toString()       ?? '';
        _updateUrlC.text = conf['update_url']?.toString()     ?? '';
        _minVerC.text    = ver['min_version']?.toString()     ?? '1';
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      await Future.wait([
        db.collection('app_config').doc('remote_control').set({
          'maintenance': _maintenance, 'maint_msg': _maintMsgC.text.trim(),
          'locked': _locked, 'lock_msg': _lockMsgC.text.trim(),
          'guest_only': false,
        }, SetOptions(merge: true)),
        db.collection('app_config').doc('remote_config').set({
          'server_host': _serverC.text.trim(), 'whatsapp': _waC.text.trim(),
          'telegram': _tgC.text.trim(), 'update_url': _updateUrlC.text.trim(),
        }, SetOptions(merge: true)),
        db.collection('app_config').doc('version').set({
          'min_version': int.tryParse(_minVerC.text.trim()) ?? 1,
        }, SetOptions(merge: true)),
      ]);
      RC.onConfigChanged?.call();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم الحفظ ✓', style: T.cairo(s: 12, c: Colors.black)),
        backgroundColor: C.gold, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطأ: $e', style: T.cairo(s: 12)),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _saving = false);
  }

  InputDecoration _dec(String h, {IconData? icon}) => InputDecoration(
    hintText: h, hintStyle: T.cairo(s: 12, c: Colors.white38),
    prefixIcon: icon != null ? Icon(icon, color: Colors.white38, size: 16) : null,
    filled: true, fillColor: C.bg, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CExtra.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: CExtra.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.gold)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: C.gold));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(children: [
        // Control panel
        _section('حالة التطبيق', Icons.toggle_on_rounded, [
          _toggle2('وضع الصيانة', 'إيقاف التطبيق مؤقتاً', _maintenance, (v) => setState(() => _maintenance = v)),
          const SizedBox(height: 8),
          if (_maintenance) ...[TextField(controller: _maintMsgC, style: T.cairo(s: 13), decoration: _dec('رسالة الصيانة')), const SizedBox(height: 8)],
          _toggle2('قفل التطبيق', 'منع دخول جميع المستخدمين', _locked, (v) => setState(() => _locked = v)),
          if (_locked) ...[const SizedBox(height: 8), TextField(controller: _lockMsgC, style: T.cairo(s: 13), decoration: _dec('رسالة القفل'))],
        ]),
        const SizedBox(height: 16),
        _section('إعدادات السيرفر', Icons.dns_rounded, [
          TextField(controller: _serverC, style: T.cairo(s: 13), decoration: _dec('رابط السيرفر', icon: Icons.link_rounded)),
          const SizedBox(height: 8),
          TextField(controller: _updateUrlC, style: T.cairo(s: 13), decoration: _dec('رابط التحديث', icon: Icons.download_rounded)),
        ]),
        const SizedBox(height: 16),
        _section('التواصل والدعم', Icons.support_agent_rounded, [
          TextField(controller: _waC, keyboardType: TextInputType.phone, style: T.cairo(s: 13),
            decoration: _dec('رقم واتساب (بدون +)', icon: Icons.phone_rounded)),
          const SizedBox(height: 8),
          TextField(controller: _tgC, style: T.cairo(s: 13), decoration: _dec('رابط تيليغرام', icon: Icons.telegram_rounded)),
        ]),
        const SizedBox(height: 16),
        _section('إصدار التطبيق', Icons.system_update_rounded, [
          TextField(controller: _minVerC, keyboardType: TextInputType.number, style: T.cairo(s: 13),
            decoration: _dec('الإصدار الأدنى المطلوب (رقم صحيح)', icon: Icons.numbers_rounded)),
          const SizedBox(height: 6),
          Text('الإصدار الحالي: ${AppVersion.version}', style: T.caption(c: C.gold)),
        ]),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: Container(height: 52, decoration: BoxDecoration(
            gradient: _saving ? null : C.playGrad, color: _saving ? C.surface : null,
            borderRadius: BorderRadius.circular(14)),
            child: Center(child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: C.gold, strokeWidth: 2))
                : Text('حفظ جميع الإعدادات', style: T.cairo(s: 15, c: Colors.black, w: FontWeight.w800))))),
      ]));
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: CExtra.border, width: 0.5)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: C.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: C.gold, size: 16)),
        const SizedBox(width: 8),
        Text(title, style: T.cairo(s: 13, w: FontWeight.w700)),
      ]),
      const SizedBox(height: 14),
      ...children,
    ]));

  Widget _toggle2(String title, String sub, bool val, Function(bool) onChange) =>
    Container(height: 56, child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title, style: T.cairo(s: 13, w: FontWeight.w600)),
        Text(sub, style: T.caption(c: CC.textSec)),
      ])),
      Switch(value: val, onChanged: onChange, activeColor: C.gold),
    ]));
}

// ════════════════════════════════════════════════════════════════
//  AUTH GATE WIDGET — used in ProfilePage
// ════════════════════════════════════════════════════════════════
class _AuthGateWidget extends StatelessWidget {
  const _AuthGateWidget();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authChanges,
      builder: (ctx, snap) {
        final user = snap.data;
        if (user == null) return _buildLoginPrompt(ctx);
        return _buildUserCard(ctx, user);
      });
  }

  Widget _buildLoginPrompt(BuildContext ctx) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: C.surface, border: Border.all(color: CExtra.border),
      borderRadius: BorderRadius.circular(14)),
    child: Column(children: [
      const Icon(Icons.account_circle_outlined, color: C.grey, size: 40),
      const SizedBox(height: 10),
      Text('تسجيل الدخول', style: T.cairo(s: 14, w: FontWeight.w700)),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: () => Navigator.of(ctx).pushNamed('/login'),
        child: Container(width: double.infinity, height: 42,
          decoration: BoxDecoration(gradient: C.playGrad, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text('تسجيل الدخول',
              style: T.cairo(s: 13, c: Colors.black, w: FontWeight.w700))))),
    ]));

  Widget _buildUserCard(BuildContext ctx, User user) =>
    // ★ FIX 1: AdminAwareBuilder يستجيب فوراً لتغييرات Firestore
    // بدلاً من AuthService.isAdmin الثابت الذي يتطلب rebuild كامل
    AdminAwareBuilder(builder: (isAdmin) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.surface,
        border: Border.all(
          color: isAdmin ? C.gold.withOpacity(.4) : CExtra.border),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        CircleAvatar(radius: 24, backgroundColor: C.card,
          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
          child: user.photoURL == null
              ? Text((user.displayName?.isNotEmpty == true ? user.displayName![0] : 'U').toUpperCase(),
                  style: T.cairo(s: 18, w: FontWeight.w700, c: C.gold)) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.displayName ?? user.email ?? 'مستخدم', style: T.cairo(s: 13, w: FontWeight.w700)),
          Text(user.email ?? '', style: T.caption(c: C.grey)),
          if (isAdmin)
            Container(margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: CC.goldBg, borderRadius: BorderRadius.circular(20)),
              child: Text('أدمن', style: T.caption(c: C.gold, s: 9))),
        ])),
        if (isAdmin)
          GestureDetector(
            onTap: () => Navigator.of(ctx).pushNamed('/admin'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: CC.goldBg,
                border: Border.all(color: C.gold.withOpacity(.3)),
                borderRadius: BorderRadius.circular(8)),
              child: Text('لوحة التحكم', style: T.cairo(s: 10, c: C.gold, w: FontWeight.w700)))),
      ])));
}
