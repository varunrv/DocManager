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
   `key.properties` and `*.jks` are gitignored — do not commit them.

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

**Package name (fixed after first publish):** `com.varun.docket`

If `key.properties` is missing, release builds fall back to debug signing (fine for local testing, **not** for Play Store upload).

### Permissions (keep aligned with the app)

The main manifest:

- Declares **CAMERA** (optional hardware) for photographing documents
- Declares **biometric** permissions for optional app lock
- **Removes** `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` (Photo Picker / SAF only)
- Keeps legacy `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` with low `maxSdkVersion` for older Android only

After changing permissions, confirm gallery pick + camera still work on a real device before uploading.

### Privacy policy URL (required)

1. Host [`docs/privacy-policy.md`](docs/privacy-policy.md) as a public HTTPS page (GitHub Pages, your site, Notion public page, etc.).
2. Paste that URL into Play Console → **App content → Privacy policy**.
3. In the app, users can also open **Settings → About → Privacy policy**.

### Play Console — App content checklist

Fill these so they match `docs/privacy-policy.md` and the in-app About screen:

| Form | Docket answer |
| --- | --- |
| **Data safety** | No data collected/sent by Docket; files encrypted at rest; delete via app / uninstall |
| **Photo & video permissions** | Only if Play still detects media permissions after merge — should not apply after `tools:node="remove"` |
| **Encryption export** | Uses standard AES encryption (exemption form) |
| **Ads** | No |
| **In-app purchases** | No |
| **Target audience** | Adults; not Designed for Families |
| **App access** | All features without login; app lock off by default |
| **Closed testing** | New personal accounts often need 12 testers × 14 days before Production |

### Device smoke test (release)

```bash
flutter run --release
```

Walk through: add via camera, add via gallery/file, PDF preview, share, export backup, import backup, app lock on/off.

---

## iOS (App Store)

### One-time setup

1. Enroll in the [Apple Developer Program](https://developer.apple.com/programs/).
2. Create an app in [App Store Connect](https://appstoreconnect.apple.com) with bundle ID **`com.varun.docket`**.
3. Open the project in Xcode and confirm signing:

   ```bash
   open ios/Runner.xcworkspace
   ```

   **Runner → Signing & Capabilities:** select your Team, enable automatic signing.

Camera / Photos / Face ID usage strings are already in `ios/Runner/Info.plist`.

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
- [ ] App tested on a real device in **release** mode
- [ ] Privacy policy **HTTPS URL** live (from `docs/privacy-policy.md`)
- [ ] Store listing: description, screenshots (fake docs only), feature graphic, icon
- [ ] Android: `key.properties` configured, **AAB** built with upload keystore
- [ ] Play Data safety + encryption forms match the privacy policy
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
