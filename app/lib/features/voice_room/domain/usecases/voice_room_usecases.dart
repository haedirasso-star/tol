import '../../core/failures.dart';
import '../entities/room_participant.dart';
import '../entities/room_role.dart';
import '../entities/voice_room.dart';
import '../repositories/voice_room_repository.dart';

class JoinVoiceRoom {
  final VoiceRoomRepository _r;
  const JoinVoiceRoom(this._r);
  Future<Result<VoiceRoom>> call(String roomId) => _r.join(roomId);
}

class LeaveVoiceRoom {
  final VoiceRoomRepository _r;
  const LeaveVoiceRoom(this._r);
  Future<Result<void>> call() => _r.leave();
}

/// يحرس القواعد **قبل** لمس الطبقة التقنية.
/// وضع هذا المنطق هنا (لا في الـ BLoC) يجعله قابلاً للاختبار بلا Flutter.
class ToggleMicrophone {
  final VoiceRoomRepository _r;
  const ToggleMicrophone(this._r);

  Future<Result<void>> call({
    required RoomParticipant? me,
    required bool enable,
  }) async {
    if (me == null) {
      return const Err(NotAllowedFailure('لم تنضم للغرفة بعد'));
    }
    if (enable && me.role == RoomRole.listener) {
      return const Err(NotAllowedFailure('أنت مستمع — ارفع يدك لطلب التحدث'));
    }
    if (enable && me.isMutedByHost) {
      return const Err(NotAllowedFailure('المضيف كتم المايك الخاص بك'));
    }
    return _r.setMicEnabled(enable);
  }
}

class PromoteToSpeaker {
  final VoiceRoomRepository _r;
  const PromoteToSpeaker(this._r);

  Future<Result<void>> call({
    required RoomParticipant? actor,
    required String targetUid,
  }) async {
    if (actor?.role != RoomRole.host) {
      return const Err(NotAllowedFailure('للمضيف فقط'));
    }
    return _r.promote(targetUid);
  }
}

class ModerateParticipant {
  final VoiceRoomRepository _r;
  const ModerateParticipant(this._r);

  Future<Result<void>> mute(RoomParticipant? actor, String uid) async {
    if (actor?.role != RoomRole.host) {
      return const Err(NotAllowedFailure('للمضيف فقط'));
    }
    return _r.muteParticipant(uid);
  }

  Future<Result<void>> kick(RoomParticipant? actor, String uid) async {
    if (actor?.role != RoomRole.host) {
      return const Err(NotAllowedFailure('للمضيف فقط'));
    }
    return _r.kick(uid);
  }
}

class FetchVoiceRooms {
  final VoiceRoomRepository _r;
  const FetchVoiceRooms(this._r);
  Future<Result<List<VoiceRoomSummary>>> call() => _r.fetchRooms();
}

class CreateVoiceRoom {
  final VoiceRoomRepository _r;
  const CreateVoiceRoom(this._r);
  Future<Result<String>> call(String title) => _r.createRoom(title.trim());
}
