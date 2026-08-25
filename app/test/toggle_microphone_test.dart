import 'package:flutter_test/flutter_test.dart';
import 'package:totv_voice_rooms/features/voice_room/core/failures.dart';
import 'package:totv_voice_rooms/features/voice_room/domain/entities/room_participant.dart';
import 'package:totv_voice_rooms/features/voice_room/domain/entities/room_role.dart';
import 'package:totv_voice_rooms/features/voice_room/domain/entities/voice_room.dart';
import 'package:totv_voice_rooms/features/voice_room/domain/repositories/voice_room_repository.dart';
import 'package:totv_voice_rooms/features/voice_room/domain/usecases/voice_room_usecases.dart';

/// ═══════════════════════════════════════════════════════════════
///  الفائدة العملية للـ Clean Architecture تظهر هنا:
///  نختبر منطق الصلاحيات بلا Flutter، بلا Firebase، بلا LiveKit،
///  وبلا شبكة. الاختبار كله يعمل في أجزاء من الثانية.
/// ═══════════════════════════════════════════════════════════════
class _FakeRepo implements VoiceRoomRepository {
  bool? lastMicCall;

  @override
  Future<Result<void>> setMicEnabled(bool enabled) async {
    lastMicCall = enabled;
    return const Ok(null);
  }

  @override
  Stream<RoomConnectionState> get connectionState => const Stream.empty();
  @override
  Stream<VoiceRoom> get roomStream => const Stream.empty();
  @override
  Stream<Map<String, double>> get audioLevels => const Stream.empty();
  @override
  Future<Result<VoiceRoom>> join(String r) async => const Ok(VoiceRoom(id: ''));
  @override
  Future<Result<void>> leave() async => const Ok(null);
  @override
  Future<Result<void>> setSpeakerphone(bool on) async => const Ok(null);
  @override
  Future<Result<void>> raiseHand(bool up) async => const Ok(null);
  @override
  Future<Result<void>> promote(String uid) async => const Ok(null);
  @override
  Future<Result<void>> muteParticipant(String uid) async => const Ok(null);
  @override
  Future<Result<void>> kick(String uid) async => const Ok(null);
  @override
  Future<Result<List<VoiceRoomSummary>>> fetchRooms() async => const Ok([]);
  @override
  Future<Result<String>> createRoom(String t) async => const Ok('');
  @override
  Future<Result<void>> closeRoom(String id) async => const Ok(null);
  @override
  Future<void> dispose() async {}
}

void main() {
  late _FakeRepo repo;
  late ToggleMicrophone toggle;

  setUp(() {
    repo = _FakeRepo();
    toggle = ToggleMicrophone(repo);
  });

  test('المستمع لا يستطيع فتح المايك', () async {
    const me = RoomParticipant(
        uid: 'u1', name: 'أحمد', role: RoomRole.listener);

    final r = await toggle(me: me, enable: true);

    expect(r.isOk, isFalse);
    expect(repo.lastMicCall, isNull, reason: 'يجب ألا نصل للطبقة التقنية أصلاً');
    r.fold((f) => expect(f, isA<NotAllowedFailure>()), (_) => fail('نجح خطأً'));
  });

  test('المكتوم من المضيف لا يستطيع فتح المايك', () async {
    const me = RoomParticipant(
        uid: 'u1', name: 'أحمد', role: RoomRole.speaker, isMutedByHost: true);

    final r = await toggle(me: me, enable: true);

    expect(r.isOk, isFalse);
    expect(repo.lastMicCall, isNull);
  });

  test('المتحدث يستطيع فتح المايك', () async {
    const me =
        RoomParticipant(uid: 'u1', name: 'أحمد', role: RoomRole.speaker);

    final r = await toggle(me: me, enable: true);

    expect(r.isOk, isTrue);
    expect(repo.lastMicCall, isTrue);
  });

  test('المستمع يستطيع الكتم دائماً (لا يحتاج صلاحية)', () async {
    const me = RoomParticipant(
        uid: 'u1', name: 'أحمد', role: RoomRole.listener);

    final r = await toggle(me: me, enable: false);

    expect(r.isOk, isTrue);
    expect(repo.lastMicCall, isFalse);
  });

  test('الترقية للمضيف فقط', () async {
    final promote = PromoteToSpeaker(repo);
    const notHost =
        RoomParticipant(uid: 'u1', name: 'أحمد', role: RoomRole.speaker);

    final r = await promote(actor: notHost, targetUid: 'u2');

    expect(r.isOk, isFalse);
  });
}
