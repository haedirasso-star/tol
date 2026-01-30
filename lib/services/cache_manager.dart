import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static const String _movieCacheKey = "cached_movies_list";
  static const String _cacheTimeKey = "last_cache_time";

  // حفظ قائمة الأفلام في ذاكرة الهاتف
  static Future<void> cacheMovies(List<dynamic> movies) async {
    final prefs = await SharedPreferences.getInstance();
    String encodedData = json.encode(movies);
    await prefs.setString(_movieCacheKey, encodedData);
    await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  // جلب الأفلام من الذاكرة (بدون إنترنت)
  static Future<List<dynamic>?> getCachedMovies() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString(_movieCacheKey);
    
    if (cachedData != null) {
      // فحص هل البيانات قديمة (أكثر من 24 ساعة)؟
      int lastCache = prefs.getInt(_cacheTimeKey) ?? 0;
      int now = DateTime.now().millisecondsSinceEpoch;
      
      if (now - lastCache < 86400000) { // 24 ساعة بالملي ثانية
        return json.decode(cachedData);
      }
    }
    return null;
  }

  // مسح التخزين المؤقت عند تحديث القناة أو السيرفر
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_movieCacheKey);
  }
}
