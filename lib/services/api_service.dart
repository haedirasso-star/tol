import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ApiService {
  final String _baseUrl = "https://api.themoviedb.org/3";

  // الدالة المتطورة: تجلب البيانات بناءً على الـ ID الخاص بالتصنيف
  Future<List<dynamic>> fetchMoviesByCategory(int genreId) async {
    // 1. تحديد الرابط: إذا كان الـ ID هو 0 (الكل) يجلب التريند، وإلا يجلب تصنيفاً محدداً
    String endpoint = (genreId == 0) 
        ? "$_baseUrl/trending/movie/week" 
        : "$_baseUrl/discover/movie";

    // 2. بناء الرابط مع مفتاح الـ API واللغة وفلتر التصنيف
    final String fullUrl = "$endpoint?api_key=${AppAssets.tmdbApiKey}&language=ar&with_genres=${genreId == 0 ? '' : genreId}";

    try {
      final response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['results']; // إرجاع قائمة الأفلام المفلترة
      } else {
        throw Exception('فشل في جلب البيانات من السيرفر');
      }
    } catch (e) {
      // في حال حدوث خطأ، نوجه المستخدم للدعم الفني الخاص بك
      print("Error: $e");
      return [];
    }
  }
}
