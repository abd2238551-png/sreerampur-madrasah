import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_paths.dart';
import 'madrasa_database.dart';

class MadrasaRepository {
  Database get _db => MadrasaDatabase.instance;
  final _passwordKdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 180000, bits: 256);

  Future<bool> hasLocalAccount() async => Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM local_users')) != 0;

  Future<void> createOwner(String username, String password) async {
    final name = username.trim();
    if (name.length < 3) throw const FormatException('ব্যবহারকারীর নাম অন্তত ৩ অক্ষরের হতে হবে।');
    if (password.length < 10) throw const FormatException('নিরাপদ পাসওয়ার্ড অন্তত ১০ অক্ষরের দিন।');
    if (await hasLocalAccount()) throw StateError('প্রথম administrator account ইতিমধ্যে তৈরি হয়েছে।');
    final salt = _randomBytes(16);
    final hash = await _hashPassword(password, salt);
    await _db.insert('local_users', {
      'username': name, 'password_hash': base64UrlEncode(hash),
      'salt': base64UrlEncode(salt), 'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<bool> verifyLogin(String username, String password) async {
    final users = await _db.query('local_users', where: 'username = ?', whereArgs: [username.trim()], limit: 1);
    if (users.isEmpty) return false;
    final row = users.first;
    final salt = base64Url.decode(row['salt']! as String);
    final expected = base64Url.decode(row['password_hash']! as String);
    final actual = await _hashPassword(password, salt);
    if (expected.length != actual.length) return false;
    var diff = 0;
    for (var i=0;i<expected.length;i++) { diff |= expected[i] ^ actual[i]; }
    return diff == 0;
  }

  Future<List<Map<String,Object?>>> list(ModuleSpec module, {String search='', int page=0, int pageSize=50}) async {
    final terms = search.trim().toLowerCase();
    String? where;
    List<Object?>? args;
    if (terms.isNotEmpty) {
      where = module.columns.map((c) => 'CAST("$c" AS TEXT) LIKE ?').join(' OR ');
      args = List<Object?>.filled(module.columns.length, '%$terms%');
    }
    return _db.query(module.table, where: where, whereArgs: args,
      orderBy: module.columns.first, limit: pageSize, offset: page*pageSize);
  }

  Future<int> count(ModuleSpec module, {String search=''}) async {
    final terms=search.trim().toLowerCase();
    if(terms.isEmpty)return Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM "${module.table}"'))??0;
    final where=module.columns.map((c)=>'CAST("$c" AS TEXT) LIKE ?').join(' OR ');
    return Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM "${module.table}" WHERE $where',List<Object?>.filled(module.columns.length,'%$terms%')))??0;
  }

  Future<void> save(ModuleSpec module, Map<String,Object?> record, {String? id}) async {
    final data=<String,Object?>{};
    for(final field in module.fields){
      var value=record[field.key];
      if(value is String && value.trim().isEmpty)value=null;
      if(field.required && (value==null || value.toString().trim().isEmpty))throw FormatException('${field.label} লিখুন।');
      if(field.type=='number' && value!=null){value=double.tryParse(value.toString());if(value==null)throw FormatException('${field.label} সঠিক সংখ্যা নয়।');}
      data[field.key]=value;
    }
    switch(module.table){
      case 'classes':data['sort_order']??=0;break;
      case 'students':data['status']??='সক্রিয়';break;
      case 'teachers':data['status']??='সক্রিয়';data['salary']??=0;break;
      case 'staff':data['status']??='সক্রিয়';data['salary']??=0;break;
      case 'fees':data['discount']??=0;break;
      case 'books':data['total']??=0;data['available']??=data['total'];data['status']??='সক্রিয়';break;
      case 'library_transactions':data['status']??=data['return_date']==null?'ইস্যু':'ফেরত';break;
    }
    if(module.table=='library_transactions'){
      await _db.transaction((txn)async{
        Map<String,Object?>? previous;
        if(id!=null){final rows=await txn.query(module.table,where:'id = ?',whereArgs:[id],limit:1);if(rows.isEmpty)throw StateError('রেকর্ডটি আর পাওয়া যাচ্ছে না।');previous=rows.first;}
        final oldOpen=previous!=null&&previous['return_date']==null;
        final newOpen=data['return_date']==null;
        if(oldOpen){await txn.rawUpdate('UPDATE books SET available=available+1 WHERE id=?',[previous['book_id']]);}
        if(newOpen){final changed=await txn.rawUpdate('UPDATE books SET available=available-1 WHERE id=? AND available>0',[data['book_id']]);if(changed!=1)throw StateError('বইটির কপি পাওয়া যাচ্ছে না।');}
        if(id==null){data['id']=_newId();await txn.insert(module.table,data);}else{await txn.update(module.table,data,where:'id = ?',whereArgs:[id]);}
      });
      return;
    }
    if(id==null){data['id']=_newId();await _db.insert(module.table,data,conflictAlgorithm:ConflictAlgorithm.abort);}
    else {final changed=await _db.update(module.table,data,where:'id = ?',whereArgs:[id]);if(changed!=1)throw StateError('রেকর্ডটি আর পাওয়া যাচ্ছে না।');}
  }

  Future<void> delete(ModuleSpec module,String id) async {
    if(module.table=='library_transactions'){
      await _db.transaction((txn)async{final rows=await txn.query(module.table,where:'id = ?',whereArgs:[id],limit:1);if(rows.isEmpty)throw StateError('রেকর্ডটি আর পাওয়া যাচ্ছে না।');final r=rows.first;if(r['return_date']==null)await txn.rawUpdate('UPDATE books SET available=available+1 WHERE id=?',[r['book_id']]);await txn.delete(module.table,where:'id = ?',whereArgs:[id]);});
      return;
    }
    final changed=await _db.delete(module.table,where:'id = ?',whereArgs:[id]);
    if(changed!=1)throw StateError('রেকর্ডটি আর পাওয়া যাচ্ছে না।');
  }

  Future<int> markClassPresent(String classId,String date) async {
    return _db.transaction((txn)async{
      final students=await txn.query('students',columns:['id'],where:'class_id = ? AND status = ?',whereArgs:[classId,'সক্রিয়']);
      for(final student in students){await txn.insert('attendance',{'id':_newId(),'date':date,'class_id':classId,'student_id':student['id'],'status':'উপস্থিত'},conflictAlgorithm:ConflictAlgorithm.replace);}
      return students.length;
    });
  }

  Future<Map<String,String>> settings() async {
    final rows=await _db.query('settings');
    return {for(final row in rows) row['key']! as String:row['value']! as String};
  }

  Future<void> saveSettings(Map<String,String> values) async {
    await _db.transaction((txn) async {
      for(final entry in values.entries){await txn.insert('settings',{'key':entry.key,'value':entry.value},conflictAlgorithm:ConflictAlgorithm.replace);}
    });
  }

  Future<int> tableCount(String table) async {
    if(!{'students','teachers','staff','classes','subjects','attendance','teacher_attendance','staff_attendance','exams','marks','fees','homework','notices','books','library_transactions','expenses','income','accounts'}.contains(table))throw ArgumentError('Invalid table.');
    return Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM "$table"'))??0;
  }

  Future<List<Map<String,Object?>>> allForBackup(String table) async {
    if(!{'settings','academic_years','classes','students','teachers','staff','subjects','attendance','teacher_attendance','staff_attendance','exams','marks','fees','homework','notices','books','library_transactions','expenses','income','accounts'}.contains(table))throw ArgumentError('Invalid table.');
    return _db.query(table);
  }

  Future<void> importLegacyJson(Map<String,Object?> pack) async {
    final raw=pack['data'];
    if(raw is! Map)throw const FormatException('JSON backup-এর data অংশ পাওয়া যায়নি।');
    const importTables=['classes','teachers','staff','students','subjects','exams','books','attendance','teacher_attendance','staff_attendance','marks','fees','homework','notices','library_transactions','expenses','income','accounts'];
    const aliases=<String,String>{
      'student_id':'studentId','admission_no':'admissionNo','arabic_name':'arabicName','father_name':'fatherName','mother_name':'motherName','birth_date':'birthDate','class_id':'classId','guardian_phone':'guardianPhone','admission_date':'admissionDate','blood_group':'bloodGroup','previous_school':'previousSchool','photo_path':'photo',
      'teacher_id':'teacherId','staff_id':'staffId','join_date':'joinDate','subject_ids':'subjectIds','full_marks':'fullMarks','pass_marks':'passMarks','start_date':'startDate','end_date':'endDate','exam_id':'examId','subject_id':'subjectId','receipt_no':'receiptNo','return_date':'returnDate','issue_date':'issueDate','due_date':'dueDate','paid_by':'paidBy','account_name':'accountName','entry_type':'entryType','sort_order':'sortOrder','book_id':'bookId',
      'name':'name','title':'title','type':'type','phone':'phone','email':'email','address':'address','roll':'roll','section':'section','gender':'gender','qualification':'qualification','designation':'designation','salary':'salary','isbn':'isbn','author':'author','total':'total','available':'available','shelf':'shelf','marks':'marks','grade':'grade','gpa':'gpa','discount':'discount','receiver':'receiver','comment':'comment','source':'source','amount':'amount','reference':'reference','note':'note','id':'id','code':'code','active':'active','publisher':'publisher','details':'details','description':'description','priority':'priority','method':'method','category':'category','date':'date','year':'year','status':'status'
    };
    final settings=raw['settings'];
    await _db.transaction((txn) async {
      var imported=0;
      final classIdRemap=<String,String>{};
      final legacyClasses=raw['classes'];
      if(legacyClasses is List){for(final item in legacyClasses){if(item is! Map)continue;final old=Map<String,Object?>.from(item.cast<String,Object?>());final name=(old['name']??'').toString().trim();if(name.isEmpty)continue;final oldId=(old['id']??_newId()).toString();final existing=await txn.query('classes',where:'name = ?',whereArgs:[name],limit:1);if(existing.isNotEmpty){classIdRemap[oldId]=existing.first['id'].toString();continue;}try{await txn.insert('classes',{'id':oldId,'name':name,'sort_order':old['sortOrder']??old['sort_order']??0,'active':old['active']??1},conflictAlgorithm:ConflictAlgorithm.ignore);final inserted=await txn.query('classes',where:'id = ?',whereArgs:[oldId],limit:1);if(inserted.isNotEmpty)classIdRemap[oldId]=oldId;imported++;}on DatabaseException{}}}
      for(final table in importTables){
        if(table=='classes')continue;
        final rows=raw[table];if(rows is! List)continue;
        for(final item in rows){
          if(item is! Map)continue;
          final old=Map<String,Object?>.from(item.cast<String,Object?>());
          final row=<String,Object?>{'id':(old['id']??_newId()).toString()};
          for(final mapping in aliases.entries){final value=old[mapping.value];if(value!=null&&mapping.key!='id')row[mapping.key]=value;}
          for(final key in aliases.keys){if(old.containsKey(key)&&key!='id')row.putIfAbsent(key,()=>old[key]);}
          if(row['class_id']!=null)row['class_id']=classIdRemap[row['class_id'].toString()]??row['class_id'];
          if(table=='students'&&row['class_id']==null){final fallback=await txn.query('classes',limit:1,orderBy:'sort_order');if(fallback.isNotEmpty)row['class_id']=fallback.first['id'];}
          if(table=='students')row['roll']=(row['roll']??'').toString();
          if({'students','teachers','staff'}.contains(table)&&row['photo_path'] is String)row['photo_path']=await _importLegacyPhoto(row['photo_path'] as String,table,(row['id']??_newId()).toString());
          if(table=='books'){row['total']??=0;row['available']??=row['total'];}
          if(table=='fees')row['discount']??=0;
          if(table=='teachers'||table=='staff')row['salary']??=0;
          try{await txn.insert(table,row,conflictAlgorithm:ConflictAlgorithm.ignore);imported++;}on DatabaseException{/* Duplicate or broken legacy references are skipped; valid rows continue. */}
        }
      }
      if(settings is Map){
        const settingMap={'name':'school_name','address':'school_address','phone':'school_phone','email':'school_email','headmaster':'head_name','year':'academic_year','logo':'logo_path'};
        for(final entry in settingMap.entries){var value=settings[entry.key];if(entry.key=='logo'&&value is String&&value.startsWith('data:image/'))value=await _importLegacyPhoto(value,'logo','madrasa-logo');if(value!=null&&value.toString().trim().isNotEmpty){await txn.insert('settings',{'key':entry.value,'value':value.toString()},conflictAlgorithm:ConflictAlgorithm.replace);}}
      }
      if(imported==0)throw const FormatException('কোনো বৈধ legacy record পাওয়া যায়নি। JSON backup-এর data পরীক্ষা করুন।');
    });
  }

  Future<String?> _importLegacyPhoto(String value,String kind,String id) async {
    final match=RegExp(r'^data:image/(png|jpeg|jpg|webp);base64,(.+)$',caseSensitive:false,dotAll:true).firstMatch(value);
    if(match==null)return null;
    final extension=match.group(1)!.toLowerCase()=='jpeg'?'.jpg':'.${match.group(1)!.toLowerCase()}';
    final folder=kind=='students'?'students':kind=='logo'?'':'staff';
    final relative=folder.isEmpty?'photos/$id$extension':'photos/$folder/${id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'),'_')}$extension';
    final file=File(p.join(AppPaths.root.path,relative));
    await file.parent.create(recursive:true);
    await file.writeAsBytes(base64.decode(match.group(2)!),flush:true);
    return relative;
  }

  Future<Uint8List> _hashPassword(String password,List<int> salt) async {
    final key=await _passwordKdf.deriveKey(secretKey:SecretKey(utf8.encode(password)),nonce:salt);
    return Uint8List.fromList(await key.extractBytes());
  }

  List<int> _randomBytes(int n){final r=Random.secure();return List<int>.generate(n,(_)=>r.nextInt(256));}
  String _newId(){final r=Random.secure();return List<int>.generate(16,(_)=>r.nextInt(256)).map((x)=>x.toRadixString(16).padLeft(2,'0')).join();}
}
