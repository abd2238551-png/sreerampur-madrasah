import 'dart:convert';
import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../core/app_paths.dart';
import 'madrasa_repository.dart';

const appwriteEndpoint = 'https://fra.cloud.appwrite.io/v1';
const appwriteProjectId = '6ad01c2400399eaf6362';
const appwriteDatabaseId = '6ad01db200392a309d8c';
const appwriteTableId = '6ad01dd0002c91ff7e69';

class SyncConflict {
  const SyncConflict({required this.key, required this.collection, required this.id,
    required this.local, required this.cloud});
  final String key, collection, id;
  final Map<String, Object?>? local, cloud;
}

class SyncReport {
  const SyncReport({required this.records, required this.pushed, required this.pulled,
    required this.conflictsResolved});
  final int records, pushed, pulled, conflictsResolved;
}

/// Authenticated, owner-scoped Appwrite synchronization for the Windows app.
/// This client never uses a server API key.
class AppwriteCloudSync {
  AppwriteCloudSync._();
  static final AppwriteCloudSync instance = AppwriteCloudSync._();
  final Client client = Client().setEndpoint(appwriteEndpoint).setProject(appwriteProjectId);
  late final Account account = Account(client);
  late final TablesDB tables = TablesDB(client);

  Future<dynamic> currentUser() async => account.get();

  Future<void> signIn(String email, String password) async {
    await account.createEmailPasswordSession(email: email.trim(), password: password);
  }

  Future<void> createAccount(String email, String password) async {
    final normalized = email.trim();
    await account.create(userId: ID.unique(), email: normalized, password: password,
      name: normalized.split('@').first);
    await signIn(normalized, password);
  }

  Future<void> signOut() async {
    try { await account.deleteSession(sessionId: 'current'); } catch (_) {}
  }

  Future<SyncReport> synchronize(MadrasaRepository repository,
      Future<String?> Function(SyncConflict conflict) chooseConflict) async {
    final user = await account.get();
    final userId = user.$id;
    final local = await _readLocal(repository);
    final cloud = await _readCloud(userId);
    final settings = await repository.settings();
    final baselineKey = '_cloud_sync_baseline_$userId';
    Map<String, dynamic> baseline = {};
    try {
      final raw = settings[baselineKey];
      if (raw != null) baseline = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {}

    final keys = <String>{...local.keys, ...cloud.keys, ...baseline.keys};
    final finalRows = <String, _SyncRecord>{};
    final conflicts = <SyncConflict>[];
    for (final key in keys) {
      final l = local[key];
      final r = cloud[key];
      final b = baseline[key] is Map ? Map<String, dynamic>.from(baseline[key] as Map) : null;
      final localState = l == null ? null : {'deleted': l.deleted, 'value': l.deleted ? null : l.value};
      final cloudState = r == null ? null : {'deleted': r.deleted, 'value': r.deleted ? null : r.value};
      final baseState = b == null ? null : {'deleted': b['deleted'] == true, 'value': b['deleted'] == true ? null : b['value']};
      final localChanged = !_same(localState, baseState);
      final cloudChanged = !_same(cloudState, baseState);
      final meta = l ?? r ?? (b == null ? null : _SyncRecord(collection: '${b['collection']}', id: '${b['id']}', value: null, deleted: true));
      if (meta == null) continue;
      if (localChanged && cloudChanged && !_same(localState, cloudState)) {
        conflicts.add(SyncConflict(key: key, collection: meta.collection, id: meta.id,
          local: l?.value, cloud: r?.value));
      } else {
        final chosen = localChanged ? l : cloudChanged ? r : (b == null ? l : _SyncRecord(
          collection: meta.collection, id: meta.id, value: b['value'] is Map ? Map<String, Object?>.from(b['value'] as Map) : null, deleted: b['deleted'] == true));
        final value = chosen ?? _SyncRecord(collection: meta.collection, id: meta.id, value: null, deleted: true);
        finalRows[key] = _SyncRecord(collection: meta.collection, id: meta.id,
          value: value.value, deleted: value.deleted, rowId: value.rowId ?? r?.rowId);
      }
    }

    final choices = <String, String>{};
    for (final conflict in conflicts) {
      final selected = await chooseConflict(conflict);
      if (selected == null) throw const _SyncCancelled();
      choices[conflict.key] = selected;
      final picked = (selected == 'local' ? local[conflict.key] : cloud[conflict.key]) ??
        _SyncRecord(collection: conflict.collection, id: conflict.id, value: null, deleted: true);
      finalRows[conflict.key] = _SyncRecord(collection: conflict.collection, id: conflict.id,
        value: picked.value, deleted: picked.deleted, rowId: cloud[conflict.key]?.rowId);
    }

    final latestLocal = await _readLocal(repository);
    if (local.length != latestLocal.length || local.entries.any((entry) =>
        !_same({'deleted': entry.value.deleted, 'value': entry.value.deleted ? null : entry.value.value},
          latestLocal[entry.key] == null ? null : {'deleted': latestLocal[entry.key]!.deleted,
            'value': latestLocal[entry.key]!.deleted ? null : latestLocal[entry.key]!.value}))) {
      throw StateError('Sync প্রস্তুত করার পর local data বদলেছে। কিছু লেখা হয়নি; আবার sync করুন।');
    }

    final nextBaseline = <String, dynamic>{};
    var pushed = 0, pulled = 0;
    final cloudChanges = <MapEntry<String, _SyncRecord>>[];
    for (final entry in finalRows.entries) {
      final selected = entry.value;
      nextBaseline[entry.key] = {'collection': selected.collection, 'id': selected.id,
        'deleted': selected.deleted, 'value': selected.value};
      final remote = cloud[entry.key];
      if (remote == null || !_same({'deleted': remote.deleted, 'value': remote.deleted ? null : remote.value},
          {'deleted': selected.deleted, 'value': selected.deleted ? null : selected.value})) {
        cloudChanges.add(entry);
        pushed++;
      }
      final before = local[entry.key];
      if (before == null || !_same({'deleted': before.deleted, 'value': before.deleted ? null : before.value},
          {'deleted': selected.deleted, 'value': selected.deleted ? null : selected.value})) pulled++;
    }

    await _writeCloudBatches(userId, cloud, cloudChanges);
    await repository.applyCloudRecords(finalRows.values.map((record)=>{
      'collection':record.collection,'id':record.id,'value':record.value,'deleted':record.deleted,
    }).toList());
    await repository.saveSettings({baselineKey: jsonEncode(nextBaseline)});
    return SyncReport(records: finalRows.length, pushed: pushed, pulled: pulled, conflictsResolved: choices.length);
  }

  Future<Map<String, _SyncRecord>> _readLocal(MadrasaRepository repository) async {
    final out = <String, _SyncRecord>{};
    const collections = ['academic_years','classes','students','teachers','staff','subjects','attendance',
      'teacher_attendance','staff_attendance','exams','marks','fees','homework','notices','books',
      'library_transactions','expenses','income','accounts'];
    for (final collection in collections) {
      for (final raw in await repository.allForBackup(collection)) {
        final value = Map<String, Object?>.from(raw);
        final id = '${value['id'] ?? ''}';
        if (id.isEmpty) continue;
        value.remove('created_at');
        value.remove('sort_order');
        if (value['active'] == 1) value.remove('active');
        await _encodePhoto(value, collection);
        value.removeWhere((key, item) => item == null || item == '');
        final key = _key(collection, id);
        out[key] = _SyncRecord(collection: collection, id: id, value: value, deleted: false);
      }
    }
    final values = await repository.settings();
    values.removeWhere((key, _) => key == 'schema_version' || key.startsWith('_cloud_sync_baseline_'));
    if (values.containsKey('school_name') || values.length > 1) {
      const settingAliases = {'school_name':'school_name','school_address':'school_address','school_phone':'school_phone',
        'school_email':'school_email','head_name':'head_name','academic_year':'academic_year','currency':'currency'};
      final canonical = <String, Object?>{'id':'_settings','school_name':'Sreerampur Madrasah',
        'school_address':'','school_phone':'','school_email':'','head_name':'','academic_year':'','currency':'৳','logo_data':''};
      for (final entry in settingAliases.entries) {
        if (values.containsKey(entry.key)) canonical[entry.key] = values[entry.key] ?? canonical[entry.key];
      }
      final logo = values['logo_path'];
      if (logo != null && logo.isNotEmpty) {
        final path = p.isAbsolute(logo) ? logo : p.join(AppPaths.root.path, logo);
        final file = File(path);
        if (await file.exists()) {
          final extension = p.extension(path).toLowerCase();
          final mime = extension == '.png' ? 'image/png' : extension == '.webp' ? 'image/webp' : 'image/jpeg';
          canonical['logo_data'] = 'data:$mime;base64,${base64Encode(await file.readAsBytes())}';
        } else { throw StateError('সেটিংসে থাকা লোগো ফাইলটি পাওয়া যায়নি; sync বন্ধ রাখা হয়েছে যাতে লোগো হারিয়ে না যায়।'); }
      }
      out[_key('settings','_settings')] = _SyncRecord(collection:'settings',id:'_settings',value:canonical,deleted:false);
    }
    return out;
  }

  Future<void> _encodePhoto(Map<String, Object?> row, String collection) async {
    final pathValue = row.remove('photo_path');
    if (pathValue is! String || pathValue.isEmpty) return;
    final path = p.isAbsolute(pathValue) ? pathValue : p.join(AppPaths.root.path, pathValue);
    final file = File(path);
    if (!await file.exists()) throw StateError('একটি ছবির ফাইল পাওয়া যায়নি; sync বন্ধ রাখা হয়েছে যাতে ছবিটি হারিয়ে না যায়।');
    final ext = p.extension(path).toLowerCase();
    final mime = ext == '.png' ? 'image/png' : ext == '.webp' ? 'image/webp' : 'image/jpeg';
    row['photo_data'] = 'data:$mime;base64,${base64Encode(await file.readAsBytes())}';
  }

  Future<Map<String, _SyncRecord>> _readCloud(String userId) async {
    final out = <String, _SyncRecord>{};
    var offset = 0;
    while (true) {
      final page = await tables.listRows(databaseId: appwriteDatabaseId, tableId: appwriteTableId,
        queries: [Query.equal('owner_id',[userId]), Query.limit(100), Query.offset(offset)]);
      for (final row in page.rows) {
        final collection = row.data['collection']?.toString() ?? '';
        final id = row.data['record_id']?.toString() ?? '';
        if (collection.isEmpty || id.isEmpty) continue;
        Map<String,Object?> value = {};
        try { value = Map<String,Object?>.from(jsonDecode(row.data['payload']?.toString() ?? '{}') as Map); }
        catch (_) { throw StateError('Appwrite record-এর JSON পড়া যাচ্ছে না; কোনো তথ্য বদলানো হয়নি।'); }
        final record = _SyncRecord(collection: collection, id: id, value: value,
          deleted: row.data['is_deleted'] == true, rowId: row.$id);
        out[_key(collection,id)] = record;
      }
      if (page.rows.length < 100) break;
      offset += page.rows.length;
    }
    return out;
  }

  Future<void> _writeCloudBatches(String userId, Map<String, _SyncRecord> cloud,
      List<MapEntry<String, _SyncRecord>> changes) async {
    for (var start = 0; start < changes.length; start += 100) {
      final batch = changes.skip(start).take(100).toList();
      final fresh = await _readCloud(userId);
      for (final entry in batch) {
        final before = cloud[entry.key], now = fresh[entry.key];
        if (!_same(before == null ? null : {'deleted': before.deleted, 'value': before.deleted ? null : before.value},
            now == null ? null : {'deleted': now.deleted, 'value': now.deleted ? null : now.value})) {
          throw StateError('Sync চলার সময় cloud data বদলেছে। local data লেখা হয়নি; আবার sync করে conflict দেখুন।');
        }
      }
      final tx = await tables.createTransaction();
      try {
        for (final entry in batch) {
          final record = entry.value;
          final rowId = record.rowId ?? await _stableRowId('$userId\u0000${record.collection}\u0000${record.id}');
          final data = {'owner_id':userId,'collection':record.collection,'record_id':record.id,
            'payload':jsonEncode(record.value ?? {}),'updated_at':DateTime.now().toUtc().toIso8601String(),
            'is_deleted':record.deleted};
          if (cloud[entry.key] != null) {
            await tables.updateRow(databaseId:appwriteDatabaseId,tableId:appwriteTableId,rowId:rowId,
              data:data,transactionId:tx.$id);
          } else {
            await tables.createRow(databaseId:appwriteDatabaseId,tableId:appwriteTableId,rowId:rowId,
              data:data,transactionId:tx.$id,permissions:[Permission.read(Role.user(userId)),
                Permission.update(Role.user(userId)),Permission.delete(Role.user(userId))]);
          }
        }
        await tables.updateTransaction(transactionId:tx.$id,commit:true);
      } catch (error) {
        try { await tables.updateTransaction(transactionId:tx.$id,rollback:true); } catch (_) {}
        if (error is AppwriteException && (error.code == 409 || error.code == 412)) {
          throw StateError('Cloud data একই সময়ে বদলে গেছে। local data লেখা হয়নি; আবার sync করে conflict দেখুন।');
        }
        rethrow;
      }
    }
  }

  static String _key(String collection,String id)=>'$collection\u0000$id';
  static dynamic _sort(dynamic value) {
    if (value is Map) { final keys=value.keys.map((e)=>e.toString()).toList()..sort(); return {for(final key in keys)key:_sort(value[key])}; }
    if (value is List) return value.map(_sort).toList();
    return value;
  }
  static bool _same(dynamic a,dynamic b)=>jsonEncode(_sort(a))==jsonEncode(_sort(b));
  static Future<String> _stableRowId(String value) async {
    final digest = await Sha256().hash(utf8.encode(value));
    return digest.bytes.map((x)=>x.toRadixString(16).padLeft(2,'0')).join().substring(0,36);
  }
}

class _SyncRecord {
  const _SyncRecord({required this.collection,required this.id,required this.value,required this.deleted,this.rowId});
  final String collection,id;
  final Map<String,Object?>? value;
  final bool deleted;
  final String? rowId;
}

class _SyncCancelled implements Exception { const _SyncCancelled(); }
