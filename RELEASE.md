# Release builds — Play Store & App Store

Version is defined in `pubspec.yaml`:

```yaml
version: 1.0.0+1   # 1.0.0 = user-facing, +1 = build number
```

Bump the build number (`+2`, `+3`, …) for every store upload.

---

## Android (Google Play)

### One-time setup

1. **Create an upload keystore**

   ```bash
   cd android
   keytool -genkey -v \
     -keystore upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload
   ```

   Back up `upload-keystore.jks` and the passwords securely. You cannot update the app on Play Store without them.

2. **Configure signing**

   ```bash
   cp key.properties.example key.properties
   ```

   Edit `android/key.properties` with your passwords and keystore path.

### Build for Play Store

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

Release builds use R8 minification + resource shrinking (`minifyEnabled` / `shrinkResources`) with keep rules in `android/app/proguard-rules.pro`.

Upload this file in [Google Play Console](https://play.google.com/console):

```
build/app/outputs/bundle/release/app-release.aab
```

**Package name (fixed after first publish):** `com.docmanager.doc_manager`

If `key.properties` is missing, release builds fall back to debug signing (fine for local testing, **not** for Play Store upload).

---

## iOS (App Store)

### One-time setup

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/).
2. Create an app in [App Store Connect](https://appstoreconnect.apple.com) with bundle ID **`com.docmanager.docManager`**.
3. Open the project in Xcode and confirm signing:

   ```bash
   open ios/Runner.xcworkspace
   ```

   **Runner → Signing & Capabilities:** select your Team, enable automatic signing.

### Build for App Store

```bash
flutter clean
flutter pub get
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Upload the IPA with [Transporter](https://apps.apple.com/app/transporter/id1450874784) or Xcode → Organizer:

```
build/ios/ipa/*.ipa
```

---

## Pre-upload checklist

- [ ] Version bumped in `pubspec.yaml`
- [ ] App tested on a real device in release mode
- [ ] Privacy policy URL ready (required — app stores documents and uses biometrics)
- [ ] Store listing: description, screenshots, app icon
- [ ] Android: `key.properties` configured, AAB built
- [ ] iOS: signing valid in Xcode, IPA built

---

## Useful commands

```bash
# Android release APK (side-loading / testers, not for Play Store)
flutter build apk --release

# Run release on connected device
flutter run --release

# Check Flutter / toolchain
flutter doctor -v
```
