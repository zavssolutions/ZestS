import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAFB00XSj9c9fvzRcIea72GEd8H_vRfz2k',
    appId: '1:278971942608:android:64d99eeff28c0d4b77c0d5',
    messagingSenderId: '278971942608',
    projectId: 'test-49b1d',
    storageBucket: 'test-49b1d.firebasestorage.app',
  );
}
