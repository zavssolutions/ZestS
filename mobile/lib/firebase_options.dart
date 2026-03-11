import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCxmHEo-FUFvlNbNZmEEkyltw5cKxJ1yvY',
    appId: '1:36898535072:android:80ea49322e21ae4fc5bbc5',
    messagingSenderId: '36898535072',
    projectId: 'zestsapp',
    storageBucket: 'zestsapp.firebasestorage.app',
  );
}
