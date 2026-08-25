import 'package:cloud_functions/cloud_functions.dart';

class VoiceToken {
  final String token;
  final String url;
  final String role;      // host | speaker | listener
  final String roomTitle;
  const VoiceToken(this.token, this.url, this.role, this.roomTitle);
}

/// ═══════════════════════════════════════════════════════════════
///  ⚠️ سر LiveKit لا يوجد في التطبيق إطلاقاً.
///     التطبيق يستلم توكناً موقّعاً جاهزاً — ولا يعرف كيف يوقّع.
///     قراءات/كتابات Firestore هنا: صفر.
/// ═══════════════════════════════════════════════════════════════
class RoomTokenDataSource {
  final FirebaseFunctions _fn;
  const RoomTokenDataSource(this._fn);

  Future<VoiceToken> fetch(String roomId) async {
    final res = await _fn
        .httpsCallable('mintVoiceToken')
        .call<Map<String, dynamic>>({'roomId': roomId})
        .timeout(const Duration(seconds: 15));
    final d = res.data;
    return VoiceToken(
      d['token'] as String,
      d['url'] as String,
      d['role']?.toString() ?? 'listener',
      d['roomTitle']?.toString() ?? '',
    );
  }
}
