/**
 * ════════════════════════════════════════════════════════════════════════
 *  TOTV+ — دوال الغرف الصوتية (LiveKit)
 *
 *  الأسرار (لا تُكتب في أي ملف):
 *      firebase functions:secrets:set LIVEKIT_API_KEY
 *      firebase functions:secrets:set LIVEKIT_API_SECRET
 *
 *  التثبيت:  cd functions && npm install
 *  النشر:    firebase deploy --only functions
 *
 *  🛡 المبدأ الحاكم: الدور والصلاحيات تُحدَّد **هنا** من Firestore.
 *     لا نثق بأي شيء يرسله العميل عن دوره — لو فعلنا، لتحدّث في
 *     غرفتك أي شخص يعدّل الطلب.
 * ════════════════════════════════════════════════════════════════════════
 */
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {
  AccessToken,
  RoomServiceClient,
  WebhookReceiver,
} = require("livekit-server-sdk");

const LK_KEY = defineSecret("LIVEKIT_API_KEY");
const LK_SECRET = defineSecret("LIVEKIT_API_SECRET");
const SECRETS = [LK_KEY, LK_SECRET];

// مشروعك على LiveKit Cloud
const LK_WS = "wss://tovplus-dwo14rw5.livekit.cloud";
const LK_HTTP = "https://tovplus-dwo14rw5.livekit.cloud";

const TOKEN_TTL = "2h"; // قصير عمداً: الحظر يُطبَّق عند إعادة الاتصال
const MAX_SPEAKERS = 12;
const MAX_ROOMS_PER_HOST = 3;

const db = getFirestore();
const svc = () => new RoomServiceClient(LK_HTTP, LK_KEY.value(), LK_SECRET.value());

// ════════════════════════════════════════════════════════════════════════
//  ① mintVoiceToken — إصدار توكن الدخول
// ════════════════════════════════════════════════════════════════════════
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

  // ★ الدور من الخادم حصراً
  const isHost = room.hostUid === uid;
  const isSpeaker =
    isHost || (Array.isArray(room.speakers) && room.speakers.includes(uid));
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
    canPublish,              // 🎙 المستمع لا يستطيع النشر تقنياً
    canSubscribe: true,
    canPublishData: true,
    // 🔇 صوت فقط — يمنع نشر الفيديو حتى من عميل معدّل
    canPublishSources: canPublish ? ["microphone"] : [],
    roomAdmin: isHost,
  });

  return {
    token: await at.toJwt(),
    url: LK_WS,
    role: isHost ? "host" : (isSpeaker ? "speaker" : "listener"),
    roomTitle: room.title || "",
  };
});

// ════════════════════════════════════════════════════════════════════════
//  ② إنشاء وإغلاق الغرفة
// ════════════════════════════════════════════════════════════════════════
exports.createVoiceRoom = onCall({secrets: SECRETS}, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "سجّل الدخول");
  const uid = req.auth.uid;

  const title = String(req.data?.title || "").trim().slice(0, 60);
  if (title.length < 3) {
    throw new HttpsError("invalid-argument", "عنوان الغرفة قصير جداً");
  }

  const user = (await db.collection("users").doc(uid).get()).data() || {};
  if (user.status === "banned") {
    throw new HttpsError("permission-denied", "حسابك موقوف");
  }

  const mine = await db.collection("voice_rooms")
      .where("hostUid", "==", uid)
      .where("closed", "==", false).get();
  if (mine.size >= MAX_ROOMS_PER_HOST) {
    throw new HttpsError("resource-exhausted",
        `لديك ${mine.size} غرف مفتوحة — أغلق واحدة أولاً`);
  }

  const ref = db.collection("voice_rooms").doc();
  await ref.set({
    title,
    hostUid: uid,
    hostName: user.display_name || "مضيف",
    speakers: [],
    banned: [],
    raised_hands: [],
    locked: false,
    closed: false,
    live: false,
    count: 0,
    created_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  });
  return {roomId: ref.id};
});

exports.closeVoiceRoom = onCall({secrets: SECRETS}, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "سجّل الدخول");
  const roomId = String(req.data?.roomId || "").trim();
  const snap = await db.collection("voice_rooms").doc(roomId).get();
  if (!snap.exists) throw new HttpsError("not-found", "الغرفة غير موجودة");
  if (snap.data().hostUid !== req.auth.uid) {
    throw new HttpsError("permission-denied", "للمضيف فقط");
  }
  try {
    await svc().deleteRoom(roomId);
  } catch (e) {
    console.warn("deleteRoom skipped:", e.message);
  }
  await snap.ref.update({
    closed: true, live: false, count: 0,
    ended_at: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

// ════════════════════════════════════════════════════════════════════════
//  ③ إجراءات المضيف
//     updateParticipant يغيّر الصلاحيات **فوراً على الاتصال القائم** —
//     بلا إعادة اتصال وبلا انقطاع صوت. هذه ميزة SFU التي يستحيل
//     تحقيقها بـ P2P.
// ════════════════════════════════════════════════════════════════════════
async function assertHost(req) {
  if (!req.auth) throw new HttpsError("unauthenticated", "سجّل الدخول");
  const roomId = String(req.data?.roomId || "").trim();
  const targetUid = String(req.data?.targetUid || "").trim();
  if (!roomId || !targetUid) {
    throw new HttpsError("invalid-argument", "roomId و targetUid مطلوبان");
  }
  const snap = await db.collection("voice_rooms").doc(roomId).get();
  if (!snap.exists) throw new HttpsError("not-found", "الغرفة غير موجودة");
  const room = snap.data();
  if (room.hostUid !== req.auth.uid) {
    throw new HttpsError("permission-denied", "للمضيف فقط");
  }
  if (targetUid === room.hostUid) {
    throw new HttpsError("failed-precondition", "لا يمكن تطبيق الإجراء على المضيف");
  }
  return {roomId, targetUid, room};
}

exports.promoteSpeaker = onCall({secrets: SECRETS}, async (req) => {
  const {roomId, targetUid, room} = await assertHost(req);
  if ((room.speakers || []).length >= MAX_SPEAKERS) {
    throw new HttpsError("resource-exhausted",
        `الحد الأقصى ${MAX_SPEAKERS} متحدثاً`);
  }
  await svc().updateParticipant(roomId, targetUid, {
    permission: {
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      canPublishSources: ["microphone"],
    },
    metadata: JSON.stringify({host: false, muted: false}),
  });
  await db.collection("voice_rooms").doc(roomId).update({
    speakers: FieldValue.arrayUnion(targetUid),
    raised_hands: FieldValue.arrayRemove(targetUid),
    updated_at: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

exports.muteParticipant = onCall({secrets: SECRETS}, async (req) => {
  const {roomId, targetUid} = await assertHost(req);
  const client = svc();
  try {
    const p = await client.getParticipant(roomId, targetUid);
    for (const t of p.tracks || []) {
      if (t.type === "AUDIO" || t.type === 1) {
        await client.mutePublishedTrack(roomId, targetUid, t.sid, true);
      }
    }
  } catch (e) {
    console.warn("mute track skipped:", e.message);
  }
  await client.updateParticipant(roomId, targetUid, {
    permission: {canPublish: false, canSubscribe: true, canPublishData: true},
    metadata: JSON.stringify({host: false, muted: true}),
  });
  await db.collection("voice_rooms").doc(roomId).update({
    speakers: FieldValue.arrayRemove(targetUid),
    updated_at: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

exports.kickFromRoom = onCall({secrets: SECRETS}, async (req) => {
  const {roomId, targetUid} = await assertHost(req);
  try {
    await svc().removeParticipant(roomId, targetUid);
  } catch (e) {
    console.warn("remove skipped:", e.message);
  }
  await db.collection("voice_rooms").doc(roomId).update({
    banned: FieldValue.arrayUnion(targetUid),
    speakers: FieldValue.arrayRemove(targetUid),
    raised_hands: FieldValue.arrayRemove(targetUid),
    updated_at: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

exports.raiseHand = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "سجّل الدخول");
  const roomId = String(req.data?.roomId || "").trim();
  const up = req.data?.up !== false;
  if (!roomId) throw new HttpsError("invalid-argument", "roomId مطلوب");
  await db.collection("voice_rooms").doc(roomId).update({
    raised_hands: up
      ? FieldValue.arrayUnion(req.auth.uid)
      : FieldValue.arrayRemove(req.auth.uid),
  });
  return {ok: true};
});

// ════════════════════════════════════════════════════════════════════════
//  ④ Webhook — عدّاد المشاركين بلا أي مستمع Firestore من العميل
//     سجّله في: LiveKit Cloud → Settings → Webhooks
//     https://us-central1-totvq-8e439.cloudfunctions.net/livekitWebhook
// ════════════════════════════════════════════════════════════════════════
exports.livekitWebhook = onRequest({secrets: SECRETS}, async (req, res) => {
  try {
    const receiver = new WebhookReceiver(LK_KEY.value(), LK_SECRET.value());
    // ★ التحقّق من التوقيع — بدونه يستطيع أي أحد تزوير الأحداث
    const ev = await receiver.receive(
        req.rawBody.toString(), req.get("Authorization"));

    const name = ev.room?.name;
    if (!name) return res.status(200).send("ignored");
    const ref = db.collection("voice_rooms").doc(name);

    if (ev.event === "room_finished") {
      await ref.set({
        live: false, count: 0,
        ended_at: FieldValue.serverTimestamp(),
      }, {merge: true});
    } else if (["room_started", "participant_joined", "participant_left"]
        .includes(ev.event)) {
      await ref.set({
        live: true,
        count: ev.room.numParticipants || 0,
        updated_at: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return res.status(200).send("ok");
  } catch (e) {
    console.error("webhook error:", e.message);
    return res.status(401).send("unauthorized");
  }
});
