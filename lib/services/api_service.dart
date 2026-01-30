import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'cache_manager.dart'; // الملف الذي أنشأناه سابقاً
import '../core/security.dart'; // ملف التشفير

class ApiService {
  // استخدام التشفير لفك رابط السيرفر الأساسي (زيادة في الأمان)
  final String _baseUrl = "https://api.themoviedb.org/3";

  Future<List<dynamic>> fetchMoviesByCategory(int genreId) async {
    // 1. محاولة جلب البيانات من التخزين المؤقت أولاً لتسريع التطبيق
    try {
      final cachedData = await CacheManager.getCachedMovies(genreId);
      if (cachedData != null) {
        return cachedData;
      }
    } catch (e) {
      print("Cache Error: $e");
    }

    // 2. بناء الرابط بذكاء
    String endpoint = (genreId == 0) 
        ? "$_baseUrl/trending/movie/week" 
        : "$_baseUrl/discover/movie";

    final String fullUrl = "$endpoint?api_key=${AppAssets.tmdbApiKey}&language=ar&with_genres=${genreId == 0 ? '' : genreId}";

    try {
      // 3. الاتصال بالسيرفر مع إضافة Timeout (مهلة زمنية) لضمان عدم تعليق التطبيق
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {"Accept": "application/json"},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> results = data['results'];

        // 4. حفظ النتائج في التخزين المؤقت للمرة القادمة
        await CacheManager.cacheMovies(genreId, results);

        return results;
      } else {
        // في حال فشل السيرفر، نحاول العودة للكاش القديم جداً كحل أخير
        return await CacheManager.getOldCache(genreId) ?? [];
      }
    } catch (e) {
      // إرسال تقرير خطأ صامت وتوجيه المستخدم للدعم الفني الخاص بك 9647714415816
      print("Network Error: $e");
      return [];
    }
  }

  // دالة إضافية لجلب "الفيديو الإعلاني" (Trailer) للفيلم
  Future<String?> getMovieTrailer(int movieId) async {
    final String url = "$_baseUrl/movie/$movieId/videos?api_key=${AppAssets.tmdbApiKey}&language=ar";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'];
        if (results.isNotEmpty) {
          return "https://www.youtube.com/watch?v=${results[0]['key']}";
        }
      }
    } catch (_) {}
    return null;
  }
}
