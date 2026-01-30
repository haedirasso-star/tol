import 'package:shared_preferences/shared_preferences.dart'; // لحفظ حالة الاشتراك

class SubscriptionGuard {
  static const String _subKey = "is_user_subscribed";

  // فحص هل المستخدم مشترك فعلاً؟
  static Future<bool> checkSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    // نتحقق من القيمة المخزنة، إذا كانت null تعني لم يشترك بعد
    return prefs.getBool(_subKey) ?? false; 
  }

  // تحديث الحالة عند الضغط على زر الاشتراك
  static Future<void> markAsSubscribed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_subKey, true);
  }
}
