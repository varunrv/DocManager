# Docket — Implementation notes (v1.1)

This document describes the features landed on the `feature` branch
(commit `c4516db` and follow-ups). Use it as a reference for how the
new behaviour works, which files own it, and what is still out of scope.

**App:** Docket (`com.varun.docket`)  
**Package:** `docket`  
**Related release notes:** [`RELEASE.md`](../RELEASE.md)  
**Privacy (hostable):** [`privacy-policy.md`](privacy-policy.md)

---

## Table of contents

1. [Encryption at rest](#1-encryption-at-rest)
2. [Selective encrypted backup (export)](#2-selective-encrypted-backup-export)
3. [Merge import (no vault wipe)](#3-merge-import-no-vault-wipe)
4. [Expiry tab + reminder flag](#4-expiry-tab--reminder-flag)
5. [Bulk move & delete](#5-bulk-move--delete)
6. [Quick add templates](#6-quick-add-templates)
7. [About & privacy](#7-about--privacy)
8. [Play Store / Android hardening](#8-play-store--android-hardening)
9. [Dependency upgrades](#9-dependency-upgrades)
10. [Database schema](#10-database-schema)
11. [Tests](#11-tests)
12. [Out of scope / later](#12-out-of-scope--later)
13. [Key file map](#13-key-file-map)

---

## 1. Encryption at rest

### What users see
Nothing to turn on. Document **file bytes** (and thumbnails) are always
encrypted when written to disk / IndexedDB. Preview, share, and backup
still receive **decrypted** bytes through the repository.

App lock remains **optional** and only gates the UI. It does **not**
load or clear the encryption key.

### How it works
| Piece | Role |
| --- | --- |
| `VaultKeyHolder` | Holds the 256-bit DEK in memory for the process lifetime |
| `VaultKeyRepository` | Creates / loads DEK from `flutter_secure_storage` |
| `VaultCryptoService` | AES-256-GCM encrypt/decrypt; 12-byte nonce prepended to ciphertext |
| `EncryptedFileStore` | Wraps the platform `FileStore`; encrypt on write, decrypt on read |
| `VaultFileMigration` | One-time plaintext → encrypted rewrite of existing blobs |

On startup (`main.dart`), Docket:

1. Loads / generates the DEK  
2. Runs migration if the SharedPreferences flag `encryption_migrated_v1` is unset  
3. Then starts the UI  

Repositories always use `fileStoreProvider` → `EncryptedFileStore`.

### Security notes
- **Protected:** raw extraction of file blobs without the device DEK  
- **Not protected by encryption alone:** someone using an unlocked phone with app lock off  
- SQLite **metadata** (titles, tags, notes) is still unencrypted in this version  

Settings shows an info line: documents are encrypted on this device
(with a web-specific note about browser storage).

---

## 2. Selective encrypted backup (export)

### User flow
**Settings → Export backup**

1. **Choose people** — “All people” at the top; each person card shows
   how many of their docs are selected. Checkbox selects/clears that
   person’s docs; tap opens that person’s document list.  
2. **Choose documents** — “All documents” for that person only; back
   returns to the people list.  
3. If any of **your (Me)** docs are included and the Self display name
   is still empty / `"Me"`, Docket asks for a **real name** before
   continuing (so the backup does not label you as “Me”).  
4. Enter backup password (min 8 characters, confirmed).  
5. Share / download a password-protected `.docket` file.

### Archive format (after password decryption)
```
manifest.json          # people, categories, documents metadata
files/{storageKey}     # decrypted plaintext document bytes
files/{id}-thumb       # optional thumbnails
```

Encryption of the archive: PBKDF2 (100k iterations) → AES-256-GCM,
with salt + nonce stored in the payload header.

Only selected documents (plus their people and needed categories) are
included. App lock / theme settings are **not** exported.

---

## 3. Merge import (no vault wipe)

### User flow
**Settings → Import backup**

1. Pick a `.docket` file  
2. Enter password → decrypt & validate  
3. **For each person in the backup**, choose:
   - **Merge into existing person** (pick who; Self defaults to local Me)
   - **Create as new person** (name + relationship), or for Self:
     “Save onto Me (update name)” — never creates a second Me  
   - **Skip** — do not import that person’s documents  
4. Import runs as a **merge**. Existing local data is never wiped.

### Conflict rules
| Case | Behaviour |
| --- | --- |
| Document id already on device | **Skip** that document (keep local) |
| Person missing locally + Create | Insert person, attach docs |
| Backup Self | Always maps onto local Me when merged / “save onto Me” |
| Missing category for imported docs | Upsert category from backup |

A short snackbar summarises: documents added, people created, docs
skipped, people skipped.

---

## 4. Expiry tab + reminder flag

### Navigation
Bottom nav: **Library | Expiry | People | Categories | Settings**

### Behaviour
- Lists only documents with an `expiresAt` date  
- Buckets: **Expired**, **Expiring soon** (≤ 30 days), **Upcoming**  
- Each row can toggle **Reminder** (`reminderEnabled`)  
- Notifications are **not** scheduled yet — toggle persists for a
  future notifications release (“coming soon” copy in UI)

### Schema
Drift schema **v2** adds `documents.reminder_enabled` (bool, default
false) with an `onUpgrade` migration from v1.

---

## 5. Bulk move & delete

Library long-press / multi-select mode (share already existed) now also
supports:

- **Move** — pick a person; updates `personId` for selected docs  
- **Delete** — confirm, then delete DB rows + encrypted blobs  

Implemented via `DocumentRepository.deleteMany` and
`updatePersonIdMany`.

---

## 6. Quick add templates

Library has a small bolt FAB that opens a **Quick add** sheet with
presets (Aadhaar, PAN, Passport, Driving License, Insurance, Voter ID).

Choosing a template opens `/add?template=…` and pre-fills title,
category, and tags on `DocumentFormScreen`. User still attaches the
file and saves normally.

---

## 7. About & privacy

### In app
- **Settings → About Docket** — app name, **version + build number**
  (`package_info_plus`), local-only / encryption / no-cloud summary  
- **About → Privacy policy** — full policy text from
  `AppPrivacy` (same content as the hostable markdown)

### For Play Console
Host [`docs/privacy-policy.md`](privacy-policy.md) as a public HTTPS
page and paste the URL into **App content → Privacy policy**. The file
also includes a Data safety quick-reference table.

---

## 8. Play Store / Android hardening

| Change | Why |
| --- | --- |
| Strip `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` (`tools:node="remove"`) | Avoid Play Photo/Video Permissions form; app only needs one-off picks via Photo Picker / SAF |
| Keep `CAMERA` + biometric permissions | Photograph documents; optional app lock |
| Pin `compileSdk` / module override to **36** | Compatible with installed SDK; plugins that declare 37 no longer break the build |
| Gitignore `key.properties` / `*.jks` | Prevent committing the upload keystore |
| Expand `RELEASE.md` | Play checklist: AAB, Data safety, privacy URL, closed testing note |

Package id remains **`com.varun.docket`** (immutable after first publish).

---

## 9. Dependency upgrades

Notable bumps included with this work:

- `flutter_riverpod` **3.x** — `AsyncValue.value` replaces `valueOrNull`;
  `StateProvider` imported from `flutter_riverpod/legacy.dart`  
- `go_router` **18.x**  
- Added: `cryptography`, `flutter_secure_storage`, `archive`,
  `package_info_plus`

---

## 10. Database schema

| Version | Change |
| --- | --- |
| 1 | Initial people / categories / documents |
| 2 | `documents.reminder_enabled` |

Regenerate with:

```bash
dart run build_runner build
```

---

## 11. Tests

| File | Covers |
| --- | --- |
| `test/vault_backup_service_test.dart` | Selective export, Self-name gate, merge without wipe, create/skip people, wrong password, empty selection |
| `test/app_privacy_test.dart` | Privacy sections present for About / hosting |
| Existing `test/widget_test.dart` | Formatters / person labels |

Run:

```bash
flutter test
```

---

## 12. Out of scope / later

These were deliberately **not** built in this release:

- Local notifications / scheduling for `reminderEnabled`  
- Cloud sync  
- Encrypting SQLite metadata (titles, tags, notes)  
- Erase-and-replace import mode (only merge now)  
- Tying DEK lifecycle to app lock (clear key on background)  
- Hosting the privacy URL (markdown is ready; you still publish HTTPS)

---

## 13. Key file map

```
lib/main.dart                          # DEK load + migration before runApp
lib/core/crypto/                       # Vault crypto + key + migration
lib/core/storage/encrypted_file_store.dart
lib/core/providers.dart                # EncryptedFileStore + backup service
lib/core/database/app_database.dart    # schema v2 reminderEnabled

lib/features/backup/                   # Export/import UI + VaultBackupService
lib/features/documents/presentation/expiry_screen.dart
lib/features/documents/presentation/library_screen.dart   # bulk move/delete
lib/features/documents/presentation/quick_add_sheet.dart
lib/features/documents/domain/quick_add_template.dart
lib/features/settings/presentation/about_screen.dart
lib/features/settings/presentation/privacy_policy_screen.dart
lib/features/settings/domain/app_privacy.dart

android/app/src/main/AndroidManifest.xml
android/build.gradle.kts               # compileSdk 36 override for plugins
docs/privacy-policy.md
RELEASE.md
```

---

## How to try it (smoke)

1. Add a document → confirm open/share still works (encryption transparent)  
2. **Export** — pick one person, subset of docs, set Self name if prompted  
3. **Import** into a vault that already has data — confirm nothing is wiped;
   try merge / create / skip  
4. Set expiry dates → open **Expiry** tab → toggle reminder  
5. Long-press library → bulk move / delete  
6. Quick add → save a templated document  
7. **Settings → About** → version + privacy policy  

For Play upload steps, see [`RELEASE.md`](../RELEASE.md).
