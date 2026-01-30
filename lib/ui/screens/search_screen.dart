import 'package:flutter/material.dart';
import '../../services/search_service.dart';
import '../widgets/movie_card.dart'; // سننشئ هذا الملف لاحقاً

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchService _searchService = SearchService();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;

  void _onSearchChanged(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await _searchService.searchContent(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "ابحث عن فيلم، مسلسل، أو مباراة...",
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final item = _searchResults[index];
                return _buildSearchResultItem(item);
              },
            ),
    );
  }

  Widget _buildSearchResultItem(dynamic item) {
    final String? posterPath = item['poster_path'] ?? item['profile_path'];
    return GestureDetector(
      onTap: () {
        // هنا يتم الانتقال لصفحة التشغيل بدقة 1080p
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: posterPath != null
            ? Image.network("https://image.tmdb.org/t/p/w500$posterPath", fit: BoxFit.cover)
            : Container(color: Colors.grey[900], child: const Icon(Icons.movie, color: Colors.white24)),
      ),
    );
  }
}
