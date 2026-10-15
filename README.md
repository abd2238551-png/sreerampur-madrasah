# Sreerampur Madrasah Management (Windows Desktop)

This folder is being migrated from the previous browser-based app to an offline Flutter Windows application. The old `index.html`, `js/`, and `css/` files are retained as a source for exporting/importing legacy JSON backups; they are not the desktop application's runtime.

## Desktop architecture

- Flutter Material desktop UI in `lib/` with a sidebar, paged/searchable records, Bangla labels, and local print/PDF support.
- SQLite database at `<selected Data Folder>/database/madrasa.db`, using `sqflite_common_ffi`, foreign keys, indexes, and schema versioning.
- The first launch asks for a data folder and creates `database`, `photos`, `documents`, `backups`, `reports`, and `exports` folders. The selected path is remembered in the Windows application-support directory, separate from the install folder.
- Passwords for the first local administrator are stored as salted PBKDF2 hashes. This is a single-computer local login, not an internet account or multi-user server.
- ZIP backups include the database and managed files. Restore validates the ZIP/database, creates a safety backup, then swaps managed folders with rollback on failure.
- Browser JSON import merges supported legacy module records and stores embedded base64 images in the selected data folder.

## Modules in this first desktop implementation

Dashboard; students; teachers; staff; classes; subjects; student/teacher/staff attendance; exams and marks; fees/receipts; income and accounts; expenses; homework; notices; books and library transactions; reports/CSV; institution settings; data-folder management; backup/restore.

## Build prerequisites

Install the Flutter SDK and Visual Studio with the **Desktop development with C++** workload. Then, from this folder:

```powershell
flutter create --platforms=windows .
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows
```

The Flutter-generated `windows/` runner is not checked in yet. Create it with `flutter create --platforms=windows .` after installing Flutter. Build and run are not yet verified in this environment because Flutter/Dart and the Visual Studio C++ desktop workload are unavailable here.

## Legacy data migration

In the old browser app, create/download its JSON backup first. In the desktop app, open **Backup & Restore → পুরোনো Browser App থেকে JSON Import** and select the backup. Import merges available records; keep the original JSON file and a separate copy of the old browser data until the imported records have been reviewed.

## Important operational notes

- This desktop build is offline-first; Supabase and Google Drive are not used by the new Flutter app.
- Keep backups on another drive or external storage as well as the app's `backups/` directory.
- The local username/password only gates this app on this computer; it does not encrypt the whole Windows profile or database file.
- Database and app startup, Windows packaging, printer behavior, and end-to-end workflows still need actual Windows Flutter build/runtime verification.
