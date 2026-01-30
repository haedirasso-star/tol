import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // ربط مجاني بالسحابة
  runApp(const TOLApp());
}

class TOLApp extends StatelessWidget {
  const TOLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFFD700), // اللون الذهبي الخاص بك
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const SubscriptionScreen(),
    );
  }
}

// --- شاشة الاشتراك المطورة (اختيارية) ---
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.grey.shade900],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded, size: 120, color: Color(0xFFFFD700)),
              const SizedBox(height: 20),
              const Text("TOL STREAM", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                child: Text("اشترك في قناة المطور لتفعيل كافة ميزات البث المباشر", textAlign: TextAlign.center),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => launchUrl(Uri.parse('https://t.me/O_2828')),
                child: const Text("اشتراك تليجرام", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen())),
                child: const Text("تم الاشتراك؟ دخول الآن", style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- الصفحة الرئيسية المطورة (تصميم المنصات) ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text("TOL", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none))],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildFeaturedPoster(), // بوستر إعلاني ضخم في الأعلى
            _buildSectionHeader("القنوات المباشرة"),
            _buildLiveChannels(),
            _buildSectionHeader("أفلام حصرية"),
            _buildMovieGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedPoster() {
    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: NetworkImage('https://via.placeholder.com/600x300/FFD700/000000?text=Featured+Movie'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent]),
        ),
        padding: const EdgeInsets.all(15),
        alignment: Alignment.bottomLeft,
        child: const Text("شاهد الآن: فيلم الأسبوع", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("عرض الكل", style: TextStyle(color: Color(0xFFFFD700), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildLiveChannels() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 15),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          width: 80,
          margin: const EdgeInsets.only(right: 15),
          decoration: BoxDecoration(
            shape: BoxType.circle, // قنوات دائرية مثل Instagram Stories
            border: Border.all(color: const Color(0xFFFFD700), width: 2),
            color: Colors.grey.shade900,
          ),
          child: const Icon(Icons.tv, color: Color(0xFFFFD700)),
        ),
      ),
    );
  }

  Widget _buildMovieGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          color: Colors.grey.shade900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Container(color: Colors.grey.shade800, child: const Center(child: Icon(Icons.image, size: 50)))),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("اسم الفيلم هنا", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
