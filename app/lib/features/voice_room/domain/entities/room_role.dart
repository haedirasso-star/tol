/// دور المشارك — يُحدَّد من الخادم دائماً، لا من العميل
enum RoomRole {
  /// يسمع فقط. لا يُنشئ مسار صوت إطلاقاً → توفير بطارية كامل.
  listener,

  /// يستطيع التحدث — لديه مسار صوت منشور
  speaker,

  /// متحدث + صلاحيات إدارة
  host;

  static RoomRole fromString(String? s) => switch (s) {
        'host' => RoomRole.host,
        'speaker' => RoomRole.speaker,
        _ => RoomRole.listener,
      };

  bool get canPublish => this != RoomRole.listener;
}

/// جودة الاتصال كما يبلّغ عنها الخادم
enum ConnectionQuality { excellent, good, poor, lost, unknown }

/// حالة الاتصال بالغرفة
enum RoomConnectionState { disconnected, connecting, connected, reconnecting }
