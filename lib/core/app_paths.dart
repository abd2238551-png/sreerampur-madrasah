import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persists the user's selected data root outside the install directory.
class AppPaths {
  AppPaths._();
  static const _configName = 'sreerampur_madrasah_config.json';
  static String? dataRoot;

  static Future<File> get _configFile async {
    final support = await getApplicationSupportDirectory();
    await support.create(recursive: true);
    return File(p.join(support.path, _configName));
  }

  static Future<String?> loadDataRoot() async {
    try {
      final file = await _configFile;
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      final saved = decoded is Map ? decoded['dataRoot'] as String? : null;
      if (saved == null || saved.trim().isEmpty) return null;
      final dir = Directory(saved);
      if (!await dir.exists()) throw const DataFolderUnavailable();
      dataRoot = dir.absolute.path;
      return dataRoot;
    } on DataFolderUnavailable {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveDataRoot(String path) async {
    final root = Directory(path).absolute;
    await root.create(recursive: true);
    await _configFile.then((f) => f.writeAsString(
          jsonEncode({'dataRoot': root.path, 'updatedAt': DateTime.now().toUtc().toIso8601String()}),
          flush: true,
        ));
    dataRoot = root.path;
  }

  static Directory get root => Directory(dataRoot!);
  static Directory get database => Directory(p.join(dataRoot!, 'database'));
  static Directory get photos => Directory(p.join(dataRoot!, 'photos'));
  static Directory get documents => Directory(p.join(dataRoot!, 'documents'));
  static Directory get backups => Directory(p.join(dataRoot!, 'backups'));
  static Directory get reports => Directory(p.join(dataRoot!, 'reports'));
  static Directory get exports => Directory(p.join(dataRoot!, 'exports'));
  static File get databaseFile => File(p.join(database.path, 'madrasa.db'));

  static Future<void> ensureStructure() async {
    if (dataRoot == null) throw StateError('Data folder has not been selected.');
    for (final dir in [root, database, photos, documents, backups, reports, exports,
      Directory(p.join(photos.path, 'students')),
      Directory(p.join(photos.path, 'staff')),
      Directory(p.join(documents.path, 'students'))]) {
      await dir.create(recursive: true);
      await dir.stat(); // Surface permission and unavailable-drive errors early.
    }
  }
}

class DataFolderUnavailable implements Exception {
  const DataFolderUnavailable();
  @override
  String toString() => 'আগের Data Folder পাওয়া যাচ্ছে না। drive সংযুক্ত করে আবার চেষ্টা করুন অথবা নতুন folder নির্বাচন করুন।';
}
