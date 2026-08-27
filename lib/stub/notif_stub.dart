// lib/stub/notif_stub.dart
// Web stub — flutter_local_notifications (not supported on web)

class FlutterLocalNotificationsPlugin {
  Future<bool?> initialize(dynamic settings,
      {dynamic onDidReceiveNotificationResponse,
      dynamic onDidReceiveBackgroundNotificationResponse}) async => true;
  Future<void> show(int id, String? title, String? body,
      dynamic notificationDetails, {String? payload}) async {}
  Future<void> cancel(int id) async {}
  T? resolvePlatformSpecificImplementation<T>() => null;
}

class InitializationSettings {
  final dynamic android;
  final dynamic iOS;
  final dynamic macOS;
  const InitializationSettings({this.android, this.iOS, this.macOS});
}

class AndroidInitializationSettings {
  final String defaultIcon;
  const AndroidInitializationSettings(this.defaultIcon);
}

class DarwinInitializationSettings {
  const DarwinInitializationSettings();
}

class NotificationDetails {
  final dynamic android;
  final dynamic iOS;
  final dynamic macOS;
  const NotificationDetails({this.android, this.iOS, this.macOS});
}

class AndroidNotificationDetails {
  final String channelId;
  final String channelName;
  final Importance? importance;
  final Priority? priority;
  final String? icon;
  final bool? playSound;
  final dynamic sound;
  const AndroidNotificationDetails(this.channelId, this.channelName,
      {this.importance, this.priority, this.icon, this.playSound, this.sound});
}

class DarwinNotificationDetails {
  const DarwinNotificationDetails();
}

class AndroidFlutterLocalNotificationsPlugin {
  Future<bool?> requestNotificationsPermission() async => true;
  Future<void> createNotificationChannel(AndroidNotificationChannel channel) async {}
}

class AndroidNotificationChannel {
  final String id;
  final String name;
  final Importance? importance;
  final bool? playSound;
  const AndroidNotificationChannel(this.id, this.name,
      {this.importance, this.playSound});
}

class Importance {
  final int value;
  const Importance._(this.value);
  static const Importance unspecified = Importance._(-1000);
  static const Importance none        = Importance._(0);
  static const Importance min         = Importance._(1);
  static const Importance low         = Importance._(2);
  static const Importance defaultImportance = Importance._(3);
  static const Importance high        = Importance._(4);
  static const Importance max         = Importance._(5);
}

class Priority {
  final int value;
  const Priority._(this.value);
  static const Priority min     = Priority._(-2);
  static const Priority low     = Priority._(-1);
  static const Priority defaultPriority = Priority._(0);
  static const Priority high    = Priority._(1);
  static const Priority max     = Priority._(2);
}
