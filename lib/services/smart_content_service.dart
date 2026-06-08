part of '../main.dart';

// ════════════════════════════════════════════════════════════════
//  SmartContentService — نظام ذكي شامل لجلب المحتوى
//  ✅ 1. Server-side fetching مع كاش ثلاثي الطبقات
//  ✅ 2. Stream listeners لـ Firestore (تحديث فوري)
//  ✅ 3. Poster prefetch ذكي ومتوازي
//  ✅ 4. Fallback Trailer Logic (YouTube/TMDB) عند فشل الرابط
//  ✅ 5. Check-then-write للمستخدم الجديد (لا تعارض)
//  ✅ 6. مستمع مستمر لبيانات المستخدم الشخصية
// ════════════════════════════════════════════════════════════════

// ────────────────────────────────────────────────────────────────
//  UserDataWatcher — مستمع مستمر لبيانات المستخدم في Firestore
//  يستجيب فوراً لأي تغيير من لوحة الإدارة
// ────────────────────────────────────────────────────────────────
class UserDataWatcher {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static StreamSubscription<DocumentSnapshot>? _userSub;

  // بث التغييرات للـ UI
  static final _userDataCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get userDataStream =>
      _userDataCtrl.stream;

  // آخر بيانات معروفة
  static Map<String, dynamic> _lastData = {};
  static Map<String, dynamic> get lastData => Map.unmodifiable(_lastData);
  // آخر سيرفر معروف — للمقارنة الصحيحة بدون loop
  static String _lastKnownServer = '';

  /// يبدأ الاستماع المستمر لبيانات المستخدم
  static void startListening(String uid) {
    _userSub?.cancel();
    _userSub = _db.collection('users').doc(uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      _lastData = data;
      _userDataCtrl.add(data);

      // ── التحقق من تغيير السيرفر في الوقت الفعلي ──
      // نقارن فقط مع آخر قيمة معروفة — لا نقارن مع RC.serverHost
      // لأن _beat() يكتب في users مما يُطلق الـ snapshot باستمرار
      final userServer = data['server_host']?.toString() ?? '';
      if (userServer.isNotEmpty &&
          userServer != _lastKnownServer &&
          _lastKnownServer.isNotEmpty) {
        // السيرفر تغيّر فعلياً من لوحة الإدارة
        debugPrint('UserDataWatcher: server changed $userServer → reload');
        _lastKnownServer = userServer;
        // إعادة تحميل بدون clearAll لتجنب التجميد
        AppState.isLoaded = false;
        unawaited(AppState.loadAll(force: true));
      } else if (userServer.isNotEmpty && _lastKnownServer.isEmpty) {
        _lastKnownServer = userServer;
      }

      // ── التحقق من تعليق الحساب ──
      if (data['status']?.toString() == 'banned') {
        _onAccountBanned?.call();
      }

      // ── مزامنة الاشتراك إذا تغيّر username أو password فقط ──
      // لا نكتب إلا عند تغيير حقيقي لمنع الحلقة المفرغة مع _beat()
      final sub = data['subscription'] as Map<String, dynamic>?;
      if (sub != null) {
        final plan  = sub['plan']?.toString() ?? Sub.kFree;
        final uname = sub['username']?.toString() ?? '';
        final upass = sub['password']?.toString() ?? '';
        // تحقق صارم: تغيّر فعلي في بيانات الدخول
        final changed = uname.isNotEmpty &&
            upass.isNotEmpty &&
            plan != Sub.kFree &&
            (uname != Sub.username || upass != Sub.password);
        if (changed) {
          final exTs = sub['expiry_date'];
          DateTime? expiry;
          if (exTs is Timestamp) expiry = exTs.toDate();
          if (expiry == null || expiry.isAfter(DateTime.now())) {
            debugPrint('UserDataWatcher: sub credentials changed → restore');
            unawaited(Sub._restoreDirectly(
                username: uname, password: upass,
                expiry: expiry, plan: plan));
          }
        }
      }

      // ── مزامنة free_watch ──
      final fw = data['free_watch'] as Map<String, dynamic>?;
      if (fw != null) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        if (fw['date'] == today) {
          final fbMs = (fw['used_ms'] as num?)?.toInt() ?? 0;
          GuestSession._syncFromRemote(fbMs);
        }
      }
    }, onError: (e) {
      debugPrint('UserDataWatcher error: $e');
    });
  }

  static void stopListening() {
    _userSub?.cancel();
    _userSub = null;
    _lastData = {};
  }

  static VoidCallback? _onAccountBanned;
  static void setOnBanned(VoidCallback cb) => _onAccountBanned = cb;
}

// ────────────────────────────────────────────────────────────────
//  SmartPosterCache — كاش ذكي للبوسترات بثلاث طبقات
//  - طبقة 1: ذاكرة التطبيق (HashMap سريع — فوري)
//  - طبقة 2: SharedPreferences (ثابت بين الجلسات — ms)
//  - طبقة 3: CachedNetworkImage (ذاكرة القرص — تلقائي)
// ────────────────────────────────────────────────────────────────
class SmartPosterCache {
  static final Map<String, String> _memCache = {};
  static int _prefetchCount = 0;
  static const _maxPrefetch = 80;
  static const _kPosterMap  = 'spc_poster_map_v2';
  static bool   _diskLoaded = false;

  /// تحميل روابط البوسترات المحفوظة مسبقاً من القرص (عند بدء التطبيق)
  static Future<void> loadFromDisk() async {
    if (_diskLoaded) return;
    _diskLoaded = true;
    try {
      final p   = await SPref.i;
      final raw = p.getString(_kPosterMap);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((k, v) => _memCache[k] = v.toString());
      debugPrint('SmartPosterCache: loaded ${_memCache.length} posters from disk');
    } catch (e) { debugPrint('[smart_content_service] $e'); }
  }

  /// حفظ خريطة البوسترات على القرص (في الخلفية)
  static void _saveToDisk() {
    Future.microtask(() async {
      try {
        final p = await SPref.i;
        // نحفظ أول 300 عنصر فقط للحفاظ على حجم معقول
        final subset = Map.fromEntries(_memCache.entries.take(300));
        await p.setString(_kPosterMap, jsonEncode(subset));
      } catch (e) { debugPrint('[smart_content_service] $e'); }
    });
  }

  /// حفظ رابط البوستر في الذاكرة والقرص
  static void put(String contentId, String url) {
    if (contentId.isEmpty || url.isEmpty) return;
    if (_memCache[contentId] == url) return; // تجنب الكتابة المتكررة
    _memCache[contentId] = url;
    _saveToDisk();
  }

  /// جلب رابط البوستر من الذاكرة (فوري)
  static String? get(String contentId) => _memCache[contentId];

  /// تحميل البوسترات مسبقاً بذكاء (أولوية للمحتوى الأحدث + حفظ الروابط)
  static Future<void> prefetchAll(BuildContext ctx, {
    required List<dynamic> movies,
    required List<dynamic> series,
    required List<dynamic> live,
  }) async {
    if (_prefetchCount > 0) return; // تجنب التكرار
    _prefetchCount++;

    // Step 1: حفظ الروابط في الذاكرة فوراً (بدون تحميل صور)
    // هذا يسرّع فتح القوائم فوراً
    for (final item in [...movies.take(200), ...series.take(150), ...live.take(100)]) {
      final url = _extractImageUrl(item);
      if (url.isEmpty) continue;
      final id  = item['stream_id']?.toString() ?? item['id']?.toString() ?? '';
      if (id.isNotEmpty) _memCache[id] = url;
    }
    // حفظ الروابط على القرص (للجلسة القادمة)
    _saveToDisk();

    // Step 2: تحميل صور الأولوية في الخلفية
    final priority = <dynamic>[];
    final recentIds = WatchHistory.recent
        .map((h) => h['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final id in recentIds) {
      final found = [...movies, ...series, ...live]
          .firstWhere((item) =>
              item['stream_id']?.toString() == id ||
              item['id']?.toString() == id,
              orElse: () => null);
      if (found != null) priority.add(found);
    }

    priority.addAll(movies.take(25));
    priority.addAll(series.take(20));
    priority.addAll(live.take(15));

    // تحميل متوازي بحزم متوسطة
    const batchSize = 12;
    for (int i = 0; i < priority.length && i < _maxPrefetch; i += batchSize) {
      final batch = priority.skip(i).take(batchSize);
      final futures = batch.map((item) async {
        final url = _extractImageUrl(item);
        if (url.isEmpty) return;
        try {
          await precacheImage(
            CachedNetworkImageProvider(
              _imgUrl(url),
              maxWidth: 200,
              maxHeight: 300,
            ),
            ctx,
          ).timeout(const Duration(seconds: 5));
        } catch (e) { debugPrint('[smart_content_service] $e'); }
      });
      await Future.wait(futures);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  static String _extractImageUrl(dynamic item) {
    final icon  = item['stream_icon']?.toString() ?? '';
    final cover = item['cover']?.toString()       ?? '';
    return icon.isNotEmpty ? icon : cover;
  }

  static void clear() {
    _memCache.clear();
    _prefetchCount = 0;
  }
}

// ────────────────────────────────────────────────────────────────
//  TrailerFallbackService — خدمة البديل الذكي للتشغيل
//  عند فشل رابط الفيلم، يبحث تلقائياً عن Trailer من TMDB/YouTube
// ────────────────────────────────────────────────────────────────
class TrailerFallbackResult {
  final bool   found;
  final String trailerUrl;
  final String trailerKey; // YouTube key للتشغيل المضمّن
  final String source;     // 'youtube' | 'tmdb'
  const TrailerFallbackResult({
    this.found       = false,
    this.trailerUrl  = '',
    this.trailerKey  = '',
    this.source      = '',
  });
}

class TrailerFallbackService {
  static final Map<String, TrailerFallbackResult> _cache = {};

  /// يبحث عن trailer بكل الطرق المتاحة
  static Future<TrailerFallbackResult> findTrailer({
    required String title,
    required bool   isTv,
    String? tmdbId,
    String? searchKey,
  }) async {
    final cacheKey = '${isTv ? "tv" : "mv"}_$title';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    // ── محاولة 1: من tmdb_id إذا متوفر ──
    if (tmdbId != null && tmdbId.isNotEmpty) {
      final id = int.tryParse(tmdbId);
      if (id != null) {
        final key = await TMDB.getTrailerKey(id, isTv: isTv);
        if (key != null && key.isNotEmpty) {
          final result = TrailerFallbackResult(
            found:      true,
            trailerUrl: 'https://www.youtube.com/watch?v=$key',
            trailerKey: key,
            source:     'tmdb',
          );
          _cache[cacheKey] = result;
          return result;
        }
      }
    }

    // ── محاولة 2: البحث باسم المحتوى ──
    try {
      final key = await TMDB.getTrailerKeyByName(
          searchKey ?? title, isTv: isTv)
          .timeout(const Duration(seconds: 8));
      if (key != null && key.isNotEmpty) {
        final result = TrailerFallbackResult(
          found:      true,
          trailerUrl: 'https://www.youtube.com/watch?v=$key',
          trailerKey: key,
          source:     'youtube',
        );
        _cache[cacheKey] = result;
        return result;
      }
    } catch (e) { debugPrint('[smart_content_service] $e'); }

    // ── محاولة 3: البحث في YouTube مباشرة عبر TMDB search ──
    try {
      final searchResult = await TMDB.search(title, isTv: isTv)
          .timeout(const Duration(seconds: 6));
      final tmdbIdStr = searchResult['tmdb_id'] ?? '';
      if (tmdbIdStr.isNotEmpty) {
        final id = int.tryParse(tmdbIdStr);
        if (id != null) {
          final key = await TMDB.getTrailerKey(id, isTv: isTv);
          if (key != null && key.isNotEmpty) {
            final result = TrailerFallbackResult(
              found:      true,
              trailerUrl: 'https://www.youtube.com/watch?v=$key',
              trailerKey: key,
              source:     'tmdb_search',
            );
            _cache[cacheKey] = result;
            return result;
          }
        }
      }
    } catch (e) { debugPrint('[smart_content_service] $e'); }

    const notFound = TrailerFallbackResult(found: false);
    _cache[cacheKey] = notFound;
    return notFound;
  }

  static void clear() => _cache.clear();
}

// ────────────────────────────────────────────────────────────────
//  SmartContentLoader — محمّل المحتوى الذكي
//  يستبدل AppState._fetchFromServer بنسخة أسرع ومتوازية
// ────────────────────────────────────────────────────────────────
class SmartContentLoader {
  static bool _running = false;
  // ★ CancelToken — يُلغي جميع الطلبات الجارية عند الحاجة
  static CancelToken _cancelToken = CancelToken();

  /// إلغاء جميع الطلبات الجارية (عند تغيير الاشتراك / السيرفر)
  static void cancelAll() {
    if (!_cancelToken.isCancelled) _cancelToken.cancel('reset');
    _cancelToken = CancelToken();
    _running = false;
  }

  /// تحميل متوازي مع إعطاء الأولوية للمحتوى المرئي أولاً
  static Future<void> loadWithPriority({
    bool force = false,
    VoidCallback? onFirstBatch,
  }) async {
    if (_running && !force) return;
    if (AppState.isLoaded && !force) {
      onFirstBatch?.call();
      return;
    }
    if (force) {
      // إعادة إنشاء CancelToken عند force reload
      _cancelToken = CancelToken();
    }
    _running = true;

    // تحديد بيانات الاتصال
    final bool usePaid = Sub.isActive &&
        Sub.username.isNotEmpty &&
        Server.hasHost;
    final bool hasDefault = RC.hasDefaultServer;

    if (!usePaid && !hasDefault) {
      AppState.isLoaded = true;
      _running = false;
      return;
    }

    final u = usePaid ? Sub.username : RC.defaultUser;
    final p = usePaid ? Sub.password : RC.defaultPass;
    final h = usePaid ? null : RC.defaultHost;

    // ── المرحلة 1: جلب القوائم والفئات بالتوازي ──
    try {
      // أولاً: الفئات تُحمَّل فوراً (خفيفة وسريعة)
      final cats = await Future.wait([
        Server.fetchList('get_vod_categories',    username: u, password: p, hostOverride: h, cancelToken: _cancelToken),
        Server.fetchList('get_series_categories', username: u, password: p, hostOverride: h, cancelToken: _cancelToken),
        Server.fetchList('get_live_categories',   username: u, password: p, hostOverride: h, cancelToken: _cancelToken),
      ]).timeout(const Duration(seconds: 8));

      AppState.movieCats  = cats[0];
      AppState.seriesCats = cats[1];
      AppState.liveCats   = cats[2];

      // إشعار بأن الفئات جاهزة
      onFirstBatch?.call();
      AppState.onPartialLoad?.call();

      // ── المرحلة 2: جلب المحتوى الكامل بالتوازي ──
      final content = await Future.wait([
        Server.fetchList('get_vod_streams',  username: u, password: p, hostOverride: h,
            timeoutSec: 12, cancelToken: _cancelToken),
        Server.fetchList('get_series',       username: u, password: p, hostOverride: h,
            timeoutSec: 12, cancelToken: _cancelToken),
        Server.fetchList('get_live_streams', username: u, password: p, hostOverride: h,
            timeoutSec: 10, cancelToken: _cancelToken),
      ]);

      AppState.allMovies = content[0];
      AppState.allSeries = content[1];
      AppState.allLive   = content[2];
      AppState.isLoaded  = true;

      await AppState._saveToDisk();
      AppState.onPartialLoad?.call();

      debugPrint('SmartContentLoader: ✅ '
          'movies=${AppState.allMovies.length} '
          'series=${AppState.allSeries.length} '
          'live=${AppState.allLive.length}');
    } catch (e) {
      debugPrint('SmartContentLoader error: $e');
      AppState.isLoaded = true;
    }
    _running = false;
  }
}

// ────────────────────────────────────────────────────────────────
//  SafeUserWriter — كتابة بيانات المستخدم بأمان (check-then-write)
//  يمنع التعارض بين المستخدمين القدامى والجدد
// ────────────────────────────────────────────────────────────────
class SafeUserWriter {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// كتابة آمنة بدون await — لا تُجمّد تسجيل الدخول أبداً
  /// المنطق: اكتب أولاً بـ merge:true، ثم اقرأ واستعد الاشتراك في الخلفية
  static Future<bool> writeUserData({
    required String uid,
    required String method,
    required Map<String, dynamic> baseData,
  }) async {
    try {
      final docRef = _db.collection('users').doc(uid);
      final today  = DateTime.now().toIso8601String().substring(0, 10);

      // ── الكتابة الأساسية: دائماً merge:true ── لا تمسح أي حقل موجود
      final loginWrite = <String, dynamic>{
        ...baseData,
        'last_login': FieldValue.serverTimestamp(),
        'last_seen':  FieldValue.serverTimestamp(),
        'is_online':  true,
      };
      await docRef.set(loginWrite, SetOptions(merge: true));
      debugPrint('SafeUserWriter: ✅ login data written uid=$uid');

      // ── في الخلفية: اقرأ وتحقق من وجود المستخدم ──
      // لا await هنا — لا يُجمّد الدخول
      unawaited(_initNewUserIfNeeded(docRef, uid, today));

      return true;
    } catch (e) {
      debugPrint('SafeUserWriter error: $e');
      return false;
    }
  }

  /// تهيئة المستخدم الجديد وأستعادة اشتراك القديم — في الخلفية
  static Future<void> _initNewUserIfNeeded(
    DocumentReference<Map<String, dynamic>> docRef,
    String uid,
    String today,
  ) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final snap = await docRef.get().timeout(const Duration(seconds: 8));

      if (!snap.exists) {
        // مستخدم جديد — أضف البيانات الافتراضية
        await docRef.set({
          'status':     'active',
          'role':       'user',
          'created_at': FieldValue.serverTimestamp(),
          'subscription': {
            'plan':        Sub.kFree,
            'username':    '',
            'password':    '',
            'expiry_date': null,
            'started_at':  FieldValue.serverTimestamp(),
            'updated_at':  FieldValue.serverTimestamp(),
          },
          'free_watch': {
            'used_ms':    0,
            'date':       today,
            'expires_ms': GuestSession.freeMinutes * 60 * 1000,
          },
        }, SetOptions(merge: true));
        debugPrint('SafeUserWriter: ✅ New user initialized uid=$uid');
        return;
      }

      // مستخدم موجود — استعد الاشتراك إذا كان موجوداً
      final data = snap.data()!;
      final sub  = data['subscription'] as Map<String, dynamic>?;
      if (sub != null) {
        final plan  = sub['plan']?.toString()     ?? Sub.kFree;
        final uname = sub['username']?.toString() ?? '';
        final upass = sub['password']?.toString() ?? '';
        if (plan != Sub.kFree && uname.isNotEmpty && upass.isNotEmpty) {
          final exTs = sub['expiry_date'];
          DateTime? expiry;
          if (exTs is Timestamp) expiry = exTs.toDate();
          if (expiry == null || expiry.isAfter(DateTime.now())) {
            await Sub._restoreDirectly(
                username: uname, password: upass,
                expiry: expiry, plan: plan);
            debugPrint('SafeUserWriter: ✅ Sub restored uid=$uid');
          }
        }
      }
    } catch (e) {
      debugPrint('SafeUserWriter._initNewUserIfNeeded error: $e');
    }
  }
}
