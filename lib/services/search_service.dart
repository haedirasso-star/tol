import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';

class SearchService {
  final String _baseUrl = "https://api.themoviedb.org/3/search/multi";

  // دالة البحث الشامل (أفلام، مسلسلات، ممثلين)
  Future<List<dynamic>> searchContent(String query) async {
    if (query.isEmpty) return [];

    final response = await http.get(
      Uri.parse("$_baseUrl?api_key=${AppAssets.tmdbApiKey}&language=ar&query=$query&include_adult=false"),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'];
    } else {
      throw Exception('فشل الاتصال بمحرك البحث العالمي');
    }
  }
}
