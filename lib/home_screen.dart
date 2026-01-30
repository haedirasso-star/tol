import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../constants.dart';
import '../widgets/shimmer_loading.dart';
import 'video_player_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _trendingMovies = [];
  dynamic _heroMovie;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // جلب البيانات الفعلية من السيرفر لتطبيق TOL
  Future<void> _loadData() async {
    try {
      final movies = await _apiService.fetchMoviesByCategory(0); // جلب التريند
      setState(() {
        _trendingMovies = movies;
        if (movies.isNotEmpty) _heroMovie = movies[0]; // أول فيلم يكون هو الواجهة
        _isLoading = false;
      });
    } catch (e) {
      print("خطأ في TOL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading 
          ? const ShimmerLoading() 
          : CustomScrollView(
              slivers: [
                // 1. الجزء العلوي الديناميكي (Hero Section)
                SliverToBoxAdapter(
                  child: _buildHeroSection(_heroMovie),
                ),

                // 2. شريط التصنيفات الاحترافي
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                
                // 3. الأقسام المتعددة (Movies Rows)
                _buildSectionTitle("الأكثر مشاهدة على TOL"),
                _buildHorizontalList(_trendingMovies),

                _buildSectionTitle("مسلسلات حصرية"),
                _buildHorizontalList(_trendingMovies.reversed.toList()),

                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ),
    );
  }

  Widget _buildHeroSection(dynamic movie) {
    return Container(
      height: 550,
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage("https://image.tmdb.org/t/p/original${movie['poster_path']}"),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                movie['title'] ?? movie['name'] ?? "TOL Original",
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  // ربط زر التشغيل بمشغل الفيديو 1080p
                  ElevatedButton.icon(
                    onPressed: () => _playVideo(movie),
                    icon: const Icon(Icons.play_arrow, color: Colors.black),
                    label: const Text("تشغيل الآن", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(width: 15),
                  // زر الدعم الفني (واتسابك)
                  OutlinedButton.icon(
                    onPressed: () => _openSupport(),
                    icon: const Icon(Icons.support_agent, color: Colors.white),
                    label: const Text("دعم TOL", style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // دالة تشغيل الفيديو مع فحص الاشتراك الإجباري
  void _playVideo(dynamic movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          videoUrl: "https://vidsrc.to/embed/movie/${movie['id']}",
          title: movie['title'] ?? "TOL Stream",
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHorizontalList(List<dynamic> movies) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          scrollDirection: Axis.horizontal,
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            return Container(
              width: 150,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  "https://image.tmdb.org/t/p/w500${movie['poster_path']}",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openSupport() {
    // كود فتح الواتساب 9647714415816
  }
}
