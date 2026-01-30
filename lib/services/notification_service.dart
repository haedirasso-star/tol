import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // تهيئة النظام عند تشغيل التطبيق
  Future<void> initialize() async {
    // طلب إذن من المستخدم لإرسال الإشعارات
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('تم تفعيل نظام الإشعارات بنجاح');
      
      // الحصول على "توكن" الجهاز (مفتاح فريد لكل مستخدم)
      String? token = await _fcm.getToken();
      print("Token الخاص بالمستخدم: $token");
      
      // هنا يمكنك حفظ التوكن في قاعدة بياناتك لترسل له إشعارات خاصة
    }

    // التعامل مع الإشعارات عندما يكون التطبيق في الخلفية
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  // عرض الإشعار بشكل احترافي في أعلى الشاشة
  void _showLocalNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'streaming_channel_id',
      'بث المباريات والأفلام',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFFFFD700), // اللون الذهبي الخاص بك
      playSound: true,
    );

    _localNotifications.show(
      0,
      message.notification?.title, // مثال: "بدأت المباراة الآن! ⚽"
      message.notification?.body,  // مثال: "شاهد ريال مدريد ضد برشلونة بجودة 1080p"
      const NotificationDetails(android: androidDetails),
    );
  }
}
