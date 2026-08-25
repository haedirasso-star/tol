/**
 * ════════════════════════════════════════════════════════════════
 *  TOTV+ Voice Rooms — نقطة الدخول للـ Cloud Functions
 *
 *  النشر:
 *    cd functions && npm install
 *    firebase functions:secrets:set LIVEKIT_API_KEY
 *    firebase functions:secrets:set LIVEKIT_API_SECRET
 *    firebase deploy --only functions
 * ════════════════════════════════════════════════════════════════
 */
const {initializeApp, getApps} = require("firebase-admin/app");
const {setGlobalOptions} = require("firebase-functions/v2");

if (getApps().length === 0) initializeApp();

// اختر أقرب منطقة لمستخدميك — يقلّل تأخير إصدار التوكن
setGlobalOptions({region: "europe-west1", maxInstances: 10});

// ── إصدار التوكن ────────────────────────────────────────────────
exports.mintVoiceToken = require("./src/tokens").mintVoiceToken;

// ── دورة حياة الغرفة ───────────────────────────────────────────
const rooms = require("./src/rooms");
exports.createVoiceRoom = rooms.createVoiceRoom;
exports.closeVoiceRoom = rooms.closeVoiceRoom;

// ── إجراءات المضيف ─────────────────────────────────────────────
const mod = require("./src/moderation");
exports.promoteSpeaker = mod.promoteSpeaker;
exports.muteParticipant = mod.muteParticipant;
exports.kickFromRoom = mod.kickFromRoom;
exports.raiseHand = mod.raiseHand;

// ── Webhook ────────────────────────────────────────────────────
exports.livekitWebhook = require("./src/webhook").livekitWebhook;
