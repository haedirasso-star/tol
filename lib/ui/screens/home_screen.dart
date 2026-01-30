// 1. تعريف المتغير في أعلى الكلاس (خارج دالة build)
class _HomeScreenState extends State<HomeScreen> {
  int navigationCount = 0; // عداد التصفح
  List<dynamic> _movieList = []; // قائمة الأفلام التي ستعرض
  final ApiService apiService = ApiService(); // محرك جلب البيانات

  // 2. وضع الدالة التي تتحكم في الضغط على التصنيفات
  void onGenreTap(int genreId) async {
    navigationCount++;
    
    // فحص الاشتراك الإجباري بعد 3 ضغطات
    if (navigationCount > 3) {
      bool isSubbed = await SubscriptionGuard.checkSubscriptionStatus();
      if (!isSubbed) {
        // إظهار نافذة الاشتراك في قناتك t.me/O_2828
        AppDialogs.showForceSub(context, "https://t.me/O_2828");
        return; // توقف الكود هنا ولن يتم جلب الأفلام حتى يشترك
      }
    }
    
    // جلب البيانات الجديدة بناءً على التصنيف
    try {
      final List<dynamic> updatedMovies = await apiService.fetchMoviesByCategory(genreId);
      setState(() {
        _movieList = updatedMovies;
      });
    } catch (e) {
      print("خطأ في تحديث القائمة: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // هنا يتم استدعاء onGenreTap عند الضغط على أي زر في FilterBar
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          FilterBar(onGenreSelected: onGenreTap), // ربط الشريط بالدالة
          Expanded(child: MovieGridView(movies: _movieList)), // عرض الأفلام
        ],
      ),
    );
  }
}
