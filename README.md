# Sreerampur Madrasah Management (Windows Desktop)

Sreerampur Madrasah includes a browser app and an offline-first Windows desktop app. Both can synchronize records through the configured Appwrite TablesDB project. The browser version runs directly from this folder; the Windows version is Flutter source and needs a Windows runner/build before it can be distributed as an executable.

## Desktop architecture

- Flutter Material desktop UI in `lib/` with a sidebar, paged/searchable records, Bangla labels, and local print/PDF support.
- SQLite database at `<selected Data Folder>/database/madrasa.db`, using `sqflite_common_ffi`, foreign keys, indexes, and schema versioning.
- The first launch asks for a data folder and creates `database`, `photos`, `documents`, `backups`, `reports`, and `exports` folders. The selected path is remembered in the Windows application-support directory, separate from the install folder.
- Passwords for the first local administrator are stored as salted PBKDF2 hashes. This local login protects the Windows app on that computer. Appwrite login is separate and is used for cloud sync.
- ZIP backups include the database and managed files. Restore validates the ZIP/database, creates a safety backup, then swaps managed folders with rollback on failure.
- Browser JSON import merges supported legacy module records and stores embedded base64 images in the selected data folder.
- The **Appwrite Cloud Sync** page signs in to the shared Appwrite account and syncs supported records in both directions. Web and Windows must use the same account to see the same rows.
- Sync compares local, cloud, and last-synced versions per record. If both sides changed the same record, it asks which version to keep. Cancelling leaves that record unresolved. Deletes are synchronized as tombstones.
- Before the first sync, keep an independent backup of both apps. Initial sync merges records by their existing IDs; conflicting IDs are shown for a choice. It does not merge records by matching names.
- Appwrite's public endpoint, project, database, and table IDs in source are client configuration, not server secrets. No server API key is included. Each record is scoped to the signed-in owner's row permissions; do not change the Appwrite table's row security or permissions to public access.

## Modules in this first desktop implementation

Dashboard; students; teachers; staff; classes; subjects; student/teacher/staff attendance; exams and marks; fees/receipts; income and accounts; expenses; homework; notices; books and library transactions; reports/CSV; institution settings; data-folder management; backup/restore.

## Web app and deployment

The web app is `index.html` with files under `css/`, `js/`, and `assets/`. It saves browser data locally and requires the user to press **Sync** to exchange data with Appwrite. To host it as a static site, publish the repository root (`.`) with no build command. Add the exact hosted domain under the Appwrite project's Web platform before using login and recovery links from that site.

New users can create an Appwrite email/password account from either app, then sign in with that same account on the other device. Account recovery sends a link by email. Each account can read or change its own rows only.

## Windows build prerequisites

Install Flutter and Visual Studio with the **Desktop development with C++** workload. Then, from this folder:

```powershell
flutter create --platforms=windows .
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows
```

The Flutter-generated `windows/` runner is not checked in yet. Create it with `flutter create --platforms=windows .` after installing Flutter, then run the listed dependency, analysis, and build steps. This environment does not have Flutter/Dart available, so the Windows binary has not been built or runtime-verified here.

## Legacy data migration

In the old browser app, create/download its JSON backup first. In the desktop app, open **Backup & Restore → পুরোনো Browser App থেকে JSON Import** and select the backup. Import merges available records; keep the original JSON file and a separate copy of the old browser data until the imported records have been reviewed.

## Important operational notes

- The Flutter app remains usable offline. Supabase is no longer used; Appwrite is only for account login and manual cloud sync. Google Drive is not used by the Flutter app.
- Keep backups on another drive or external storage as well as the app's `backups/` directory.
- The local username/password only gates this app on this computer; it does not encrypt the whole Windows profile or database file.
- Database and app startup, Windows packaging, printer behavior, Appwrite sync behavior, and end-to-end workflows still need actual Windows Flutter build/runtime verification.
