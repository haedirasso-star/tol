import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const TOLApp());
}

class TOLApp extends StatelessWidget {
  const TOLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SubscriptionScreen(),
    );
  }
}

// 1. شاشة الاشتراك (مع تفعيل زر الدخول وتعديل الخطوط)
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield, size: 100, color: Color(0xFFFFD700)),
              const SizedBox(height: 20),
              const Text(
                "تطبيق TOL",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFFD700)),
              ),
              const SizedBox(height: 15),
              const Text(
                "لمتابعة البث المباشر والحصول على كافة الميزات، يجب الاشتراك في قناة المطور أولاً.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              
              // زر الاشتراك الأصفر
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () => launchUrl(Uri.parse('https://t.me/O_2828')),
                icon: const Icon(Icons.send),
                label: const Text("اشترك الآن لتفعيل التطبيق", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              
              const SizedBox(height: 20),

              // تفعيل نص "تم الاشتراك؟ اضغط هنا للدخول"
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                child: const Text(
                  "تم الاشتراك؟ اضغط هنا للدخول",
                  style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 2. الصفحة الرئيسية المنظمة (نظام البطاقات والأقسام)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TOL - القائمة الرئيسية"),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          _buildSectionTitle("البث المباشر"),
          _buildHorizontalList(["قناة 1", "قناة 2", "قناة 3"]),
          const SizedBox(height: 20),
          _buildSectionTitle("آخر الأفلام"),
          _buildMovieGrid(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFD700))),
    );
  }

  Widget _buildHorizontalList(List<String> items) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) => Container(
          width: 150,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(items[index])),
        ),
      ),
    );
  }

  Widget _buildMovieGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.7,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(15)),
        child: const Center(child: Icon(Icons.movie, size: 50)),
      ),
    );
  }
}
