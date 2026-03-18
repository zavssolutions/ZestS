import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDK_nXcB4y0sIohdJPxe_iq4-RPyky8740',
    appId: '1:278971942608:android:d620b69cb052ae2077c0d5',
    messagingSenderId: '278971942608',
    projectId: 'test-49b1d',
    storageBucket: 'test-49b1d.firebasestorage.app',
  );
}
