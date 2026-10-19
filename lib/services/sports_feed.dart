part of '../main.dart';

// ════════════════════════════════════════════════════════════════════
//  SportsFeed — يقرأ خلاصة المباريات المنشورة على GitHub Pages
//
//  • التطبيق لا يتصل بـ API-Football إطلاقاً، ولا يحمل أي مفتاح.
//    خادم صغير مجاني (GitHub Actions) يجلب البيانات مرة واحدة للجميع
//    وينشر ملف matches.json — كل المستخدمين يقرؤون نفس الملف.
//  • الرابط من Firestore: app_config/remote_config → sports_feed
//    (أو الثابت kSportsFeed) مثال: https://USER.github.io/totv-sports
//  • التحديث: كل 90 ثانية أثناء وجود مباراة جارية وصفحة الرياضة ظاهرة،
//    وكل 5 دقائق في غير ذلك — مع نسخة محلية تعمل بلا إنترنت.
// ════════════════════════════════════════════════════════════════════

class FxTeam {
  final int id;
  final String name, ar, logo;
  const FxTeam(this.id, this.name, this.ar, this.logo);
  String get label => ar.isNotEmpty ? ar : name;
  factory FxTeam.fromJson(Map j) => FxTeam(
      (j['id'] as num?)?.toInt() ?? 0, '${j['n'] ?? ''}', '${j['ar'] ?? ''}', '${j['logo'] ?? ''}');
}

class FxLeague {
  final int id, order;
  final String ar, logo;
  const FxLeague(this.id, this.ar, this.logo, this.order);
}

class FxMatch {
  final int id, lg, ts;
  final String st, rd, venue;
  final int? el, gh, ga;
  final bool imp;
  final FxTeam h, a;
  final List<String> ch;
  const FxMatch({required this.id, required this.lg, required this.ts, required this.st,
      required this.rd, required this.venue, this.el, this.gh, this.ga,
      required this.imp, required this.h, required this.a, required this.ch});

  factory FxMatch.fromJson(Map j) => FxMatch(
        id: (j['id'] as num).toInt(), lg: (j['lg'] as num).toInt(), ts: (j['ts'] as num).toInt(),
        st: '${j['st'] ?? 'NS'}', rd: '${j['rd'] ?? ''}', venue: '${j['venue'] ?? ''}',
        el: (j['el'] as num?)?.toInt(), gh: (j['gh'] as num?)?.toInt(), ga: (j['ga'] as num?)?.toInt(),
        imp: j['imp'] == true,
        h: FxTeam.fromJson(j['h'] as Map), a: FxTeam.fromJson(j['a'] as Map),
        ch: ((j['ch'] as List?) ?? const []).map((e) => '$e').toList(),
      );

  static const _liveSt = {'1H', 'HT', '2H', 'ET', 'BT', 'P', 'LIVE', 'INT'};
  DateTime get kick => DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  bool get isLive => _liveSt.contains(st);
  bool get isDone => st == 'FT' || st == 'AET' || st == 'PEN';
  bool get isOff  => const {'PST', 'CANC', 'ABD', 'AWD', 'WO', 'SUSP'}.contains(st);
  int  get minsToKick => kick.difference(DateTime.now()).inMinutes;
  /// يمكن المشاهدة: جارية أو تبدأ خلال 30 دقيقة
  bool get watchable => isLive || (!isDone && !isOff && minsToKick <= 30 && minsToKick > -150);

  String get time {
    final k = kick;
    return '${k.hour.toString().padLeft(2, '0')}:${k.minute.toString().padLeft(2, '0')}';
  }

  /// تُعرض بالاتجاه LTR والمستضيف على اليمين (RTL) → أهداف الضيف أولاً من اليسار
  String get score => '${ga ?? 0} - ${gh ?? 0}';

  String get liveLabel {
    if (st == 'HT') return 'استراحة';
    if (st == 'P')  return 'ركلات الترجيح';
    if (st == 'ET') return el != null ? 'إضافي $el\'' : 'وقت إضافي';
    return el != null ? '$el\'' : 'مباشر';
  }

  String get offLabel => switch (st) {
        'PST' => 'مؤجلة',
        'CANC' => 'ملغاة',
        'ABD' => 'متوقفة',
        'SUSP' => 'معلّقة',
        _ => 'انتهت',
      };
}

class SportsFeed {
  static final ValueNotifier<int> rev = ValueNotifier(0);
  static List<FxMatch> matches = [];
  static Map<int, FxLeague> leagues = {};
  static Map<String, List<String>> channels = {};
  static int updated = 0;
  static bool loading = false;
  static String error = '';
  static DateTime? _fetchedAt;
  static bool _cacheTried = false;

  static const _kCache = 'sports_feed_v1';
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
    responseType: ResponseType.plain,
  ));

  static String get base => RC.sportsFeed.trim().replaceAll(RegExp(r'/+$'), '');
  static bool get configured => base.isNotEmpty;
  static bool get hasLive => matches.any((m) => m.isLive);
  static String url(String rel) =>
      rel.isEmpty ? '' : (rel.startsWith('http') ? rel : '$base/$rel');

  static Future<void> load({bool force = false}) async {
    if (!configured) { error = 'not_configured'; rev.value++; return; }
    if (loading) return;
    final age = _fetchedAt == null ? 1 << 30 : DateTime.now().difference(_fetchedAt!).inSeconds;
    if (!force && matches.isNotEmpty && age < (hasLive ? 90 : 300)) return;

    loading = true;
    if (!_cacheTried) { _cacheTried = true; await _loadCache(); }
    rev.value++;
    try {
      // نفس الرابط لكل المستخدمين خلال دقيقتين → يُخدم من ذاكرة CDN
      final bucket = DateTime.now().millisecondsSinceEpoch ~/ 120000;
      final r = await _dio.get('$base/matches.json', queryParameters: {'b': bucket});
      final raw = r.data is String ? r.data as String : jsonEncode(r.data);
      _parse(jsonDecode(raw) as Map);
      _fetchedAt = DateTime.now();
      error = '';
      try { (await SPref.i).setString(_kCache, raw); } catch (_) {}
    } catch (e) {
      debugPrint('[sports_feed] $e');
      if (matches.isEmpty) error = 'network';
    }
    loading = false;
    rev.value++;
  }

  static Future<void> _loadCache() async {
    try {
      final raw = (await SPref.i).getString(_kCache);
      if (raw != null && raw.isNotEmpty) _parse(jsonDecode(raw) as Map);
    } catch (_) {}
  }

  static void _parse(Map j) {
    updated = (j['updated'] as num?)?.toInt() ?? 0;
    final lg = <int, FxLeague>{};
    (j['leagues'] as Map? ?? {}).forEach((k, v) {
      final id = int.tryParse('$k') ?? 0;
      lg[id] = FxLeague(id, '${v['ar'] ?? ''}', '${v['logo'] ?? ''}', (v['order'] as num?)?.toInt() ?? 99);
    });
    leagues = lg;
    final ch = <String, List<String>>{};
    (j['channels'] as Map? ?? {}).forEach((k, v) {
      ch['$k'] = ((v as List?) ?? const []).map((e) => '$e').toList();
    });
    channels = ch;
    matches = ((j['matches'] as List?) ?? const [])
        .map((e) { try { return FxMatch.fromJson(e as Map); } catch (_) { return null; } })
        .whereType<FxMatch>()
        .toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
  }

  // ── مطابقة القناة الناقلة مع قنوات السيرفر ─────────────────────
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9؀-ۿ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// القنوات المصرّح بها للمستخدم والمطابقة للمباراة — الأفضل أولاً.
  /// [exact] = true إن كانت الأولى قناة محدّدة يدوياً لهذه المباراة.
  static ({List<dynamic> list, bool exact}) channelsFor(FxMatch m) {
    final all = AppState.allLive
        .where((c) => Sub.liveAllowed((c['name'] ?? '').toString()))
        .toList();
    final out  = <dynamic>[];
    final seen = <String>{};
    bool exact = false;

    void add(String kw, {bool override = false}) {
      final k = _norm(kw);
      if (k.isEmpty) return;
      final variants = {k, k.replaceAll('sports', 'sport')};
      final res = variants.map((v) => RegExp('(^| )${RegExp.escape(v)}(?![0-9])')).toList();
      final compact = k.replaceAll(' ', '');
      final resC = RegExp('${RegExp.escape(compact)}(?![0-9])');
      for (final c in all) {
        final n = _norm('${c['name'] ?? ''}');
        if (res.any((r) => r.hasMatch(n)) || resC.hasMatch(n.replaceAll(' ', ''))) {
          final id = '${c['stream_id'] ?? c['name']}';
          if (seen.add(id)) {
            if (override && out.isEmpty) exact = true;
            out.add(c);
          }
        }
      }
    }

    for (final o in m.ch) add(o, override: true);
    for (final kw in channels['${m.lg}'] ?? channels['default'] ?? const <String>[]) add(kw);
    return (list: out.take(12).toList(), exact: exact);
  }
}
