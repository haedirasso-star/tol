// ═══════════════════════════════════════════════════════════════
//  مُولَّد من google-services.json الخاص بمشروع totvq-8e439
//  (Android فقط — لإضافة iOS نفّذ: flutterfire configure)
//
//  ℹ️ هذه القيم ليست أسراراً: كل تطبيق أندرويد يشحنها داخل الـ APK
//     ويمكن استخراجها بسهولة. ما يحمي بياناتك فعلاً هو firestore.rules.
// ═══════════════════════════════════════════════════════════════
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('الويب غير مُهيّأ — نفّذ flutterfire configure');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
            'iOS غير مُهيّأ — نفّذ flutterfire configure لإضافته');
      default:
        throw UnsupportedError('منصّة غير مدعومة: $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBR9NjEZHm9RhngSfYNMmphaH_gDLTApTY',
    appId: '1:214530463737:android:c6447caa773d03b1164f28',
    messagingSenderId: '214530463737',
    projectId: 'totvq-8e439',
    storageBucket: 'totvq-8e439.firebasestorage.app',
  );
}
