import '../../domain/entities/room_participant.dart';
import '../../domain/entities/room_role.dart';
import '../../domain/entities/voice_room.dart';

class VoiceRoomState {
  final RoomConnectionState connection;
  final VoiceRoom? room;
  final String myUid;
  final bool micEnabled;
  final bool speakerphone;
  final bool handRaised;
  final bool busy;
  final String? error;

  const VoiceRoomState({
    this.connection = RoomConnectionState.disconnected,
    this.room,
    this.myUid = '',
    this.micEnabled = false,
    this.speakerphone = true,
    this.handRaised = false,
    this.busy = false,
    this.error,
  });

  RoomParticipant? get me => room?.participantById(myUid);
  RoomRole get myRole => me?.role ?? RoomRole.listener;

  bool get isHost => myRole == RoomRole.host;
  bool get isListener => myRole == RoomRole.listener;
  bool get canToggleMic => me?.canSpeak ?? false;
  bool get isLive => connection == RoomConnectionState.connected;
  bool get isReconnecting => connection == RoomConnectionState.reconnecting;

  List<RoomParticipant> get speakers => room?.speakers ?? const [];
  int get listenerCount => room?.listenerCount ?? 0;

  VoiceRoomState copyWith({
    RoomConnectionState? connection,
    VoiceRoom? room,
    String? myUid,
    bool? micEnabled,
    bool? speakerphone,
    bool? handRaised,
    bool? busy,
    String? error,
    bool clearError = false,
    bool clearRoom = false,
  }) =>
      VoiceRoomState(
        connection: connection ?? this.connection,
        room: clearRoom ? null : (room ?? this.room),
        myUid: myUid ?? this.myUid,
        micEnabled: micEnabled ?? this.micEnabled,
        speakerphone: speakerphone ?? this.speakerphone,
        handRaised: handRaised ?? this.handRaised,
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  bool operator ==(Object o) =>
      o is VoiceRoomState &&
      o.connection == connection &&
      o.micEnabled == micEnabled &&
      o.speakerphone == speakerphone &&
      o.handRaised == handRaised &&
      o.busy == busy &&
      o.error == error &&
      o.myUid == myUid &&
      _sameSpeakers(o.speakers, speakers) &&
      o.listenerCount == listenerCount;

  static bool _sameSpeakers(List<RoomParticipant> a, List<RoomParticipant> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(connection, micEnabled, speakerphone,
      handRaised, busy, error, myUid, listenerCount, speakers.length);
}
