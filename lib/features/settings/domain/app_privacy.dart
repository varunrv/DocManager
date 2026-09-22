/// Privacy copy shown in-app and mirrored in docs/privacy-policy.md for hosting.
class AppPrivacy {
  static const lastUpdated = '22 September 2026';

  static const summary = '''
Docket is a local-first document vault. Your people, categories, notes, and files stay on this device. We do not run a Docket cloud account, and we do not upload your documents to our servers.''';

  static const sections = <(String, String)>[
    (
      'What Docket stores',
      'Document files (PDFs, images, and text), titles, tags, notes, expiry dates, people profiles, and categories. These stay in the app’s private storage on your device (or in this browser on web).',
    ),
    (
      'Encryption',
      'Document file contents are encrypted on this device with AES-256-GCM. The encryption key is kept in the platform secure store (Android Keystore / iOS Keychain / browser local secure storage on web). Metadata such as titles and tags is stored in the local database and is not encrypted in this version.',
    ),
    (
      'App lock & biometrics',
      'App lock is optional. When enabled, Docket asks the operating system to authenticate with your device biometrics, PIN, or pattern. Docket never receives or stores your fingerprint or face data.',
    ),
    (
      'Camera & photos',
      'Camera and photo access are used only when you choose to capture or pick a document to save. Docket does not scan your gallery in the background.',
    ),
    (
      'Backup & sharing',
      'Export creates a password-protected .docket file that you can save or share yourself. Import only adds data you choose and does not wipe your vault. When you use Share or Export, the files leave the app through the system share sheet or a file you save — Docket does not send them to us.',
    ),
    (
      'Internet & analytics',
      'The release app does not require an internet connection for core features. Docket does not include advertising SDKs, analytics SDKs, or crash reporters that upload vault contents.',
    ),
    (
      'Deleting your data',
      'Delete individual documents in the app, or clear Docket’s app data / uninstall the app to remove the vault from this device. On web, clearing site data deletes the vault.',
    ),
    (
      'Children',
      'Docket is not directed at children under 13 and is not designed as a kids’ app.',
    ),
    (
      'Contact',
      'Questions about privacy: open Settings → About in the app, or contact the developer listed on the store listing for Docket (package com.varun.docket).',
    ),
  ];
}
