part of '../main.dart';

// ════════════════════════════════════════════════════════════════
//  TOTV+ — constants.dart
//  الإصدار: 1.0.0  (مصدر الحقيقة الوحيد هو pubspec.yaml)
//  كل ثوابت التطبيق + نظام الإعدادات + الاشتراك
// ════════════════════════════════════════════════════════════════

// ── إصدار التطبيق — لا تعدّل هنا، يُقرأ من package_info ──────
// kAppVersion يُملأ في runtime من PackageInfo لضمان التطابق
// مع pubspec.yaml دائماً. انظر AppVersion.init() في main.dart
String _kAppVersion = '1.0.0'; // قيمة أولية فقط — تُحدَّث عند الإقلاع

// ── ثوابت ثابتة ───────────────────────────────────────────────
const kPkgName     = 'com.totv.plus';
const kTgChannel   = 'https://t.me/O_2828';
const kAdAppId     = 'ca-app-pub-6787200447252705~6903397497';
const kAdInterId   = 'ca-app-pub-6787200447252705/9494869419';
const kAdBannerId  = 'ca-app-pub-6787200447252705/9494869419';

// ════════════════════════════════════════════════════════════════
//  AppVersion — قراءة الإصدار الحقيقي من package_info
// ════════════════════════════════════════════════════════════════
class AppVersion {
  static String _version = '1.0.0';
  static int    _build   = 1;

  static String get version => _version;
  static int    get build   => _build;
  /// الرقم الرئيسي فقط (1.0.0 → 1) للمقارنة مع min_version
  static int    get major   => int.tryParse(_version.split('.').first) ?? 1;

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _build   = int.tryParse(info.buildNumber) ?? 1;
      _kAppVersion = _version;
      debugPrint('AppVersion: $_version+$_build');
    } catch (e) {
      debugPrint('AppVersion.init error: $e');
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  PLATFORM HELPER
// ════════════════════════════════════════════════════════════════
class Plat {
  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS     => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isMobile  => isAndroid || isIOS;
  static bool get isTV {
    if (kIsWeb) return false;
    final size = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final dpr  = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    return size.shortestSide / dpr >= 700;
  }
  static String get name {
    if (kIsWeb)     return 'web';
    if (isAndroid)  return 'android';
    if (isIOS)      return 'ios';
    return 'unknown';
  }
}

// ════════════════════════════════════════════════════════════════
//  DEVICE ID
// ════════════════════════════════════════════════════════════════
class DeviceId {
  static String? _id;
  static Future<String> get() async {
    if (_id != null) return _id!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _id = prefs.getString('_dev_id');
      if (_id != null && _id!.isNotEmpty) return _id!;
      // توليد ID فريد
      if (Plat.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        _id = info.id.isNotEmpty ? info.id : _generateId();
      } else if (Plat.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        _id = info.identifierForVendor ?? _generateId();
      } else {
        _id = _generateId();
      }
      await prefs.setString('_dev_id', _id!);
    } catch (_) {
      _id = _generateId();
    }
    return _id!;
  }
  static String _generateId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      math.Random().nextInt(0xFFFFFF).toRadixString(36);
}

// ════════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ════════════════════════════════════════════════════════════════
class C {
  static const bg      = Color(0xFF0A0A0A);
  static const surface = Color(0xFF141414);
  static const card    = Color(0xFF1C1C1C);
  static const gold    = Color(0xFFFFD740);
  static const grey    = Color(0xFF888888);
  static const dim     = Color(0xFF444444);
  static const white70 = Color(0xFFB3B3B3);
  static const red     = Color(0xFFE53935);

  static const playGrad = LinearGradient(
    colors: [Color(0xFFFFD740), Color(0xFFFFAB00)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const darkGrad = LinearGradient(
    colors: [Colors.transparent, Color(0xDD000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class T {
  static TextStyle cairo({
    double s = 14,
    FontWeight w = FontWeight.w600,
    Color c = Colors.white,
    double? h,
  }) =>
      TextStyle(
        fontFamily: GoogleFonts.cairo().fontFamily,
        fontSize: s, fontWeight: w, color: c, height: h,
      );

  static TextStyle body({Color c = Colors.white70, double s = 13}) =>
      cairo(s: s, w: FontWeight.w400, c: c);

  static TextStyle caption({Color c = Colors.white38, double s = 11}) =>
      cairo(s: s, w: FontWeight.w400, c: c);

  static TextStyle heading({double s = 18}) =>
      cairo(s: s, w: FontWeight.w800);

  static const double rSm  = 8.0;
  static const double rMd  = 12.0;
  static const double rLg  = 16.0;
  static const double rXl  = 20.0;
}

// ════════════════════════════════════════════════════════════════
//  RC — Remote Config من Firestore مباشرة
//  مصدر الحقيقة الوحيد لجميع الإعدادات
//  Collections:
//    app_config/remote_control  → maintenance, locked, guest_only
//    app_config/remote_config   → server_host, whatsapp, telegram
//    app_config/version         → min_version (int), force_update, store_url
//    app_config/settings        → tmdb_key, support_whatsapp
//    servers                    → (محذوف — السيرفر الآن في remote_config)
// ════════════════════════════════════════════════════════════════
class RC {
  static final _db = FirebaseFirestore.instance;

  // ── Subscriptions ──────────────────────────────────────────
  static StreamSubscription<DocumentSnapshot>? _ctrlSub;
  static StreamSubscription<DocumentSnapshot>? _confSub;
  static StreamSubscription<DocumentSnapshot>? _verSub;
  static StreamSubscription<DocumentSnapshot>? _settingsSub;
  static StreamSubscription<QuerySnapshot>?    _notifSub;
  static Timer? _heartbeatTimer;

  // ── State — يُحمَّل من Firestore حصراً ────────────────────
  // السيرفر الافتراضي — لعرض المحتوى للجميع (ضيف + مسجّل)
  static String _defaultHost  = '';  // app_config/remote_config → default_server_host
  static String _defUser      = '';  // اسم المستخدم الافتراضي
  static String _defPass      = '';  // كلمة المرور الافتراضية
  static String _serverHost   = '';  // host فقط بدون /
  static bool   _maintenance  = false;
  static String _maintMsg    = '';
  static bool   _locked      = false;
  static String _lockMsg     = '';
  static bool   _guestOnly   = false;
  static int    _minVersion  = 0;    // int مقارنة صحيحة
  static bool   _forceUpdate = false;
  static String _updateUrl   = '';
  static String _updateMsg   = '';
  static String _whatsapp    = '';
  static String _telegram    = kTgChannel;
  static String _tmdbKey     = '';
  static String _adminNotifTitle = '';
  static String _adminNotifBody  = '';
  static bool   _adminNotifShow  = false;
  // رابط الشراء — يُقرأ من Firestore (app_config/remote_config → buy_url)
  static String _buyUrl = 'https://payment-totv.vercel.app/';

  // ── Cache Keys (SharedPreferences) ────────────────────────
  static const _kCtrl = 'rc_ctrl_v1';
  static const _kConf = 'rc_conf_v1';
  static const _kVer  = 'rc_ver_v1';

  // ── Getters ────────────────────────────────────────────────
  static String get serverHost      => _serverHost.replaceAll(RegExp(r'/$'), '');
  // السيرفر الافتراضي — لعرض المحتوى للجميع
  static String get defaultHost     => _defaultHost.replaceAll(RegExp(r'/$'), '');
  static String get defaultUser     => _defUser;
  static String get defaultPass     => _defPass;
  static bool   get hasDefaultServer => _defaultHost.isNotEmpty;
  static bool   get maintenance     => _maintenance;
  static String get maintMsg     => _maintMsg;
  static bool   get locked       => _locked;
  static String get lockMsg      => _lockMsg;
  static bool   get guestOnly    => _guestOnly;
  static int    get minVersion   => _minVersion;
  static bool   get forceUpdate  => _forceUpdate;
  static String get updateUrl    => _updateUrl;
  static String get updateMsg    => _updateMsg;
  static String get whatsapp     => _whatsapp;
  static String get telegram     => _telegram.isNotEmpty ? _telegram : kTgChannel;
  static String get tmdbKey      => _tmdbKey;
  static String get adminNotifTitle => _adminNotifTitle;
  static String get adminNotifBody  => _adminNotifBody;
  static bool   get adminNotifShow  => _adminNotifShow;
  /// رابط الشراء — قابل للتغيير من Firestore، fallback ثابت
  static String get buyUrl => _buyUrl.isNotEmpty
      ? _buyUrl : 'https://payment-totv.vercel.app/';

  /// هل يحتاج التطبيق تحديثاً؟
  /// مقارنة رقمية صحيحة: min_version (int) vs major version
  static bool get needsUpdate {
    if (_minVersion <= 0) return false;
    return _minVersion > AppVersion.major;
  }

  // ── Callbacks ──────────────────────────────────────────────
  static VoidCallback? onConfigChanged;
  static VoidCallback? onVersionChanged;
  static VoidCallback? onAdminNotification;

  // ══════════════════════════════════════════════════════════
  //  INIT
  // ══════════════════════════════════════════════════════════
  static Future<void> init() async {
    await _loadFromCache();
    _listenCtrl();
    _listenConf();
    _listenVer();
    _listenSettings();
    _listenNotif();
    _startHeartbeat();
    debugPrint('RC: initialized — host=$_serverHost');
  }

  // ── Listener: remote_control ─────────────────────────────
  static void _listenCtrl() {
    _ctrlSub?.cancel();
    _ctrlSub = _db.collection('app_config').doc('remote_control')
        .snapshots().listen((s) {
      if (!s.exists) return;
      final d = s.data()!;
      _maintenance = d['maintenance'] == true;
      _locked      = d['locked']      == true;
      _guestOnly   = d['guest_only']  == true;
      _maintMsg    = d['maint_msg']?.toString() ?? '';
      _lockMsg     = d['lock_msg']?.toString()  ?? '';
      _cacheDoc(_kCtrl, d);
      onConfigChanged?.call();
    }, onError: (_) {});
  }

  // ── Listener: remote_config — سيرفر + معلومات تواصل ──────
  // Firestore doc fields:
  //   server_host: "http://example.com:8080"  ← الهوست الكامل
  //   whatsapp: "9647714415816"
  //   telegram: "https://t.me/..."
  static void _listenConf() {
    _confSub?.cancel();
    _confSub = _db.collection('app_config').doc('remote_config')
        .snapshots().listen((s) {
      if (!s.exists) return;
      final d = s.data()!;
      _serverHost  = _str(d, 'server_host',         _serverHost);
      _defaultHost = _str(d, 'default_server_host', _defaultHost);
      _defUser     = _str(d, 'username',             _defUser);
      _defPass     = _str(d, 'password',             _defPass);
      _whatsapp    = _str(d, 'whatsapp',             _whatsapp);
      _telegram    = _str(d, 'telegram',             _telegram);
      _updateUrl   = _str(d, 'update_url',           _updateUrl);
      _buyUrl      = _str(d, 'buy_url',              _buyUrl);
      _cacheDoc(_kConf, d);
      onConfigChanged?.call();
      debugPrint('RC[conf]: host=$_serverHost defaultHost=$_defaultHost user=$_defUser');
    }, onError: (_) {});
  }

  // ── Listener: version — فحص التحديث الإجباري ─────────────
  // Firestore doc fields:
  //   min_version: 2        ← int — الحد الأدنى للإصدار الرئيسي
  //   force_update: true    ← bool
  //   store_url: "https://..." ← رابط التحميل
  //   update_msg: "..."     ← رسالة للمستخدم
  static void _listenVer() {
    _verSub?.cancel();
    _verSub = _db.collection('app_config').doc('version')
        .snapshots().listen((s) {
      if (!s.exists) return;
      final d = s.data()!;
      // min_version يجب أن يكون int في Firestore
      final mv = (d['min_version'] as num?)?.toInt() ?? 0;
      if (mv > 0) _minVersion = mv;
      _forceUpdate = d['force_update'] == true;
      _updateUrl   = _str(d, 'store_url',   _str(d, 'update_url', _updateUrl));
      _updateMsg   = _str(d, 'update_msg',  _updateMsg);
      _cacheDoc(_kVer, d);
      onVersionChanged?.call();
      debugPrint('RC[ver]: min=$_minVersion force=$_forceUpdate needsUpdate=${needsUpdate}');
    }, onError: (_) {});
  }

  // ── Listener: settings — TMDB key ─────────────────────────
  static void _listenSettings() {
    _settingsSub?.cancel();
    _settingsSub = _db.collection('app_config').doc('settings')
        .snapshots().listen((s) {
      if (!s.exists) return;
      final d = s.data()!;
      _tmdbKey  = d['tmdb_key']?.toString() ?? '';
      // يمكن تجاوز whatsapp من settings أيضاً
      final wa = d['support_whatsapp']?.toString() ?? '';
      if (wa.isNotEmpty) _whatsapp = wa;
      onConfigChanged?.call();
    }, onError: (_) {});
  }

  // ── Listener: notifications ────────────────────────────────
  static void _listenNotif() {
    _notifSub?.cancel();
    _notifSub = _db.collection('notifications')
        .where('active', isEqualTo: true)
        .orderBy('sent_at', descending: true).limit(1)
        .snapshots().listen((snap) {
      if (snap.docs.isEmpty) { _adminNotifShow = false; return; }
      final d = snap.docs.first.data();
      _adminNotifTitle = d['title']?.toString() ?? '';
      _adminNotifBody  = d['body']?.toString()  ?? '';
      _adminNotifShow  = _adminNotifTitle.isNotEmpty;
      if (_adminNotifShow) onAdminNotification?.call();
    }, onError: (_) {});
  }

  // ── Heartbeat — last_seen ────────────────────────────────
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 5), (_) => _beat());
    Future.delayed(const Duration(seconds: 10), _beat);
  }

  // آخر وقت heartbeat ناجح — لمنع التكرار المفرط
  static DateTime? _lastBeat;

  static Future<void> _beat() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      // debounce: لا تكتب إذا مضى أقل من 4 دقائق
      final now = DateTime.now();
      if (_lastBeat != null &&
          now.difference(_lastBeat!).inMinutes < 4) return;
      _lastBeat = now;
      // update() بدل set() — لا يُطلق snapshot على كل الحقول
      await _db.collection('users').doc(u.uid).update({
        'last_seen':   FieldValue.serverTimestamp(),
        'is_online':   true,
      });
    } catch (_) {
      // إذا فشل update (مستخدم جديد) اكتب مرة واحدة فقط
      try {
        final u = FirebaseAuth.instance.currentUser;
        if (u == null) return;
        await _db.collection('users').doc(u.uid).set({
          'last_seen': FieldValue.serverTimestamp(),
          'is_online': true,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  static Future<void> markOffline() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      await _db.collection('users').doc(u.uid).update({
        'is_online':  false,
        'last_seen':  FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── Cache — offline support ───────────────────────────────
  static Future<void> _loadFromCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      _applyMap(p.getString(_kCtrl), (d) {
        _maintenance = d['maintenance'] == true;
        _locked      = d['locked']      == true;
        _guestOnly   = d['guest_only']  == true;
        _maintMsg    = d['maint_msg']?.toString() ?? '';
        _lockMsg     = d['lock_msg']?.toString()  ?? '';
      });
      _applyMap(p.getString(_kConf), (d) {
        _serverHost  = _str(d, 'server_host',         _serverHost);
        _defaultHost = _str(d, 'default_server_host', _defaultHost);
        _defUser     = _str(d, 'username',             _defUser);
        _defPass     = _str(d, 'password',             _defPass);
        _whatsapp    = _str(d, 'whatsapp',             _whatsapp);
        _telegram    = _str(d, 'telegram',             _telegram);
        _updateUrl   = _str(d, 'update_url',           _updateUrl);
        _buyUrl      = _str(d, 'buy_url',              _buyUrl);
      });
      _applyMap(p.getString(_kVer), (d) {
        final mv = (d['min_version'] as num?)?.toInt() ?? 0;
        if (mv > 0) _minVersion = mv;
        _forceUpdate = d['force_update'] == true;
        _updateUrl   = _str(d, 'store_url', _str(d, 'update_url', _updateUrl));
        _updateMsg   = _str(d, 'update_msg', _updateMsg);
      });
    } catch (_) {}
  }

  static Future<void> _cacheDoc(String key, Map<String, dynamic> d) async {
    try {
      final clean = <String, dynamic>{};
      d.forEach((k, v) {
        if (v is Timestamp) {
          clean[k] = v.millisecondsSinceEpoch;
        } else if (v is! DateTime) {
          clean[k] = v;
        }
      });
      (await SharedPreferences.getInstance()).setString(key, jsonEncode(clean));
    } catch (_) {}
  }

  static void _applyMap(String? raw, void Function(Map<String, dynamic>) fn) {
    if (raw == null) return;
    try { fn(jsonDecode(raw) as Map<String, dynamic>); } catch (_) {}
  }

  static String _str(Map d, String k, String fb) {
    final v = d[k];
    return (v != null && v.toString().isNotEmpty) ? v.toString() : fb;
  }

  static void dispose() {
    _ctrlSub?.cancel();
    _confSub?.cancel();
    _verSub?.cancel();
    _settingsSub?.cancel();
    _notifSub?.cancel();
    _heartbeatTimer?.cancel();
    // أوقف المستمع الشامل لبيانات المستخدم
    UserDataWatcher.stopListening();
    // مسح كاش البوسترات
    SmartPosterCache.clear();
    markOffline();
  }
}

// ════════════════════════════════════════════════════════════════
//  SERVER — الهوست الواحد الذي يُقرأ من Firestore
//  بنية URL: {RC.serverHost}/player_api.php?username=X&password=Y&action=Z
//  بنية Stream: {RC.serverHost}/{type}/{username}/{password}/{id}.{ext}
// ════════════════════════════════════════════════════════════════
class Server {
  static String get host => RC.serverHost;
  static bool   get hasHost => host.isNotEmpty;

  // ── بناء URL للـ API ──────────────────────────────────────
  static String apiUrl(String action, {
    required String username,
    required String password,
    Map<String, String>? extra,
    String? hostOverride,
  }) {
    final effectiveHost = (hostOverride ?? host).replaceAll(RegExp(r'/\$'), '');
    if (effectiveHost.isEmpty) return '';
    final params = <String, String>{
      'username': username,
      'password': password,
      'action':   action,
      ...?extra,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$effectiveHost/player_api.php?$query';
  }

  // ── بناء رابط البث ────────────────────────────────────────
  // type: live | movie | series
  static String streamUrl(String type, String id, String ext, {
    required String username,
    required String password,
  }) {
    if (host.isEmpty) return '';
    return '$host/$type/$username/$password/$id.$ext';
  }

  // ── جلب قائمة ─────────────────────────────────────────────
  static Future<List<dynamic>> fetchList(String action, {
    required String username,
    required String password,
    String? hostOverride,  // override host (للسيرفر الافتراضي)
    Map<String, String>? extra,
    int timeoutSec = 20,
  }) async {
    final url = apiUrl(action, username: username, password: password,
        extra: extra, hostOverride: hostOverride);
    if (url.isEmpty) return [];
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: Duration(seconds: timeoutSec),
      ));
      final r = await dio.get(url);
      if (r.data is List) return List<dynamic>.from(r.data as List);
      if (r.data is Map && r.data['data'] is List) {
        return List<dynamic>.from(r.data['data'] as List);
      }
    } catch (e) {
      debugPrint('Server.fetchList [$action]: $e');
    }
    return [];
  }
}

// ════════════════════════════════════════════════════════════════
//  Sub — نظام الاشتراك الموحّد
//  نوع واحد: المشترك يدخل username + password
//  يتصل مباشرة بـ RC.serverHost
// ════════════════════════════════════════════════════════════════
class Sub {
  // ── SharedPreferences Keys ─────────────────────────────────
  static const _kUser   = 'sub_username_v1';
  static const _kPass   = 'sub_password_v1';
  static const _kExpiry = 'sub_expiry_v1';
  static const _kPlan   = 'sub_plan_v1';
  static const _kActive = 'sub_active_v1';

  // ── Plan names ────────────────────────────────────────────
  static const kFree      = 'free';
  static const kPremium   = 'premium';

  // ── State ─────────────────────────────────────────────────
  static String    _username    = '';
  static String    _password    = '';
  static bool      _active      = false;
  static String    _plan        = kFree;
  static DateTime? _expiry;
  static DateTime? _activatedAt;

  // ── Getters ───────────────────────────────────────────────
  static String    get username  => _username;
  static String    get password  => _password;
  static bool      get isActive  => _active;
  static bool      get isFree    => !_active;
  static bool      get isPremium => _active;
  static String    get plan      => _plan;
  static DateTime? get expiry    => _expiry;

  static int get daysLeft {
    if (_expiry == null) return 0;
    return _expiry!.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  static DateTime? get activatedAt => _activatedAt;

  static String get expiryStr {
    if (_expiry == null) return '';
    return '${_expiry!.day.toString().padLeft(2, "0")}/'
        '${_expiry!.month.toString().padLeft(2, "0")}/'
        '${_expiry!.year}';
  }

  // ── Load from local storage ────────────────────────────────
  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _username = p.getString(_kUser) ?? '';
      _password = p.getString(_kPass) ?? '';
      _plan     = p.getString(_kPlan) ?? kFree;
      _active   = p.getBool(_kActive) ?? false;
      final ex  = p.getString(_kExpiry);
      final ac  = p.getString('_s_ac');
      if (ex != null) _expiry = DateTime.tryParse(ex);
      if (ac != null) _activatedAt = DateTime.tryParse(ac);

      // التحقق من انتهاء الصلاحية
      if (_active && _expiry != null && _expiry!.isBefore(DateTime.now())) {
        await _clearLocal();
        debugPrint('Sub: expired — reset to free');
        return;
      }

      // مزامنة مع Firestore إذا المستخدم مسجّل دخول
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _syncFromFirestore(user.uid);
      }
    } catch (e) {
      debugPrint('Sub.load error: $e');
    }
  }

  // ── تفعيل الاشتراك ────────────────────────────────────────
  /// المشترك يدخل username + password → يتصل بالسيرفر → يحفظ محلياً
  static Future<SubResult> activate({
    required String username,
    required String password,
  }) async {
    final u = username.trim();
    final p = password.trim();
    if (u.isEmpty || p.isEmpty) {
      return SubResult(false, 'يرجى إدخال اسم المستخدم وكلمة المرور');
    }
    if (!Server.hasHost) {
      return SubResult(false, 'السيرفر غير متاح حالياً، حاول لاحقاً');
    }

    // الاتصال بالسيرفر للتحقق
    try {
      final url = Server.apiUrl(
        'get_live_categories',
        username: u,
        password: p,
      );
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final r = await dio.get(url);

      // إذا رجع خطأ مصادقة
      if (r.data is Map) {
        final d = r.data as Map;
        if (d['user_info'] != null) {
          final ui   = d['user_info'] as Map;
          final auth = ui['auth'];
          if (auth == 0 || auth == '0' || auth == false) {
            return SubResult(false, 'اسم المستخدم أو كلمة المرور غير صحيحة');
          }
          // قراءة تاريخ الانتهاء من السيرفر
          final expTs = ui['exp_date']?.toString() ?? '';
          DateTime? expiry;
          if (expTs.isNotEmpty) {
            final ms = int.tryParse(expTs);
            if (ms != null) {
              expiry = DateTime.fromMillisecondsSinceEpoch(ms * 1000);
            }
          }
          if (expiry != null && expiry.isBefore(DateTime.now())) {
            return SubResult(false, 'انتهت صلاحية اشتراكك، تواصل مع الدعم');
          }
          await _saveSession(username: u, password: p, expiry: expiry);
          return SubResult(true, 'تم تفعيل الاشتراك بنجاح',
              expiry: expiry, plan: kPremium);
        }
      }

      // قائمة فارغة = بيانات صحيحة لكن لا محتوى
      if (r.data is List) {
        await _saveSession(username: u, password: p);
        return SubResult(true, 'تم تفعيل الاشتراك بنجاح', plan: kPremium);
      }

      return SubResult(false, 'لم يتم التحقق من الاشتراك، حاول مجدداً');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return SubResult(false, 'تعذّر الاتصال بالسيرفر، تحقق من الإنترنت');
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return SubResult(false, 'اسم المستخدم أو كلمة المرور غير صحيحة');
      }
      return SubResult(false, 'خطأ في الاتصال، حاول مجدداً');
    } catch (e) {
      debugPrint('Sub.activate error: $e');
      return SubResult(false, 'حدث خطأ غير متوقع');
    }
  }

  // ── مزامنة من Firestore ────────────────────────────────────
  static Future<void> _syncFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get()
          .timeout(const Duration(seconds: 5));
      if (!doc.exists) return;
      final d   = doc.data()!;
      final sub = d['subscription'] as Map<String, dynamic>?;
      if (sub == null) return;

      final savedPlan = sub['plan']?.toString() ?? kFree;
      if (savedPlan == kFree) return;

      final expiryTs = sub['expiry_date'];
      DateTime? expiry;
      if (expiryTs is Timestamp) expiry = expiryTs.toDate();
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        await _clearLocal();
        await _clearFirestore(uid);
        return;
      }

      final savedUser = sub['username']?.toString() ?? d['username']?.toString() ?? '';
      final savedPass = sub['password']?.toString() ?? d['password']?.toString() ?? '';
      if (savedUser.isNotEmpty && savedPass.isNotEmpty) {
        // استخدام _restoreDirectly فقط — لا تستدعي _saveSession لأنها تستدعي clearAll
        await _restoreDirectly(username: savedUser, password: savedPass, expiry: expiry);
        debugPrint('Sub: restored from Firestore — user=$savedUser expires=$expiry');
      }
    } catch (e) {
      debugPrint('Sub._syncFromFirestore error: $e');
    }
  }

  // ── FIX: استعادة الاشتراك من Firestore بشكل آمن ─────────────
  // لا تكتب في Firestore (تمنع الحلقة المفرغة)
  // لا تستدعي AppState.clearAll (تمنع التجميد)
  static Future<void> _restoreDirectly({
    required String username,
    required String password,
    DateTime? expiry,
    String plan = kPremium,
  }) async {
    if (username.isEmpty || password.isEmpty) return;
    // إذا نفس البيانات، لا شيء يتغير
    if (_active && _username == username && _password == password) return;
    debugPrint('Sub._restoreDirectly: user=\$username expires=\$expiry');
    _username    = username;
    _password    = password;
    _active      = true;
    _plan        = plan;
    _expiry      = expiry;
    _activatedAt ??= DateTime.now();
    // حفظ محلي فقط — بدون Firestore وبدون clearAll
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kUser,  username);
      await p.setString(_kPass,  password);
      await p.setString(_kPlan,  plan);
      await p.setBool(_kActive,  true);
      if (expiry != null) await p.setString(_kExpiry, expiry.toIso8601String());
    } catch (_) {}
  }

  // ── حفظ الجلسة ────────────────────────────────────────────
  static Future<void> _saveSession({
    required String username,
    required String password,
    DateTime? expiry,
    String plan = kPremium,
  }) async {
    _username    = username;
    _password    = password;
    _active      = true;
    _plan        = plan;
    _expiry      = expiry;
    _activatedAt ??= DateTime.now();

    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kUser,   username);
      await p.setString(_kPass,   password);
      await p.setString(_kPlan,   plan);
      await p.setBool(_kActive,   true);
      if (expiry != null) await p.setString(_kExpiry, expiry.toIso8601String());
      await p.setString('_s_ac', (_activatedAt ?? DateTime.now()).toIso8601String());
    } catch (_) {}

    // حفظ في Firestore للمزامنة
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      unawaited(_saveToFirestore(user.uid, username, password, expiry, plan));
    }

    // لا نستدعي AppState.clearAll() هنا — تُستدعى فقط عند تغيير السيرفر
    // لأن clearAll() يسبب إعادة تحميل كامل وبطء
  }

  static Future<void> _saveToFirestore(
    String uid, String username, String password,
    DateTime? expiry, String plan,
  ) async {
    try {
      final deviceId = await DeviceId.get();
      final platform = Plat.name;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'subscription': {
          'plan':        plan,
          'username':    username,
          'password':    password,
          'expiry_date': expiry != null ? Timestamp.fromDate(expiry) : null,
          'updated_at':  FieldValue.serverTimestamp(),
          'activated_at': FieldValue.serverTimestamp(),
        },
        'device_id':  deviceId,
        'platform':   platform,
        'app_version': AppVersion.version,
        'last_seen':  FieldValue.serverTimestamp(),
        'is_online':  true,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── تسجيل خروج ────────────────────────────────────────────
  static Future<void> logout() async {
    await _clearLocal();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _clearFirestore(user.uid);
    AppState.clearAll();
  }

  static Future<void> _clearLocal() async {
    _username = ''; _password = ''; _active = false;
    _plan = kFree; _expiry = null;
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in [_kUser, _kPass, _kPlan, _kExpiry, _kActive]) {
        await p.remove(k);
      }
    } catch (_) {}
  }

  static Future<void> _clearFirestore(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'subscription': {
          'plan':       kFree,
          'updated_at': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

// ════════════════════════════════════════════════════════════════
//  SubResult — نتيجة عملية الاشتراك
// ════════════════════════════════════════════════════════════════
class SubResult {
  final bool      ok;
  final String    msg;
  final String    plan;
  final DateTime? expiry;
  const SubResult(this.ok, this.msg, {
    this.plan = Sub.kFree,
    this.expiry,
  });
}

// ════════════════════════════════════════════════════════════════
//  AppState — تحميل المحتوى من السيرفر الواحد
//  مصدر البيانات الوحيد: Server.fetchList()
// ════════════════════════════════════════════════════════════════
class AppState {
  static List<dynamic> allMovies  = [];
  static List<dynamic> allSeries  = [];
  static List<dynamic> allLive    = [];
  static List<dynamic> movieCats  = [];
  static List<dynamic> seriesCats = [];
  static List<dynamic> liveCats   = [];
  static bool isLoaded  = false;
  static bool _loading  = false;

  // ── Cache Keys ─────────────────────────────────────────────
  static const _kMovies = 'as_movies_v1';
  static const _kSeries = 'as_series_v1';
  static const _kLive   = 'as_live_v1';
  static const _kMCats  = 'as_mcats_v1';
  static const _kSCats  = 'as_scats_v1';
  static const _kLCats  = 'as_lcats_v1';
  static const _kTime   = 'as_time_v1';

  static const int _cacheTtlMs = 72 * 3600 * 1000; // 72 ساعة

  static VoidCallback? onPartialLoad;

  // ── التحميل الرئيسي — مُحسَّن بـ SmartContentLoader ──────────
  static Future<void> loadAll({bool force = false}) async {
    if (_loading && !force) return;
    if (isLoaded && !force && _hasData) return;

    final bool hasPaidServer   = Sub.isActive && Server.hasHost;
    final bool hasDefaultServer = RC.hasDefaultServer;

    // ★ إذا لم يكن هناك سيرفر بعد، انتظر RC قليلاً ثم حاول
    if (!hasPaidServer && !hasDefaultServer) {
      debugPrint('AppState: no server yet — waiting for RC...');
      // انتظر RC.init() لمدة 3 ثوانٍ كحد أقصى
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (RC.hasDefaultServer || (Sub.isActive && Server.hasHost)) break;
      }
      // إذا لا يزال لا يوجد سيرفر → حمّل من الكاش المحلي فقط
      if (!RC.hasDefaultServer && !(Sub.isActive && Server.hasHost)) {
        await _loadFromDisk();
        isLoaded = true;
        if (_hasData) onPartialLoad?.call();
        debugPrint('AppState: loaded from disk only (no server)');
        return;
      }
    }

    _loading = true;

    // 1. تحميل من الكاش المحلي أولاً للعرض السريع
    if (!force) {
      await _loadFromDisk();
      if (_hasData && !_cacheExpired()) {
        isLoaded = true;
        _loading = false;
        onPartialLoad?.call();
        // تحديث في الخلفية بعد 2 ثانية (بدون إعاقة الواجهة)
        Future.delayed(const Duration(seconds: 2), () {
          if (!_loading) SmartContentLoader.loadWithPriority(force: true,
            onFirstBatch: () => onPartialLoad?.call());
        });
        return;
      }
    }

    // 2. استخدام SmartContentLoader للتحميل المتوازي الذكي
    await SmartContentLoader.loadWithPriority(
      force: force,
      onFirstBatch: () => onPartialLoad?.call(),
    );
    _loading = false;
  }

  static bool get _hasData => allMovies.isNotEmpty || allLive.isNotEmpty;

  static bool _cacheExpired() {
    final ts = _cacheTs;
    if (ts == 0) return true;
    return DateTime.now().millisecondsSinceEpoch - ts > _cacheTtlMs;
  }
  static int _cacheTs = 0;

  static Future<void> _fetchFromServer() async {
    try {
      // إذا المشترك لديه سيرفر خاص يستخدمه — وإلا السيرفر الافتراضي
      final u = Sub.isActive && Sub.username.isNotEmpty ? Sub.username : RC.defaultUser;
      final p = Sub.isActive && Sub.password.isNotEmpty ? Sub.password : RC.defaultPass;
      final h = Sub.isActive && Server.hasHost ? null : RC.defaultHost;
      final results = await Future.wait([
        Server.fetchList('get_vod_categories', username: u, password: p, hostOverride: h),
        Server.fetchList('get_series_categories', username: u, password: p, hostOverride: h),
        Server.fetchList('get_live_categories', username: u, password: p, hostOverride: h),
        Server.fetchList('get_vod_streams', username: u, password: p, hostOverride: h),
        Server.fetchList('get_series', username: u, password: p, hostOverride: h),
        Server.fetchList('get_live_streams', username: u, password: p, hostOverride: h),
      ]);
      movieCats  = results[0];
      seriesCats = results[1];
      liveCats   = results[2];
      allMovies  = results[3];
      allSeries  = results[4];
      allLive    = results[5];
      isLoaded   = true;
      await _saveToDisk();
      onPartialLoad?.call();
      debugPrint('AppState: loaded — movies=${allMovies.length} series=${allSeries.length} live=${allLive.length}');
    } catch (e) {
      debugPrint('AppState._fetchFromServer error: $e');
      isLoaded = true; // لا نبقى في وضع التحميل إلى الأبد
    }
  }

  static Future<void> _loadFromDisk() async {
    try {
      final p = await SharedPreferences.getInstance();
      _cacheTs   = p.getInt(_kTime) ?? 0;
      allMovies  = _dec(p.getString(_kMovies));
      allSeries  = _dec(p.getString(_kSeries));
      allLive    = _dec(p.getString(_kLive));
      movieCats  = _dec(p.getString(_kMCats));
      seriesCats = _dec(p.getString(_kSCats));
      liveCats   = _dec(p.getString(_kLCats));
      if (_hasData) isLoaded = true;
    } catch (_) {}
  }

  static Future<void> _saveToDisk() async {
    Future.microtask(() async {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kMovies, _enc(allMovies.take(3000).toList()));
        await p.setString(_kSeries, _enc(allSeries.take(3000).toList()));
        await p.setString(_kLive,   _enc(allLive.take(2000).toList()));
        await p.setString(_kMCats,  _enc(movieCats));
        await p.setString(_kSCats,  _enc(seriesCats));
        await p.setString(_kLCats,  _enc(liveCats));
        await p.setInt(_kTime, DateTime.now().millisecondsSinceEpoch);
        _cacheTs = DateTime.now().millisecondsSinceEpoch;
      } catch (_) {}
    });
  }

  static List<dynamic> _dec(String? s) {
    if (s == null || s.isEmpty) return [];
    try { return jsonDecode(s) as List; } catch (_) { return []; }
  }

  static String _enc(List<dynamic> l) {
    try { return jsonEncode(l); } catch (_) { return '[]'; }
  }

  /// مسح كل البيانات — عند تغيير الاشتراك أو السيرفر
  static void clearAll() {
    allMovies = []; allSeries = []; allLive = [];
    movieCats = []; seriesCats = []; liveCats = [];
    isLoaded = false;
    _cacheTs = 0;
    _clearDisk();
  }

  static void _clearDisk() {
    SharedPreferences.getInstance().then((p) {
      for (final k in [_kMovies, _kSeries, _kLive, _kMCats, _kSCats, _kLCats, _kTime]) {
        p.remove(k);
      }
    }).catchError((_) {});
  }

  static Future<void> preloadPosters(BuildContext ctx) async {
    // استخدام SmartPosterCache للتحميل المسبق الذكي
    unawaited(SmartPosterCache.prefetchAll(
      ctx,
      movies: allMovies,
      series: allSeries,
      live:   allLive,
    ));
  }
}

// ════════════════════════════════════════════════════════════════
//  Api — الواجهة الوحيدة لجلب البيانات من السيرفر
//  يستخدم Sub.username + Sub.password + RC.serverHost
// ════════════════════════════════════════════════════════════════
class Api {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ))..interceptors.add(_RetryInterceptor());

  // ── جلب قائمة ─────────────────────────────────────────────
  static Future<List<dynamic>> getList(String action, {
    bool force = false,
    Map<String, String>? extra,
  }) async {
    final cacheKey = '${Sub.username}_${action}_${extra?.toString() ?? ''}';
    if (!force) {
      final cached = ListCache.get(cacheKey);
      if (cached != null) return cached;
    }
    if (!Sub.isActive || !Server.hasHost) return [];

    final list = await Server.fetchList(
      action,
      username: Sub.username,
      password: Sub.password,
      extra: extra,
    );
    if (list.isNotEmpty) ListCache.put(cacheKey, list);
    return list;
  }

  // ── معلومات مسلسل ─────────────────────────────────────────
  static Future<Map<String, dynamic>> getSeriesInfo(String sid) async {
    final cached = _SeriesCache.get(sid);
    if (cached != null) return cached;
    if (!Sub.isActive || !Server.hasHost) return {};

    final url = Server.apiUrl(
      'get_series_info',
      username: Sub.username,
      password: Sub.password,
      extra: {'series_id': sid},
    );
    try {
      final r = await _dio.get(url).timeout(const Duration(seconds: 15));
      if (r.data is Map) {
        final d = Map<String, dynamic>.from(r.data as Map);
        _SeriesCache.put(sid, d);
        return d;
      }
    } catch (e) {
      debugPrint('Api.getSeriesInfo error: $e');
    }
    return {};
  }

  // ── بناء روابط البث ───────────────────────────────────────
  static List<String> liveUrls(dynamic item) {
    final id = item['stream_id'].toString();
    if (!Sub.isActive) return [];
    return [
      Server.streamUrl('live', id, 'ts',   username: Sub.username, password: Sub.password),
      Server.streamUrl('live', id, 'm3u8', username: Sub.username, password: Sub.password),
    ].where((u) => u.isNotEmpty).toList();
  }

  static List<String> movieUrls(dynamic item) {
    final id  = item['stream_id'].toString();
    final ext = (item['container_extension']?.toString() ?? 'mp4')
        .toLowerCase().replaceAll('.', '');
    if (!Sub.isActive) return [];
    final urls = <String>[
      Server.streamUrl('movie', id, ext,   username: Sub.username, password: Sub.password),
    ];
    if (ext != 'mp4') {
      urls.add(Server.streamUrl('movie', id, 'mp4', username: Sub.username, password: Sub.password));
    }
    return urls.where((u) => u.isNotEmpty).toList();
  }

  static List<String> episodeUrls(dynamic ep) {
    final id  = ep['id'].toString();
    final ext = (ep['container_extension']?.toString() ?? 'mp4')
        .toLowerCase().replaceAll('.', '');
    if (!Sub.isActive) return [];
    return [
      Server.streamUrl('series', id, ext,   username: Sub.username, password: Sub.password),
      if (ext != 'mp4')
        Server.streamUrl('series', id, 'mp4', username: Sub.username, password: Sub.password),
    ].where((u) => u.isNotEmpty).toList();
  }
}

class _RetryInterceptor extends Interceptor {
  static const _max = 2;
  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final retry = err.requestOptions.extra['_retry'] as int? ?? 0;
    if (retry < _max && (
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.receiveTimeout    ||
      err.type == DioExceptionType.connectionError   ||
      (err.response?.statusCode ?? 0) >= 500
    )) {
      await Future.delayed(Duration(milliseconds: 600 * (retry + 1)));
      err.requestOptions.extra['_retry'] = retry + 1;
      try {
        final resp = await Api._dio.fetch(err.requestOptions);
        handler.resolve(resp);
        return;
      } catch (_) {}
    }
    super.onError(err, handler);
  }
}

// ════════════════════════════════════════════════════════════════
//  In-Memory Caches
// ════════════════════════════════════════════════════════════════
class ListCache {
  static final Map<String, List<dynamic>> _d = {};
  static final Map<String, DateTime>      _t = {};
  static const int _ttlMin = 120; // دقيقتان

  static List<dynamic>? get(String k) {
    final t = _t[k];
    if (t == null || DateTime.now().difference(t).inMinutes > _ttlMin) return null;
    return _d[k];
  }
  static void put(String k, List<dynamic> v) {
    _d[k] = v; _t[k] = DateTime.now();
  }
  static void clear()      { _d.clear(); _t.clear(); }
  static void invalidate() { _d.clear(); _t.clear(); }
}

class _SeriesCache {
  static final Map<String, Map<String, dynamic>> _d = {};
  static final Map<String, DateTime>             _t = {};
  static const int _ttlMin = 25;

  static Map<String, dynamic>? get(String id) {
    final t = _t[id];
    if (t == null || DateTime.now().difference(t).inMinutes > _ttlMin) return null;
    return _d[id];
  }
  static void put(String id, Map<String, dynamic> v) {
    _d[id] = v; _t[id] = DateTime.now();
  }
}

// رابط صورة المحتوى
String _imgUrl(String url, {bool thumb = false}) {
  if (url.isEmpty) return '';
  if (url.contains('image.tmdb.org')) {
    if (thumb) return url
        .replaceAll('/original/', '/w342/')
        .replaceAll('/w1280/',    '/w500/')
        .replaceAll('/w780/',     '/w342/');
    return url;
  }
  return url;
}

// ════════════════════════════════════════════════════════════════
//  PlayUrlCache — كاش روابط التشغيل (24 ساعة)
// ════════════════════════════════════════════════════════════════
class PlayUrlCache {
  static const _k        = 'play_urls_v1';
  static const _maxItems = 500;
  static const _ttl      = 24 * 3600 * 1000;

  static Map<String, _CachedUrl> _cache = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final p   = await SharedPreferences.getInstance();
      final raw = p.getString(_k);
      if (raw != null) {
        final map = jsonDecode(raw) as Map;
        _cache = map.map((k, v) =>
            MapEntry(k.toString(), _CachedUrl.fromJson(v as Map)));
      }
    } catch (_) {}
    _loaded = true;
  }

  static String? get(String id) {
    final e = _cache[id];
    if (e == null) return null;
    if (DateTime.now().millisecondsSinceEpoch - e.ts > _ttl) {
      _cache.remove(id); return null;
    }
    return e.url;
  }

  static void put(String id, String url) {
    if (id.isEmpty || url.isEmpty) return;
    _cache[id] = _CachedUrl(url: url, ts: DateTime.now().millisecondsSinceEpoch);
    if (_cache.length > _maxItems) {
      final oldest = _cache.entries.toList()
        ..sort((a, b) => a.value.ts.compareTo(b.value.ts));
      for (final e in oldest.take(_cache.length - _maxItems)) _cache.remove(e.key);
    }
    _saveToDisk();
  }

  static void _saveToDisk() {
    Future.microtask(() async {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_k, jsonEncode(
            _cache.map((k, v) => MapEntry(k, v.toJson()))));
      } catch (_) {}
    });
  }

  static Future<void> clear() async {
    _cache.clear();
    try {
      (await SharedPreferences.getInstance()).remove(_k);
    } catch (_) {}
  }
}

class _CachedUrl {
  final String url;
  final int    ts;
  const _CachedUrl({required this.url, required this.ts});
  factory _CachedUrl.fromJson(Map m) =>
      _CachedUrl(url: m['url']?.toString() ?? '', ts: (m['ts'] as int?) ?? 0);
  Map<String, dynamic> toJson() => {'url': url, 'ts': ts};
}

// ════════════════════════════════════════════════════════════════
//  TV LAYOUT
// ════════════════════════════════════════════════════════════════
class TVLayout {
  static bool _isTV     = false;
  static bool _detected = false;

  static Future<void> detect() async {
    if (_detected) return;
    _detected = true;
    try {
      if (!kIsWeb && Plat.isAndroid) {
        final info    = await DeviceInfoPlugin().androidInfo;
        final display = WidgetsBinding.instance.platformDispatcher.views.first;
        final ratio   = display.physicalSize.shortestSide / display.devicePixelRatio;
        _isTV = ratio >= 700 || info.systemFeatures.contains('android.software.leanback');
      }
    } catch (_) {}
  }

  static bool get isTV          => _isTV || Plat.isTV;
  static double get titleFontSize => isTV ? 24.0 : 16.0;
  static double get bodyFontSize  => isTV ? 18.0 : 13.0;
  static double get cardWidth     => isTV ? 220.0 : 130.0;
  static double get cardHeight    => isTV ? 130.0 : 75.0;
  static EdgeInsets get pagePadding => isTV
      ? const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0)
      : const EdgeInsets.all(16.0);
}

// ════════════════════════════════════════════════════════════════
//  SOUND & HAPTICS
// ════════════════════════════════════════════════════════════════
class Sound {
  static AudioPlayer? _p;
  static bool _init = false;

  static Future<void> init() async {
    if (_init) return;
    try { _p = AudioPlayer(); _init = true; } catch (_) {}
  }

  static void hapticL() { try { HapticFeedback.lightImpact();  } catch (_) {} }
  static void hapticM() { try { HapticFeedback.mediumImpact(); } catch (_) {} }

  static Future<void> hapticOk() async {
    try {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static void hapticNotif() {
    try {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 100),
          () => HapticFeedback.lightImpact());
    } catch (_) {}
  }
}

// ════════════════════════════════════════════════════════════════
//  SmartPoster — صورة المحتوى مع fallback لـ TMDB
// ════════════════════════════════════════════════════════════════
class SmartPoster extends StatefulWidget {
  final dynamic item;
  final bool isTv;
  final BoxFit fit;
  final double? memH, memW;
  final BorderRadius? radius;
  final bool showShimmer;
  const SmartPoster({
    required this.item,
    this.isTv       = false,
    this.fit        = BoxFit.cover,
    this.memH, this.memW,
    this.radius,
    this.showShimmer = true,
  });
  @override State<SmartPoster> createState() => _SmartPosterState();
}

class _SmartPosterState extends State<SmartPoster> {
  String _url = '';
  bool _triedTmdb = false;

  @override
  void initState() {
    super.initState();
    // ── أولاً: تحقق من SmartPosterCache (أسرع) ──
    final id = widget.item['stream_id']?.toString() ??
               widget.item['id']?.toString() ?? '';
    if (id.isNotEmpty) {
      final cached = SmartPosterCache.get(id);
      if (cached != null && cached.isNotEmpty) {
        _url = cached;
        return;
      }
    }
    _url = _getPrimaryUrl();
    // احفظ في الكاش إذا وجد
    if (_url.isNotEmpty && id.isNotEmpty) {
      SmartPosterCache.put(id, _url);
    }
    if (_url.isEmpty) _fetchTmdb();
  }

  String _getPrimaryUrl() {
    final icon  = widget.item['stream_icon']?.toString() ?? '';
    final cover = widget.item['cover']?.toString()       ?? '';
    return icon.isNotEmpty ? icon : cover;
  }

  Future<void> _fetchTmdb() async {
    if (_triedTmdb) return;
    _triedTmdb = true;
    final name = widget.item['name']?.toString() ?? '';
    if (name.isEmpty) return;
    try {
      final info = await TMDB.search(name, isTv: widget.isTv)
          .timeout(const Duration(seconds: 5));
      final u = info['poster'] ?? info['poster_sm'] ?? '';
      if (u.isNotEmpty && mounted) {
        // احفظ في SmartPosterCache
        final id = widget.item['stream_id']?.toString() ??
                   widget.item['id']?.toString() ?? '';
        if (id.isNotEmpty) SmartPosterCache.put(id, u);
        setState(() => _url = u);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name']?.toString() ?? '';
    if (_url.isEmpty) return _placeholder(name);
    Widget img = CachedNetworkImage(
      imageUrl: _imgUrl(_url),
      fit: widget.fit,
      memCacheHeight: widget.memH?.toInt(),
      memCacheWidth:  widget.memW?.toInt(),
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => widget.showShimmer
          ? _Shimmer(radius: widget.radius)
          : Container(color: C.surface),
      errorWidget: (_, __, ___) {
        if (!_triedTmdb) { _fetchTmdb(); return _Shimmer(radius: widget.radius); }
        return _placeholder(name);
      },
    );
    if (widget.radius != null) img = ClipRRect(borderRadius: widget.radius!, child: img);
    return img;
  }

  Widget _placeholder(String name) => Container(
    decoration: BoxDecoration(
      color: C.surface,
      borderRadius: widget.radius,
    ),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(widget.isTv ? Icons.tv_rounded : Icons.movie_rounded,
          color: C.dim, size: 24),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(name, style: T.caption(c: C.dim),
            maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
    ])),
  );
}

class _Shimmer extends StatefulWidget {
  final BorderRadius? radius;
  const _Shimmer({this.radius});
  @override State<_Shimmer> createState() => _ShimmerState();
}
class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _anim = Tween(begin: -1.5, end: 2.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: widget.radius ?? BorderRadius.zero,
    child: AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          stops: [
            (_anim.value - 0.5).clamp(0.0, 1.0),
            _anim.value.clamp(0.0, 1.0),
            (_anim.value + 0.5).clamp(0.0, 1.0),
          ],
          colors: const [Color(0xFF1A1A1A), Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        )),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════
//  COMPAT + STUBS — طبقة التوافق الكاملة والنهائية
//  هذا هو المصدر الوحيد لجميع الرموز — لا تكرار
// ════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
//  C EXTENSIONS
// ─────────────────────────────────────────────────────────────
extension CExtra on C {
  static const border   = Color(0xFF2A2A2A);
  static const white    = Colors.white;
  static const live     = Color(0xFFFF3D3D);
  static const heroGrad = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xDD000000)],
  );
}

// All C color stubs in one place — no extensions-on-extensions
class CC {
  static const success  = Color(0xFF4CAF50);
  static const goldBg   = Color(0xFF1A1200);
  static const goldBg2  = Color(0xFF2A1F00);
  static const goldGrad = LinearGradient(
    colors: [Color(0xFFFFD740), Color(0xFFFFAB00)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const goldLight= Color(0xFFFFE57F);
  static const goldDark = Color(0xFFFF8F00);
  static const textPri  = Colors.white;
  static const textSec  = Color(0xFFAAAAAA);
  static const info     = Color(0xFF42A5F5);
  static const glass    = Color(0x1AFFFFFF);
  static const glassBdr = Color(0x22FFFFFF);
}

// ─────────────────────────────────────────────────────────────
//  T EXTENSIONS
// ─────────────────────────────────────────────────────────────
extension TExtra on T {
  static TextStyle h2({Color c = Colors.white, double s = 16}) =>
      TextStyle(fontFamily: GoogleFonts.cairo().fontFamily,
          fontSize: s, fontWeight: FontWeight.w700, color: c);

  static TextStyle mont({double s = 13, FontWeight w = FontWeight.w400,
      Color c = Colors.white70, double ls = 0}) =>
      TextStyle(fontFamily: GoogleFonts.cairo().fontFamily,
          fontSize: s, fontWeight: w, color: c, letterSpacing: ls);

  static TextStyle cinzel({double s = 14, Color c = Colors.white,
      FontWeight w = FontWeight.w700}) =>
      GoogleFonts.cinzelDecorative(fontSize: s, fontWeight: w, color: c);

  static TextStyle display({double s = 22, Color c = Colors.white}) =>
      TextStyle(fontFamily: GoogleFonts.cairo().fontFamily,
          fontSize: s, fontWeight: FontWeight.w800, color: c);

  static TextStyle h1({Color c = Colors.white, double s = 22}) =>
      TextStyle(fontFamily: GoogleFonts.cairo().fontFamily,
          fontSize: s, fontWeight: FontWeight.w800, color: c);

  static TextStyle label({Color c = Colors.white, double s = 11,
      FontWeight w = FontWeight.w700}) =>
      TextStyle(fontFamily: GoogleFonts.cairo().fontFamily,
          fontSize: s, fontWeight: w, color: c, letterSpacing: 0.3);
}

// ─────────────────────────────────────────────────────────────
//  S — Spacing & radius constants
// ─────────────────────────────────────────────────────────────
class S {
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 20.0;
  static const double xxl  = 24.0;
  static const double rSm  = 6.0;
  static const double rMd  = 10.0;
  static const double rLg  = 14.0;
  static const double rXl  = 20.0;
  static const double rPill= 50.0;
}

// ─────────────────────────────────────────────────────────────
//  SOUND
// ─────────────────────────────────────────────────────────────
extension SoundSuccess on Sound {
  static Future<void> success() async {
    try {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────
//  RC COMPAT
// ─────────────────────────────────────────────────────────────
extension RCCompat on RC {
  static String get settingsBuyUrl =>
      RC.whatsapp.isNotEmpty ? 'https://wa.me/${RC.whatsapp}' : '';
  static String get proxyUrl  => '';
  static String get serverUrl => RC.serverHost;
  static String get username  => Sub.username;
  static String get password  => Sub.password;
  static String getStr(String key, [String fallback = '']) => fallback;
}

// ─────────────────────────────────────────────────────────────
//  SUB COMPAT
// ─────────────────────────────────────────────────────────────
extension SubCompat on Sub {
  static bool   get isPremium    => Sub.isActive;
  static bool   get isFree       => !Sub.isActive;
  static bool   get isTOTV       => false;
  static bool   get isPremiumSub => Sub.isActive;
  static bool   get isNormal     => Sub.isActive;

  /// رابط الشراء — يأتي من RC.buyUrl (Firestore) أولاً
  static String get buyUrl    => RC.buyUrl;
  static String get vipBuyUrl => RC.buyUrl;
  static String get whatsapp  => RC.whatsapp;
  static String get telegram  => RC.telegram;
  static String get email     => '';

  static String get xtreamUser => Sub.username;
  static String get xtreamPass => Sub.password;
  static String get xtreamBase => RC.serverHost;
  static String get xtreamHost => RC.serverHost;

  static Future<SubResult> validateCode(String code) async {
    final parts = code.split(':');
    if (parts.length == 2) {
      return Sub.activate(username: parts[0].trim(), password: parts[1].trim());
    }
    return const SubResult(false, 'أدخل اسم المستخدم وكلمة المرور');
  }

  static Future<void> saveTOTVDirect({
    required String host, required String username, required String password,
  }) async {
    await Sub.activate(username: username, password: password);
  }

  static Future<void> restoreFromFirestore(String uid) async => Sub.load();
}

// ─────────────────────────────────────────────────────────────
//  kAppVersion — global getter
// ─────────────────────────────────────────────────────────────
String get kAppVersion => AppVersion.version;

// ListCache — defined in core section above

// ─────────────────────────────────────────────────────────────
//  WatchHistory
// ─────────────────────────────────────────────────────────────
class WatchHistory {
  static const _kHistory  = 'wh_history_v1';
  static const _kProgress = 'wh_progress_v1';
  static const int _maxItems = 200;

  static List<Map<String, dynamic>> _history  = [];
  static Map<String, int>           _progress = {};
  static bool _loaded = false;

  static List<Map<String, dynamic>> get recentHistory => _history;
  static List<Map<String, dynamic>> get recent        => _history.take(20).toList();

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final p    = await SharedPreferences.getInstance();
      final hRaw = p.getString(_kHistory);
      final pRaw = p.getString(_kProgress);
      if (hRaw != null) _history  = (jsonDecode(hRaw) as List).cast<Map<String, dynamic>>();
      if (pRaw != null) {
        final raw = jsonDecode(pRaw) as Map<String, dynamic>;
        _progress = raw.map((k, v) => MapEntry(k, (v as num).toInt()));
      }
    } catch (_) {}
    _loaded = true;
  }

  static void addItem(dynamic item, String type) {
    if (item == null) return;
    final id   = item['stream_id']?.toString() ?? item['id']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    if (id.isEmpty) return;
    _history.removeWhere((h) => h['id'] == id);
    _history.insert(0, {
      'id': id, 'name': name, 'type': type,
      'icon': item['stream_icon']?.toString() ?? item['cover']?.toString() ?? '',
      'ts':   DateTime.now().millisecondsSinceEpoch,
    });
    if (_history.length > _maxItems) _history = _history.take(_maxItems).toList();
    _saveToDisk();
  }

  static void saveProgress(String id, int posSecs, int durSecs) {
    if (id.isEmpty) return;
    _progress[id] = posSecs;
    _saveToDisk();
  }

  /// Returns progress in milliseconds as int
  static int getProgressMs(String id) => (_progress[id] ?? 0) * 1000;

  static double getPercent(String id, int fallbackDurSecs) {
    final posSecs = _progress[id] ?? 0;
    final durSecs = fallbackDurSecs > 0 ? fallbackDurSecs : 3600;
    return (posSecs / durSecs).clamp(0.0, 1.0);
  }

  static bool isCompleted(String id) => getPercent(id, 3600) >= 0.92;

  static List<Map<String, dynamic>> continueWatching() =>
      _history.where((h) {
        final id  = h['id']?.toString() ?? '';
        final pct = getPercent(id, 3600);
        return pct > 0.02 && !isCompleted(id);
      }).take(10).toList();

  static List<Map<String, dynamic>> recommend(List<dynamic> pool) {
    final seen = _history.take(5).map((h) => h['name']?.toString() ?? '').toSet();
    return pool
        .where((item) => !seen.contains(item['name']?.toString() ?? ''))
        .take(20)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  static void _saveToDisk() {
    SharedPreferences.getInstance().then((p) {
      p.setString(_kHistory,  jsonEncode(_history));
      p.setString(_kProgress, jsonEncode(_progress));
    }).catchError((_) {});
    _syncToFirestore();
  }

  static void _syncToFirestore() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Save last 20 items + progress to Firestore
    final recent = _history.take(20).toList();
    FirebaseFirestore.instance.collection('users').doc(uid).set({
      'watch_history': recent,
      'watch_history_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((_) {});
  }

  static Future<void> syncProgressToFirestore(String uid, String id, int secs) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'watch_progress': {id: secs},
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────
//  Recommendations
// ─────────────────────────────────────────────────────────────
class Recommendations {
  static List<dynamic> continueWatching() => WatchHistory.continueWatching();

  static List<dynamic> forYou({int limit = 15}) {
    final pool = [...AppState.allMovies, ...AppState.allSeries];
    pool.shuffle();
    return WatchHistory.recommend(pool).take(limit).toList();
  }
}

// ─────────────────────────────────────────────────────────────
//  WL — Watchlist / Favorites
// ─────────────────────────────────────────────────────────────
class WL {
  static const _k = 'wl_items_v1';
  static List<Map<String, dynamic>> _items = [];
  static bool _loaded = false;

  static List<Map<String, dynamic>> get all => List.from(_items);

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_k);
      if (raw != null) _items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    // Sync from Firestore if logged in
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(uid).get()
            .timeout(const Duration(seconds: 4));
        final remote = (doc.data()?['watchlist'] as List?)?.cast<Map<String, dynamic>>();
        if (remote != null && remote.isNotEmpty) {
          // Merge local + remote
          final merged = <String, Map<String, dynamic>>{};
          for (final item in [...remote, ..._items]) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) merged[id] = item;
          }
          _items = merged.values.toList();
          _saveLocal();
        }
      } catch (_) {}
    }
    _loaded = true;
  }

  static bool has(dynamic item) {
    final id = item['stream_id']?.toString() ?? item['id']?.toString() ?? '';
    return _items.any((i) => i['id']?.toString() == id);
  }

  static Future<bool> toggle(dynamic item, String type) async {
    await _ensureLoaded();
    final id   = item['stream_id']?.toString() ?? item['id']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    if (id.isEmpty) return false;
    final icon = item['stream_icon']?.toString() ?? item['cover']?.toString() ?? '';
    if (has(item)) {
      _items.removeWhere((i) => i['id']?.toString() == id);
    } else {
      _items.insert(0, {
        'id': id, 'name': name, 'type': type, 'icon': icon,
        'added_at': DateTime.now().toIso8601String(),
      });
    }
    _saveLocal();
    _syncToFirestore();
    return has(item);
  }

  static void _saveLocal() {
    SharedPreferences.getInstance().then((p) => p.setString(_k, jsonEncode(_items)))
        .catchError((_) {});
  }

  static void _syncToFirestore() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance.collection('users').doc(uid).set({
      'watchlist': _items,
      'watchlist_count': _items.length,
      'watchlist_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((_) {});
  }

  /// Force reload from Firestore
  static Future<void> reload() async {
    _loaded = false;
    _items = [];
    await _ensureLoaded();
  }
}

// ─────────────────────────────────────────────────────────────
//  Ads stub
// ─────────────────────────────────────────────────────────────
class Ads {
  static void show() {}
  static void init() {}
}

// ─────────────────────────────────────────────────────────────
//  EpgService stub
// ─────────────────────────────────────────────────────────────
class EpgService {
  static String? currentProgram(String channelId) => null;
}

// ─────────────────────────────────────────────────────────────
//  SecurityLayer stub
// ─────────────────────────────────────────────────────────────
class SecurityLayer {
  static void enableScreenRecord()  {}
  static void disableScreenRecord() {}
  static Map<String, String> streamHeaders({bool isLive = false}) =>
      {'User-Agent': 'TOTV+/${AppVersion.version}'};
}

// ─────────────────────────────────────────────────────────────
//  VpnGuard stub
// ─────────────────────────────────────────────────────────────
class VpnGuard {
  static Future<bool> isVpnActive() async => false;
}

// ─────────────────────────────────────────────────────────────
//  DeviceId.isBanned extension
// ─────────────────────────────────────────────────────────────
extension DeviceIdBanned on DeviceId {
  static Future<bool> isBanned() async {
    try {
      final id  = await DeviceId.get();
      final doc = await FirebaseFirestore.instance
          .collection('banned_devices').doc(id)
          .get().timeout(const Duration(seconds: 4));
      return doc.exists && doc.data()?['banned'] == true;
    } catch (_) { return false; }
  }
}

// ─────────────────────────────────────────────────────────────
//  LiveLoadBalancer
// ─────────────────────────────────────────────────────────────
class LiveLoadBalancer {
  static final Map<String, int>      _fails    = {};
  static final Map<String, DateTime> _lastFail = {};
  static int _rr = 0;

  static void markSuccess(String host) { _fails.remove(host); }
  static void markFail(String host)    {
    _fails[host]    = (_fails[host] ?? 0) + 1;
    _lastFail[host] = DateTime.now();
  }
  static bool isHealthy(String host) {
    final f = _fails[host] ?? 0;
    if (f < 3) return true;
    final t = _lastFail[host];
    if (t == null) return true;
    return DateTime.now().difference(t).inSeconds >= 60;
  }
  static String pickBest(List<String> urls) {
    if (urls.isEmpty) return '';
    if (urls.length == 1) return urls.first;
    final healthy = urls.where((u) {
      try { return isHealthy(Uri.parse(u).host); } catch (_) { return true; }
    }).toList();
    if (healthy.isEmpty) return urls.first;
    _rr = (_rr + 1) % healthy.length;
    return healthy[_rr];
  }
}

// ─────────────────────────────────────────────────────────────
//  VoduSearchService + VoduResult
// ─────────────────────────────────────────────────────────────
class VoduResult {
  final bool   found;
  final String url;
  const VoduResult({this.found = false, this.url = ''});
}

class VoduSearchService {
  static Future<VoduResult> search({
    required String title,
    String? type,
    String? season,
    String? episode,
  }) async {
    // Stub — returns not found in new system
    return const VoduResult(found: false, url: '');
  }
}

// ─────────────────────────────────────────────────────────────
//  CmsService stub
// ─────────────────────────────────────────────────────────────
class CmsService {
  static bool get hasServerData => Server.hasHost;

  static String buildStreamUrl(String type, String id, String ext) =>
      Server.streamUrl(type, id, ext,
          username: Sub.username, password: Sub.password);

  static String buildApiUrl(String action, [Map<String, dynamic>? extra]) =>
      Server.apiUrl(action,
          username: Sub.username, password: Sub.password,
          extra: extra?.map((k, v) => MapEntry(k, v.toString())));

  static void startHeartbeat() {}
  static void stopHeartbeat()  {}
}

// ─────────────────────────────────────────────────────────────
//  TVFocusHelper
// ─────────────────────────────────────────────────────────────
class TVFocusHelper {
  static Widget withDpad({
    required Widget child,
    VoidCallback? onUp, VoidCallback? onDown,
    VoidCallback? onLeft, VoidCallback? onRight,
    VoidCallback? onOk, VoidCallback? onBack,
  }) {
    if (!TVLayout.isTV) return child;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp)    { onUp?.call();    return KeyEventResult.handled; }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown)  { onDown?.call();  return KeyEventResult.handled; }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft)  { onLeft?.call();  return KeyEventResult.handled; }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) { onRight?.call(); return KeyEventResult.handled; }
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter)      { onOk?.call();    return KeyEventResult.handled; }
        if (event.logicalKey == LogicalKeyboardKey.goBack)     { onBack?.call();  return KeyEventResult.handled; }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TMDB.fromWorker extension
// ─────────────────────────────────────────────────────────────
extension TMDBFromWorker on TMDB {
  static Future<Map<String, String>> fromWorker(
      String id, String name, {bool isTv = false}) =>
      TMDB.search(name, isTv: isTv);
}

// ─────────────────────────────────────────────────────────────
//  WatchTimer
// ─────────────────────────────────────────────────────────────
class WatchTimer {
  static const int _maxMs = 60 * 60 * 1000;
  static const _kUsed = 'wt_used_v1';
  static const _kDate = 'wt_date_v1';

  static int  _savedMs = 0;
  static int? _startMs;
  static bool _loaded  = false;

  static int get totalLiveMs => _startMs == null
      ? _savedMs
      : _savedMs + (DateTime.now().millisecondsSinceEpoch - _startMs!);

  static int    get remainingSecs  => ((_maxMs - totalLiveMs) / 1000).ceil().clamp(0, 86400);
  static bool   get isExpired      => !Sub.isActive && totalLiveMs >= _maxMs;
  static double get usedFraction   => (totalLiveMs / _maxMs).clamp(0.0, 1.0);

  static String get remainingStr {
    if (Sub.isActive) return '∞';
    final s = remainingSecs;
    if (s <= 0) return 'انتهى الوقت';
    final m   = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, "0")}:${sec.toString().padLeft(2, "0")}';
  }

  static Future<void> load() async {
    if (_loaded) return;
    if (Sub.isActive) { _loaded = true; return; }
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getString(_kDate) == today) {
        _savedMs = p.getInt(_kUsed) ?? 0;
      } else {
        await p.setString(_kDate, today);
        await p.setInt(_kUsed, 0);
        _savedMs = 0;
      }
    } catch (_) {}
    _loaded = true;
  }

  static void startPlayback() {
    if (Sub.isActive || _startMs != null) return;
    _startMs = DateTime.now().millisecondsSinceEpoch;
  }

  static void stopPlayback() {
    if (_startMs == null) return;
    _savedMs = totalLiveMs;
    _startMs = null;
    SharedPreferences.getInstance().then((p) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      p.setString(_kDate, today);
      p.setInt(_kUsed, _savedMs);
    }).catchError((_) {});
  }
}

// ─────────────────────────────────────────────────────────────
//  AuthResult & UserStatus
// ─────────────────────────────────────────────────────────────
// NOTE: AuthResult is defined in profile_player.dart
// UserStatus and UserStatusService defined here:
enum UserStatus { active, banned, unknown }

class UserStatusService {
  static Future<UserStatus> checkStatus(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .get().timeout(const Duration(seconds: 5));
      if (!doc.exists) return UserStatus.active;
      if (doc.data()?['status']?.toString() == 'banned') return UserStatus.banned;
    } catch (_) {}
    return UserStatus.active;
  }
}

// ─────────────────────────────────────────────────────────────
//  PlayUrlCache
// PlayUrlCache and _CachedUrl — defined in core section above

// ─────────────────────────────────────────────────────────────
//  PricingPage → SubscriptionPage
// ─────────────────────────────────────────────────────────────
class PricingPage extends StatelessWidget {
  const PricingPage({super.key});
  @override
  Widget build(BuildContext context) => const SubscriptionPage();
}

// ─────────────────────────────────────────────────────────────
//  SubscriptionPage — صفحة الاشتراك الموحّدة
// ─────────────────────────────────────────────────────────────
class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});
  @override State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool   _busy     = false;
  bool   _showPass = false;
  String _msg      = '';
  bool   _ok       = false;

  @override void dispose() { _userCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _activate() async {
    final u = _userCtrl.text.trim();
    final p = _passCtrl.text.trim();
    if (u.isEmpty || p.isEmpty) {
      setState(() { _msg = 'أدخل اسم المستخدم وكلمة المرور'; _ok = false; });
      return;
    }
    setState(() { _busy = true; _msg = ''; });
    final result = await Sub.activate(username: u, password: p);
    if (!mounted) return;
    setState(() { _busy = false; _msg = result.msg; _ok = result.ok; });
    if (result.ok) {
      // ★ صوت واهتزاز عند نجاح التفعيل
      await Sound.hapticOk();
      await Future.delayed(const Duration(milliseconds: 80));
      await Sound.hapticOk();
      AppState.loadAll(force: true);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wa = RC.whatsapp;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('تفعيل الاشتراك', style: T.cairo(s: 17, w: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(T.rLg),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.info_outline_rounded, color: C.gold, size: 18),
                const SizedBox(width: 8),
                Text('كيف يعمل الاشتراك؟', style: T.cairo(s: 14, w: FontWeight.w700, c: C.gold)),
              ]),
              const SizedBox(height: 10),
              Text(
                'أدخل اسم المستخدم وكلمة المرور للاتصال بالسيرفر وتفعيل اشتراكك.',
                style: T.body(c: CC.textSec), textDirection: TextDirection.rtl,
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Text('اسم المستخدم', style: T.cairo(s: 13, c: CC.textSec)),
          const SizedBox(height: 8),
          _buildField(_userCtrl, 'username'),
          const SizedBox(height: 16),
          Text('كلمة المرور', style: T.cairo(s: 13, c: CC.textSec)),
          const SizedBox(height: 8),
          _buildField(_passCtrl, 'password', obscure: !_showPass,
            suffix: IconButton(
              icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white38, size: 18),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
          ),
          const SizedBox(height: 28),
          // ── زر تفعيل الاشتراك (إدخال username/password) ──
          GestureDetector(
            onTap: _busy ? null : _activate,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: _busy ? null : C.playGrad,
                color: _busy ? C.surface : null,
                borderRadius: BorderRadius.circular(T.rMd),
              ),
              child: Center(child: _busy
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: C.gold, strokeWidth: 2))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.verified_user_rounded, color: Colors.black, size: 20),
                      const SizedBox(width: 8),
                      Text('تفعيل اشتراكي',
                          style: T.cairo(s: 15, c: Colors.black, w: FontWeight.w800)),
                    ])),
            ),
          ),
          const SizedBox(height: 10),
          // ── زر شراء اشتراك جديد ──
          GestureDetector(
            onTap: () {
              final url = RC.buyUrl;
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: C.gold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(T.rMd),
                border: Border.all(color: C.gold.withOpacity(0.5), width: 1.2),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ShaderMask(
                  shaderCallback: (r) => C.playGrad.createShader(r),
                  child: const Icon(Icons.shopping_cart_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Text('شراء اشتراك جديد',
                    style: T.cairo(s: 15, c: C.gold, w: FontWeight.w800)),
              ]),
            ),
          ),
          if (_msg.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _ok ? CC.success.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(T.rSm),
                border: Border.all(
                  color: _ok ? CC.success.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
              ),
              child: Row(children: [
                Icon(_ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                    color: _ok ? CC.success : Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_msg, style: T.body(c: _ok ? CC.success : Colors.redAccent))),
              ]),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(color: Color(0xFF2A2A2A)),
          const SizedBox(height: 20),
          if (wa.isNotEmpty) ...[
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://wa.me/$wa?text=${Uri.encodeComponent("مرحباً، أريد الاشتراك في TOTV+")}'),
                mode: LaunchMode.externalApplication),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(T.rMd),
                  border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
                ),
                child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.support_agent_rounded, color: Color(0xFF25D366), size: 20),
                  const SizedBox(width: 8),
                  Text('اشترك عبر واتساب',
                      style: T.cairo(s: 14, c: const Color(0xFF25D366), w: FontWeight.w700)),
                ])),
              ),
            ),
            const SizedBox(height: 12),
          ],
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(RC.telegram), mode: LaunchMode.externalApplication),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF229ED9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(T.rMd),
                border: Border.all(color: const Color(0xFF229ED9).withOpacity(0.3)),
              ),
              child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.telegram, color: Color(0xFF229ED9), size: 20),
                const SizedBox(width: 8),
                Text('القناة الرسمية',
                    style: T.cairo(s: 14, c: const Color(0xFF229ED9), w: FontWeight.w700)),
              ])),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String hint,
      {bool obscure = false, Widget? suffix}) =>
      TextField(
        controller: c, obscureText: obscure, textAlign: TextAlign.left,
        style: T.cairo(s: 14, c: Colors.white),
        decoration: InputDecoration(
          hintText: hint, hintStyle: T.cairo(s: 13, c: Colors.white38),
          filled: true, fillColor: C.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rSm),
              borderSide: const BorderSide(color: Color(0xFF2A2A2A), width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rSm),
              borderSide: const BorderSide(color: Color(0xFF2A2A2A), width: 0.5)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(T.rSm),
              borderSide: const BorderSide(color: C.gold, width: 1)),
          suffixIcon: suffix,
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  _VpnBlockPage stub
// ─────────────────────────────────────────────────────────────
class _VpnBlockPage extends StatelessWidget {
  const _VpnBlockPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.vpn_lock_rounded, color: C.gold, size: 72),
      const SizedBox(height: 24),
      Text('يُرجى إيقاف VPN للمتابعة', style: T.cairo(s: 18, w: FontWeight.w700)),
    ])));
}

// ─────────────────────────────────────────────────────────────
//  _ShimmerBox
// ─────────────────────────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  final BorderRadius? radius;
  const _ShimmerBox({this.radius});
  @override State<_ShimmerBox> createState() => _ShimmerBoxState();
}
class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _anim = Tween(begin: -1.5, end: 2.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: widget.radius ?? BorderRadius.zero,
    child: AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          stops: [
            (_anim.value - 0.5).clamp(0.0, 1.0),
            _anim.value.clamp(0.0, 1.0),
            (_anim.value + 0.5).clamp(0.0, 1.0),
          ],
          colors: const [Color(0xFF1A1A1A), Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        )),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
//  GuestSession — إدارة جلسة المستخدم المجاني (ساعة مجانية)
//  القواعد:
//  - ضيف (بدون حساب): يرى المحتوى فقط، عند الضغط للتشغيل → تسجيل دخول
//  - مستخدم مسجّل مجاني: ساعة واحدة من التشغيل يومياً
//  - مشترك مدفوع: بلا حدود
// ════════════════════════════════════════════════════════════════
class GuestSession {
  static const int freeMinutes = 60; // ساعة واحدة
  static const int _maxMs = freeMinutes * 60 * 1000;
  static const _kUsed     = 'gs_used_ms_v1';
  static const _kDate     = 'gs_date_v1';
  static const _kUid      = 'gs_uid_v1';

  static int  _usedMs  = 0;
  static int? _startMs;
  static bool _loaded  = false;

  // ── وقت المشاهدة الكلي الحالي ─────────────────────────────
  static int get totalMs =>
      _usedMs + (_startMs != null
          ? DateTime.now().millisecondsSinceEpoch - _startMs!
          : 0);

  static int    get remainingMs   => (_maxMs - totalMs).clamp(0, _maxMs);
  static int    get remainingSecs => (remainingMs / 1000).ceil();
  static bool   get isExpired     => Sub.isActive ? false : totalMs >= _maxMs;
  static double get usedFraction  => (totalMs / _maxMs).clamp(0.0, 1.0);

  static String get remainingStr {
    if (Sub.isActive) return '∞';
    final s = remainingSecs;
    if (s <= 0) return 'انتهى الوقت المجاني';
    final m   = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
  }

  // ── تحميل وقت المشاهدة من Firestore + Local ───────────────
  static Future<void> load(String uid) async {
    if (_loaded) return;
    if (Sub.isActive) { _loaded = true; return; }

    final today = _today();
    int localMs = 0;

    try {
      final p = await SharedPreferences.getInstance();
      final savedUid  = p.getString(_kUid) ?? '';
      final savedDate = p.getString(_kDate) ?? '';
      // إعادة تعيين إذا تغيّر اليوم أو المستخدم
      if (savedDate == today && savedUid == uid) {
        localMs = p.getInt(_kUsed) ?? 0;
      } else {
        await p.setString(_kDate, today);
        await p.setString(_kUid, uid);
        await p.setInt(_kUsed, 0);
      }
    } catch (_) {}

    // جلب من Firestore (المصدر الرئيسي للحقيقة)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get()
          .timeout(const Duration(seconds: 4));
      if (doc.exists) {
        final gw = doc.data()?['free_watch'] as Map<String, dynamic>?;
        if (gw != null && gw['date'] == today) {
          final fbMs = (gw['used_ms'] as num?)?.toInt() ?? 0;
          localMs = localMs > fbMs ? localMs : fbMs;
        }
      }
    } catch (_) {}

    _usedMs = localMs;
    _loaded = true;
  }

  // ── بدء التشغيل ────────────────────────────────────────────
  static void startPlayback() {
    if (Sub.isActive || _startMs != null) return;
    _startMs = DateTime.now().millisecondsSinceEpoch;
  }

  // ── إيقاف التشغيل وحفظ الوقت ──────────────────────────────
  static Future<void> stopPlayback(String uid) async {
    if (_startMs == null) return;
    _usedMs = totalMs;
    _startMs = null;
    await _save(uid);
  }

  // ── حفظ في Local + Firestore ───────────────────────────────
  static Future<void> _save(String uid) async {
    final today = _today();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kDate, today);
      await p.setString(_kUid, uid);
      await p.setInt(_kUsed, _usedMs);
    } catch (_) {}
    // حفظ في Firestore
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'free_watch': {
          'used_ms':    _usedMs,
          'date':       today,
          'expires_ms': _maxMs,
          'updated_at': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── مزامنة دورية مع Firestore ──────────────────────────────
  static Future<void> syncToFirestore(String uid) async {
    if (!_loaded || Sub.isActive) return;
    await _save(uid);
  }

  static void reset() {
    _usedMs = 0; _startMs = null; _loaded = false;
  }

  /// مزامنة من Firestore stream (استدعاء من UserDataWatcher)
  static void _syncFromRemote(int remoteMs) {
    if (Sub.isActive) return;
    // خذ القيمة الأكبر (الجهاز أو السيرفر)
    if (remoteMs > _usedMs) {
      _usedMs = remoteMs;
      debugPrint('GuestSession: synced from remote = $_usedMs ms');
    }
  }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);
}
