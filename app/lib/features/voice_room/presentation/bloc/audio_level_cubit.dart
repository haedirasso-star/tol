import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/voice_room_repository.dart';

/// ═══════════════════════════════════════════════════════════════
///  ⚡ منفصل عن VoiceRoomBloc عمداً.
///
///  مستويات الصوت تتحدّث ~10 مرات/ثانية. لو وضعناها في الحالة
///  الرئيسية لأعدنا بناء الشاشة كاملة 10 مرات/ثانية = استنزاف
///  بطارية شديد وتقطيع في الواجهة.
///
///  هنا مع buildWhen المناسب يُعاد بناء الأفاتار المعني فقط.
/// ═══════════════════════════════════════════════════════════════
class AudioLevelCubit extends Cubit<Map<String, double>> {
  StreamSubscription? _sub;

  AudioLevelCubit(VoiceRoomRepository repo) : super(const {}) {
    _sub = repo.audioLevels.listen((levels) {
      if (!isClosed) emit(levels);
    });
  }

  double levelOf(String uid) => state[uid] ?? 0.0;
  bool isSpeaking(String uid) => levelOf(uid) > 0.05;

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
