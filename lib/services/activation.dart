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
  //  التفعيل — الدالة الرئيسية  (Supabase)
  //  ────────────────────────────────────────────────────────────────────
  //  كل المنطق يجري داخل قاعدة البيانات في دالة redeem_code:
  //   • قفل ذرّي على صف الكود ⇒ يستحيل تفعيله من جهازين معاً
  //   • كبح التخمين: 10 محاولات فاشلة ⇒ إيقاف 15 دقيقة
  //   • يكتب بيانات المشترك داخل الكود وفي جدول الاشتراكات دفعة واحدة
  //  التطبيق لا يقرأ الجداول إطلاقاً — استدعاء واحد فقط.
  // ══════════════════════════════════════════════════════════════════════
  static Future<CodeResult> redeem(String rawCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const CodeResult(false, 'سجّل الدخول بحسابك أولاً ثم أدخل الكود');
    }
    if (!kSupaReady) {
      return const CodeResult(false,
          'إعدادات الخادم غير مكتملة — تواصل مع الدعم (SUPA_CFG)');
    }

    final code = normalize(rawCode);
    if (code.length < 8) {
      return const CodeResult(false, 'الكود غير مكتمل — تأكد من كتابته كاملاً');
    }

    String deviceId = '';
    try { deviceId = await DeviceId.get(); } catch (_) {}

    final res = await Supa.rpc('redeem_code', {
      'p_code':     code,
      'p_uid':      user.uid,
      'p_email':    (user.email ?? '').toLowerCase(),
      'p_name':     user.displayName ?? '',
      'p_device':   deviceId,
      'p_platform': Plat.name,
      'p_appver':   AppVersion.version,
    });

    if (res == null) {
      return const CodeResult(false,
          'تعذّر الاتصال بالخادم — تحقّق من الإنترنت وحاول مجدداً');
    }
    if (res['ok'] != true) {
      final err = res['error']?.toString() ?? 'UNKNOWN';
      debugPrint('ActivationService.redeem failed: $err  ${res['detail'] ?? ''}');
      return CodeResult(false, _mapError(err));
    }

    // ── نجح: احفظ محلياً فوراً ─────────────────────────────────────────
    final host   = _cleanHost(res['host']?.toString() ?? '');
    final xuser  = res['username']?.toString() ?? '';
    final xpass  = res['password']?.toString() ?? '';
    final plan   = res['plan']?.toString() ?? planMonthly;
    final days   = (res['days'] is num)
        ? (res['days'] as num).toInt() : daysForPlan(plan);
    final expiry = DateTime.tryParse(res['expiry']?.toString() ?? '')
        ?? DateTime.now().add(Duration(days: days));

    if (host.isEmpty || xuser.isEmpty || xpass.isEmpty) {
      return const CodeResult(false,
          'بيانات السيرفر في هذا الكود ناقصة — تواصل مع الدعم');
    }

    await Sub.applyFromCode(
      code: code, host: host, username: xuser, password: xpass,
      tier: plan, days: days, expiry: expiry,
    );

    // ── حمّل المحتوى من سيرفر الكود فوراً ─────────────────────────────
    try {
      AppState.clearAll();
      ListCache.clear();
      SmartContentLoader.cancelAll();
      unawaited(AppState.loadAll(force: true)
          .then((_) => AppState.notifyContent())
          .catchError((_) {}));
    } catch (_) {}

    return CodeResult(
      true, 'تم تفعيل اشتراك ${planLabel(plan)} بنجاح',
      plan: plan, days: days, expiry: expiry,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  استعادة الاشتراك من السحابة (بعد تسجيل الخروج / إعادة التثبيت)
  //  استدعاء واحد — يحلّ محل خمس قراءات كانت تتم من Firestore.
  // ══════════════════════════════════════════════════════════════════════
  static Future<bool> restoreFromCloud({String? uid}) async {
    final id = uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (id.isEmpty || !kSupaReady) return false;

    final res = await Supa.rpc('get_subscription', {'p_uid': id},
        timeout: const Duration(seconds: 12));
    if (res == null || res['ok'] != true) {
      if (res != null && res['error']?.toString() == 'EXPIRED') {
        debugPrint('ActivationService: subscription expired on server');
      }
      return false;
    }

    final host  = _cleanHost(res['host']?.toString() ?? '');
    final xu    = res['username']?.toString() ?? '';
    final xp    = res['password']?.toString() ?? '';
    if (host.isEmpty || xu.isEmpty || xp.isEmpty) return false;

    final tier   = res['tier']?.toString() ?? planMonthly;
    final days   = (res['days'] is num) ? (res['days'] as num).toInt() : 0;
    final code   = res['code']?.toString() ?? '';
    final expiry = DateTime.tryParse(res['expiry']?.toString() ?? '');
    if (expiry != null && expiry.isBefore(DateTime.now())) return false;

    await Sub.applyFromCode(
      code: code, host: host, username: xu, password: xp,
      tier: tier, days: days,
      expiry: expiry ?? DateTime.now().add(Duration(days: days > 0 ? days : 30)),
    );
    debugPrint('ActivationService: restored from Supabase — host=$host');
    return true;
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

  /// يحوّل رمز الخطأ القادم من القاعدة إلى رسالة عربية واضحة.
  static String _mapError(String err) {
    switch (err) {
      case 'NOT_FOUND':
        return 'هذا الكود غير موجود — تأكد من كتابته بشكل صحيح';
      case 'USED':
        return 'هذا الكود مُستخدم مسبقاً من حساب آخر';
      case 'DISABLED':
        return 'هذا الكود موقوف من الإدارة';
      case 'EXPIRED':
        return 'انتهت صلاحية هذا الكود';
      case 'BAD_FORMAT':
        return 'صيغة الكود غير صحيحة';
      case 'TOO_MANY':
        return 'محاولات كثيرة خاطئة — انتظر 15 دقيقة ثم أعد المحاولة';
      case 'NO_UID':
        return 'سجّل الدخول بحسابك أولاً';
      case 'NONE':
        return 'لا يوجد اشتراك مرتبط بهذا الحساب';
      default:
        if (err.startsWith('HTTP_401') || err.startsWith('HTTP_403')) {
          return 'مفتاح الخادم غير صحيح — تواصل مع الدعم ($err)';
        }
        if (err.startsWith('HTTP_404')) {
          return 'دوال القاعدة غير منشورة — تواصل مع الدعم ($err)';
        }
        return 'تعذّر تفعيل الكود ($err)';
    }
  }
}
