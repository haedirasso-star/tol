# ════════════════════════════════════════════════════════════
#  TOTV+ ProGuard Rules — Android 14/15 Compatible
# ════════════════════════════════════════════════════════════

# ── Flutter ──────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── Firebase ─────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Firestore ────────────────────────────────────────────────
-keep class com.google.firestore.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# ── OkHttp / Dio ─────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── Video Player ─────────────────────────────────────────────
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ── CachedNetworkImage ───────────────────────────────────────
-keep class com.github.bumptech.glide.** { *; }
-dontwarn com.github.bumptech.glide.**

# ── FlutterDownloader ────────────────────────────────────────
-keep class vn.hunghd.flutterdownloader.** { *; }
-dontwarn vn.hunghd.**

# ── Kotlin Coroutines ────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ── AndroidX ─────────────────────────────────────────────────
-keep class androidx.** { *; }
-dontwarn androidx.**

# ── Prevent stripping of app code ────────────────────────────
-keep class com.totv.plus.** { *; }
-keepclassmembers class com.totv.plus.** { *; }

# ── Serialization (Gson / JSON) ──────────────────────────────
-keepattributes EnclosingMethod
-keep class * implements java.io.Serializable { *; }

# ── Suppress common warnings ─────────────────────────────────
-dontwarn java.lang.invoke.**
-dontwarn sun.misc.**
-dontwarn javax.annotation.**

# ── Android 14/15 specific ───────────────────────────────────
-keep class android.window.** { *; }
-dontwarn android.window.**
