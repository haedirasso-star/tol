part of '../main.dart';

// ════════════════════════════════════════════════════════════════
//  VoiceRooms — الغرف الصوتية (LiveKit SFU)
//  ────────────────────────────────────────────────────────────
//  مدمجة في معمارية TOTV+ نفسها (part of main.dart)
//
//  ⚡ استهلاك البيانات: ~28 kbps للمشارك = 12 ميغابايت/ساعة
//     • Opus أحادي @ 24 kbps
//     • DTX مفعّل → يتوقف الإرسال أثناء الصمت (~2 kbps)
//     • المستمع لا يُنشئ مسار صوت إطلاقاً
//
//  💰 استهلاك Firestore: صفر مستمعين داخل الغرفة.
//     قائمة المشاركين تأتي من LiveKit عبر WebSocket القائم أصلاً.
//     العدّاد يكتبه Webhook من الخادم، لا العميل.
// ════════════════════════════════════════════════════════════════

enum VRole { listener, speaker, host }

extension VRoleX on VRole {
  bool get canPublish => this != VRole.listener;
  String get label => switch (this) {
        VRole.host => 'المضيف',
        VRole.speaker => 'متحدث',
        VRole.listener => 'مستمع',
      };

  static VRole parse(String? s) => switch (s) {
        'host' => VRole.host,
        'speaker' => VRole.speaker,
        _ => VRole.listener,
      };
}

// ────────────────────────────────────────────────────────────────
//  نموذج المشارك
// ────────────────────────────────────────────────────────────────
class VParticipant {
  final String uid;
  final String name;
  final String avatar;
  final VRole role;
  final bool micOn;
  final bool mutedByHost;
  final bool isLocal;

  const VParticipant({
    required this.uid,
    required this.name,
    this.avatar = '',
    this.role = VRole.listener,
    this.micOn = false,
    this.mutedByHost = false,
    this.isLocal = false,
  });

  bool get canSpeak => role.canPublish && !mutedByHost;
  bool get isHost => role == VRole.host;
}

// ────────────────────────────────────────────────────────────────
//  ملخّص الغرفة في القائمة
// ────────────────────────────────────────────────────────────────
class VRoomInfo {
  final String id;
  final String title;
  final String hostUid;
  final String hostName;
  final int count;
  final bool live;
  final bool locked;

  const VRoomInfo({
    required this.id,
    required this.title,
    this.hostUid = '',
    this.hostName = '',
    this.count = 0,
    this.live = false,
    this.locked = false,
  });

  factory VRoomInfo.fromMap(String id, Map<String, dynamic> m) => VRoomInfo(
        id: id,
        title: m['title']?.toString() ?? '',
        hostUid: m['hostUid']?.toString() ?? '',
        hostName: m['hostName']?.toString() ?? '',
        count: (m['count'] as num?)?.toInt() ?? 0,
        live: m['live'] == true,
        locked: m['locked'] == true,
      );
}

// ════════════════════════════════════════════════════════════════
//  VoiceService — كل تعامل مع LiveKit
// ════════════════════════════════════════════════════════════════
class VoiceService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// ⚠️ يجب أن تطابق setGlobalOptions في functions/index.js
  static const String fnRegion = 'us-central1';

  static FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: fnRegion);

  // ══════════════════════════════════════════════════════════════
  //  ⚡ إعدادات الباقة والبطارية — أهم أرقام في الملف
  // ══════════════════════════════════════════════════════════════

  /// Opus أحادي. 24000 = جودة كلام ممتازة ≈ 12 ميغابايت/ساعة.
  /// اقتصادي: 16000 · هاتفي: 12000. لا تتجاوز 32000 لصوت الكلام.
  static const int _opusBitrate = 24000;

  /// ★★★ DTX — أهم إعداد في الميزة كلها.
  /// يوقف الإرسال أثناء الصمت. في غرفة نقاش المستخدم صامت 80-90%
  /// من الوقت → توفير ~70% من الباقة و~40% من المعالج.
  static const bool _dtx = true;

  /// RED — إعادة إرسال الحزم داخل التدفق نفسه.
  /// ⚠️ افتراضياً `true` في LiveKit، ويزيد النطاق ~30%.
  /// أوقفناه لأن الأولوية هنا هي توفير باقة المستخدم.
  /// فعّله (true) إن لاحظت تقطّعاً على شبكات ضعيفة جداً.
  static const bool _red = false;

  // ── الحالة ────────────────────────────────────────────────────
  static lk.Room? _room;
  static lk.EventsListener<lk.RoomEvent>? _events;
  static String _roomId = '';
  static String _roomTitle = '';
  static VRole _myRole = VRole.listener;

  static final _partsCtrl = StreamController<List<VParticipant>>.broadcast();
  static final _levelsCtrl = StreamController<Map<String, double>>.broadcast();
  static final _stateCtrl = StreamController<lk.ConnectionState>.broadcast();

  static Stream<List<VParticipant>> get participants => _partsCtrl.stream;
  static Stream<Map<String, double>> get audioLevels => _levelsCtrl.stream;
  static Stream<lk.ConnectionState> get connState => _stateCtrl.stream;

  static String get roomTitle => _roomTitle;
  static VRole get myRole => _myRole;
  static bool get inRoom => _room != null;
  static bool get micOn =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;

  // ══════════════════════════════════════════════════════════════
  //  قائمة الغرف — قراءة واحدة، بلا مستمعين
  // ══════════════════════════════════════════════════════════════
  static Future<List<VRoomInfo>> fetchRooms({int limit = 30}) async {
    try {
      final snap = await _db
          .collection('voice_rooms')
          .where('closed', isEqualTo: false)
          .orderBy('live', descending: true)
          .orderBy('count', descending: true)
          .limit(limit)
          .get()
          .timeout(const Duration(seconds: 12));
      return snap.docs
          .map((d) => VRoomInfo.fromMap(d.id, d.data()))
          .toList();
    } catch (e) {
      debugPrint('[VoiceService.fetchRooms] $e');
      return const [];
    }
  }

  static Future<String?> createRoom(String title) async {
    try {
      final r = await _fn
          .httpsCallable('createVoiceRoom')
          .call<Map<String, dynamic>>({'title': title.trim()});
      return r.data['roomId']?.toString();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'تعذّر إنشاء الغرفة');
    }
  }

  static Future<void> closeRoom(String roomId) async {
    try {
      await _fn.httpsCallable('closeVoiceRoom').call({'roomId': roomId});
    } catch (e) {
      debugPrint('[closeRoom] $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  الانضمام
  // ══════════════════════════════════════════════════════════════
  static Future<void> join(String roomId) async {
    await leave();

    // ① التوكن — الخادم يقرّر الدور، لا العميل.
    //    لو وثقنا بالعميل لتحدّث أي شخص يعدّل الطلب.
    final res = await _fn
        .httpsCallable('mintVoiceToken')
        .call<Map<String, dynamic>>({'roomId': roomId})
        .timeout(const Duration(seconds: 15));

    final token = res.data['token'] as String;
    final url = res.data['url'] as String;
    _myRole = VRoleX.parse(res.data['role']?.toString());
    _roomTitle = res.data['roomTitle']?.toString() ?? '';
    _roomId = roomId;

    // ② إذن المايك فقط لمن سيتحدث فعلاً
    if (_myRole.canPublish) {
      final st = await Permission.microphone.request();
      if (!st.isGranted) {
        throw Exception('إذن المايكروفون مرفوض');
      }
    }

    _room = lk.Room(
      roomOptions: const lk.RoomOptions(
        adaptiveStream: false, // بلا معنى بلا فيديو
        dynacast: true,
        defaultAudioCaptureOptions: lk.AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          highPassFilter: true,
          typingNoiseDetection: true,
          // يطفئ التقاط الصوت فعلياً عند الكتم → يخفي مؤشر المايك
          // في شريط النظام ويوفّر البطارية
          stopAudioCaptureOnMute: true,
        ),
        defaultAudioPublishOptions: lk.AudioPublishOptions(
          dtx: _dtx,
          red: _red,
          audioBitrate: _opusBitrate,
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

    // ══ 🔋 المستمع لا يُنشئ مسار صوت إطلاقاً ══════════════════
    // لا مايك، لا مُرمِّز Opus، لا AEC، لا رفع. المستمعون عادةً
    // 90% من الغرفة، والفرق في بطاريتهم ~3×.
    if (_myRole.canPublish) {
      // ★ ندخل مكتومين دائماً — لا أحد يريد بثّ صوت غرفته فجأة
      await _room!.localParticipant?.setMicrophoneEnabled(false);
    }

    _emit();
  }

  static void _wire(lk.EventsListener<lk.RoomEvent> l) {
    void changed(dynamic _) => _emit();

    l
      ..on<lk.RoomConnectedEvent>((_) {
        _push(lk.ConnectionState.connected);
        _emit();
      })
      ..on<lk.RoomDisconnectedEvent>(
          (_) => _push(lk.ConnectionState.disconnected))
      ..on<lk.RoomReconnectingEvent>(
          (_) => _push(lk.ConnectionState.reconnecting))
      ..on<lk.RoomReconnectedEvent>((_) {
        _push(lk.ConnectionState.connected);
        _emit();
      })
      ..on<lk.ParticipantConnectedEvent>(changed)
      ..on<lk.ParticipantDisconnectedEvent>(changed)
      ..on<lk.TrackPublishedEvent>(changed)
      ..on<lk.TrackUnpublishedEvent>(changed)
      ..on<lk.LocalTrackPublishedEvent>(changed)
      ..on<lk.LocalTrackUnpublishedEvent>(changed)
      ..on<lk.TrackMutedEvent>(changed)
      ..on<lk.TrackUnmutedEvent>(changed)
      ..on<lk.ParticipantPermissionsUpdatedEvent>(changed)
      ..on<lk.ParticipantMetadataUpdatedEvent>(changed)
      // ★ مستويات الصوت على تيار منفصل.
      // تتحدّث ~10 مرات/ثانية — دمجها في تيار المشاركين يعني
      // إعادة بناء الشاشة 10 مرات/ثانية = استنزاف بطارية.
      ..on<lk.ActiveSpeakersChangedEvent>((e) {
        if (_levelsCtrl.isClosed) return;
        _levelsCtrl.add({for (final s in e.speakers) s.identity: s.audioLevel});
      });
  }

  static void _push(lk.ConnectionState s) {
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  static void _emit() {
    if (_partsCtrl.isClosed) return;
    final r = _room;
    if (r == null) {
      _partsCtrl.add(const []);
      return;
    }
    final out = <VParticipant>[];
    final me = r.localParticipant;
    if (me != null) out.add(_map(me, isLocal: true));
    for (final p in r.remoteParticipants.values) {
      out.add(_map(p));
    }
    out.sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      if (a.role != b.role) return a.role.index > b.role.index ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    _partsCtrl.add(out);
  }

  static VParticipant _map(lk.Participant p, {bool isLocal = false}) {
    // ★ الدور من صلاحيات الخادم — غير قابل للتزوير
    final canPub = p.permissions.canPublish;

    Map<String, dynamic> meta = const {};
    final raw = p.metadata;
    if (raw != null && raw.isNotEmpty) {
      try {
        meta = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }

    final pubs = p.audioTrackPublications;
    return VParticipant(
      uid: p.identity,
      name: p.name.isNotEmpty ? p.name : 'مستخدم',
      avatar: meta['avatar']?.toString() ?? '',
      role: !canPub
          ? VRole.listener
          : (meta['host'] == true ? VRole.host : VRole.speaker),
      micOn: pubs.isNotEmpty && !pubs.first.muted,
      mutedByHost: !canPub && meta['muted'] == true,
      isLocal: isLocal,
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  التحكّم
  // ══════════════════════════════════════════════════════════════
  static Future<void> setMic(bool on) async {
    if (on) {
      final st = await Permission.microphone.request();
      if (!st.isGranted) throw Exception('إذن المايكروفون مرفوض');
    }
    await _room?.localParticipant?.setMicrophoneEnabled(on);
    _emit();
  }

  static Future<void> setSpeakerphone(bool on) async {
    try {
      await lk.Hardware.instance.setSpeakerphoneOn(on);
    } catch (e) {
      debugPrint('[setSpeakerphone] $e');
    }
  }

  // ── إجراءات تمر عبر الخادم (سر LiveKit لا يُكشف للعميل) ──────
  static Future<void> raiseHand(bool up) =>
      _act('raiseHand', {'roomId': _roomId, 'up': up});

  static Future<void> promote(String uid) =>
      _act('promoteSpeaker', {'roomId': _roomId, 'targetUid': uid});

  static Future<void> muteUser(String uid) =>
      _act('muteParticipant', {'roomId': _roomId, 'targetUid': uid});

  static Future<void> kick(String uid) =>
      _act('kickFromRoom', {'roomId': _roomId, 'targetUid': uid});

  static Future<void> _act(String name, Map<String, dynamic> args) async {
    try {
      await _fn
          .httpsCallable(name)
          .call(args)
          .timeout(const Duration(seconds: 15));
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'فشل الإجراء');
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  الخروج
  // ══════════════════════════════════════════════════════════════
  static Future<void> leave() async {
    try {
      await _events?.dispose();
      await _room?.disconnect();
      await _room?.dispose();
    } catch (e) {
      debugPrint('[VoiceService.leave] $e');
    }
    _events = null;
    _room = null;
    _roomId = '';
    _roomTitle = '';
    _myRole = VRole.listener;
    if (!_partsCtrl.isClosed) _partsCtrl.add(const []);
  }
}
