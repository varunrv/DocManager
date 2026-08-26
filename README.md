# Docket

A local-first Flutter app to store, find, share, and download documents for yourself and your family — available on Android, iOS, and Web.

## Features

- Save documents for **Me** or any family member (name + relationship)
- Add files from the file picker, gallery, or camera
- Search and filter by person, category, or keyword
- List and grid views
- Preview images and PDFs in-app
- Share via the native share sheet (mobile) or download (web)
- Offline-first: all data stays on device

## Running the app

```bash
flutter pub get
dart run build_runner build
flutter run
```

## Building for web

```bash
flutter build web
```

## Tech stack

- Flutter 3.x (Android, iOS, Web)
- Riverpod (state management)
- go_router (navigation)
- Drift + SQLite (metadata)
- IndexedDB (file storage on web)
- pdfrx (PDF preview)
