# Session Commands Log

This file tracks the commands executed during our development sessions and their purpose.

## Session: Firebase Authentication Setup & Emulator Troubleshooting

| Command | Purpose |
|---------|---------|
| `flutter run` | Attempted to build and install the ZestS Flutter app onto the Android emulator. |
| `flutter run -v` | Ran in verbose mode to obtain a detailed stack trace of the emulator freeze during APK installation. |
| `keytool -list -v -keystore ...` | Generated the SHA-1 debug certificate fingerprint required for Google Sign-In setup in the Firebase Console. |
| `Stop-Process -Name "qemu-system*" ...` | Force-closed the frozen Android emulator and its background processes when it became unresponsive. |
| `adb kill-server; adb start-server` | Restarted the Android Debug Bridge (ADB) to ensure a clean connection for the next emulator launch. |
