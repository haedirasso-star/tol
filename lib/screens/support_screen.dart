import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // ستحتاج لإضافتها في pubspec.yaml
import 'package:url_launcher/url_launcher.dart';
import '../../constants.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  // دالة ذكية لفتح الروابط الخارجية
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'تعذر فتح الرابط: $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("مركز الدعم والاشتراك", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // شعار التطبيق أو صورة رمزية
            const CircleAvatar(
              radius: 60,
              backgroundColor: Color(0xFFFFD700),
              child: Icon(Icons.support_agent, size: 70, color: Colors.black),
            ),
            const SizedBox(height: 30),
            
            const Text(
              "كيف يمكننا مساعدتك؟",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "تواصل معنا مباشرة للحصول على كود التفعيل أو الإبلاغ عن مشكلة في البث",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 40),

            // زر الواتساب الذهبي
            _buildSupportCard(
              title: "تحدث معنا عبر واتساب",
              subtitle: "009647714415816",
              icon: FontAwesomeIcons.whatsapp,
              color: const Color(0xFF25D366),
              onTap: () => _launchURL("https://wa.me/9647714415816"),
            ),

            const SizedBox(height: 20),

            // زر التليجرام الاحترافي
            _buildSupportCard(
              title: "قناة التحديثات (تليجرام)",
              subtitle: "@O_2828",
              icon: FontAwesomeIcons.telegram,
              color: const Color(0xFF0088CC),
              onTap: () => _launchURL("https://t.me/O_2828"),
            ),

            const SizedBox(height: 40),
            
            // حقوق الملكية في الأسفل
            const Text(
              "جميع الحقوق محفوظة © 2026",
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}
