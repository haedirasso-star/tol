import '../../core/failures.dart';
import '../entities/room_participant.dart';
import '../entities/room_role.dart';
import '../entities/voice_room.dart';

/// نتيجة إما خطأ أو قيمة — بديل خفيف عن dartz بلا تبعية إضافية
sealed class Result<T> {
  const Result();
  R fold<R>(R Function(Failure) onError, R Function(T) onOk) => switch (this) {
        Err<T>(failure: final f) => onError(f),
        Ok<T>(value: final v) => onOk(v),
      };
  bool get isOk => this is Ok<T>;
  T? get valueOrNull => this is Ok<T> ? (this as Ok<T>).value : null;
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final Failure failure;
  const Err(this.failure);
}

/// ═══════════════════════════════════════════════════════════════
///  العقد المجرّد — ⚠️ لا يذكر LiveKit ولا Firebase إطلاقاً.
///  لاستبدال LiveKit بـ Agora: اكتب Impl جديداً فقط.
///  الـ Domain والـ BLoC والواجهة لا تتغيّر بحرف واحد.
/// ═══════════════════════════════════════════════════════════════
abstract class VoiceRoomRepository {
  Stream<RoomConnectionState> get connectionState;

  /// الغرفة ومشاركوها — يُبثّ عند كل تغيير هيكلي
  Stream<VoiceRoom> get roomStream;

  /// مستويات الصوت — تيار منفصل عالي التردد (~10 مرات/ثانية).
  /// ⚠️ لا تدمجه في roomStream وإلا أعدت بناء الشاشة 10 مرات/ثانية.
  Stream<Map<String, double>> get audioLevels;

  Future<Result<VoiceRoom>> join(String roomId);
  Future<Result<void>> leave();

  Future<Result<void>> setMicEnabled(bool enabled);
  Future<Result<void>> setSpeakerphone(bool on);

  Future<Result<void>> raiseHand(bool up);
  Future<Result<void>> promote(String uid);
  Future<Result<void>> muteParticipant(String uid);
  Future<Result<void>> kick(String uid);

  /// قائمة الغرف — قراءة واحدة من Firestore
  Future<Result<List<VoiceRoomSummary>>> fetchRooms();
  Future<Result<String>> createRoom(String title);
  Future<Result<void>> closeRoom(String roomId);

  Future<void> dispose();
}
