import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/room_role.dart';
import '../../domain/repositories/voice_room_repository.dart';
import '../../domain/usecases/voice_room_usecases.dart';
import 'voice_room_event.dart';
import 'voice_room_state.dart';

class VoiceRoomBloc extends Bloc<VoiceRoomEvent, VoiceRoomState>
    with WidgetsBindingObserver {
  final JoinVoiceRoom _join;
  final LeaveVoiceRoom _leave;
  final ToggleMicrophone _toggleMic;
  final PromoteToSpeaker _promote;
  final ModerateParticipant _moderate;
  final VoiceRoomRepository _repo;

  StreamSubscription? _roomSub;
  StreamSubscription? _connSub;

  VoiceRoomBloc({
    required JoinVoiceRoom join,
    required LeaveVoiceRoom leave,
    required ToggleMicrophone toggleMic,
    required PromoteToSpeaker promote,
    required ModerateParticipant moderate,
    required VoiceRoomRepository repo,
    required String myUid,
  })  : _join = join,
        _leave = leave,
        _toggleMic = toggleMic,
        _promote = promote,
        _moderate = moderate,
        _repo = repo,
        super(VoiceRoomState(myUid: myUid)) {
    on<RoomJoinRequested>(_onJoin);
    on<RoomLeaveRequested>(_onLeave);
    on<MicToggled>(_onMic);
    on<SpeakerphoneToggled>(_onSpeakerphone);
    on<HandRaised>(_onHand);
    on<SpeakerPromoted>(_onPromote);
    on<ParticipantMuted>(_onMute);
    on<ParticipantKicked>(_onKick);
    on<ErrorDismissed>((_, emit) => emit(state.copyWith(clearError: true)));
    on<RoomDataUpdated>(_onRoomData);
    on<ConnectionStateChanged>(
        (e, emit) => emit(state.copyWith(connection: e.state)));

    WidgetsBinding.instance.addObserver(this);
  }

  // ── الانضمام ──────────────────────────────────────────────────
  Future<void> _onJoin(
      RoomJoinRequested e, Emitter<VoiceRoomState> emit) async {
    emit(state.copyWith(
      busy: true,
      clearError: true,
      connection: RoomConnectionState.connecting,
    ));

    // اربط التيارات مرة واحدة فقط
    _roomSub ??= _repo.roomStream.listen((r) => add(RoomDataUpdated(r)));
    _connSub ??=
        _repo.connectionState.listen((s) => add(ConnectionStateChanged(s)));

    final res = await _join(e.roomId);
    res.fold(
      (f) => emit(state.copyWith(
        busy: false,
        error: f.message,
        connection: RoomConnectionState.disconnected,
      )),
      (room) => emit(state.copyWith(
        busy: false,
        room: room,
        micEnabled: false, // ★ ندخل مكتومين دائماً
        connection: RoomConnectionState.connected,
      )),
    );
  }

  /// يزامن حالة المايك المحلية مع ما يبلّغه الخادم فعلاً
  /// (مهم عندما يكتمك المضيف — الزر يجب أن ينطفئ من نفسه)
  void _onRoomData(RoomDataUpdated e, Emitter<VoiceRoomState> emit) {
    final mine = e.room.participantById(state.myUid);
    emit(state.copyWith(
      room: e.room,
      micEnabled: mine?.isMicEnabled ?? state.micEnabled,
    ));
  }

  // ── المايك (تحديث متفائل) ─────────────────────────────────────
  Future<void> _onMic(MicToggled e, Emitter<VoiceRoomState> emit) async {
    final target = !state.micEnabled;

    // الزر يستجيب فوراً بلا انتظار الشبكة
    emit(state.copyWith(micEnabled: target, clearError: true));

    final res = await _toggleMic(me: state.me, enable: target);
    res.fold(
      (f) => emit(state.copyWith(micEnabled: !target, error: f.message)),
      (_) {},
    );
  }

  Future<void> _onSpeakerphone(
      SpeakerphoneToggled e, Emitter<VoiceRoomState> emit) async {
    final next = !state.speakerphone;
    await _repo.setSpeakerphone(next);
    emit(state.copyWith(speakerphone: next));
  }

  Future<void> _onHand(HandRaised e, Emitter<VoiceRoomState> emit) async {
    emit(state.copyWith(handRaised: e.up, clearError: true));
    final res = await _repo.raiseHand(e.up);
    res.fold(
      (f) => emit(state.copyWith(handRaised: !e.up, error: f.message)),
      (_) {},
    );
  }

  // ── إجراءات المضيف ────────────────────────────────────────────
  Future<void> _onPromote(
      SpeakerPromoted e, Emitter<VoiceRoomState> emit) async {
    final res = await _promote(actor: state.me, targetUid: e.uid);
    res.fold((f) => emit(state.copyWith(error: f.message)), (_) {});
  }

  Future<void> _onMute(
      ParticipantMuted e, Emitter<VoiceRoomState> emit) async {
    final res = await _moderate.mute(state.me, e.uid);
    res.fold((f) => emit(state.copyWith(error: f.message)), (_) {});
  }

  Future<void> _onKick(
      ParticipantKicked e, Emitter<VoiceRoomState> emit) async {
    final res = await _moderate.kick(state.me, e.uid);
    res.fold((f) => emit(state.copyWith(error: f.message)), (_) {});
  }

  Future<void> _onLeave(
      RoomLeaveRequested e, Emitter<VoiceRoomState> emit) async {
    await _leave();
    emit(VoiceRoomState(myUid: state.myUid));
  }

  // ══════════════════════════════════════════════════════════════
  //  🔋 قاعدة بطارية: اكتم المايك عند الخروج للخلفية.
  //  لا نقطع الاتصال — المستخدم يريد مواصلة الاستماع — لكن إبقاء
  //  المايك مفتوحاً يشغّل مُرمِّزاً و AEC في الخلفية بلا فائدة،
  //  ويبثّ صوت محيطه دون أن يدري.
  // ══════════════════════════════════════════════════════════════
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused && state.micEnabled) {
      add(const MicToggled());
    }
  }

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    await _roomSub?.cancel();
    await _connSub?.cancel();
    await _repo.dispose();
    return super.close();
  }
}
