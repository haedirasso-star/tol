import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ApiService {
  final String _baseUrl = "https://api.themoviedb.org/3";

  // جلب قائمة الأفلام الرائجة (Trending)
  Future<List<dynamic>> getTrendingMovies() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/trending/movie/week?api_key=${AppAssets.tmdbApiKey}&language=ar"),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body)['results'];
    } else {
      throw Exception('فشل في الاتصال بالسيرفر');
    }
  }

  // جلب تفاصيل المسلسلات (Series)
  Future<List<dynamic>> getPopularTVShows() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/tv/popular?api_key=${AppAssets.tmdbApiKey}&language=ar"),
    );
    return json.decode(response.body)['results'];
  }
}
