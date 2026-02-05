/// إعدادات الاتصال بسيرفر المحتوى (صور وأفلام).
/// المفتاح يُستخدم في رؤوس الطلبات لتفويض جلب الوسائط.
class ApiConfig {
  ApiConfig._();

  /// مفتاح تفويض جلب الصور والأفلام من السيرفر.
  /// يُضاف في رؤوس الطلبات (X-API-Key أو Authorization).
  static const String mediaApiKey = '5b166a24c91f59178e8ce30f1f3735c0';

  /// رؤوس HTTP لطلبات الوسائط (صور + فيديو).
  /// استخدمها مع CachedNetworkImage و VideoPlayerController.
  static Map<String, String> get mediaHeaders => {
        'X-API-Key': mediaApiKey,
        'User-Agent': 'TOTV-Plus/1.0',
      };
}
