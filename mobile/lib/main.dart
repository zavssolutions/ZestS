import "package:firebase_core/firebase_core.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:zests_app/app/app.dart";
import "package:zests_app/firebase_options.dart";

Future<void> main() async {
  // 1. Ensure the Flutter engine is ready
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. Check for existing apps
    if (Firebase.apps.isNotEmpty) {
      debugPrint("Firebase already initialized: ${Firebase.apps.first.name}");
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Firebase initialized for the first time.");
    }
  } on FirebaseException catch (e) {
    if (e.code == "duplicate-app") {
      debugPrint("Caught duplicate-app error; safe to ignore.");
    } else {
      rethrow;
    }
  } catch (e) {
    debugPrint("General Firebase initialization error: $e");
  }

  runApp(const ProviderScope(child: ZestsApp()));
}
