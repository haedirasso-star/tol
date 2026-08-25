import 'room_participant.dart';
import 'room_role.dart';

/// ملخّص الغرفة في القائمة الرئيسية (من Firestore — قراءة واحدة)
class VoiceRoomSummary {
  final String id;
  final String title;
  final String hostUid;
  final String hostName;
  final int listenerCount;
  final bool isLive;
  final bool isLocked;

  const VoiceRoomSummary({
    required this.id,
    required this.title,
    required this.hostUid,
    this.hostName = '',
    this.listenerCount = 0,
    this.isLive = false,
    this.isLocked = false,
  });

  factory VoiceRoomSummary.fromMap(String id, Map<String, dynamic> m) =>
      VoiceRoomSummary(
        id: id,
        title: m['title']?.toString() ?? '',
        hostUid: m['hostUid']?.toString() ?? '',
        hostName: m['hostName']?.toString() ?? '',
        listenerCount: (m['count'] as num?)?.toInt() ?? 0,
        isLive: m['live'] == true,
        isLocked: m['locked'] == true,
      );
}

/// الغرفة الحيّة — تأتي من LiveKit مباشرة، لا من Firestore
class VoiceRoom {
  final String id;
  final String title;
  final String hostUid;

  /// المتحدثون فقط. المستمعون لا يُعرضون فردياً — قد يكونون بالآلاف.
  final List<RoomParticipant> speakers;
  final int listenerCount;

  const VoiceRoom({
    required this.id,
    this.title = '',
    this.hostUid = '',
    this.speakers = const [],
    this.listenerCount = 0,
  });

  RoomParticipant? participantById(String uid) {
    for (final p in speakers) {
      if (p.uid == uid) return p;
    }
    return null;
  }

  List<RoomParticipant> get activeSpeakers =>
      speakers.where((p) => p.role != RoomRole.listener).toList();
}
