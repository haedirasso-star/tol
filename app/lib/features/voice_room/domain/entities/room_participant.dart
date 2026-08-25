import 'room_role.dart';

class RoomParticipant {
  final String uid;
  final String name;
  final String avatarUrl;
  final RoomRole role;

  /// المايك مفتوح من طرف المستخدم نفسه
  final bool isMicEnabled;

  /// كُتم من قِبل المضيف — لا يستطيع فتحه بنفسه
  final bool isMutedByHost;

  final ConnectionQuality quality;
  final bool isLocal;

  const RoomParticipant({
    required this.uid,
    required this.name,
    this.avatarUrl = '',
    this.role = RoomRole.listener,
    this.isMicEnabled = false,
    this.isMutedByHost = false,
    this.quality = ConnectionQuality.unknown,
    this.isLocal = false,
  });

  bool get canSpeak => role.canPublish && !isMutedByHost;
  bool get isHost => role == RoomRole.host;

  RoomParticipant copyWith({
    RoomRole? role,
    bool? isMicEnabled,
    bool? isMutedByHost,
    ConnectionQuality? quality,
  }) =>
      RoomParticipant(
        uid: uid,
        name: name,
        avatarUrl: avatarUrl,
        role: role ?? this.role,
        isMicEnabled: isMicEnabled ?? this.isMicEnabled,
        isMutedByHost: isMutedByHost ?? this.isMutedByHost,
        quality: quality ?? this.quality,
        isLocal: isLocal,
      );

  @override
  bool operator ==(Object o) =>
      o is RoomParticipant &&
      o.uid == uid &&
      o.role == role &&
      o.isMicEnabled == isMicEnabled &&
      o.isMutedByHost == isMutedByHost &&
      o.quality == quality;

  @override
  int get hashCode =>
      Object.hash(uid, role, isMicEnabled, isMutedByHost, quality);
}
