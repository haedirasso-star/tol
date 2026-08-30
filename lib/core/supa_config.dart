part of '../main.dart';

// ════════════════════════════════════════════════════════════════════════
//  TOTV+ — إعدادات Supabase
//  ──────────────────────────────────────────────────────────────────────
//  ★★★  ضع هنا قيمتين فقط من لوحة Supabase  ★★★
//
//  1) Project URL:
//       Supabase → Settings → Data API → Project URL
//       مثال: https://abcdxyz.supabase.co
//
//  2) Publishable key:
//       Supabase → Settings → API Keys → قسم "Publishable key"
//       يبدأ بـ sb_publishable_  (أو eyJ... في المشاريع القديمة)
//
//  ⚠️ ممنوع منعاً باتاً وضع مفتاح من قسم "Secret keys" هنا
//     (يبدأ بـ sb_secret_). هذا يتجاوز كل الحماية ويسمح لأي شخص
//     بقراءة كل أكوادك وحذف قاعدتك. المفتاح العام وحده آمن —
//     الحماية تأتي من RLS داخل القاعدة، لا من إخفاء المفتاح.
// ════════════════════════════════════════════════════════════════════════

/// رابط مشروع Supabase — مثال: https://abcdefghijk.supabase.co
const String kSupaUrl = 'https://hlmaksidfqdarwunedqj.supabase.co';

/// المفتاح العام — يقبل الصيغتين:
///   • الجديدة:  sb_publishable_xxxxxxxx      (Settings → API Keys)
///   • القديمة:  eyJhbGciOi...                (anon public)
///
/// ⚠️ لا تضع أبداً مفتاحاً يبدأ بـ sb_secret_ أو service_role —
///    هذان يتجاوزان كل الحماية ويجب ألا يخرجا من السيرفر إطلاقاً.
const String kSupaPublicKey = 'sb_publishable_-lEvqrjoQgkXJdN4lZExxw_1cycMoEj';

/// حارس أمان: يرفض التشغيل إن وُضع مفتاح سرّي بالخطأ.
bool get kSupaKeyIsSecret =>
    kSupaPublicKey.startsWith('sb_secret_') ||
    kSupaPublicKey.contains('service_role');

/// هل الإعدادات مكتملة وصالحة؟
bool get kSupaReady {
  if (kSupaKeyIsSecret) {
    // ignore: avoid_print
    print('🛑 SUPABASE: وُضع مفتاح سرّي في التطبيق! استبدله بـ publishable.');
    return false;
  }
  final urlOk = kSupaUrl.startsWith('https://') &&
      kSupaUrl.contains('.supabase.co') &&
      !kSupaUrl.contains('PUT-YOUR');
  final keyOk = kSupaPublicKey.length > 20 &&
      !kSupaPublicKey.contains('PUT-YOUR') &&
      (kSupaPublicKey.startsWith('sb_publishable_') ||
       kSupaPublicKey.startsWith('eyJ'));
  return urlOk && keyOk;
}
