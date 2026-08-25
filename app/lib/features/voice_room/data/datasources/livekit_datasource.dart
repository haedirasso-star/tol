import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:permission_handler/permission_handler.dart';

/// ═══════════════════════════════════════════════════════════════
///  الملف **الوحيد** في المشروع الذي يستورد livekit_client.
///  لاستبدال المزوّد لاحقاً، اكتب نظيراً لهذا الملف فقط.
/// ═══════════════════════════════════════════════════════════════
class LiveKitDataSource {
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _events;

  lk.Room? get room => _room;

  final _stateCtrl = StreamController<lk.ConnectionState>.broadcast();
  final _changedCtrl = StreamController<void>.broadcast();
  final _levelsCtrl = StreamController<Map<String, double>>.broadcast();

  Stream<lk.ConnectionState> get connectionState => _stateCtrl.stream;
  Stream<void> get roomChanged => _changedCtrl.stream;
  Stream<Map<String, double>> get audioLevels => _levelsCtrl.stream;

  // ══════════════════════════════════════════════════════════════
  //  ⚡ الإعدادات الحاسمة للباقة والبطارية
  // ══════════════════════════════════════════════════════════════

  /// Opus أحادي. 24000 = جودة كلام ممتازة ≈ 12 ميغابايت/ساعة.
  /// الاقتصادي: 16000 · الهاتفي: 12000 · لا تتجاوز 32000 لصوت الكلام.
  static const int kOpusBitrate = 24000;

  /// ★★★ DTX — أهم إعداد في المشروع كله.
  /// يوقف الإرسال أثناء الصمت (~2 kbps بدل 24). في غرفة نقاش
  /// المستخدم صامت 80-90% من الوقت → توفير ~70% من الباقة
  /// و~40% من المعالج. بلا هذا، كل جهاز يبثّ ضجيج الخلفية بلا توقف.
  static const bool kDtx = true;

  // ══════════════════════════════════════════════════════════════
  //  الاتصال
  // ══════════════════════════════════════════════════════════════
  Future<void> connect({
    required String url,
    required String token,
    required bool canPublish,
  }) async {
    await disconnect();

    _room = lk.Room(
      roomOptions: const lk.RoomOptions(
        // 🔇 صوت فقط — لا كاميرا ولا معالجة صور إطلاقاً
        adaptiveStream: false, // بلا معنى بلا فيديو
        dynacast: true, // الخادم يوقف المسارات غير المشترَك بها

        defaultAudioCaptureOptions: lk.AudioCaptureOptions(
          echoCancellation: true, // تعمل على DSP الجهاز — رخيصة
          noiseSuppression: true,
          autoGainControl: true,
          highPassFilter: true, // يقصّ الهسهسة منخفضة التردد
          typingNoiseDetection: true,
          // يوقف التقاط الصوت فعلياً عند الكتم — يطفئ مؤشر
          // المايك في شريط النظام ويوفّر البطارية
          stopAudioCaptureOnMute: true,
        ),

        defaultAudioPublishOptions: lk.AudioPublishOptions(
          dtx: kDtx,
          audioBitrate: kOpusBitrate,
          stopMicTrackOnMute: true,
          name: 'voice',
        ),
      ),
    );

    _events = _room!.createListener();
    _wire(_events!);

    await _room!.connect(
      url,
      token,
      connectOptions: const lk.ConnectOptions(autoSubscribe: true),
    );

    // ══ 🔋 القاعدة الذهبية للبطارية ══════════════════════════════
    // المستمع **لا يُنشئ مسار صوت إطلاقاً**: لا مايك، لا مُرمِّز
    // Opus، لا AEC، لا رفع. المستمعون عادةً 90% من الغرفة، والفرق
    // في بطاريتهم ~3×. الخادم أصلاً لا يمنحهم canPublish.
    if (canPublish) {
      // ندخل مكتومين دائماً — قاعدة UX غير قابلة للتفاوض
      await _room!.localParticipant?.setMicrophoneEnabled(false);
    }
  }

  void _wire(lk.EventsListener<lk.RoomEvent> l) {
    void changed(dynamic _) {
      if (!_changedCtrl.isClosed) _changedCtrl.add(null);
    }

    l
      ..on<lk.RoomConnectedEvent>(
          (_) => _emitState(lk.ConnectionState.connected))
      ..on<lk.RoomDisconnectedEvent>(
          (_) => _emitState(lk.ConnectionState.disconnected))
      ..on<lk.RoomReconnectingEvent>(
          (_) => _emitState(lk.ConnectionState.reconnecting))
      ..on<lk.RoomReconnectedEvent>(
          (_) => _emitState(lk.ConnectionState.connected))
      ..on<lk.ParticipantConnectedEvent>(changed)
      ..on<lk.ParticipantDisconnectedEvent>(changed)
      ..on<lk.TrackPublishedEvent>(changed)
      ..on<lk.TrackUnpublishedEvent>(changed)
      ..on<lk.LocalTrackPublishedEvent>(changed)
      ..on<lk.LocalTrackUnpublishedEvent>(changed)
      ..on<lk.TrackMutedEvent>(changed)
      ..on<lk.TrackUnmutedEvent>(changed)
      ..on<lk.ParticipantMetadataUpdatedEvent>(changed)
      ..on<lk.ParticipantPermissionsUpdatedEvent>(changed)
      // ★ مستويات الصوت على تيار منفصل — لا تُعيد بناء قائمة المشاركين
      ..on<lk.ActiveSpeakersChangedEvent>((e) {
        if (_levelsCtrl.isClosed) return;
        _levelsCtrl.add({
          for (final s in e.speakers) s.identity: s.audioLevel,
        });
      });
  }

  void _emitState(lk.ConnectionState s) {
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  // ══════════════════════════════════════════════════════════════
  //  التحكّم
  // ══════════════════════════════════════════════════════════════
  Future<bool> ensureMicPermission() async {
    final st = await Permission.microphone.request();
    return st.isGranted;
  }

  Future<void> setMic(bool on) async {
    await _room?.localParticipant?.setMicrophoneEnabled(on);
  }

  Future<void> setSpeakerphone(bool on) async {
    try {
      await lk.Hardware.instance.setSpeakerphoneOn(on);
    } catch (e) {
      debugPrint('[LiveKit] setSpeakerphoneOn: $e');
    }
  }

  /// إرسال بيانات خفيفة (تفاعلات) عبر قناة البيانات — مجاناً، بلا Firestore
  Future<void> sendData(List<int> bytes) async {
    try {
      await _room?.localParticipant
          ?.publishData(bytes, reliable: false);
    } catch (e) {
      debugPrint('[LiveKit] publishData: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _events?.dispose();
      await _room?.disconnect();
      await _room?.dispose();
    } catch (e) {
      debugPrint('[LiveKit] disconnect: $e');
    }
    _events = null;
    _room = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateCtrl.close();
    await _changedCtrl.close();
    await _levelsCtrl.close();
  }
}
