import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/entities/voice_room.dart';

/// ═══════════════════════════════════════════════════════════════
///  قائمة الغرف — قراءة واحدة عند فتح الصفحة، بلا مستمعين.
///  العدّاد يكتبه Webhook من LiveKit، لا العميل.
/// ═══════════════════════════════════════════════════════════════
class RoomCatalogDataSource {
  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;
  const RoomCatalogDataSource(this._db, this._fn);

  /// ⚡ .get() لا .snapshots() — صفر مستمعين دائمين
  Future<List<VoiceRoomSummary>> fetchRooms({int limit = 30}) async {
    final snap = await _db
        .collection('voice_rooms')
        .where('closed', isEqualTo: false)
        .orderBy('live', descending: true)
        .orderBy('count', descending: true)
        .limit(limit)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));

    return snap.docs
        .map((d) => VoiceRoomSummary.fromMap(d.id, d.data()))
        .toList();
  }

  Future<String> create(String title) async {
    final res = await _fn
        .httpsCallable('createVoiceRoom')
        .call<Map<String, dynamic>>({'title': title});
    return res.data['roomId'] as String;
  }

  Future<void> close(String roomId) =>
      _fn.httpsCallable('closeVoiceRoom').call({'roomId': roomId});
}
