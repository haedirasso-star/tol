/**
 * TOTV+ Voice Rooms — إعدادات مركزية
 * ─────────────────────────────────────────────────────────────
 * ⚠️ المفتاح والسر يأتيان من Firebase Secret Manager — ليسا في الكود:
 *      firebase functions:secrets:set LIVEKIT_API_KEY
 *      firebase functions:secrets:set LIVEKIT_API_SECRET
 */
const {defineSecret} = require("firebase-functions/params");

const LK_KEY = defineSecret("LIVEKIT_API_KEY");
const LK_SECRET = defineSecret("LIVEKIT_API_SECRET");

// مشروعك على LiveKit Cloud
const LK_WS_URL = "wss://tovplus-dwo14rw5.livekit.cloud";
const LK_HTTP_URL = "https://tovplus-dwo14rw5.livekit.cloud";

// السرّان اللذان تحتاجهما كل دالة تتعامل مع LiveKit
const SECRETS = [LK_KEY, LK_SECRET];

// عمر التوكن — قصير عمداً: إعادة الاتصال تطلب توكناً جديداً،
// فالحظر والطرد يُطبَّقان فوراً بلا انتظار انتهاء جلسة طويلة.
const TOKEN_TTL = "2h";

const LIMITS = {
  maxSpeakers: 12,       // فوق هذا تصبح الغرفة فوضى صوتية
  maxRoomsPerHost: 3,
  roomTitleMax: 60,
};

module.exports = {
  LK_KEY, LK_SECRET, LK_WS_URL, LK_HTTP_URL, SECRETS, TOKEN_TTL, LIMITS,
};
