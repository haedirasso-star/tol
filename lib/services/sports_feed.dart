part of '../main.dart';

// ════════════════════════════════════════════════════════════════════
//  SportsFeed — يقرأ خلاصة المباريات المنشورة على GitHub Pages
//
//  • التطبيق لا يتصل بـ API-Football إطلاقاً، ولا يحمل أي مفتاح.
//    خادم صغير مجاني (GitHub Actions) يجلب مباريات الأسبوع مرة واحدة
//    للجميع وينشر matches.json — كل المستخدمين يقرؤون نفس الملف.
//  • الرابط من Firestore: app_config/remote_config → sports_feed
//    (أو الثابت kSportsFeed) مثال: https://USER.github.io/totv-sports
//  • لا نتائج ولا أهداف: الحالة تُحسب محلياً من وقت الانطلاق
//    (عدّاد تنازلي ← «تُلعب الآن» ← تختفي بعد نهايتها).
// ════════════════════════════════════════════════════════════════════

Color? _hexColor(Object? v) {
  final s = '${v ?? ''}'.replaceAll('#', '').trim();
  if (s.length != 6) return null;
  final n = int.tryParse(s, radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

class FxTeam {
  final int id;
  final String name, ar, logo;
  final Color? color;      // اللون الغالب في شعار النادي (يُحسب على الخادم)
  const FxTeam(this.id, this.name, this.ar, this.logo, this.color);
  String get label => ar.isNotEmpty ? ar : name;
  factory FxTeam.fromJson(Map j) => FxTeam(
      (j['id'] as num?)?.toInt() ?? 0, '${j['n'] ?? ''}', '${j['ar'] ?? ''}',
      '${j['logo'] ?? ''}', _hexColor(j['c']));
}

class FxLeague {
  final int id, order;
  final String ar, logo;
  final Color? color;
  const FxLeague(this.id, this.ar, this.logo, this.order, this.color);
}

class FxMatch {
  final int id, lg, ts;
  final String st, rd, venue, poster;
  final bool imp;
  final FxTeam h, a;
  final List<String> ch;
  const FxMatch({required this.id, required this.lg, required this.ts, required this.st,
      required this.rd, required this.venue, required this.poster,
      required this.imp, required this.h, required this.a, required this.ch});

  factory FxMatch.fromJson(Map j) => FxMatch(
        id: (j['id'] as num).toInt(), lg: (j['lg'] as num).toInt(), ts: (j['ts'] as num).toInt(),
        st: '${j['st'] ?? 'NS'}', rd: '${j['rd'] ?? ''}', venue: '${j['venue'] ?? ''}',
        poster: '${j['poster'] ?? ''}',
        imp: j['imp'] == true,
        h: FxTeam.fromJson(j['h'] as Map), a: FxTeam.fromJson(j['a'] as Map),
        ch: ((j['ch'] as List?) ?? const []).map((e) => '$e').toList(),
      );

  /// نسخة بصورة عرض مختلفة (تعديل الأدمن من «بطاقات المباريات»)
  FxMatch withPoster(String p) => FxMatch(id: id, lg: lg, ts: ts, st: st, rd: rd, venue: venue,
      poster: p, imp: imp, h: h, a: a, ch: ch);

  static const _liveSt = {'1H', 'HT', '2H', 'ET', 'BT', 'P', 'LIVE', 'INT'};
  static const _doneSt = {'FT', 'AET', 'PEN'};
  static const _offSt  = {'PST', 'CANC', 'ABD', 'AWD', 'WO', 'SUSP'};

  DateTime get kick => DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  int get secsToKick => kick.difference(DateTime.now()).inSeconds;
  int get minsToKick => secsToKick ~/ 60;

  bool get isOff  => _offSt.contains(st);
  /// تُلعب الآن — من الحالة إن وُجدت، وإلا من الوقت (115 دقيقة بعد الانطلاق)
  bool get isLive => !isOff && (_liveSt.contains(st) ||
      (!_doneSt.contains(st) && secsToKick <= 0 && secsToKick > -115 * 60));
  bool get isDone => _doneSt.contains(st) || (!isLive && !isOff && secsToKick <= -115 * 60);
  bool get upcoming => !isOff && !isLive && !isDone;
  /// يمكن المشاهدة: تُلعب الآن أو تبدأ خلال 30 دقيقة
  bool get watchable => isLive || (upcoming && minsToKick <= 30);

  String get time {
    final k = kick;
    return '${k.hour.toString().padLeft(2, '0')}:${k.minute.toString().padLeft(2, '0')}';
  }

  static const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو',
      'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  static const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  /// «19 أكتوبر 2026»
  String get dateLabel => '${kick.day} ${_months[kick.month - 1]} ${kick.year}';
  String get weekday => _weekdays[kick.weekday - 1];

  String get offLabel => switch (st) {
        'PST' => 'مؤجلة',
        'CANC' => 'ملغاة',
        'ABD' => 'متوقفة',
        'SUSP' => 'معلّقة',
        _ => 'انتهت',
      };
}

/// إعلان مباراة (صورة يرفعها المشرف يومياً في مجلد promos)
class MatchPromo {
  final String img, title;
  final int ts, fixture;
  final bool ad;   // إعلان عام (شعار/عرض) — بلا مباراة ولا عدّاد
  const MatchPromo({required this.img, required this.ts, required this.fixture, required this.title, this.ad = false});
  DateTime? get kick => ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : null;
  FxMatch? get match {
    if (fixture == 0) return null;
    for (final m in SportsFeed.matches) { if (m.id == fixture) return m; }
    return null;
  }
}

class SportsFeed {
  static final ValueNotifier<int> rev = ValueNotifier(0);
  /// طلب فتح «القنوات المباشرة» داخل صفحة الرياضة (حين لا توجد قناة ناقلة)
  static final ValueNotifier<int> openChannels = ValueNotifier(0);
  static List<FxMatch> matches = [];
  static List<FxMatch> _raw = [];        // كما وصلت من الخلاصة (قبل تعديلات الأدمن)
  static DateTime? liveAt;               // آخر تحديث لقائمة قنوات السيرفر
  static bool _liveBusy = false;
  static final ValueNotifier<int> liveRev = ValueNotifier(0);   // تغيّرت قائمة القنوات (بلا إعادة بناء بقية التطبيق)
  /// يحدّث قائمة القنوات المباشرة إن مرّ عليها أكثر من 10 دقائق (أرقام القنوات تتغيّر في السيرفر)
  static Future<void> refreshLiveIfStale({int minutes = 10}) async {
    if (_liveBusy) return;
    if (AppState.allLive.isNotEmpty && liveAt != null && DateTime.now().difference(liveAt!).inMinutes < minutes) return;
    _liveBusy = true;
    try {
      final fresh = await Api.getList('get_live_streams', force: true).timeout(const Duration(seconds: 20));
      if (fresh.isNotEmpty) { AppState.allLive = fresh; liveAt = DateTime.now(); liveRev.value++; }
    } catch (_) {}
    _liveBusy = false;
  }
  static List<MatchPromo> promos = [];
  static Map<int, FxLeague> leagues = {};
  static Map<String, List<String>> channels = {};
  static int updated = 0;
  static bool loading = false;
  static String error = '';
  static DateTime? _fetchedAt;
  static bool _cacheTried = false;

  static const _kCache = 'sports_feed_v2';
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
    responseType: ResponseType.plain,
  ));

  static String get base => RC.sportsFeed.trim().replaceAll(RegExp(r'/+$'), '');
  static bool get configured => base.isNotEmpty;
  static String url(String rel) =>
      rel.isEmpty ? '' : (rel.startsWith('http') ? rel : '$base/$rel');

  /// المباريات القادمة أو الجارية (المنتهية تُخفى — لا نعرض نتائج)
  static List<FxMatch> get active => matches.where((m) => !m.isDone && !m.isOff).toList();

  /// إعلانات المباريات الصالحة الآن (حتى ساعتين بعد الانطلاق)
  static List<MatchPromo> get activePromos {
    final now = DateTime.now();
    return promos.where((p) {
      final k = p.kick;
      return k == null || k.isAfter(now.subtract(const Duration(hours: 2)));
    }).toList();
  }

  static Future<void> load({bool force = false}) async {
    MatchOverrides.ensure();
    if (!configured) { error = 'not_configured'; rev.value++; return; }
    if (loading) return;
    final age = _fetchedAt == null ? 1 << 30 : DateTime.now().difference(_fetchedAt!).inSeconds;
    if (!force && matches.isNotEmpty && age < 600) return;   // الجدول يتغيّر نادراً

    loading = true;
    if (!_cacheTried) { _cacheTried = true; await _loadCache(); }
    rev.value++;
    try {
      // نفس الرابط لكل المستخدمين خلال 10 دقائق → يُخدم من ذاكرة CDN
      final bucket = DateTime.now().millisecondsSinceEpoch ~/ 600000;
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
      lg[id] = FxLeague(id, '${v['ar'] ?? ''}', '${v['logo'] ?? ''}',
          (v['order'] as num?)?.toInt() ?? 99, _hexColor(v['color']));
    });
    leagues = lg;
    final ch = <String, List<String>>{};
    (j['channels'] as Map? ?? {}).forEach((k, v) {
      ch['$k'] = ((v as List?) ?? const []).map((e) => '$e').toList();
    });
    channels = ch;
    _raw = ((j['matches'] as List?) ?? const [])
        .map((e) { try { return FxMatch.fromJson(e as Map); } catch (_) { return null; } })
        .whereType<FxMatch>()
        .toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
    matches = MatchOverrides.apply(_raw);
    promos = ((j['promos'] as List?) ?? const []).map((e) {
      try {
        final m = e as Map;
        return MatchPromo(img: url('${m['img'] ?? ''}'), ts: (m['ts'] as num?)?.toInt() ?? 0,
            fixture: (m['fx'] as num?)?.toInt() ?? 0, title: '${m['title'] ?? ''}',
            ad: m['ad'] == 1 || m['ad'] == true);
      } catch (_) { return null; }
    }).whereType<MatchPromo>().where((p) => p.img.isNotEmpty).toList();
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


// ════════════════════════════════════════════════════════════════════
//  ✏️ تعديلات الأدمن على بطاقات المباريات  (app_config/match_overrides)
//  لكل مباراة: m<رقم المباراة> = {
//     poster     صورة عرض بديلة (https)
//     stream_id  رقم القناة في السيرفر (الأدق)
//     name       اسم القناة في السيرفر (احتياط إن تغيّر الرقم)
//     url        رابط تشغيل مباشر (اختياري — يتقدّم على القناة)
//     label      اسم يظهر للمستخدم (اختياري)
//  }
// ════════════════════════════════════════════════════════════════════
class MatchOverrides {
  MatchOverrides._();
  static Map<String, dynamic> _d = {};
  static StreamSubscription? _sub;

  static void ensure() {
    if (_sub != null) return;
    try {
      _sub = FirebaseFirestore.instance.collection('app_config').doc('match_overrides')
          .snapshots().listen((s) {
        _d = s.data() ?? {};
        SportsFeed.matches = apply(SportsFeed._raw);
        SportsFeed.rev.value++;
      }, onError: (e) => debugPrint('[overrides] $e'));
    } catch (e) { debugPrint('[overrides] $e'); }
  }

  static Map<String, dynamic>? of(int id) {
    final v = _d['m$id'];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  static List<FxMatch> apply(List<FxMatch> raw) => raw.map((m) {
    final p = '${of(m.id)?['poster'] ?? ''}'.trim();
    return p.startsWith('https://') ? m.withPoster(p) : m;
  }).toList();

  /// القناة التي حدّدها الأدمن لهذه المباراة — من قائمة السيرفر الحالية (روابط جديدة)
  static dynamic pinned(int id) {
    final o = of(id);
    if (o == null) return null;
    final url = '${o['url'] ?? ''}'.trim();
    final label = '${o['label'] ?? ''}'.trim();
    if (url.startsWith('http')) {
      return {'name': label.isNotEmpty ? label : '${o['name'] ?? 'البث الرئيسي'}', '_direct': url, '_pinned': true};
    }
    final sid = '${o['stream_id'] ?? ''}'.trim();
    final name = '${o['name'] ?? ''}'.trim().toLowerCase();
    dynamic hit;
    if (sid.isNotEmpty) {
      for (final c in AppState.allLive) { if ('${c['stream_id']}' == sid) { hit = c; break; } }
    }
    if (hit == null && name.isNotEmpty) {
      for (final c in AppState.allLive) { if ('${c['name'] ?? ''}'.trim().toLowerCase() == name) { hit = c; break; } }
    }
    if (hit == null) return null;
    return {...Map<String, dynamic>.from(hit as Map), '_pinned': true, if (label.isNotEmpty) '_label': label};
  }
}

// ════════════════════════════════════════════════════════════════════
//  📡 تقارير القنوات المعطّلة — تصل للأدمن ليعرف أي قناة لا تعمل الآن
//  (تقرير واحد لكل قناة في كل جلسة — لا إغراق)
// ════════════════════════════════════════════════════════════════════
class ChannelReport {
  ChannelReport._();
  static final _sent = <String>{};
  static void add(String name, String id, String reason) {
    final k = id.isEmpty ? name : id;
    if (k.isEmpty || !_sent.add(k)) return;
    try {
      final n = DateTime.now();
      FirebaseFirestore.instance.collection('channel_reports').add({
        'name': name, 'cid': id,
        'reason': reason.length > 160 ? reason.substring(0, 160) : reason,
        'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'day': '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}',
        'ver': AppVersion.version,
        'at': FieldValue.serverTimestamp(),
      }).then((_) {}, onError: (_) {});
    } catch (_) {}
  }
}
