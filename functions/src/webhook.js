/**
 * livekitWebhook — عدّاد المشاركين بلا أي مستمع Firestore من العميل
 * ═══════════════════════════════════════════════════════════════
 * LiveKit يرسل حدثاً عند كل دخول/خروج → نكتب رقماً واحداً.
 * قائمة الغرف تقرأ هذا الرقم بقراءة واحدة عند فتح الصفحة.
 *
 * سجّل الرابط في: LiveKit Cloud → Settings → Webhooks
 *   https://<region>-<project-id>.cloudfunctions.net/livekitWebhook
 */
const {onRequest} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {WebhookReceiver} = require("livekit-server-sdk");
const {LK_KEY, LK_SECRET, SECRETS} = require("./config");

const db = getFirestore();

exports.livekitWebhook = onRequest({secrets: SECRETS, cors: false}, async (req, res) => {
  try {
    const receiver = new WebhookReceiver(LK_KEY.value(), LK_SECRET.value());
    // ★ التحقّق من التوقيع — بدونه يستطيع أي أحد تزوير الأحداث
    const event = await receiver.receive(
        req.rawBody.toString(), req.get("Authorization"));

    const roomName = event.room?.name;
    if (!roomName) return res.status(200).send("ignored");
    const ref = db.collection("voice_rooms").doc(roomName);

    switch (event.event) {
      case "room_started":
        await ref.set({live: true, count: 0}, {merge: true});
        break;

      case "participant_joined":
      case "participant_left":
        await ref.set({
          live: true,
          count: event.room.numParticipants || 0,
          updated_at: FieldValue.serverTimestamp(),
        }, {merge: true});
        break;

      case "room_finished":
        await ref.set({
          live: false, count: 0,
          ended_at: FieldValue.serverTimestamp(),
        }, {merge: true});
        break;
    }
    return res.status(200).send("ok");
  } catch (e) {
    console.error("webhook error:", e.message);
    return res.status(401).send("unauthorized");
  }
});
