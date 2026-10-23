#!/usr/bin/env python3
"""
TOTV+ — يضبط Firebase لنسخة الآيفون تلقائياً من GoogleService-Info.plist:
  1) lib/firebase_options.dart  ← قسم ios بالقيم الحقيقية (appId الخاص بالآيفون...)
  2) ios/Runner/Info.plist       ← GIDClientID + رابط REVERSED_CLIENT_ID (تسجيل الدخول بجوجل)
الاستخدام: python3 ios/ci/configure_firebase.py ios/Runner/GoogleService-Info.plist
"""
import plistlib, re, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
g = plistlib.load(open(sys.argv[1], 'rb'))
need = ['API_KEY', 'GOOGLE_APP_ID', 'GCM_SENDER_ID', 'PROJECT_ID', 'BUNDLE_ID']
miss = [k for k in need if not g.get(k)]
if miss:
    sys.exit(f'GoogleService-Info.plist ينقصه: {miss}')
if g['BUNDLE_ID'] != 'com.totv.plus':
    print(f"⚠️  BUNDLE_ID في الملف = {g['BUNDLE_ID']} (المتوقع com.totv.plus) — سجّل تطبيق iOS بهذا المعرّف في Firebase")

# ── 1) firebase_options.dart ─────────────────────────────────────────
opt = root / 'lib' / 'firebase_options.dart'
src = opt.read_text(encoding='utf-8')
fields = [
    ('apiKey', g['API_KEY']),
    ('appId', g['GOOGLE_APP_ID']),
    ('messagingSenderId', g['GCM_SENDER_ID']),
    ('projectId', g['PROJECT_ID']),
    ('storageBucket', g.get('STORAGE_BUCKET', '')),
    ('iosClientId', g.get('CLIENT_ID', '')),
    ('iosBundleId', g['BUNDLE_ID']),
]
body = ''.join(f"    {k + ':':<19}'{v}',\n" for k, v in fields if v)
new = f"static const FirebaseOptions ios = FirebaseOptions(\n{body}  );"
src2, n = re.subn(r'static const FirebaseOptions ios = FirebaseOptions\((?:.|\n)*?\);', new, src, count=1)
if n != 1:
    sys.exit('لم يُعثر على قسم ios في firebase_options.dart')
opt.write_text(src2, encoding='utf-8')
print('✓ firebase_options.dart (ios) — appId =', g['GOOGLE_APP_ID'])

# ── 2) Info.plist: روابط الرجوع (URL schemes) ─────────────────────────
#   • REVERSED_CLIENT_ID ← تسجيل الدخول بجوجل + هاتف/فيسبوك عبر Firebase Auth
#   • app-<GOOGLE_APP_ID> ← بديل Firebase Auth حين لا يوجد CLIENT_ID
#   بدونهما: Firebase Auth يرمي NSException ويُغلق التطبيق عند الضغط على الدخول بالهاتف/فيسبوك
ip = root / 'ios' / 'Runner' / 'Info.plist'
info = plistlib.load(open(ip, 'rb'))
cid, rev = g.get('CLIENT_ID', ''), g.get('REVERSED_CLIENT_ID', '')
schemes = ['app-' + g['GOOGLE_APP_ID'].replace(':', '-')]
if cid and rev:
    info['GIDClientID'] = cid
    schemes.insert(0, rev)
else:
    print('⚠️  لا يوجد CLIENT_ID في الملف — فعّل Google Sign-In في Firebase ثم أعد تحميل GoogleService-Info.plist')
types = [t for t in info.get('CFBundleURLTypes', [])
         if not set(t.get('CFBundleURLSchemes', [])) & set(schemes)]
types.append({'CFBundleTypeRole': 'Editor', 'CFBundleURLSchemes': schemes})
info['CFBundleURLTypes'] = types
plistlib.dump(info, open(ip, 'wb'))
print('✓ Info.plist — URL schemes:', ', '.join(schemes))
