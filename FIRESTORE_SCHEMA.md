# TOTV+ — Firestore Schema (نظام أكواد التفعيل)

## activation_codes/{CODE}   ★ المجموعة الأساسية الجديدة
معرّف المستند **هو الكود نفسه** (12 حرفاً، مثال: `TOTVAB12CD34`).
يُعرض للمستخدم بصيغة `TOTV-AB12-CD34`.

```json
{
  "code":        "TOTVAB12CD34",
  "batch_id":    "BLX8K2M1",
  "host":        "http://server.com:8080",
  "username":    "xtream_user",
  "password":    "xtream_pass",
  "plan":        "monthly | quarterly | yearly",
  "days":        30,
  "status":      "unused | used | disabled",
  "used":        false,
  "disabled":    false,
  "agent":       "اسم الوكيل",
  "note":        "ملاحظة إدارية",

  "used_by_uid":    "",
  "used_by_email":  "",
  "used_by_name":   "",
  "used_by_phone":  "",
  "used_device_id": "",
  "used_platform":  "",
  "used_app_ver":   "",
  "used_at":        null,
  "expiry_date":    null,
  "last_seen_at":   null,

  "created_by": "admin@totv.com",
  "created_at": "<timestamp>"
}
```

## users/{uid}
```json
{
  "email":        "user@example.com",
  "display_name": "اسم المستخدم",
  "platform":     "android",
  "app_version":  "1.0.0",
  "device_id":    "abc123",
  "last_seen":    "<timestamp>",
  "status":       "active",

  "subscription": {
    "plan":          "premium",
    "tier":          "monthly | quarterly | yearly",
    "duration_days": 30,
    "code":          "TOTVAB12CD34",
    "host":          "http://server.com:8080",
    "server_host":   "http://server.com:8080",
    "username":      "xtream_user",
    "password":      "xtream_pass",
    "expiry_date":   "<timestamp>",
    "activated_at":  "<timestamp>",
    "activated_by":  "code",
    "source":        "activation_code",
    "agent":         "",
    "updated_at":    "<timestamp>"
  },

  "vip": { "…نسخة احتياطية لاشتراك VIP اليدوي…" }
}
```

## activations/{autoId}   — سجل كل عملية تفعيل
```json
{
  "uid":"", "email":"", "name":"", "code":"", "host":"",
  "plan":"monthly", "days":30, "source":"activation_code",
  "device_id":"", "platform":"android", "app_version":"1.0.0",
  "created_at":"<timestamp>"
}
```

## app_config/remote_config
```json
{
  "server_host":         "http://your-server.com:8080",
  "default_server_host": "http://your-server.com:8080",
  "whatsapp":            "9647714415816",
  "telegram":            "https://t.me/O_2828",
  "update_url":          "https://yoursite.com/totv.apk",
  "buy_url":             "https://payment-totv.vercel.app/"
}
```

## app_config/remote_control
```json
{ "maintenance": false, "maint_msg": "", "locked": false, "lock_msg": "", "guest_only": false }
```

## app_config/version
```json
{ "min_version": 1, "force_update": false, "store_url": "", "update_msg": "" }
```

## app_config/settings
```json
{ "tmdb_key": "…", "support_whatsapp": "9647714415816" }
```

## app_config/secrets   ★ للأدمن فقط (لا يقرؤه التطبيق)
```json
{ "tg_token": "…", "tg_chat": "…" }
```

---

## كيف يعمل نظام الاشتراك الجديد

```
الأدمن يُدخل: Host + Username + Password + الباقة
        ↓
صفحة الأدمن تولّد كودين (2) في activation_codes
        ↓
تُباع الأكواد للمستخدمين
        ↓
المستخدم يُدخل الكود في التطبيق (مرة واحدة)
        ↓
التطبيق يحجز الكود داخل Transaction (لا يمكن استخدامه مرتين)
        ↓
يقرأ host/username/password منه ويتصل بالسيرفر مباشرة
        ↓
يحفظ الاشتراك في:
   • SharedPreferences (محلي — لا يُسأل عن الكود ثانية)
   • users/{uid}.subscription (سحابي — يُستعاد بعد تسجيل الخروج)
   • activation_codes/{CODE} (بيانات المشترك داخل الكود)
        ↓
يُحمّل كل المحتوى من سيرفر الكود
```

### عند تسجيل الخروج ثم الدخول
`Sub.endSession()` تمسح الجلسة المحلية فقط.
عند الدخول يقرأ التطبيق `users/{uid}.subscription` ويحفظه محلياً من جديد.
**لا شيء يُمسح من Firestore عند الخروج إطلاقاً.**

### عند تحديث الأدمن لبيانات السيرفر
`UserDataWatcher` يستمع لـ `users/{uid}` ويلتقط التغيير فوراً،
فيبدّل السيرفر ويعيد تحميل المحتوى دون تدخّل من المستخدم.
