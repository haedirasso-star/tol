part of '../main.dart';

// ════════════════════════════════════════════════════════════════════
//  التوقعات · الدعوات · المحادثة
//  كل الطلبات تمر عبر دالة push في Supabase، وهي تتحقق من حساب Firebase
//  ثم تكتب في القاعدة. لا مفاتيح سرية داخل التطبيق.
//  لا قراءة دورية: الرسائل الجديدة تصل كإشعار، والتوقعات تُحفظ على الجهاز.
// ════════════════════════════════════════════════════════════════════

class EngageErr implements Exception {
  final String msg;
  final int code;
  EngageErr(this.msg, [this.code = 0]);
  @override
  String toString() => msg;
}

class Engage {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 25),
    contentType: 'application/json',
    validateStatus: (_) => true,
  ));
  static String get _fn => '$kSupaUrl/functions/v1/push';

  static Future<Map<String, dynamic>> call(String action, [Map<String, dynamic> body = const {}]) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw EngageErr('سجّل الدخول أولاً', 401);
    String? t;
    try { t = await u.getIdToken(); } catch (_) {}
    if (t == null) throw EngageErr('تعذّر التحقق من حسابك — حاول مجدداً', 401);
    Response r;
    try {
      r = await _dio.post(_fn,
          data: {...body, 'action': action, 'idToken': t, 'my_name': (u.displayName ?? '').trim()},
          options: Options(headers: {'apikey': kSupaPublicKey}));
    } on DioException {
      throw EngageErr('تحقّق من اتصال الإنترنت وحاول مجدداً');
    }
    Map<String, dynamic> d = {};
    try {
      final raw = r.data;
      if (raw is Map) {
        d = Map<String, dynamic>.from(raw);
      } else if (raw is String && raw.isNotEmpty) {
        final j = jsonDecode(raw);
        if (j is Map) d = Map<String, dynamic>.from(j);
      }
    } catch (_) {}
    final code = r.statusCode ?? 0;
    if (code >= 200 && code < 300 && d['error'] == null) return d;
    final e = '${d['error'] ?? ''}';
    if (code == 401) throw EngageErr('انتهت الجلسة — أعد فتح التطبيق', 401);
    throw EngageErr(e.isNotEmpty ? e : 'الخدمة غير متاحة حالياً ($code)', code);
  }
}

// ── التوقعات ────────────────────────────────────────────────────────
class PredStats {
  final int total, home, draw, away;
  final List<(int, int, int)> top;   // (أهداف المستضيف، أهداف الضيف، العدد)
  const PredStats({this.total = 0, this.home = 0, this.draw = 0, this.away = 0, this.top = const []});
  factory PredStats.from(Object? j) {
    if (j is! Map) return const PredStats();
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final top = <(int, int, int)>[];
    for (final t in (j['top'] as List?) ?? const []) {
      if (t is Map) top.add((n(t['h']), n(t['a']), n(t['n'])));
    }
    return PredStats(total: n(j['total']), home: n(j['home']), draw: n(j['draw']), away: n(j['away']), top: top);
  }
}

class Predictions {
  static const _k = 'pred_mine_v1';
  static Map<String, dynamic> _m = {};
  static bool _loaded = false;

  /// نافذة التوقع: من 30 دقيقة قبل الانطلاق حتى الانطلاق
  static const window = Duration(minutes: 30);
  static bool isOpen(FxMatch m) => !m.isOff && m.secsToKick > 0 && m.secsToKick <= window.inSeconds;
  static bool notYet(FxMatch m) => !m.isOff && m.secsToKick > window.inSeconds;

  static Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final s = (await SPref.i).getString(_k);
      if (s != null && s.isNotEmpty) _m = Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {}
  }

  static Future<(int, int)?> mine(int id) async {
    await _load();
    final v = _m['$id'];
    if (v is Map) return ((v['h'] as num).toInt(), (v['a'] as num).toInt());
    return null;
  }

  static Future<void> _save(int id, int h, int a) async {
    await _load();
    _m['$id'] = {'h': h, 'a': a, 't': DateTime.now().millisecondsSinceEpoch};
    if (_m.length > 80) {
      int t(String k) => ((_m[k] as Map?)?['t'] as num?)?.toInt() ?? 0;
      final ks = _m.keys.toList()..sort((x, y) => t(x).compareTo(t(y)));
      for (final k in ks.take(_m.length - 60)) { _m.remove(k); }
    }
    try { await (await SPref.i).setString(_k, jsonEncode(_m)); } catch (_) {}
  }

  static Future<PredStats> submit(FxMatch m, int h, int a) async {
    final r = await Engage.call('predict', {
      'match_id': m.id, 'h': h, 'a': a, 'ts': m.ts,
      'home_name': m.h.label, 'away_name': m.a.label,
      'league': SportsFeed.leagues[m.lg]?.ar ?? '',
    });
    await _save(m.id, h, a);
    return PredStats.from(r['stats']);
  }

  /// توقعي المحفوظ في القاعدة + إحصائيات المباراة (عند فتح صفحة المباراة فقط)
  static Future<({(int, int)? mine, PredStats stats})> fetch(FxMatch m) async {
    final r = await Engage.call('pred_get', {'match_id': m.id});
    (int, int)? mine;
    final x = r['mine'];
    if (x is Map) {
      mine = ((x['home_goals'] as num).toInt(), (x['away_goals'] as num).toInt());
      await _save(m.id, mine.$1, mine.$2);
    }
    return (mine: mine, stats: PredStats.from(r['stats']));
  }
}

// ── الدعوات ─────────────────────────────────────────────────────────
class Referral {
  static const _k = 'ref_code_v1';
  static const days = 16;

  static Future<String> cached() async {
    try { return (await SPref.i).getString('${_k}_${FirebaseAuth.instance.currentUser?.uid ?? ''}') ?? ''; } catch (_) { return ''; }
  }

  static Future<Map<String, dynamic>> me() async {
    final r = await Engage.call('ref_me');
    final c = '${r['code'] ?? ''}';
    if (c.isNotEmpty) {
      try { await (await SPref.i).setString('${_k}_${FirebaseAuth.instance.currentUser?.uid ?? ''}', c); } catch (_) {}
    }
    return r;
  }

  static Future<String> apply(String code) async {
    final r = await Engage.call('ref_apply', {'code': code.trim().toUpperCase()});
    return '${r['referrer'] ?? ''}';
  }

  static String shareText(String code) {
    final link = RC.updateUrl.isNotEmpty ? RC.updateUrl : RC.telegram;
    return '🎬 جرّب تطبيق TOTV+ — أفلام ومسلسلات ومباريات مباشرة.\n'
        'حمّل التطبيق، ثم افتح «المزيد ← ادعُ صديقك» واكتب كود الدعوة:\n\n'
        '$code\n'
        '${link.isNotEmpty ? '\nرابط التحميل: $link' : ''}';
  }
}

// ── المحادثة ────────────────────────────────────────────────────────
class ChatMsg {
  final int id;
  final String sender, body, kind;
  final DateTime at;
  const ChatMsg(this.id, this.sender, this.body, this.kind, this.at);
  bool get mine => sender == 'user';
  factory ChatMsg.from(Map j) => ChatMsg(
        (j['id'] as num?)?.toInt() ?? 0, '${j['sender'] ?? ''}', '${j['body'] ?? ''}', '${j['kind'] ?? 'text'}',
        DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal() ?? DateTime.now());
}

class ChatInbox {
  static const kUnread = 'chat_unread_v1';
  static final unread = ValueNotifier<int>(0);
  static final rev = ValueNotifier<int>(0);
  static bool pageOpen = false;

  static Future<void> load() async {
    try {
      final p = await SPref.i;
      await p.reload();
      unread.value = p.getInt(kUnread) ?? 0;
    } catch (_) {}
  }

  static Future<void> bump() async {
    if (!pageOpen) unread.value++;
    rev.value++;
    try { await (await SPref.i).setInt(kUnread, unread.value); } catch (_) {}
  }

  static Future<void> clear() async {
    unread.value = 0;
    try { await (await SPref.i).setInt(kUnread, 0); } catch (_) {}
  }

  static void open() {
    final nav = rootNavKey.currentState;
    if (nav == null) return;
    if (pageOpen) { rev.value++; return; }
    nav.push(_fade(const ChatPage()));
  }

  static Future<List<ChatMsg>> list({int before = 0}) async {
    final r = await Engage.call('chat_list', {if (before > 0) 'before': before});
    return ((r['messages'] as List?) ?? const []).whereType<Map>().map(ChatMsg.from).toList();
  }

  static Future<ChatMsg> send(String text) async {
    final r = await Engage.call('chat_send', {'text': text});
    final m = r['message'];
    return m is Map ? ChatMsg.from(m) : ChatMsg(0, 'user', text, 'text', DateTime.now());
  }
}
