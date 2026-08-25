import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'data/datasources/livekit_datasource.dart';
import 'data/datasources/room_catalog_datasource.dart';
import 'data/datasources/room_token_datasource.dart';
import 'data/repositories/voice_room_repository_impl.dart';
import 'domain/repositories/voice_room_repository.dart';
import 'domain/usecases/voice_room_usecases.dart';
import 'presentation/bloc/audio_level_cubit.dart';
import 'presentation/bloc/voice_room_bloc.dart';

/// ═══════════════════════════════════════════════════════════════
///  حقن التبعيات — بلا get_it، مصنع بسيط يكفي لميزة واحدة.
///
///  ⚠️ أنشئ Repository جديداً لكل غرفة (كل غرفة = اتصال LiveKit
///     مستقل)، وتخلّص منه في close() للـ BLoC.
/// ═══════════════════════════════════════════════════════════════
class VoiceRoomFactory {
  /// ⚠️ يجب أن تطابق المنطقة setGlobalOptions في functions/index.js
  static const String functionsRegion = 'europe-west1';

  static FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: functionsRegion);

  static VoiceRoomRepository createRepository() {
    final db = FirebaseFirestore.instance;
    return VoiceRoomRepositoryImpl(
      rtc: LiveKitDataSource(),
      tokens: RoomTokenDataSource(_fn),
      catalog: RoomCatalogDataSource(db, _fn),
      functions: _fn,
    );
  }

  static VoiceRoomBloc createBloc(VoiceRoomRepository repo) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return VoiceRoomBloc(
      join: JoinVoiceRoom(repo),
      leave: LeaveVoiceRoom(repo),
      toggleMic: ToggleMicrophone(repo),
      promote: PromoteToSpeaker(repo),
      moderate: ModerateParticipant(repo),
      repo: repo,
      myUid: uid,
    );
  }

  static AudioLevelCubit createLevels(VoiceRoomRepository repo) =>
      AudioLevelCubit(repo);
}
