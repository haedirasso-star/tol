# WebRTC / LiveKit — أسماء تُستدعى من JNI، تشويهها يسبب انهياراً
-keep class org.webrtc.** { *; }
-keep class io.livekit.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**

-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
