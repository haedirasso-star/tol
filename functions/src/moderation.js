/**
 * إجراءات المضيف — ترقية / كتم / خفض / طرد
 * ═══════════════════════════════════════════════════════════════
 * كلها تستخدم RoomServiceClient.updateParticipant، وهي تغيّر
 * صلاحيات المشارك **فوراً على الاتصال القائم** — بلا إعادة اتصال
 * وبلا انقطاع صوت. هذه ميزة SFU الأساسية التي يستحيل تحقيقها بـ P2P.
 */
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {RoomServiceClient} = require("livekit-server-sdk");
const {LK_KEY, LK_SECRET, LK_HTTP_URL, SECRETS, LIMITS} = require("./config");

const db = getFirestore();
const svc = () => new RoomServiceClient(LK_HTTP_URL, LK_KEY.value(), LK_SECRET.value());

/** يتحقّق أن المُنادي هو مضيف الغرفة، ويعيد المعرّفات المنظّفة */
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

// ── ترقية مستمع إلى متحدث ──────────────────────────────────────
exports.promoteSpeaker = onCall({secrets: SECRETS}, async (req) => {
  const {roomId, targetUid, room} = await assertHost(req);

  if ((room.speakers || []).length >= LIMITS.maxSpeakers) {
    throw new HttpsError("resource-exhausted",
        `الحد الأقصى ${LIMITS.maxSpeakers} متحدثاً`);
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

// ── كتم متحدث من الخادم (لا يستطيع فتحه بنفسه) ────────────────
exports.muteParticipant = onCall({secrets: SECRETS}, async (req) => {
  const {roomId, targetUid} = await assertHost(req);
  const client = svc();

  // ① أوقف المسار المنشور فعلياً
  try {
    const p = await client.getParticipant(roomId, targetUid);
    for (const track of p.tracks || []) {
      if (track.type === "AUDIO" || track.type === 1) {
        await client.mutePublishedTrack(roomId, targetUid, track.sid, true);
      }
    }
  } catch (e) {
    console.warn("mute track skipped:", e.message);
  }

  // ② اسحب صلاحية النشر — لا يستطيع إعادة فتحه
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

// ── طرد وحظر من الغرفة ─────────────────────────────────────────
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

// ── رفع اليد (من المستمع نفسه — كتابة واحدة) ──────────────────
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
