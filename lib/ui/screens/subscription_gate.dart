import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_screen.dart';

class SubscriptionGate extends StatefulWidget {
  const SubscriptionGate({super.key});

  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate> {
  bool _isSubscribed = false;

  // دالة توجيه المستخدم للقناة t.me/O_2828
  Future<void> _joinTelegram() async {
    const String url = "https://t.me/O_2828";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      // بعد العودة، نعتبره اشترك (أو يمكنك إضافة فحص حقيقي عبر API)
      setState(() => _isSubscribed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // خلفية جمالية بشعار TOL
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.network(
                "https://images.unsplash.com/photo-1616530940355-351fabd9524b?q=80&w=1000",
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_person_rounded, size: 80, color: Color(0xFFFFD700)),
                    const SizedBox(height: 20),
                    const Text(
                      "تطبيق TOL محمي",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "للاستمتاع بمشاهدة beIN Sports وأحدث الأفلام، يجب عليك الانضمام لقناتنا الرسمية أولاً.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    
                    // زر الاشتراك الذهبي
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _joinTelegram,
                      child: const Text(
                        "انضم للقناة الآن",
                        style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // زر الدخول (لا يعمل إلا بعد الضغط على الاشتراك)
                    TextButton(
                      onPressed: _isSubscribed 
                        ? () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()))
                        : null,
                      child: Text(
                        "دخلت للقناة، أريد المشاهدة",
                        style: TextStyle(
                          color: _isSubscribed ? Colors.white : Colors.white24,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
