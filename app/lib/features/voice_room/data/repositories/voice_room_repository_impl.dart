import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../../core/failures.dart';
import '../../domain/entities/room_participant.dart';
import '../../domain/entities/room_role.dart';
import '../../domain/entities/voice_room.dart';
import '../../domain/repositories/voice_room_repository.dart';
import '../datasources/livekit_datasource.dart';
import '../datasources/room_catalog_datasource.dart';
import '../datasources/room_token_datasource.dart';

class VoiceRoomRepositoryImpl implements VoiceRoomRepository {
  final LiveKitDataSource _rtc;
  final RoomTokenDataSource _tokens;
  final RoomCatalogDataSource _catalog;
  final FirebaseFunctions _fn;

  VoiceRoomRepositoryImpl({
    required LiveKitDataSource rtc,
    required RoomTokenDataSource tokens,
    required RoomCatalogDataSource catalog,
    required FirebaseFunctions functions,
  })  : _rtc = rtc,
        _tokens = tokens,
        _catalog = catalog,
        _fn = functions {
    _changedSub = _rtc.roomChanged.listen((_) => _emit());
  }

  StreamSubscription? _changedSub;
  String _roomId = '';
  String _title = '';
  RoomRole _myRole = RoomRole.listener;

  final _roomCtrl = StreamController<VoiceRoom>.broadcast();

  @override
  Stream<RoomConnectionState> get connectionState =>
      _rtc.connectionState.map(_mapState);

  @override
  Stream<VoiceRoom> get roomStream => _roomCtrl.stream;

  @override
  Stream<Map<String, double>> get audioLevels => _rtc.audioLevels;

  // ══════════════════════════════════════════════════════════════
  //  الانضمام
  // ══════════════════════════════════════════════════════════════
  @override
  Future<Result<VoiceRoom>> join(String roomId) async {
    try {
      // ① التوكن أولاً — الخادم يقرّر الدور، لا نحن
      final t = await _tokens.fetch(roomId);
      _myRole = RoomRole.fromString(t.role);
      _title = t.roomTitle;

      // ② اطلب إذن المايك فقط لمن سيتحدث فعلاً
      if (_myRole.canPublish && !await _rtc.ensureMicPermission()) {
        return const Err(PermissionFailure());
      }

      await _rtc.connect(
        url: t.url,
        token: t.token,
        canPublish: _myRole.canPublish,
      );

      _roomId = roomId;
      final room = _build();
      if (!_roomCtrl.isClosed) _roomCtrl.add(room);
      return Ok(room);
    } on FirebaseFunctionsException catch (e) {
      return Err(_mapFnError(e));
    } on TimeoutException {
      return const Err(ConnectionFailure('انتهت مهلة الاتصال — تحقق من الشبكة'));
    } catch (e) {
      debugPrint('[join] $e');
      return const Err(ConnectionFailure());
    }
  }

  @override
  Future<Result<void>> leave() async {
    await _rtc.disconnect();
    _roomId = '';
    _myRole = RoomRole.listener;
    return const Ok(null);
  }

  // ══════════════════════════════════════════════════════════════
  //  المايك ومخرج الصوت
  // ══════════════════════════════════════════════════════════════
  @override
  Future<Result<void>> setMicEnabled(bool enabled) async {
    if (enabled && !await _rtc.ensureMicPermission()) {
      return const Err(PermissionFailure());
    }
    try {
      await _rtc.setMic(enabled);
      _emit();
      return const Ok(null);
    } catch (e) {
      return Err(ConnectionFailure('تعذّر تغيير حالة المايك: $e'));
    }
  }

  @override
  Future<Result<void>> setSpeakerphone(bool on) async {
    await _rtc.setSpeakerphone(on);
    return const Ok(null);
  }

  // ══════════════════════════════════════════════════════════════
  //  إجراءات تمر عبر الخادم — سر LiveKit لا يُكشف للعميل
  // ══════════════════════════════════════════════════════════════
  @override
  Future<Result<void>> raiseHand(bool up) =>
      _call('raiseHand', {'roomId': _roomId, 'up': up});

  @override
  Future<Result<void>> promote(String uid) => _call('promoteSpeaker', {
        'roomId': _roomId,
        'targetUid': uid,
      });

  @override
  Future<Result<void>> muteParticipant(String uid) => _call('muteParticipant', {
        'roomId': _roomId,
        'targetUid': uid,
      });

  @override
  Future<Result<void>> kick(String uid) => _call('kickFromRoom', {
        'roomId': _roomId,
        'targetUid': uid,
      });

  Future<Result<void>> _call(String name, Map<String, dynamic> args) async {
    try {
      await _fn.httpsCallable(name).call(args).timeout(
            const Duration(seconds: 15),
          );
      return const Ok(null);
    } on FirebaseFunctionsException catch (e) {
      return Err(_mapFnError(e));
    } catch (e) {
      return Err(RoomFailure('فشل الإجراء: $e'));
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  قائمة الغرف
  // ══════════════════════════════════════════════════════════════
  @override
  Future<Result<List<VoiceRoomSummary>>> fetchRooms() async {
    try {
      return Ok(await _catalog.fetchRooms());
    } catch (e) {
      debugPrint('[fetchRooms] $e');
      return const Err(RoomFailure('تعذّر تحميل الغرف'));
    }
  }

  @override
  Future<Result<String>> createRoom(String title) async {
    try {
      return Ok(await _catalog.create(title));
    } on FirebaseFunctionsException catch (e) {
      return Err(_mapFnError(e));
    } catch (e) {
      return const Err(RoomFailure('تعذّر إنشاء الغرفة'));
    }
  }

  @override
  Future<Result<void>> closeRoom(String roomId) async {
    try {
      await _catalog.close(roomId);
      return const Ok(null);
    } on FirebaseFunctionsException catch (e) {
      return Err(_mapFnError(e));
    }
  }

  @override
  Future<void> dispose() async {
    await _changedSub?.cancel();
    await _rtc.dispose();
    await _roomCtrl.close();
  }

  // ══════════════════════════════════════════════════════════════
  //  الترجمة: LiveKit → Domain
  // ══════════════════════════════════════════════════════════════
  void _emit() {
    if (_roomCtrl.isClosed) return;
    _roomCtrl.add(_build());
  }

  VoiceRoom _build() {
    final r = _rtc.room;
    if (r == null) return VoiceRoom(id: _roomId, title: _title);

    final all = <RoomParticipant>[];
    final local = r.localParticipant;
    if (local != null) all.add(_map(local, isLocal: true));
    for (final p in r.remoteParticipants.values) {
      all.add(_map(p));
    }

    // المستمعون لا يُعرضون فردياً — قد يكونون بالآلاف
    final speakers = all.where((p) => p.role != RoomRole.listener).toList()
      ..sort((a, b) {
        if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return VoiceRoom(
      id: _roomId,
      title: _title,
      hostUid: _firstHostUid(speakers),
      speakers: speakers,
      listenerCount: all.length - speakers.length,
    );
  }

  static String _firstHostUid(List<RoomParticipant> list) {
    for (final p in list) {
      if (p.isHost) return p.uid;
    }
    return '';
  }

  RoomParticipant _map(lk.Participant p, {bool isLocal = false}) {
    // ★ الدور من صلاحيات الخادم — لا يمكن تزويره من العميل
    final canPublish = p.permissions.canPublish;

    Map<String, dynamic> meta = const {};
    final raw = p.metadata;
    if (raw != null && raw.isNotEmpty) {
      try {
        meta = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }
    final isHost = meta['host'] == true;

    final pubs = p.audioTrackPublications;
    final micOn = pubs.isNotEmpty && !pubs.first.muted;

    return RoomParticipant(
      uid: p.identity,
      name: p.name.isNotEmpty ? p.name : p.identity,
      avatarUrl: meta['avatar']?.toString() ?? '',
      role: !canPublish
          ? RoomRole.listener
          : (isHost ? RoomRole.host : RoomRole.speaker),
      isMicEnabled: micOn,
      isMutedByHost: !canPublish && meta['muted'] == true,
      quality: _mapQuality(p.connectionQuality),
      isLocal: isLocal,
    );
  }

  RoomConnectionState _mapState(lk.ConnectionState s) => switch (s) {
        lk.ConnectionState.connected => RoomConnectionState.connected,
        lk.ConnectionState.connecting => RoomConnectionState.connecting,
        lk.ConnectionState.reconnecting => RoomConnectionState.reconnecting,
        _ => RoomConnectionState.disconnected,
      };

  ConnectionQuality _mapQuality(lk.ConnectionQuality q) => switch (q) {
        lk.ConnectionQuality.excellent => ConnectionQuality.excellent,
        lk.ConnectionQuality.good => ConnectionQuality.good,
        lk.ConnectionQuality.poor => ConnectionQuality.poor,
        lk.ConnectionQuality.lost => ConnectionQuality.lost,
        _ => ConnectionQuality.unknown,
      };

  Failure _mapFnError(FirebaseFunctionsException e) {
    final msg = e.message ?? 'خطأ من الخادم';
    return switch (e.code) {
      'permission-denied' => NotAllowedFailure(msg),
      'unauthenticated' => const TokenFailure('سجّل الدخول أولاً'),
      'not-found' => const RoomFailure('الغرفة غير موجودة'),
      'resource-exhausted' => RoomFailure(msg),
      'failed-precondition' => RoomFailure(msg),
      _ => TokenFailure(msg),
    };
  }
}
