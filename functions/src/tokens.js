/**
 * mintVoiceToken — إصدار توكن الدخول للغرفة
 * ═══════════════════════════════════════════════════════════════
 * 🛡 القاعدة الذهبية: الدور والصلاحيات تُحدَّد **هنا** من Firestore.
 *    لا نثق بأي شيء يرسله العميل عن دوره. لو اعتمدنا على العميل،
 *    أي شخص يعدّل الطلب يتحدث في غرفتك.
 */
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore} = require("firebase-admin/firestore");
const {AccessToken} = require("livekit-server-sdk");
const {LK_KEY, LK_SECRET, LK_WS_URL, SECRETS, TOKEN_TTL} = require("./config");

const db = getFirestore();

exports.mintVoiceToken = onCall({secrets: SECRETS}, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "سجّل الدخول أولاً");

  const uid = req.auth.uid;
  const roomId = String(req.data?.roomId || "").trim();
  if (!roomId || roomId.length > 64) {
    throw new HttpsError("invalid-argument", "roomId غير صالح");
  }

  const [roomSnap, userSnap] = await Promise.all([
    db.collection("voice_rooms").doc(roomId).get(),
    db.collection("users").doc(uid).get(),
  ]);

  if (!roomSnap.exists) throw new HttpsError("not-found", "الغرفة غير موجودة");
  const room = roomSnap.data();
  const user = userSnap.data() || {};

  // ── بوابات الرفض ────────────────────────────────────────────
  if (user.status === "banned") {
    throw new HttpsError("permission-denied", "حسابك موقوف");
  }
  if (Array.isArray(room.banned) && room.banned.includes(uid)) {
    throw new HttpsError("permission-denied", "أنت محظور من هذه الغرفة");
  }
  if (room.closed === true) {
    throw new HttpsError("failed-precondition", "الغرفة مغلقة");
  }
  if (room.locked === true && room.hostUid !== uid) {
    throw new HttpsError("permission-denied", "الغرفة مقفلة حالياً");
  }

  // ── ★ الدور من الخادم حصراً ─────────────────────────────────
  const isHost = room.hostUid === uid;
  const isSpeaker = isHost || (Array.isArray(room.speakers) && room.speakers.includes(uid));
  const canPublish = isSpeaker;

  const at = new AccessToken(LK_KEY.value(), LK_SECRET.value(), {
    identity: uid,
    name: user.display_name || user.email || "مستخدم",
    ttl: TOKEN_TTL,
    metadata: JSON.stringify({
      host: isHost,
      muted: false,
      avatar: user.photo || "",
    }),
  });

  at.addGrant({
    room: roomId,
    roomJoin: true,
    canPublish,                    // 🎙 المستمع لا يستطيع النشر تقنياً
    canSubscribe: true,
    canPublishData: true,          // لرفع اليد والتفاعلات
    // 🔇 صوت فقط — يمنع نشر الفيديو حتى من عميل معدّل
    canPublishSources: canPublish ? ["microphone"] : [],
    roomAdmin: isHost,
  });

  return {
    token: await at.toJwt(),
    url: LK_WS_URL,
    role: isHost ? "host" : (isSpeaker ? "speaker" : "listener"),
    roomTitle: room.title || "",
  };
});
