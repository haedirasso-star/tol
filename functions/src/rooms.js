/**
 * دورة حياة الغرفة — إنشاء / إغلاق
 * الكتابة في voice_rooms من الخادم فقط (القواعد تمنع العميل).
 */
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {RoomServiceClient} = require("livekit-server-sdk");
const {LK_KEY, LK_SECRET, LK_HTTP_URL, SECRETS, LIMITS} = require("./config");

const db = getFirestore();

exports.createVoiceRoom = onCall({secrets: SECRETS}, async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "سجّل الدخول");
  const uid = req.auth.uid;

  const title = String(req.data?.title || "").trim().slice(0, LIMITS.roomTitleMax);
  if (title.length < 3) {
    throw new HttpsError("invalid-argument", "عنوان الغرفة قصير جداً");
  }

  const user = (await db.collection("users").doc(uid).get()).data() || {};
  if (user.status === "banned") {
    throw new HttpsError("permission-denied", "حسابك موقوف");
  }

  // منع إغراق القائمة بغرف مهجورة
  const mine = await db.collection("voice_rooms")
      .where("hostUid", "==", uid).where("closed", "==", false).get();
  if (mine.size >= LIMITS.maxRoomsPerHost) {
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

  // اطرد الجميع من LiveKit ثم أغلق السجل
  try {
    const client = new RoomServiceClient(LK_HTTP_URL, LK_KEY.value(), LK_SECRET.value());
    await client.deleteRoom(roomId);
  } catch (e) {
    console.warn("deleteRoom skipped:", e.message);
  }

  await snap.ref.update({
    closed: true, live: false, count: 0,
    ended_at: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});
