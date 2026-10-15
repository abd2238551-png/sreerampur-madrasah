import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_paths.dart';
import 'madrasa_database.dart';

class DataManager {
  static Future<String> createBackup({String? destination}) async {
    await MadrasaDatabase.checkIntegrity();
    final timestamp=DateTime.now().toLocal();
    final stamp='${timestamp.year.toString().padLeft(4,'0')}-${timestamp.month.toString().padLeft(2,'0')}-${timestamp.day.toString().padLeft(2,'0')}_${timestamp.hour.toString().padLeft(2,'0')}${timestamp.minute.toString().padLeft(2,'0')}${timestamp.second.toString().padLeft(2,'0')}';
    final target=destination??p.join(AppPaths.backups.path,'madrasa_backup_$stamp.zip');
    final archive=Archive();
    final manifest=utf8.encode(jsonEncode({'app':'sreerampur-madrasah-desktop','backupVersion':1,'createdAt':DateTime.now().toUtc().toIso8601String(),'database':'database/madrasa.db'}));
    archive.addFile(ArchiveFile('manifest.json',manifest.length,manifest));
    for(final dirName in ['database','photos','documents','reports','exports']){
      final dir=Directory(p.join(AppPaths.root.path,dirName));
      if(!await dir.exists())continue;
      await for(final entity in dir.list(recursive:true,followLinks:false)){
        if(entity is! File)continue;
        final relative=p.relative(entity.path,from:AppPaths.root.path).replaceAll('\\','/');
        final bytes=await entity.readAsBytes();
        archive.addFile(ArchiveFile(relative,bytes.length,bytes));
      }
    }
    final encoded=ZipEncoder().encode(archive);
    if(encoded==null||encoded.isEmpty)throw StateError('ব্যাকআপ ফাইল তৈরি হয়নি।');
    final out=File(target);await out.parent.create(recursive:true);await out.writeAsBytes(encoded,flush:true);
    return out.path;
  }

  static Future<String?> pickBackupFile() async {
    final file=await openFile(acceptedTypeGroups:[const XTypeGroup(label:'ZIP backup',extensions:['zip'])]);
    return file?.path;
  }

  static Future<void> restoreBackup(String backupPath) async {
    final backup=File(backupPath);if(!await backup.exists())throw const FileSystemException('ব্যাকআপ ফাইল পাওয়া যায়নি।');
    final decoder=ZipDecoder();final archive=decoder.decodeBytes(await backup.readAsBytes());
    final files=<String,ArchiveFile>{};
    for(final entry in archive){
      final clean=entry.name.replaceAll('\\','/');
      if(entry.isSymbolicLink||p.isAbsolute(clean)||clean.split('/').contains('..'))throw const FormatException('Backup-এর মধ্যে নিরাপদ নয় এমন path আছে।');
      files[clean]=entry;
    }
    final manifestFile=files['manifest.json'];final dbEntry=files['database/madrasa.db'];
    if(manifestFile==null||dbEntry==null)throw const FormatException('এটি Sreerampur Madrasah-এর পূর্ণাঙ্গ backup নয়।');
    final manifestBytes=manifestFile.readBytes();if(manifestBytes==null)throw const FormatException('Backup manifest পড়া যায়নি।');
    final manifest=jsonDecode(utf8.decode(manifestBytes));
    if(manifest is! Map||manifest['app']!='sreerampur-madrasah-desktop'||manifest['backupVersion']!=1)throw const FormatException('Backup format বা version মেলে না।');

    final suffix='${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1<<20)}';
    final stage=Directory(p.join(AppPaths.root.path,'.restore-$suffix'));
    final rollback=Directory(p.join(AppPaths.root.path,'.restore-previous-$suffix'));
    await stage.create(recursive:true);await rollback.create(recursive:true);
    final movedOld=<String>[];final installedNew=<String>[];
    try{
      for(final entry in files.entries){
        if(!entry.value.isFile||entry.key=='manifest.json')continue;
        final out=File(p.join(stage.path,p.fromUri(Uri(path:entry.key))));
        final bytes=entry.value.readBytes();if(bytes==null)throw FormatException('Backup-এর ${entry.key} ফাইল পড়া যায়নি।');
        await out.parent.create(recursive:true);await out.writeAsBytes(bytes,flush:true);
      }
      final stagedDb=File(p.join(stage.path,'database','madrasa.db'));
      final validation=await databaseFactoryFfi.openDatabase(stagedDb.path);
      try{
        final integrity=await validation.rawQuery('PRAGMA integrity_check');
        if(integrity.isEmpty||integrity.first.values.first!='ok')throw const FormatException('Backup database নষ্ট বা অসম্পূর্ণ।');
        final tables=await validation.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        final names=tables.map((r)=>r['name']).toSet();
        if(!names.containsAll(['students','teachers','classes','settings','fees']))throw const FormatException('Backup-এ প্রয়োজনীয় Madrasa table নেই।');
      }finally{await validation.close();}

      // Before replacing anything, write a separate timestamped safety archive.
      await createBackup();
      await MadrasaDatabase.close();
      for(final dirName in ['database','photos','documents','reports','exports']){
        final incoming=Directory(p.join(stage.path,dirName));
        if(!await incoming.exists())continue;
        final output=Directory(p.join(AppPaths.root.path,dirName));
        final old=Directory(p.join(rollback.path,dirName));
        if(await output.exists()){await output.rename(old.path);movedOld.add(dirName);}
        await incoming.rename(output.path);installedNew.add(dirName);
      }
      await AppPaths.ensureStructure();await MadrasaDatabase.open();await MadrasaDatabase.checkIntegrity();
    }catch(_){
      try{
        await MadrasaDatabase.close();
        for(final dirName in installedNew.reversed){final current=Directory(p.join(AppPaths.root.path,dirName));if(await current.exists())await current.rename(p.join(stage.path,'failed-$dirName'));}
        for(final dirName in movedOld.reversed){final old=Directory(p.join(rollback.path,dirName));if(await old.exists())await old.rename(p.join(AppPaths.root.path,dirName));}
        await AppPaths.ensureStructure();await MadrasaDatabase.open();
      }catch(__){}
      rethrow;
    }finally{if(await stage.exists())await stage.delete(recursive:true);if(await rollback.exists())await rollback.delete(recursive:true);}
  }

  static Future<void> changeDataFolder(String newPath) async {
    final target=Directory(newPath).absolute;
    final previousRoot=AppPaths.dataRoot!;
    if(p.normalize(target.path).toLowerCase()==p.normalize(AppPaths.root.absolute.path).toLowerCase())return;
    final previousNormalized=p.normalize(Directory(previousRoot).absolute.path).toLowerCase();
    final targetNormalized=p.normalize(target.path).toLowerCase();
    if(targetNormalized.startsWith('$previousNormalized${p.separator}'))throw StateError('বর্তমান Data Folder-এর ভেতরের কোনো subfolder নির্বাচন করা যাবে না।');
    await target.create(recursive:true);
    final targetDb=File(p.join(target.path,'database','madrasa.db'));
    if(await targetDb.exists())throw StateError('নতুন folder-এ madrasa.db আছে। তথ্য overwrite এড়াতে খালি folder নির্বাচন করুন।');
    await createBackup();
    await MadrasaDatabase.close();
    try{
      for(final name in ['database','photos','documents','backups','reports','exports']){
        final source=Directory(p.join(AppPaths.root.path,name));final dest=Directory(p.join(target.path,name));
        if(await source.exists())await _copyDirectory(source,dest);
      }
      await AppPaths.saveDataRoot(target.path);await AppPaths.ensureStructure();await MadrasaDatabase.open();await MadrasaDatabase.checkIntegrity();
    }catch(_){
      await MadrasaDatabase.close();
      await AppPaths.saveDataRoot(previousRoot);
      try{await MadrasaDatabase.open();}catch(__){}
      rethrow;
    }
  }

  static Future<void> _copyDirectory(Directory source,Directory target) async {
    await target.create(recursive:true);
    await for(final entity in source.list(recursive:true,followLinks:false)){
      final relative=p.relative(entity.path,from:source.path),path=p.join(target.path,relative);
      if(entity is Directory){await Directory(path).create(recursive:true);}else if(entity is File){
        if(await File(path).exists())throw FileSystemException('Data copy conflict—file already exists.',path);
        await File(path).parent.create(recursive:true);await entity.copy(path);
      }
    }
  }
}
