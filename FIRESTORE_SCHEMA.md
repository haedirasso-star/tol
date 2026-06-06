# TOTV+ — Firestore Schema

## app_config/remote_control
```json
{
  "maintenance": false,
  "maint_msg": "التطبيق تحت الصيانة...",
  "locked": false,
  "lock_msg": "",
  "guest_only": false
}
```

## app_config/remote_config
```json
{
  "server_host": "http://your-server.com:8080",
  "whatsapp":    "9647714415816",
  "telegram":    "https://t.me/O_2828",
  "update_url":  "https://yoursite.com/totv.apk"
}
```

## app_config/version
```json
{
  "min_version":  1,
  "force_update": false,
  "store_url":    "https://yoursite.com/totv.apk",
  "update_msg":   "نسخة جديدة متاحة! حدّث للاستمتاع بأحدث الميزات."
}
```

## app_config/settings
```json
{
  "tmdb_key":         "your_tmdb_api_key",
  "support_whatsapp": "9647714415816"
}
```

## users/{uid}
```json
{
  "email":        "user@example.com",
  "display_name": "اسم المستخدم",
  "platform":     "android",
  "app_version":  "1.0.0",
  "last_seen":    "<timestamp>",
  "is_online":    false,
  "device_id":    "abc123",
  "status":       "active",
  "subscription": {
    "plan":        "premium",
    "username":    "xtream_user",
    "password":    "xtream_pass",
    "expiry_date": "<timestamp>",
    "updated_at":  "<timestamp>"
  }
}
```

## notifications/{id}
```json
{
  "title":   "إشعار مهم",
  "body":    "نص الإشعار",
  "active":  true,
  "sent_at": "<timestamp>"
}
```

---
## كيف يعمل نظام الإصدار

- `pubspec.yaml` → `version: 1.0.0+1`  ← مصدر الحقيقة الوحيد
- عند الإقلاع: `AppVersion.init()` يقرأ الإصدار من `PackageInfo`
- `AppVersion.major` = الرقم الأول (1 من 1.0.0)
- Firestore `app_config/version.min_version` = رقم صحيح (مثلاً 2)
- إذا `min_version > AppVersion.major` → يظهر حارس البوابة

## كيف يعمل الاشتراك

1. المشترك يدخل username + password
2. التطبيق يتصل بـ `RC.serverHost/player_api.php`
3. إذا نجح → يحفظ محلياً + في Firestore users/{uid}
4. جميع طلبات المحتوى تستخدم username/password المحفوظة
