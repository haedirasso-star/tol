// File generated manually from Firebase Console
// Project: totvq-8e439

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS:     return ios;
      case TargetPlatform.windows: return windows;
      default:                     return android;
    }
  }

  // ── Android ──────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBR9NjEZHm9RhngSfYNMmphaH_gDLTApTY',
    appId:             '1:214530463737:android:c6447caa773d03b1164f28',
    messagingSenderId: '214530463737',
    projectId:         'totvq-8e439',
    storageBucket:     'totvq-8e439.firebasestorage.app',
  );

  // ── Web ───────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey:            'AIzaSyCk0dSmHGQ248b-OQi44Rm2zWrfbpLBkpU',
    appId:             '1:214530463737:web:8c45ab9fcb43807a164f28',
    messagingSenderId: '214530463737',
    projectId:         'totvq-8e439',
    storageBucket:     'totvq-8e439.firebasestorage.app',
    authDomain:        'totvq-8e439.firebaseapp.com',
    measurementId:     'G-4QLB7GVRJT',
  );

  // ── iOS (نفس Android حتى تضيف GoogleService-Info.plist) ──
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyBR9NjEZHm9RhngSfYNMmphaH_gDLTApTY',
    appId:             '1:214530463737:android:c6447caa773d03b1164f28',
    messagingSenderId: '214530463737',
    projectId:         'totvq-8e439',
    storageBucket:     'totvq-8e439.firebasestorage.app',
    authDomain:        'totvq-8e439.firebaseapp.com',
  );

  // ── Windows (Web config) ──────────────────────────────
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey:            'AIzaSyCk0dSmHGQ248b-OQi44Rm2zWrfbpLBkpU',
    appId:             '1:214530463737:web:8c45ab9fcb43807a164f28',
    messagingSenderId: '214530463737',
    projectId:         'totvq-8e439',
    storageBucket:     'totvq-8e439.firebasestorage.app',
    authDomain:        'totvq-8e439.firebaseapp.com',
    measurementId:     'G-4QLB7GVRJT',
  );
}
