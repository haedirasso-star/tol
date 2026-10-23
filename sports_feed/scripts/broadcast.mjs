// إشعار فوري لمستخدمي TOTV+ — يُستدعى من workflow «broadcast»
import crypto from 'node:crypto';

const ALLOWED = new Set(['all_users', 'matches', 'admins']);
const title = (process.env.B_TITLE || '').trim().slice(0, 80);
const body  = (process.env.B_BODY  || '').trim().slice(0, 300);
const image = (process.env.B_IMAGE || '').trim();
const topic = (process.env.B_TOPIC || 'all_users').trim();
const SA    = process.env.FCM_SERVICE_ACCOUNT || '';

const fail = m => { console.error('❌', m); process.exit(1); };
if (!title || !body) fail('العنوان والنص مطلوبان');
if (!ALLOWED.has(topic)) fail(`topic غير مسموح: ${topic}`);
if (image && !/^https:\/\/\S+$/.test(image)) fail('رابط الصورة يجب أن يبدأ بـ https://');
if (!SA) fail('FCM_SERVICE_ACCOUNT غير موجود في Secrets');

const sa = JSON.parse(SA);
const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
const iat = Math.floor(Date.now() / 1000);
const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({
  iss: sa.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
  aud: 'https://oauth2.googleapis.com/token', iat, exp: iat + 3600 })}`;
const sig = crypto.createSign('RSA-SHA256').update(unsigned).sign(sa.private_key, 'base64url');
const tr = await fetch('https://oauth2.googleapis.com/token', {
  method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${unsigned}.${sig}` }),
});
const tok = (await tr.json()).access_token;
if (!tok) fail('تعذّر الحصول على توكن FCM — تحقق من حساب الخدمة');

const notification = { title, body };
if (image) notification.image = image;
const r = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
  method: 'POST',
  headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({ message: {
    topic, notification,
    data: { type: 'broadcast' },
    android: { priority: 'HIGH', notification: { channel_id: 'totv_main', sound: 'default' } },
    apns: { payload: { aps: { sound: 'default', 'mutable-content': 1 } }, ...(image ? { fcm_options: { image } } : {}) },
  } }),
});
if (!r.ok) fail(`FCM ${r.status}: ${await r.text()}`);
console.log(`✅ أُرسل إلى «${topic}»: ${title}`);
