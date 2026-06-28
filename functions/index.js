/**
 * TOTV+ — Cloud Functions
 * ────────────────────────────────────────────────────────────────────────
 * يفعّل الإشعارات الفورية لكل الأجهزة + إشعارات تلقائية عند الطلبات/التفعيل.
 *
 * النشر:
 *   1) cd functions && npm install
 *   2) firebase deploy --only functions
 *
 * يتطلب: Firebase Blaze plan (مجاني حتى حدود عالية).
 * ────────────────────────────────────────────────────────────────────────
 */
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();
const fcm = getMessaging();

// ── 1) إشعار جديد في notifications → ادفعه لكل الأجهزة فوراً ──────────────
exports.onNotificationCreated = onDocumentCreated("notifications/{id}", async (event) => {
  const data = event.data?.data();
  if (!data || data.pushed === true) return;
  const title = String(data.title || "TOTV+");
  const body = String(data.body || "");
  try {
    await fcm.send({
      topic: "all_users",
      notification: {title, body},
      android: {priority: "high", notification: {sound: "default", channelId: "totv_high"}},
      apns: {payload: {aps: {sound: "default"}}},
    });
    await event.data.ref.update({pushed: true, pushed_at: new Date()});
  } catch (e) {
    console.error("push failed", e);
  }
});

// ── 2) طلب جديد (orders/pending) → إشعار للأدمن عبر topic admins ──────────
exports.onOrderCreated = onDocumentCreated("orders/{id}", async (event) => {
  const o = event.data?.data();
  if (!o || o.status !== "pending") return;
  try {
    await fcm.send({
      topic: "admins",
      notification: {
        title: "🔔 طلب اشتراك جديد",
        body: `${o.name || o.email || "مستخدم"} — ${o.plan_title || o.plan || ""} (${o.price || ""} د.ع)`,
      },
      android: {priority: "high"},
    });
  } catch (e) {
    console.error("admin notify failed", e);
  }
});

// ── 3) تفعيل اشتراك (users.subscription.plan → premium) → إشعار للمستخدم ──
exports.onSubscriptionActivated = onDocumentUpdated("users/{uid}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  const wasPremium = before.subscription?.plan === "premium";
  const isPremium = after.subscription?.plan === "premium";
  if (wasPremium || !isPremium) return; // فقط عند الانتقال إلى premium
  const token = after.fcm_token;
  if (!token) return;
  try {
    await fcm.send({
      token,
      notification: {
        title: "✅ تم تفعيل اشتراكك في TOTV+",
        body: "اشتراكك فعّال الآن. أطفئ الهاتف وأعد تشغيله ثم افتح التطبيق مجدداً لتحميل القنوات والأفلام. إن لم تظهر، قدّم شكوى من داخل التطبيق.",
      },
      android: {priority: "high", notification: {sound: "default", channelId: "totv_high"}},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (e) {
    console.error("activation notify failed", e);
  }
});

// ── 4) رسالة يومية مجدولة (تقرأ القالب من app_config/daily_message) ───────
exports.dailyMessage = onSchedule("every day 19:00", async () => {
  try {
    const doc = await db.collection("app_config").doc("daily_message").get();
    const d = doc.data() || {};
    if (d.enabled !== true) return;
    // اختر رسالة عشوائية من القائمة أو الرسالة الثابتة
    let title = d.title || "TOTV+";
    let body = d.body || "";
    if (Array.isArray(d.messages) && d.messages.length > 0) {
      const pick = d.messages[Math.floor(Math.random() * d.messages.length)];
      if (typeof pick === "string") {
        body = pick;
      } else if (pick && pick.body) {
        title = pick.title || title;
        body = pick.body;
      }
    }
    if (!body) return;
    await fcm.send({
      topic: "all_users",
      notification: {title, body},
      android: {priority: "high", notification: {sound: "default", channelId: "totv_high"}},
    });
    // سجّل في notifications للأرشيف (بدون إعادة دفع)
    await db.collection("notifications").add({
      title, body, target: "all", active: true, pushed: true,
      source: "daily_schedule", sent_at: new Date(),
    });
  } catch (e) {
    console.error("daily message failed", e);
  }
});

// ── 6) رسالة مباشرة من الأدمن (users.admin_message) → Push للمستخدم ───────
exports.onAdminMessage = onDocumentUpdated("users/{uid}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  const am = after.admin_message;
  if (!am || !am.body) return;
  // أرسل فقط عند تغيّر الرسالة (مقارنة الوقت)
  const beforeAt = before.admin_message?.at;
  const afterAt = am.at;
  const ms = (t) => (t && t.toMillis ? t.toMillis() : (typeof t === "number" ? t : 0));
  if (ms(afterAt) === ms(beforeAt)) return;
  const token = after.fcm_token;
  if (!token) return;
  try {
    await fcm.send({
      token,
      notification: {
        title: String(am.title || "رسالة من الإدارة"),
        body: String(am.body),
      },
      android: {priority: "high", notification: {sound: "default", channelId: "totv_high"}},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (e) {
    console.error("admin message push failed", e);
  }
});
