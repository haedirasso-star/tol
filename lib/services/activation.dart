part of '../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — ActivationService  (نظام أكواد التفعيل)
//  ──────────────────────────────────────────────────────────────────────
//  آلية العمل الكاملة:
//   1. الأدمن يضيف بيانات سيرفر (host + username + password + مدة الباقة)
//      من صفحة الأدمن، فتتولّد تلقائياً كودان (2) لهذا السيرفر.
//   2. المستخدم يدخل الكود في التطبيق مرة واحدة فقط.
//   3. التطبيق يحجز الكود داخل Transaction (لا يمكن لاثنين استخدامه معاً)
//      ثم يقرأ منه host/username/password ومدة الباقة.
//   4. تُكتب كل بيانات الاشتراك في:
//        • users/{uid}.subscription   ← مصدر الحقيقة في السحابة
//        • activation_codes/{CODE}    ← يحمل بيانات المستخدم الذي فعّله
//        • SharedPreferences          ← نسخة محلية (لا يُسأل عن الكود ثانية)
//   5. عند تسجيل الخروج ثم الدخول: تُقرأ البيانات من Firestore وتُحفظ محلياً.
//   6. عند تحديث الأدمن لبيانات السيرفر: UserDataWatcher يلتقط التغيير فوراً.
// ════════════════════════════════════════════════════════════════════════

/// نتيجة عملية تفعيل الكود.
class CodeResult {
  final bool      ok;
  final String    msg;
  final String    plan;
  final int       days;
  final DateTime? expiry;
  const CodeResult(this.ok, this.msg, {
    this.plan   = '',
    this.days   = 0,
    this.expiry,
  });
}

class ActivationService {
  ActivationService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// اسم مجموعة الأكواد في Firestore (نفس الاسم في صفحة الأدمن).
  static const String kCol = 'activation_codes';

  // ── مدد الباقات ───────────────────────────────────────────────────────
  static const String planMonthly   = 'monthly';
  static const String planQuarterly = 'quarterly';
  static const String planYearly    = 'yearly';

  static int daysForPlan(String plan) {
    switch (plan) {
      case planYearly:    return 365;
      case planQuarterly: return 90;
      case planMonthly:   return 30;
      default:            return 30;
    }
  }

  static String planLabel(String plan) {
    switch (plan) {
      case planYearly:    return 'سنوي';
      case planQuarterly: return '3 أشهر';
      case planMonthly:   return 'شهري';
      default:            return 'اشتراك';
    }
  }

  // ── تطبيع الكود ───────────────────────────────────────────────────────
  /// يحوّل أي صيغة يكتبها المستخدم إلى معرّف المستند الفعلي.
  /// "totv-ab12-cd34" ، "TOTV AB12 CD34" ، "totvab12cd34" → "TOTVAB12CD34"
  static String normalize(String raw) {
    final up = raw.trim().toUpperCase();
    return up.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// عرض جميل للكود: TOTV-AB12-CD34
  static String pretty(String code) {
    final c = normalize(code);
    if (c.length < 8) return c;
    final buf = StringBuffer();
    for (int i = 0; i < c.length; i += 4) {
      if (i > 0) buf.write('-');
      buf.write(c.substring(i, math.min(i + 4, c.length)));
    }
    return buf.toString();
  }

  /// هل النص يبدو كوداً صالحاً شكلياً؟
  static bool looksValid(String raw) => normalize(raw).length >= 8;

  // ══════════════════════════════════════════════════════════════════════
  //  التفعيل — الدالة الرئيسية
  // ══════════════════════════════════════════════════════════════════════
  static Future<CodeResult> redeem(String rawCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const CodeResult(false, 'سجّل الدخول بحسابك أولاً ثم أدخل الكود');
    }

    final code = normalize(rawCode);
    if (code.length < 8) {
      return const CodeResult(false, 'الكود غير مكتمل — تأكد من كتابته كاملاً');
    }

    final ref = _db.collection(kCol).doc(code);

    // ★ يُجلب قبل الـ Transaction — لأن الـ Transaction قد تُعاد عدة مرات
    String deviceId = '';
    try { deviceId = await DeviceId.get(); } catch (_) {}

    // ── الخطوة ١: حجز الكود داخل Transaction ───────────────────────────
    // Transaction تضمن أن كوداً واحداً لا يُستعمل من جهازين في نفس اللحظة.
    Map<String, dynamic> claimed;
    try {
      claimed = await _db.runTransaction<Map<String, dynamic>>((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw _CodeErr.notFound;

        final d = snap.data() as Map<String, dynamic>;

        // موقوف من الأدمن؟
        if (d['status']?.toString() == 'disabled' || d['disabled'] == true) {
          throw _CodeErr.disabled;
        }

        final bool   alreadyUsed = d['used'] == true;
        final String ownerUid    = d['used_by_uid']?.toString() ?? '';

        // مستخدم من شخص آخر؟
        if (alreadyUsed && ownerUid.isNotEmpty && ownerUid != user.uid) {
          throw _CodeErr.usedByOther;
        }

        // بيانات السيرفر
        final host = _cleanHost(d['host']?.toString() ?? '');
        final xu   = d['username']?.toString() ?? '';
        final xp   = d['password']?.toString() ?? '';
        if (host.isEmpty || xu.isEmpty || xp.isEmpty) {
          throw _CodeErr.badServer;
        }

        final plan = d['plan']?.toString() ?? planMonthly;
        final days = (d['days'] is num)
            ? (d['days'] as num).toInt()
            : daysForPlan(plan);

        // تاريخ الانتهاء:
        //  • أول تفعيل            → من الآن + مدة الباقة
        //  • نفس المستخدم يعيد    → نفس التاريخ المحفوظ (لا يُمدَّد بالخداع)
        DateTime expiry;
        final savedExp = d['expiry_date'];
        if (alreadyUsed && ownerUid == user.uid && savedExp is Timestamp) {
          expiry = savedExp.toDate();
        } else {
          expiry = DateTime.now().add(Duration(days: days));
        }

        // منتهٍ فعلاً؟
        if (expiry.isBefore(DateTime.now())) throw _CodeErr.expired;

        // ★ الكتابة: كل كود يحمل بيانات صاحبه كاملة
        tx.update(ref, {
          'used':           true,
          'status':         'used',
          'used_by_uid':    user.uid,
          'used_by_email':  (user.email ?? '').toLowerCase(),
          'used_by_name':   user.displayName ?? '',
          'used_by_phone':  user.phoneNumber ?? '',
          'used_device_id': deviceId,
          'used_platform':  Plat.name,
          'used_app_ver':   AppVersion.version,
          if (!alreadyUsed) 'used_at': FieldValue.serverTimestamp(),
          'expiry_date':    Timestamp.fromDate(expiry),
          'last_seen_at':   FieldValue.serverTimestamp(),
          // حقول لا تتغيّر — نعيد إرسالها ليقبلها Firestore Rules
          'plan':     plan,
          'host':     d['host'],
          'username': xu,
          'password': xp,
        });

        return <String, dynamic>{
          'host':     host,
          'username': xu,
          'password': xp,
          'plan':     plan,
          'days':     days,
          'expiry':   expiry,
          'batch_id': d['batch_id']?.toString() ?? '',
          'agent':    d['agent']?.toString() ?? '',
        };
      }).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      return const CodeResult(false, 'الاتصال بطيء — تحقّق من الإنترنت وحاول مجدداً');
    } catch (e) {
      return CodeResult(false, _mapError(e));
    }

    // ── الخطوة ٢: حفظ الاشتراك محلياً (فوري — لا ينتظر الشبكة) ──────────
    final host    = claimed['host']    as String;
    final xuser   = claimed['username'] as String;
    final xpass   = claimed['password'] as String;
    final plan    = claimed['plan']    as String;
    final days    = claimed['days']    as int;
    final expiry  = claimed['expiry']  as DateTime;

    await Sub.applyFromCode(
      code:     code,
      host:     host,
      username: xuser,
      password: xpass,
      tier:     plan,
      days:     days,
      expiry:   expiry,
    );

    // ── الخطوة ٣: حفظ في users/{uid} (مصدر الحقيقة عند إعادة الدخول) ────
    unawaited(_writeUserDoc(
      deviceId: deviceId,
      uid:      user.uid,
      code:     code,
      host:     host,
      username: xuser,
      password: xpass,
      plan:     plan,
      days:     days,
      expiry:   expiry,
      agent:    claimed['agent']?.toString() ?? '',
    ));

    // ── الخطوة ٤: سجل التفعيل (للأدمن) ────────────────────────────────
    unawaited(_logActivation(
      deviceId: deviceId,
      uid:   user.uid,
      email: (user.email ?? '').toLowerCase(),
      name:  user.displayName ?? '',
      code:  code,
      host:  host,
      plan:  plan,
      days:  days,
    ));

    // ── الخطوة ٥: تحميل المحتوى من سيرفر الكود فوراً ───────────────────
    try {
      AppState.clearAll();
      ListCache.clear();
      SmartContentLoader.cancelAll();
      unawaited(AppState.loadAll(force: true).then((_) {
        AppState.notifyContent();
      }).catchError((_) {}));
    } catch (_) {}

    return CodeResult(
      true,
      'تم تفعيل اشتراك ${planLabel(plan)} بنجاح',
      plan:   plan,
      days:   days,
      expiry: expiry,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  كتابة مستند المستخدم
  // ══════════════════════════════════════════════════════════════════════
  static Future<void> _writeUserDoc({
    String deviceId = '',
    required String uid,
    required String code,
    required String host,
    required String username,
    required String password,
    required String plan,
    required int days,
    required DateTime expiry,
    String agent = '',
  }) async {
    try {
      if (deviceId.isEmpty) {
        try { deviceId = await DeviceId.get(); } catch (_) {}
      }

      await _db.collection('users').doc(uid).set({
        'subscription': {
          'plan':          Sub.kPremium,
          'tier':          plan,
          'duration_days': days,
          'code':          code,
          'host':          host,
          'server_host':   host,
          'username':      username,
          'password':      password,
          'expiry_date':   Timestamp.fromDate(expiry),
          'activated_at':  FieldValue.serverTimestamp(),
          'activated_by':  'code',
          'source':        'activation_code',
          if (agent.isNotEmpty) 'agent': agent,
          'updated_at':    FieldValue.serverTimestamp(),
        },
        'device_id':   deviceId,
        'platform':    Plat.name,
        'app_version': AppVersion.version,
        'last_seen':   FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('ActivationService: user doc updated for $uid');
    } catch (e) {
      debugPrint('ActivationService._writeUserDoc: $e');
      // ★ فشل الكتابة لا يُلغي التفعيل — البيانات محفوظة محلياً،
      //   وسنعيد المحاولة عند أول فتح لاحق للتطبيق.
      unawaited(_queueRetry(uid));
    }
  }

  /// إعادة محاولة الكتابة السحابية لاحقاً (يُستدعى عند الإقلاع).
  static const _kRetryKey = 'act_retry_uid_v1';

  static Future<void> _queueRetry(String uid) async {
    try {
      final p = await SPref.i;
      await p.setString(_kRetryKey, uid);
    } catch (_) {}
  }

  /// يُستدعى عند بدء التطبيق: إن كان هناك تفعيل لم يُحفظ سحابياً، أعِد المحاولة.
  static Future<void> retryPendingWrite() async {
    try {
      final p   = await SPref.i;
      final uid = p.getString(_kRetryKey) ?? '';
      if (uid.isEmpty) return;
      final cur = FirebaseAuth.instance.currentUser;
      if (cur == null || cur.uid != uid) return;
      if (!Sub.isPremium || Sub.activationCode.isEmpty) {
        await p.remove(_kRetryKey);
        return;
      }
      await _writeUserDoc(
        uid:      uid,
        code:     Sub.activationCode,
        host:     Sub.host,
        username: Sub.username,
        password: Sub.password,
        plan:     Sub.tier,
        days:     Sub.planDays,
        expiry:   Sub.expiry ?? DateTime.now().add(const Duration(days: 30)),
      );
      await p.remove(_kRetryKey);
      debugPrint('ActivationService: pending cloud write flushed');
    } catch (e) {
      debugPrint('ActivationService.retryPendingWrite: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  سجل التفعيل
  // ══════════════════════════════════════════════════════════════════════
  static Future<void> _logActivation({
    String deviceId = '',
    required String uid,
    required String email,
    required String name,
    required String code,
    required String host,
    required String plan,
    required int days,
  }) async {
    try {
      if (deviceId.isEmpty) {
        try { deviceId = await DeviceId.get(); } catch (_) {}
      }
      await _db.collection('activations').add({
        'uid':         uid,
        'email':       email,
        'name':        name,
        'code':        code,
        'host':        host,
        'plan':        plan,
        'days':        days,
        'source':      'activation_code',
        'device_id':   deviceId,
        'platform':    Plat.name,
        'app_version': AppVersion.version,
        'created_at':  FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ActivationService._logActivation: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  فحص حالة الكود (اختياري — قبل التفعيل)
  // ══════════════════════════════════════════════════════════════════════
  static Future<CodeResult> peek(String rawCode) async {
    final code = normalize(rawCode);
    if (code.length < 8) {
      return const CodeResult(false, 'الكود غير مكتمل');
    }
    try {
      final snap = await _db.collection(kCol).doc(code).get()
          .timeout(const Duration(seconds: 12));
      if (!snap.exists) return const CodeResult(false, 'هذا الكود غير موجود');
      final d    = snap.data() as Map<String, dynamic>;
      final plan = d['plan']?.toString() ?? planMonthly;
      final days = (d['days'] is num) ? (d['days'] as num).toInt() : daysForPlan(plan);
      if (d['status']?.toString() == 'disabled' || d['disabled'] == true) {
        return const CodeResult(false, 'هذا الكود موقوف من الإدارة');
      }
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final own = d['used_by_uid']?.toString() ?? '';
      if (d['used'] == true && own.isNotEmpty && own != uid) {
        return const CodeResult(false, 'هذا الكود مُستخدم مسبقاً');
      }
      return CodeResult(true, 'كود ${planLabel(plan)} صالح', plan: plan, days: days);
    } catch (e) {
      return const CodeResult(false, 'تعذّر التحقق — تحقّق من الإنترنت');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  أدوات
  // ══════════════════════════════════════════════════════════════════════
  static String _cleanHost(String raw) {
    var h = raw.trim();
    if (h.isEmpty) return '';
    if (!h.startsWith('http://') && !h.startsWith('https://')) h = 'http://$h';
    return h.replaceAll(RegExp(r'/+$'), '');
  }

  static String _mapError(Object e) {
    final s = e.toString();
    if (s.contains(_CodeErr.notFound))    return 'هذا الكود غير موجود — تأكد من كتابته بشكل صحيح';
    if (s.contains(_CodeErr.disabled))    return 'هذا الكود موقوف من الإدارة';
    if (s.contains(_CodeErr.usedByOther)) return 'هذا الكود مُستخدم مسبقاً من حساب آخر';
    if (s.contains(_CodeErr.expired))     return 'انتهت صلاحية هذا الكود';
    if (s.contains(_CodeErr.badServer))   return 'بيانات السيرفر في هذا الكود ناقصة — تواصل مع الدعم';
    if (s.contains('permission-denied'))  return 'لا تملك صلاحية استخدام هذا الكود';
    if (s.contains('unavailable') || s.contains('network')) {
      return 'تعذّر الاتصال — تحقّق من الإنترنت وحاول مجدداً';
    }
    debugPrint('ActivationService error: $e');
    return 'تعذّر تفعيل الكود — حاول مجدداً';
  }
}

/// رموز أخطاء داخلية تُرمى من داخل الـ Transaction.
class _CodeErr {
  static const notFound    = 'TOTV_CODE_NOT_FOUND';
  static const disabled    = 'TOTV_CODE_DISABLED';
  static const usedByOther = 'TOTV_CODE_USED';
  static const expired     = 'TOTV_CODE_EXPIRED';
  static const badServer   = 'TOTV_CODE_BAD_SERVER';
}
