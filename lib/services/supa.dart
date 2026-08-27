part of '../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — عميل Supabase مبسّط (REST مباشر)
//  ──────────────────────────────────────────────────────────────────────
//  لماذا REST بدل حزمة supabase_flutter؟
//   • بلا أي مكتبة إضافية في pubspec — لا تعارضات ولا زيادة في حجم APK
//   • نستدعي دالتين فقط في القاعدة، فلا داعي لعميل كامل
//   • يستخدم dio الموجود أصلاً في المشروع
//
//  التطبيق لا يستطيع قراءة الجداول مباشرةً — فقط تنفيذ redeem_code
//  و get_subscription. هذا مضبوط في القاعدة نفسها (RLS + GRANT).
// ════════════════════════════════════════════════════════════════════════

class Supa {
  Supa._();

  static Dio? _dio;

  static Dio get _client {
    _dio ??= Dio(BaseOptions(
      baseUrl: '$kSupaUrl/rest/v1/',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'apikey':        kSupaPublicKey,
        'Authorization': 'Bearer $kSupaPublicKey',
        'Content-Type':  'application/json',
      },
      // نتعامل مع رموز الخطأ بأنفسنا بدل رمي استثناء
      validateStatus: (s) => s != null && s < 500,
    ));
    return _dio!;
  }

  /// استدعاء دالة في القاعدة (RPC).
  /// يعيد Map عند النجاح، أو null عند فشل الشبكة.
  static Future<Map<String, dynamic>?> rpc(
    String fn,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (!kSupaReady) {
      debugPrint('Supa: not configured — راجع lib/core/supa_config.dart');
      return null;
    }
    try {
      final res = await _client
          .post('rpc/$fn', data: params)
          .timeout(timeout);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final d = res.data;
        if (d is Map) return Map<String, dynamic>.from(d);
        if (d is List && d.isNotEmpty && d.first is Map) {
          return Map<String, dynamic>.from(d.first as Map);
        }
        return <String, dynamic>{'ok': true, 'data': d};
      }

      debugPrint('Supa.rpc($fn) HTTP ${res.statusCode}: ${res.data}');
      return <String, dynamic>{
        'ok': false,
        'error': 'HTTP_${res.statusCode}',
        'detail': res.data?.toString() ?? '',
      };
    } on TimeoutException {
      debugPrint('Supa.rpc($fn): timeout');
      return null;
    } on DioException catch (e) {
      debugPrint('Supa.rpc($fn): ${e.type} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Supa.rpc($fn): $e');
      return null;
    }
  }

  /// فحص سريع للاتصال — يُستخدم في شاشة التشخيص.
  static Future<bool> ping() async {
    if (!kSupaReady) return false;
    try {
      final res = await _client
          .get('', options: Options(validateStatus: (s) => s != null))
          .timeout(const Duration(seconds: 8));
      return res.statusCode != null && res.statusCode! < 500;
    } catch (_) {
      return false;
    }
  }
}
