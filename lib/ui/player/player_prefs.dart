part of '../../main.dart';

// ════════════════════════════════════════════════════════════════════
//  تفضيلات المشغّل + القنوات المفضلة والأخيرة + علامات تخطي المقدمة
// ════════════════════════════════════════════════════════════════════

class PlayerPrefs {
  PlayerPrefs._();
  static bool _loaded = false;

  static const _kFit = 'pp_fit', _kSub = 'pp_sub_size', _kSubBg = 'pp_sub_bg', _kSaver = 'pp_saver',
      _kEngine = 'pp_engine', _kFav = 'pp_fav_ch', _kRecent = 'pp_recent_ch', _kAutoPip = 'pp_auto_pip';

  /// 0 = الحجم الأصلي · 1 = ملء الشاشة · 2 = تمديد
  static int fit = 0;
  /// حجم الترجمة: 0 صغير · 1 متوسط · 2 كبير
  static int subSize = 1;
  static bool subBg = false;
  static bool dataSaver = false;
  static bool autoPip = true;
  /// auto | native | mpv
  static String engine = 'auto';
  static List<String> favorites = [];
  static List<String> recent = [];

  /// يُستدعى عند تغيّر المفضلة/الأخيرة (لتحديث قسم القنوات)
  static final ValueNotifier<int> rev = ValueNotifier(0);

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final p = await SPref.i;
      fit = p.getInt(_kFit) ?? 0;
      subSize = p.getInt(_kSub) ?? 1;
      subBg = p.getBool(_kSubBg) ?? false;
      dataSaver = p.getBool(_kSaver) ?? false;
      autoPip = p.getBool(_kAutoPip) ?? true;
      engine = p.getString(_kEngine) ?? 'auto';
      favorites = p.getStringList(_kFav) ?? [];
      recent = p.getStringList(_kRecent) ?? [];
      _loaded = true;
    } catch (e) { debugPrint('[player_prefs] $e'); }
  }

  static Future<void> _save(Future<bool> Function(SharedPreferences p) f) async {
    try { await f(await SPref.i); } catch (_) {}
  }

  static void setFit(int v) { fit = v; _save((p) => p.setInt(_kFit, v)); }
  static void setSubSize(int v) { subSize = v; _save((p) => p.setInt(_kSub, v)); }
  static void setSubBg(bool v) { subBg = v; _save((p) => p.setBool(_kSubBg, v)); }
  static void setDataSaver(bool v) { dataSaver = v; _save((p) => p.setBool(_kSaver, v)); }
  static void setAutoPip(bool v) { autoPip = v; _save((p) => p.setBool(_kAutoPip, v)); }
  static void setEngine(String v) { engine = v; _save((p) => p.setString(_kEngine, v)); }

  static String chId(dynamic ch) => ch is Map ? '${ch['stream_id'] ?? ''}' : '';

  static bool isFav(dynamic ch) { final id = chId(ch); return id.isNotEmpty && favorites.contains(id); }

  static bool toggleFav(dynamic ch) {
    final id = chId(ch);
    if (id.isEmpty) return false;
    final on = !favorites.contains(id);
    on ? favorites.insert(0, id) : favorites.remove(id);
    _save((p) => p.setStringList(_kFav, favorites));
    rev.value++;
    return on;
  }

  static void addRecent(dynamic ch) {
    final id = chId(ch);
    if (id.isEmpty) return;
    recent.remove(id);
    recent.insert(0, id);
    if (recent.length > 15) recent = recent.sublist(0, 15);
    _save((p) => p.setStringList(_kRecent, recent));
    rev.value++;
  }

  /// يحوّل قائمة معرّفات إلى قنوات من قائمة الاشتراك الحالية (المسموح بها فقط)
  static List<dynamic> resolve(List<String> ids) {
    if (ids.isEmpty) return const [];
    final byId = <String, dynamic>{
      for (final c in AppState.allLive) '${c['stream_id'] ?? ''}': c,
    };
    return [
      for (final id in ids)
        if (byId[id] != null && Sub.liveAllowed('${byId[id]['name'] ?? ''}')) byId[id],
    ];
  }

  static double get subFontSize => const [17.0, 22.0, 28.0][subSize.clamp(0, 2)];
}

// ════════════════════════════════════════════════════════════════════
//  علامات تخطي المقدمة والشارة لكل مسلسل (Firestore: skip_markers/{seriesId})
//   intro_start / intro_end  ← بالثواني من بداية الحلقة
//   credits_left             ← بالثواني قبل نهاية الحلقة (بداية الشارة)
//  يضبطها الأدمن من داخل المشغّل نفسه (الإعدادات ← أدوات الأدمن).
// ════════════════════════════════════════════════════════════════════
class SkipMarkers {
  final int introStart, introEnd, creditsLeft;
  const SkipMarkers({this.introStart = 0, this.introEnd = 0, this.creditsLeft = 0});

  bool get hasIntro => introEnd > introStart && introEnd > 0;

  static final Map<String, SkipMarkers> _cache = {};

  static Future<SkipMarkers?> fetch(String seriesId) async {
    if (seriesId.isEmpty) return null;
    final c = _cache[seriesId];
    if (c != null) return c;
    try {
      final d = await FirebaseFirestore.instance.collection('skip_markers').doc(seriesId)
          .get().timeout(const Duration(seconds: 6));
      final m = d.data();
      if (m == null) return null;
      int n(String k) => (m[k] as num?)?.toInt() ?? 0;
      final r = SkipMarkers(introStart: n('intro_start'), introEnd: n('intro_end'), creditsLeft: n('credits_left'));
      _cache[seriesId] = r;
      return r;
    } catch (e) {
      debugPrint('[skip_markers] $e');
      return null;
    }
  }

  static Future<bool> save(String seriesId, Map<String, int> fields) async {
    if (seriesId.isEmpty) return false;
    try {
      await FirebaseFirestore.instance.collection('skip_markers').doc(seriesId)
          .set({...fields, 'at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      final o = _cache[seriesId] ?? const SkipMarkers();
      _cache[seriesId] = SkipMarkers(
        introStart: fields['intro_start'] ?? o.introStart,
        introEnd: fields['intro_end'] ?? o.introEnd,
        creditsLeft: fields['credits_left'] ?? o.creditsLeft,
      );
      return true;
    } catch (e) {
      debugPrint('[skip_markers] save $e');
      return false;
    }
  }
}
