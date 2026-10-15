# Sreerampur Madrasah Management (Windows Desktop)

Sreerampur Madrasah includes a browser app and an offline-first Windows desktop app. Both can synchronize records through the configured Appwrite TablesDB project. The browser version is published at [melodic-alpaca-1eff7e.netlify.app](https://melodic-alpaca-1eff7e.netlify.app/) on Netlify's free hostname; no custom domain is required. The Windows version is Flutter source, and a Windows release package is built by GitHub Actions.

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

The web app is `index.html` with files under `css/`, `js/`, and `assets/`. It saves browser data locally and requires the user to press **Sync** to exchange data with Appwrite. To host it as a static site, publish the repository root (`.`) with no build command. The deployed Netlify hostname is registered as an Appwrite Web platform so login and account recovery work from the free site URL.

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

The Flutter-generated `windows/` runner is not checked in; CI generates it, analyzes the Dart sources, builds the Windows release, and uploads the result as a 14-day artifact. Download the latest successful package from the [Windows desktop build workflow](https://github.com/abd2238551-png/sreerampur-madrasah/actions/workflows/windows-build.yml). The current CI build and analysis passed. Interactive Windows startup, local database setup, printer behavior, and a Windows-to-web Appwrite sync still need runtime verification on a Windows computer.

## Legacy data migration

In the old browser app, create/download its JSON backup first. In the desktop app, open **Backup & Restore → পুরোনো Browser App থেকে JSON Import** and select the backup. Import merges available records; keep the original JSON file and a separate copy of the old browser data until the imported records have been reviewed.

## Important operational notes

- The Flutter app remains usable offline. Supabase is no longer used; Appwrite is only for account login and manual cloud sync. Google Drive is not used by the Flutter app.
- Keep backups on another drive or external storage as well as the app's `backups/` directory.
- The local username/password only gates this app on this computer; it does not encrypt the whole Windows profile or database file.
- Windows packaging and Dart analysis pass in CI. Windows startup, local database setup, printer behavior, and Windows-to-web Appwrite sync still need runtime verification.
