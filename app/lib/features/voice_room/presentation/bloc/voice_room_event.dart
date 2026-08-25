import '../../domain/entities/room_role.dart';
import '../../domain/entities/voice_room.dart';

sealed class VoiceRoomEvent {
  const VoiceRoomEvent();
}

class RoomJoinRequested extends VoiceRoomEvent {
  final String roomId;
  const RoomJoinRequested(this.roomId);
}

class RoomLeaveRequested extends VoiceRoomEvent {
  const RoomLeaveRequested();
}

class MicToggled extends VoiceRoomEvent {
  const MicToggled();
}

class SpeakerphoneToggled extends VoiceRoomEvent {
  const SpeakerphoneToggled();
}

class HandRaised extends VoiceRoomEvent {
  final bool up;
  const HandRaised(this.up);
}

class SpeakerPromoted extends VoiceRoomEvent {
  final String uid;
  const SpeakerPromoted(this.uid);
}

class ParticipantMuted extends VoiceRoomEvent {
  final String uid;
  const ParticipantMuted(this.uid);
}

class ParticipantKicked extends VoiceRoomEvent {
  final String uid;
  const ParticipantKicked(this.uid);
}

class ErrorDismissed extends VoiceRoomEvent {
  const ErrorDismissed();
}

// ── أحداث داخلية من الـ Repository (لا تُطلقها الواجهة) ──────
class RoomDataUpdated extends VoiceRoomEvent {
  final VoiceRoom room;
  const RoomDataUpdated(this.room);
}

class ConnectionStateChanged extends VoiceRoomEvent {
  final RoomConnectionState state;
  const ConnectionStateChanged(this.state);
}
