#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  TOTV+ — تجهيز Runner.app غير الموقّع ليقبله Sideloadly / AltStore
#
#  المشكلة: «flutter build ios --no-codesign» يُنتج ملفات تنفيذية بلا أي توقيع.
#  Sideloadly يستبدل التوقيع الموجود — وإن لم يجد بنية توقيع في إطار ما
#  (خصوصاً أطر FFmpeg/mpv الكثيرة) قد يتخطّاه، فيرفض iOS التثبيت:
#    0xe800801c (No code signature found)
#
#  الحل: توقيع «مؤقت» (ad-hoc, الهوية "-") لكل dylib وكل framework ثم التطبيق،
#  من الداخل إلى الخارج. هذا ليس توقيعاً صالحاً للتشغيل وحده — لكنه يعطي
#  Sideloadly بنية كاملة يعيد توقيعها بحساب Apple ID.
#
#  الاستخدام: bash ios/ci/fakesign.sh build/ios/iphoneos/Runner.app
# ════════════════════════════════════════════════════════════════════
set -euo pipefail
APP="${1:?path to Runner.app}"
FW="$APP/Frameworks"
CS=(codesign --force --sign - --timestamp=none)

echo "── الأطر داخل التطبيق ──"
if [ -d "$FW" ]; then
  for f in "$FW"/*.framework; do
    [ -e "$f" ] || continue
    exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$f/Info.plist" 2>/dev/null || true)
    if [ -z "$exe" ] || [ ! -f "$f/$exe" ]; then
      echo "::warning::إطار بلا ملف تنفيذي صالح: $(basename "$f") (CFBundleExecutable='$exe')"
    else
      echo "  $(basename "$f")  →  $exe"
    fi
  done
fi

# بقايا قد تربك أدوات إعادة التوقيع
find "$APP" -name '_CodeSignature' -type d -prune -exec rm -rf {} + 2>/dev/null || true
find "$APP" -name '*.dSYM' -type d -prune -exec rm -rf {} + 2>/dev/null || true
rm -f "$APP/embedded.mobileprovision"

# 1) كل مكتبة dylib (داخل الأطر أو مباشرة)
while IFS= read -r -d '' lib; do "${CS[@]}" "$lib"; done < <(find "$APP" -name '*.dylib' -type f -print0)

# 2) الأطر — الأعمق أولاً (find -depth يسرد المحتوى قبل المجلد نفسه)
while IFS= read -r -d '' f; do "${CS[@]}" "$f"; done < <(find "$APP" -depth -name '*.framework' -type d -print0)

# 3) التطبيق نفسه (بدون صلاحيات خاصة — Sideloadly يضع صلاحيات حسابك)
"${CS[@]}" "$APP"

echo "── التحقق ──"
codesign --verify --deep --strict --verbose=2 "$APP"
missing=0
while IFS= read -r -d '' m; do
  if file "$m" | grep -q 'Mach-O' && ! codesign -dv "$m" >/dev/null 2>&1; then
    echo "::error::ملف تنفيذي بلا توقيع: ${m#$APP/}"; missing=1
  fi
done < <(find "$APP" -type f \( -perm -111 -o -name '*.dylib' \) -print0)
[ $missing -eq 0 ] && echo "✓ كل الملفات التنفيذية تحمل بنية توقيع — جاهز لـ Sideloadly"
exit $missing
