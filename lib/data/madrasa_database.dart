import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/app_paths.dart';

class FieldSpec {
  const FieldSpec(this.key, this.label, {this.type = 'text', this.required = false});
  final String key;
  final String label;
  final String type;
  final bool required;
}

class ModuleSpec {
  const ModuleSpec(this.key, this.title, this.table, this.fields, this.columns);
  final String key;
  final String title;
  final String table;
  final List<FieldSpec> fields;
  final List<String> columns;
}

const madrasaModules = <ModuleSpec>[
  ModuleSpec('students','শিক্ষার্থী','students',[
    FieldSpec('student_id','শিক্ষার্থী আইডি',required:true),FieldSpec('admission_no','ভর্তি নম্বর'),FieldSpec('name','শিক্ষার্থীর নাম',required:true),FieldSpec('arabic_name','আরবি নাম'),FieldSpec('father_name','পিতার নাম'),FieldSpec('mother_name','মাতার নাম'),FieldSpec('birth_date','জন্ম তারিখ',type:'date'),FieldSpec('gender','লিঙ্গ'),FieldSpec('class_id','শ্রেণি',type:'class',required:true),FieldSpec('section','শাখা'),FieldSpec('roll','রোল নম্বর',required:true),FieldSpec('phone','মোবাইল'),FieldSpec('guardian_phone','অভিভাবকের মোবাইল'),FieldSpec('address','ঠিকানা',type:'multiline'),FieldSpec('admission_date','ভর্তির তারিখ',type:'date'),FieldSpec('blood_group','রক্তের গ্রুপ'),FieldSpec('previous_school','পূর্বের প্রতিষ্ঠান'),FieldSpec('photo_path','ছবি',type:'photo'),FieldSpec('status','অবস্থা')
  ],['student_id','name','father_name','class_id','roll','phone','status']),
  ModuleSpec('teachers','শিক্ষক','teachers',[
    FieldSpec('teacher_id','শিক্ষক আইডি',required:true),FieldSpec('name','নাম',required:true),FieldSpec('arabic_name','আরবি নাম'),FieldSpec('father_name','পিতার নাম'),FieldSpec('phone','মোবাইল'),FieldSpec('email','ইমেইল'),FieldSpec('qualification','যোগ্যতা'),FieldSpec('designation','পদবি'),FieldSpec('subject_ids','বিষয়'),FieldSpec('join_date','যোগদানের তারিখ',type:'date'),FieldSpec('salary','বেতন',type:'number'),FieldSpec('address','ঠিকানা',type:'multiline'),FieldSpec('photo_path','ছবি',type:'photo'),FieldSpec('status','অবস্থা')
  ],['teacher_id','name','designation','phone','status']),
  ModuleSpec('staff','কর্মচারী','staff',[FieldSpec('staff_id','কর্মচারী আইডি',required:true),FieldSpec('name','নাম',required:true),FieldSpec('designation','পদবি',required:true),FieldSpec('phone','মোবাইল'),FieldSpec('join_date','যোগদানের তারিখ',type:'date'),FieldSpec('salary','বেতন',type:'number'),FieldSpec('address','ঠিকানা',type:'multiline'),FieldSpec('photo_path','ছবি',type:'photo'),FieldSpec('status','অবস্থা')],['staff_id','name','designation','phone','status']),
  ModuleSpec('classes','শ্রেণি','classes',[FieldSpec('name','শ্রেণির নাম',required:true),FieldSpec('sort_order','ক্রম',type:'number')],['name','sort_order']),
  ModuleSpec('subjects','বিষয়','subjects',[FieldSpec('name','বিষয়ের নাম',required:true),FieldSpec('arabic_name','আরবি নাম'),FieldSpec('code','বিষয় কোড'),FieldSpec('class_id','শ্রেণি',type:'class',required:true),FieldSpec('teacher_id','শিক্ষক',type:'teacher'),FieldSpec('full_marks','পূর্ণমান',type:'number',required:true),FieldSpec('pass_marks','পাস নম্বর',type:'number',required:true)],['name','code','class_id','teacher_id','full_marks']),
  ModuleSpec('attendance','শিক্ষার্থী উপস্থিতি','attendance',[FieldSpec('date','তারিখ',type:'date',required:true),FieldSpec('class_id','শ্রেণি',type:'class',required:true),FieldSpec('student_id','শিক্ষার্থী',type:'student',required:true),FieldSpec('status','উপস্থিতি',required:true),FieldSpec('note','মন্তব্য')],['date','class_id','student_id','status']),
  ModuleSpec('teacher_attendance','শিক্ষক উপস্থিতি','teacher_attendance',[FieldSpec('date','তারিখ',type:'date',required:true),FieldSpec('teacher_id','শিক্ষক',type:'teacher',required:true),FieldSpec('status','উপস্থিতি',required:true),FieldSpec('note','মন্তব্য')],['date','teacher_id','status']),
  ModuleSpec('staff_attendance','কর্মচারী উপস্থিতি','staff_attendance',[FieldSpec('date','তারিখ',type:'date',required:true),FieldSpec('staff_id','কর্মচারী',type:'staff',required:true),FieldSpec('status','উপস্থিতি',required:true),FieldSpec('note','মন্তব্য')],['date','staff_id','status']),
  ModuleSpec('exams','পরীক্ষা','exams',[FieldSpec('name','পরীক্ষার নাম',required:true),FieldSpec('type','পরীক্ষার ধরন'),FieldSpec('year','শিক্ষাবর্ষ',required:true),FieldSpec('class_id','শ্রেণি',type:'class',required:true),FieldSpec('start_date','শুরুর তারিখ',type:'date'),FieldSpec('end_date','শেষ তারিখ',type:'date'),FieldSpec('description','বিবরণ',type:'multiline')],['name','type','year','class_id','start_date']),
  ModuleSpec('marks','নম্বর ও ফলাফল','marks',[FieldSpec('exam_id','পরীক্ষা',type:'exam',required:true),FieldSpec('student_id','শিক্ষার্থী',type:'student',required:true),FieldSpec('subject_id','বিষয়',type:'subject',required:true),FieldSpec('marks','প্রাপ্ত নম্বর',type:'number',required:true),FieldSpec('grade','গ্রেড'),FieldSpec('gpa','GPA',type:'number')],['exam_id','student_id','subject_id','marks','grade','gpa']),
  ModuleSpec('fees','ফি ও রসিদ','fees',[FieldSpec('receipt_no','রসিদ নম্বর',required:true),FieldSpec('student_id','শিক্ষার্থী',type:'student',required:true),FieldSpec('category','ফি-এর ধরন',required:true),FieldSpec('total','মোট টাকা',type:'number',required:true),FieldSpec('discount','ছাড়',type:'number'),FieldSpec('paid','জমা',type:'number',required:true),FieldSpec('date','তারিখ',type:'date',required:true),FieldSpec('method','পেমেন্ট পদ্ধতি'),FieldSpec('receiver','গ্রহণকারী'),FieldSpec('comment','মন্তব্য',type:'multiline')],['receipt_no','student_id','category','total','discount','paid','date']),
  ModuleSpec('homework','হোমওয়ার্ক','homework',[FieldSpec('date','তারিখ',type:'date',required:true),FieldSpec('class_id','শ্রেণি',type:'class',required:true),FieldSpec('subject_id','বিষয়',type:'subject',required:true),FieldSpec('teacher_id','শিক্ষক',type:'teacher'),FieldSpec('title','শিরোনাম',required:true),FieldSpec('details','বিস্তারিত',type:'multiline'),FieldSpec('due_date','জমার তারিখ',type:'date')],['date','class_id','subject_id','title','due_date']),
  ModuleSpec('notices','নোটিশ','notices',[FieldSpec('title','শিরোনাম',required:true),FieldSpec('details','বিবরণ',type:'multiline',required:true),FieldSpec('date','তারিখ',type:'date',required:true),FieldSpec('publisher','প্রকাশকারী'),FieldSpec('priority','গুরুত্ব'),FieldSpec('class_id','শ্রেণি আইডি')],['title','date','publisher','priority','class_id']),
  ModuleSpec('books','লাইব্রেরির বই','books',[FieldSpec('book_id','বই আইডি',required:true),FieldSpec('isbn','ISBN'),FieldSpec('name','বইয়ের নাম',required:true),FieldSpec('author','লেখক'),FieldSpec('publisher','প্রকাশক'),FieldSpec('category','বিভাগ'),FieldSpec('total','মোট কপি',type:'number',required:true),FieldSpec('available','পাওয়া যাচ্ছে',type:'number'),FieldSpec('shelf','শেলফ'),FieldSpec('status','অবস্থা')],['book_id','name','author','total','available','shelf']),
  ModuleSpec('library_transactions','বই ইস্যু/ফেরত','library_transactions',[FieldSpec('book_id','বই',type:'book',required:true),FieldSpec('student_id','শিক্ষার্থী',type:'student',required:true),FieldSpec('issue_date','ইস্যুর তারিখ',type:'date',required:true),FieldSpec('due_date','ফেরতের তারিখ',type:'date'),FieldSpec('return_date','ফেরত নেওয়ার তারিখ',type:'date'),FieldSpec('status','অবস্থা')],['book_id','student_id','issue_date','due_date','return_date','status']),
  ModuleSpec('expenses','খরচ','expenses',[FieldSpec('date','তারিখ',type:'date',required:true),FieldSpec('category','বিভাগ',required:true),FieldSpec('description','বিবরণ',required:true),FieldSpec('amount','টাকার পরিমাণ',type:'number',required:true),FieldSpec('method','পেমেন্ট পদ্ধতি'),FieldSpec('paid_by','কে দিয়েছেন'),FieldSpec('comment','মন্তব্য',type:'multiline')],['date','category','description','amount','method','paid_by'])
  ,ModuleSpec('income','অন্যান্য আয়','income',[FieldSpec('date','তারিখ',type:'date',required:true),FieldSpec('source','আয়ের উৎস',required:true),FieldSpec('description','বিবরণ',required:true),FieldSpec('amount','টাকার পরিমাণ',type:'number',required:true),FieldSpec('method','পেমেন্ট পদ্ধতি'),FieldSpec('receipt_no','রসিদ নম্বর')],['date','source','description','amount','method','receipt_no'])
  ,ModuleSpec('accounts','হিসাবের খাতা','accounts',[FieldSpec('date','তারিখ',type:'date',required:true),FieldSpec('account_name','হিসাব/খাত',required:true),FieldSpec('entry_type','জমা বা খরচ',required:true),FieldSpec('description','বিবরণ',required:true),FieldSpec('amount','টাকার পরিমাণ',type:'number',required:true),FieldSpec('reference','রেফারেন্স')],['date','account_name','entry_type','description','amount','reference'])
];

class MadrasaDatabase {
  MadrasaDatabase._();
  static Database? _db;
  static Database get instance => _db ?? (throw StateError('Database is closed.'));

  static Future<void> open() async {
    if (_db != null) return;
    sqfliteFfiInit();
    _db = await databaseFactoryFfi.openDatabase(AppPaths.databaseFile.path,
      options: OpenDatabaseOptions(version: 1,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
          await db.execute('CREATE TABLE local_users (id INTEGER PRIMARY KEY, username TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL, salt TEXT NOT NULL, created_at TEXT NOT NULL)');
          await db.execute('CREATE TABLE academic_years (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, start_date TEXT, end_date TEXT, active INTEGER NOT NULL DEFAULT 0)');
          await db.execute('CREATE TABLE classes (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, sort_order INTEGER NOT NULL DEFAULT 0, active INTEGER NOT NULL DEFAULT 1, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
          await db.execute('CREATE TABLE students (id TEXT PRIMARY KEY, student_id TEXT NOT NULL UNIQUE, admission_no TEXT UNIQUE, name TEXT NOT NULL, arabic_name TEXT, father_name TEXT, mother_name TEXT, birth_date TEXT, gender TEXT, class_id TEXT NOT NULL REFERENCES classes(id) ON UPDATE CASCADE ON DELETE RESTRICT, section TEXT, roll TEXT NOT NULL, phone TEXT, guardian_phone TEXT, address TEXT, admission_date TEXT, blood_group TEXT, previous_school TEXT, photo_path TEXT, status TEXT NOT NULL DEFAULT \'সক্রিয়\', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
          await db.execute('CREATE INDEX idx_students_class_roll ON students(class_id, roll)');
          await db.execute('CREATE INDEX idx_students_name ON students(name)');
          await db.execute('CREATE TABLE teachers (id TEXT PRIMARY KEY, teacher_id TEXT NOT NULL UNIQUE, name TEXT NOT NULL, arabic_name TEXT, father_name TEXT, phone TEXT, email TEXT, qualification TEXT, designation TEXT, subject_ids TEXT, join_date TEXT, salary REAL NOT NULL DEFAULT 0, address TEXT, photo_path TEXT, status TEXT NOT NULL DEFAULT \'সক্রিয়\', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
          await db.execute('CREATE TABLE staff (id TEXT PRIMARY KEY, staff_id TEXT NOT NULL UNIQUE, name TEXT NOT NULL, designation TEXT NOT NULL, phone TEXT, join_date TEXT, salary REAL NOT NULL DEFAULT 0, address TEXT, photo_path TEXT, status TEXT NOT NULL DEFAULT \'সক্রিয়\')');
          await db.execute('CREATE TABLE subjects (id TEXT PRIMARY KEY, name TEXT NOT NULL, arabic_name TEXT, code TEXT, class_id TEXT NOT NULL REFERENCES classes(id) ON UPDATE CASCADE ON DELETE RESTRICT, teacher_id TEXT REFERENCES teachers(id) ON UPDATE CASCADE ON DELETE SET NULL, full_marks REAL NOT NULL, pass_marks REAL NOT NULL, UNIQUE(name,class_id))');
          await db.execute('CREATE TABLE attendance (id TEXT PRIMARY KEY, date TEXT NOT NULL, class_id TEXT NOT NULL REFERENCES classes(id) ON DELETE RESTRICT, student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE, status TEXT NOT NULL, note TEXT, UNIQUE(date,student_id))');
          await db.execute('CREATE INDEX idx_attendance_class_date ON attendance(class_id,date)');
          await db.execute('CREATE TABLE teacher_attendance (id TEXT PRIMARY KEY, date TEXT NOT NULL, teacher_id TEXT NOT NULL REFERENCES teachers(id) ON DELETE CASCADE, status TEXT NOT NULL, note TEXT, UNIQUE(date,teacher_id))');
          await db.execute('CREATE TABLE staff_attendance (id TEXT PRIMARY KEY, date TEXT NOT NULL, staff_id TEXT NOT NULL REFERENCES staff(id) ON DELETE CASCADE, status TEXT NOT NULL, note TEXT, UNIQUE(date,staff_id))');
          await db.execute('CREATE TABLE exams (id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT, year TEXT NOT NULL, class_id TEXT NOT NULL REFERENCES classes(id) ON DELETE RESTRICT, start_date TEXT, end_date TEXT, description TEXT)');
          await db.execute('CREATE TABLE marks (id TEXT PRIMARY KEY, exam_id TEXT NOT NULL REFERENCES exams(id) ON DELETE CASCADE, student_id TEXT NOT NULL REFERENCES students(id) ON DELETE CASCADE, subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT, marks REAL NOT NULL, grade TEXT, gpa REAL, UNIQUE(exam_id,student_id,subject_id))');
          await db.execute('CREATE INDEX idx_marks_exam_student ON marks(exam_id,student_id)');
          await db.execute('CREATE TABLE fees (id TEXT PRIMARY KEY, receipt_no TEXT NOT NULL UNIQUE, student_id TEXT NOT NULL REFERENCES students(id) ON DELETE RESTRICT, category TEXT NOT NULL, total REAL NOT NULL CHECK(total>=0), discount REAL NOT NULL DEFAULT 0 CHECK(discount>=0), paid REAL NOT NULL CHECK(paid>=0), date TEXT NOT NULL, method TEXT, receiver TEXT, comment TEXT, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
          await db.execute('CREATE INDEX idx_fees_student_date ON fees(student_id,date)');
          await db.execute('CREATE TABLE homework (id TEXT PRIMARY KEY, date TEXT NOT NULL, class_id TEXT NOT NULL REFERENCES classes(id) ON DELETE CASCADE, subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE RESTRICT, teacher_id TEXT REFERENCES teachers(id) ON DELETE SET NULL, title TEXT NOT NULL, details TEXT, due_date TEXT)');
          await db.execute('CREATE TABLE notices (id TEXT PRIMARY KEY, title TEXT NOT NULL, details TEXT NOT NULL, date TEXT NOT NULL, publisher TEXT, priority TEXT, class_id TEXT REFERENCES classes(id) ON DELETE SET NULL)');
          await db.execute('CREATE TABLE books (id TEXT PRIMARY KEY, book_id TEXT NOT NULL UNIQUE, isbn TEXT UNIQUE, name TEXT NOT NULL, author TEXT, publisher TEXT, category TEXT, total INTEGER NOT NULL DEFAULT 0 CHECK(total>=0), available INTEGER NOT NULL DEFAULT 0 CHECK(available>=0), shelf TEXT, status TEXT NOT NULL DEFAULT \'সক্রিয়\')');
          await db.execute('CREATE TABLE library_transactions (id TEXT PRIMARY KEY, book_id TEXT NOT NULL REFERENCES books(id) ON DELETE RESTRICT, student_id TEXT NOT NULL REFERENCES students(id) ON DELETE RESTRICT, issue_date TEXT NOT NULL, due_date TEXT, return_date TEXT, status TEXT NOT NULL DEFAULT \'ইস্যু\')');
          await db.execute('CREATE TABLE expenses (id TEXT PRIMARY KEY, date TEXT NOT NULL, category TEXT NOT NULL, description TEXT NOT NULL, amount REAL NOT NULL CHECK(amount>=0), method TEXT, paid_by TEXT, comment TEXT)');
          await db.execute('CREATE TABLE income (id TEXT PRIMARY KEY, date TEXT NOT NULL, source TEXT NOT NULL, description TEXT NOT NULL, amount REAL NOT NULL CHECK(amount>=0), method TEXT, receipt_no TEXT UNIQUE)');
          await db.execute('CREATE TABLE accounts (id TEXT PRIMARY KEY, date TEXT NOT NULL, account_name TEXT NOT NULL, entry_type TEXT NOT NULL CHECK(entry_type IN (\'জমা\',\'খরচ\')), description TEXT NOT NULL, amount REAL NOT NULL CHECK(amount>=0), reference TEXT)');
          await db.execute('CREATE INDEX idx_accounts_date ON accounts(date)');
          for (var i=0; i<initialClasses.length; i++) {
            await db.insert('classes', {'id':'class-${i+1}', 'name':initialClasses[i], 'sort_order':i});
          }
          await db.insert('settings', {'key':'schema_version','value':'1'});
          await db.insert('settings', {'key':'school_name','value':'Sreerampur Madrasah'});
          await db.insert('settings', {'key':'currency','value':'৳'});
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Add numbered migrations here; never delete/recreate user tables.
          if (oldVersion < 1) throw StateError('Unsupported database schema version.');
        },
      ),
    );
    await _db!.rawQuery('PRAGMA quick_check');
  }

  static const initialClasses = [
    'তাকমীল ফিল হাদিস','ফযিলত ২য় বর্ষ','ফযিলত ১ম বর্ষ','সানোবিয়্যাহ উলয়া ২য় বর্ষ','সানোবিয়্যাহ উলয়া ১ম বর্ষ','সানোবিয়্যাহ আম্মাহ ২য় বর্ষ','সানোবিয়্যাহ আম্মাহ ১ম বর্ষ','মুতাওয়াসসিতাহ ৩য় বর্ষ','মুতাওয়াসসিতাহ ২য় বর্ষ','ইবতিদায়ী ৫ম বর্ষ'
  ];

  static Future<void> close() async { await _db?.close(); _db = null; }

  static Future<void> checkIntegrity() async {
    final rows = await instance.rawQuery('PRAGMA integrity_check');
    if (rows.isEmpty || rows.first.values.first != 'ok') throw StateError('Database integrity check failed.');
    final fk = await instance.rawQuery('PRAGMA foreign_key_check');
    if (fk.isNotEmpty) throw StateError('Database-এ কিছু সম্পর্কিত তথ্য পরীক্ষা করা প্রয়োজন।');
  }
}
