import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../core/app_paths.dart';
import '../core/app_logger.dart';
import '../data/data_manager.dart';
import '../data/madrasa_database.dart';
import '../data/madrasa_repository.dart';
import 'cloud_sync_page.dart';

const _green=Color(0xFF155E48);
const _modulesByGroup=<String,List<String>>{
  'প্রধান':['dashboard'],
  'পরিচালনা':['students','teachers','staff','classes','subjects'],
  'উপস্থিতি ও মূল্যায়ন':['attendance','teacher_attendance','staff_attendance','exams','marks'],
  'আর্থিক ও শিক্ষা':['fees','income','accounts','expenses','homework','notices','books','library_transactions'],
  'প্রশাসন':['reports','settings','backup','cloud_sync'],
};
const _pageTitles=<String,String>{'dashboard':'ড্যাশবোর্ড','reports':'রিপোর্ট','settings':'সেটিংস','backup':'ব্যাকআপ ও রিস্টোর','cloud_sync':'Appwrite Cloud Sync'};
String titleOf(String key){final title=_pageTitles[key];if(title!=null)return title;for(final module in madrasaModules){if(module.key==key)return module.title;}return key;}

class MadrasaApp extends StatefulWidget {
  const MadrasaApp({super.key});
  @override State<MadrasaApp> createState()=>_MadrasaAppState();
}

class _MadrasaAppState extends State<MadrasaApp> {
  final _repo=MadrasaRepository();
  String _stage='loading',_error='',_username='';

  @override void initState(){super.initState();_initialize();}

  Future<void> _initialize() async {
    if(mounted)setState(()=>_stage='loading');
    try{
      final root=await AppPaths.loadDataRoot();
      if(root==null){if(mounted)setState(()=>_stage='folder');return;}
      await AppPaths.ensureStructure();await MadrasaDatabase.open();await MadrasaDatabase.checkIntegrity();
      final hasAccount=await _repo.hasLocalAccount();
      if(mounted)setState(()=>_stage=hasAccount?'login':'owner');
    }on DataFolderUnavailable catch(e){if(mounted)setState(()=>_stage='folderError');_error=e.toString();}
    catch(e){if(mounted){setState(()=>_stage='error');_error=_friendly(e);}}
  }

  String _friendly(Object error){
    unawaited(AppLogger.write(error,StackTrace.current));
    final text=error.toString();
    if(text.contains('database is locked'))return 'Database ব্যস্ত আছে। কয়েক সেকেন্ড পর আবার চেষ্টা করুন।';
    if(text.contains('no such table'))return 'Database setup অসম্পূর্ণ। Settings থেকে database পরীক্ষা করুন।';
    if(text.contains('DatabaseException'))return 'Database-এর তথ্য সংরক্ষণ করা যায়নি। প্রয়োজনীয় ঘর ও সম্পর্কিত রেকর্ড পরীক্ষা করুন। বিস্তারিত technical.log-এ লেখা হয়েছে।';
    if(error is FileSystemException)return 'ফাইল বা drive ব্যবহার করা যাচ্ছে না। drive সংযুক্ত আছে এবং folder-এর অনুমতি আছে কি না দেখুন।';
    return text.replaceFirst('Exception: ','').replaceFirst('Bad state: ','');
  }

  Future<void> _chooseFolder() async {
    try{
      final selected=await getDirectoryPath(confirmButtonText:'এই Data Folder ব্যবহার করুন');
      if(selected==null)return;
      await AppPaths.saveDataRoot(selected);await AppPaths.ensureStructure();await MadrasaDatabase.open();await MadrasaDatabase.checkIntegrity();
      final hasAccount=await _repo.hasLocalAccount();
      if(mounted)setState(()=>_stage=hasAccount?'login':'owner');
    }catch(e){if(mounted){setState(()=>_stage='folderError');_error=_friendly(e);}}
  }

  Future<void> _createOwner(String username,String password) async {
    await _repo.createOwner(username,password);
    if(mounted)setState(()=>_stage='main');
  }

  Future<void> _login(String username,String password) async {
    if(!await _repo.verifyLogin(username,password))throw const FormatException('ব্যবহারকারীর নাম বা পাসওয়ার্ড সঠিক নয়।');
    if(mounted)setState(()=>_stage='main');
  }

  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'Sreerampur Madrasah Management',
    localizationsDelegates:GlobalMaterialLocalizations.delegates,
    supportedLocales:const [Locale('bn','BD'),Locale('en','US')],
    theme:ThemeData(useMaterial3:true,fontFamily:'Nirmala UI',colorScheme:ColorScheme.fromSeed(seedColor:_green),scaffoldBackgroundColor:const Color(0xFFF6F8F6),inputDecorationTheme:InputDecorationTheme(border:OutlineInputBorder(borderRadius:BorderRadius.circular(9)),filled:true,fillColor:Colors.white,contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:12)),),
    home:_buildHome(),
  );

  Widget _buildHome(){
    switch(_stage){
      case 'loading':return const _LoadingScreen();
      case 'folder':case 'folderError':return _DataFolderScreen(error:_stage=='folderError'?_error:null,onChoose:_chooseFolder,onRetry:_initialize);
      case 'owner':return _CredentialsScreen(create:true,onSubmit:_createOwner,onBack:null);
      case 'login':return _CredentialsScreen(create:false,onSubmit:_login,onBack:()=>setState(()=>_stage='folder'));
      case 'main':return DesktopShell(repository:_repo,onLogout:()=>setState(()=>_stage='login'));
      default:return _DataFolderScreen(error:_error,onChoose:_chooseFolder,onRetry:_initialize);
    }
  }
}

class _LoadingScreen extends StatelessWidget {const _LoadingScreen();@override Widget build(BuildContext context)=>const Scaffold(body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[CircularProgressIndicator(),SizedBox(height:18),Text('মাদরাসার তথ্য প্রস্তুত হচ্ছে…')])));}

class _DataFolderScreen extends StatelessWidget {
  const _DataFolderScreen({required this.onChoose,this.error,this.onRetry});
  final VoidCallback onChoose;final String? error;final VoidCallback? onRetry;
  @override Widget build(BuildContext context)=>Scaffold(body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:650),child:Card(child:Padding(padding:const EdgeInsets.all(34),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Icon(Icons.school_rounded,size:42,color:_green),const SizedBox(height:20),Text(error==null?'Sreerampur Madrasah':'Data Folder পাওয়া যাচ্ছে না',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w700)),const SizedBox(height:8),Text(error??'প্রথমবার চালুর জন্য database ও ফাইল রাখার একটি Data Folder নির্বাচন করুন। এটি application install folder থেকে আলাদা থাকবে।'),if(error!=null)...[const SizedBox(height:12),Text(error!,style:const TextStyle(color:Colors.red))],const SizedBox(height:18),const _FolderStructure(),const SizedBox(height:22),Wrap(spacing:10,children:[FilledButton.icon(onPressed:onChoose,icon:const Icon(Icons.folder_open),label:const Text('Data Folder নির্বাচন করুন')),if(onRetry!=null)TextButton(onPressed:onRetry,child:const Text('আবার পরীক্ষা করুন'))]),
  ]))))));
}

class _FolderStructure extends StatelessWidget {const _FolderStructure();@override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:const Color(0xFFF1F6F3),borderRadius:BorderRadius.circular(10)),child:const Text('নির্বাচিত folder-এ স্বয়ংক্রিয়ভাবে থাকবে:\nData Folder/\n  database/madrasa.db\n  photos/  documents/  backups/\n  reports/  exports/'));}

class _CredentialsScreen extends StatefulWidget {
  const _CredentialsScreen({required this.create,required this.onSubmit,required this.onBack});
  final bool create;final Future<void> Function(String,String) onSubmit;final VoidCallback? onBack;
  @override State<_CredentialsScreen> createState()=>_CredentialsScreenState();
}
class _CredentialsScreenState extends State<_CredentialsScreen>{
  final _form=GlobalKey<FormState>(),_user=TextEditingController(),_pass=TextEditingController(),_confirm=TextEditingController();bool _busy=false,_show=false;String _error='';
  @override void dispose(){_user.dispose();_pass.dispose();_confirm.dispose();super.dispose();}
  Future<void> _submit()async{if(!_form.currentState!.validate())return;setState(()=>_busy=true);try{await widget.onSubmit(_user.text,_pass.text);}catch(e){if(mounted)setState(()=>_error=e.toString().replaceFirst('FormatException: ','').replaceFirst('Bad state: ',''));}finally{if(mounted)setState(()=>_busy=false);}}
  @override Widget build(BuildContext context)=>Scaffold(body:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:500),child:Card(child:Padding(padding:const EdgeInsets.all(30),child:Form(key:_form,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Icon(Icons.lock_person_rounded,size:40,color:_green),const SizedBox(height:16),Text(widget.create?'প্রথম Administrator account তৈরি করুন':'মাদরাসা অ্যাপে লগইন করুন',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w700)),const SizedBox(height:7),Text(widget.create?'এই account শুধু এই Windows computer-এর local database-এ থাকবে। পাসওয়ার্ড হারালে backup ছাড়া reset করা যাবে না।':'Offline ব্যবহারকারীর account দিয়ে প্রবেশ করুন।'),const SizedBox(height:20),TextFormField(controller:_user,decoration:const InputDecoration(labelText:'ব্যবহারকারীর নাম'),validator:(v)=>(v==null||v.trim().length<3)?'কমপক্ষে ৩ অক্ষর লিখুন।':null),const SizedBox(height:13),TextFormField(controller:_pass,obscureText:!_show,decoration:InputDecoration(labelText:'পাসওয়ার্ড',suffixIcon:IconButton(onPressed:()=>setState(()=>_show=!_show),icon:Icon(_show?Icons.visibility_off:Icons.visibility))),validator:(v)=>(v==null||v.length<(widget.create?10:1))?(widget.create?'অন্তত ১০ অক্ষরের পাসওয়ার্ড দিন।':'পাসওয়ার্ড লিখুন।'):null),if(widget.create)...[const SizedBox(height:13),TextFormField(controller:_confirm,obscureText:!_show,decoration:const InputDecoration(labelText:'পাসওয়ার্ড আবার লিখুন'),validator:(v)=>v!=_pass.text?'পাসওয়ার্ড মিলছে না।':null)],if(_error.isNotEmpty)...[const SizedBox(height:12),Text(_error,style:const TextStyle(color:Colors.red))],const SizedBox(height:18),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_busy?null:_submit,icon:_busy?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.login),label:Text(widget.create?'Administrator account তৈরি করুন':'প্রবেশ করুন'))),if(widget.onBack!=null)Align(alignment:Alignment.center,child:TextButton(onPressed:widget.onBack,child:const Text('Data Folder বদলান'))),
  ])))))));
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key,required this.repository,required this.onNavigate});
  final MadrasaRepository repository;final ValueChanged<String> onNavigate;
  @override State<DashboardPage> createState()=>_DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage>{late Future<Map<String,Object?>> _data;
  @override void initState(){super.initState();_data=_load();}
  Future<Map<String,Object?>> _load()async{
    final db=MadrasaDatabase.instance,day=DateTime.now().toIso8601String().substring(0,10);
    final count=(String table)=>widget.repository.tableCount(table);
    final results=await Future.wait([count('students'),count('teachers'),count('staff'),count('classes'),count('books'),count('attendance'),db.rawQuery('SELECT COUNT(*) AS n FROM attendance WHERE date=? AND status IN (?,?)',[day,'উপস্থিত','দেরিতে উপস্থিত']),db.rawQuery('SELECT COUNT(*) AS n FROM attendance WHERE date=? AND status=?',[day,'অনুপস্থিত']),db.rawQuery('SELECT COALESCE(SUM(MAX(0,total-discount-paid)),0) AS n FROM fees')]);
    return {'students':results[0],'teachers':results[1],'staff':results[2],'classes':results[3],'books':results[4],'todayRecords':results[5],'present':(results[6] as List).first['n']??0,'absent':(results[7] as List).first['n']??0,'due':(results[8] as List).first['n']??0};
  }
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,Object?>>(future:_data,builder:(context,snapshot){if(snapshot.hasError)return _ErrorPanel(message:_friendly(snapshot.error!),onRetry:()=>setState(()=>_data=_load()));if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());final d=snapshot.data!;final cards=[('মোট শিক্ষার্থী',d['students'],Icons.groups_outlined,'students'),('মোট শিক্ষক',d['teachers'],Icons.cast_for_education_outlined,'teachers'),('মোট কর্মচারী',d['staff'],Icons.badge_outlined,'staff'),('মোট শ্রেণি',d['classes'],Icons.class_outlined,'classes'),('আজ উপস্থিত',d['present'],Icons.check_circle_outline,'attendance'),('আজ অনুপস্থিত',d['absent'],Icons.event_busy_outlined,'attendance'),('মোট বকেয়া ফি','৳ ${(d['due'] as num).toStringAsFixed(2)}',Icons.account_balance_wallet_outlined,'fees'),('লাইব্রেরির বই',d['books'],Icons.local_library_outlined,'books')];return ListView(padding:const EdgeInsets.all(25),children:[Wrap(spacing:12,runSpacing:12,children:cards.map((x)=>SizedBox(width:MediaQuery.sizeOf(context).width>1300?230:205,child:Card(child:InkWell(borderRadius:BorderRadius.circular(14),onTap:()=>widget.onNavigate(x.$4),child:Padding(padding:const EdgeInsets.all(17),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(x.$3,color:_green),const SizedBox(height:14),Text(x.$2.toString(),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w700)),Text(x.$1,style:const TextStyle(color:Colors.black54))])))))).toList()),const SizedBox(height:20),Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('দ্রুত কাজ',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700)),const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[('＋ শিক্ষার্থী ভর্তি','students'),('আজকের উপস্থিতি','attendance'),('ফি গ্রহণ ও রসিদ','fees'),('পরীক্ষার নম্বর','marks'),('রিপোর্ট','reports')].map((x)=>OutlinedButton.icon(onPressed:()=>widget.onNavigate(x.$2),icon:const Icon(Icons.arrow_forward,size:17),label:Text(x.$1))).toList())]))),const SizedBox(height:10),const _InfoBanner(text:'Offline mode · তথ্য নির্বাচিত Data Folder-এর SQLite database-এ সংরক্ষিত থাকবে।')]);});
}

class _InfoBanner extends StatelessWidget {const _InfoBanner({required this.text});final String text;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:const Color(0xFFE8F3ED),borderRadius:BorderRadius.circular(10)),child:Row(children:[const Icon(Icons.offline_bolt_outlined,color:_green),const SizedBox(width:9),Expanded(child:Text(text,style:const TextStyle(color:_green)))]));}

class _ErrorPanel extends StatelessWidget {const _ErrorPanel({required this.message,required this.onRetry});final String message;final VoidCallback onRetry;@override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline,color:Colors.red,size:38),const SizedBox(height:10),Text(message,textAlign:TextAlign.center),const SizedBox(height:12),FilledButton.icon(onPressed:onRetry,icon:const Icon(Icons.refresh),label:const Text('আবার চেষ্টা করুন'))])));}

class RecordListPage extends StatefulWidget {
  const RecordListPage({super.key,required this.module,required this.repository});
  final ModuleSpec module;final MadrasaRepository repository;
  @override State<RecordListPage> createState()=>_RecordListPageState();
}
class _RecordListPageState extends State<RecordListPage>{
  static const _pageSize=40;final _search=TextEditingController();Timer? _debounce;late Future<List<Map<String,Object?>>> _rows;int _page=0,_total=0;bool _busy=false;Map<String,Map<String,String>> _labels={};
  @override void initState(){super.initState();_rows=Future.value(const []);WidgetsBinding.instance.addPostFrameCallback((_)=>_load());}
  @override void dispose(){_debounce?.cancel();_search.dispose();super.dispose();}
  Future<void> _load()async{if(!mounted)return;final rowsFuture=widget.repository.list(widget.module,search:_search.text,page:_page,pageSize:_pageSize);setState(()=>_busy=true);setState(()=>_rows=rowsFuture);try{final total=await widget.repository.count(widget.module,search:_search.text);final records=await rowsFuture;final labels=await _loadLabels(records);if(mounted)setState((){_total=total;_labels=labels;});}catch(e){if(mounted)setState(()=>_rows=Future.error(e));}finally{if(mounted)setState(()=>_busy=false);}}
  Future<Map<String,Map<String,String>>> _loadLabels(List<Map<String,Object?>> records)async{final out=<String,Map<String,String>>{};for(final field in widget.module.fields){if(!const {'class','student','teacher','subject','exam','book','staff'}.contains(field.type))continue;final ids=records.map((r)=>r[field.key]?.toString()).whereType<String>().toSet().toList();if(ids.isEmpty)continue;final table=_relationTable[field.type];if(table==null)continue;final placeholders=List.filled(ids.length,'?').join(',');final rows=await MadrasaDatabase.instance.query(table,where:'id IN ($placeholders)',whereArgs:ids);out[field.type]={for(final row in rows)row['id'].toString():_lookupLabel(field.type,row)};}return out;}
  String _lookupLabel(String type,Map<String,Object?> row)=>switch(type){'student'=>'${row['name']??''} · ${row['student_id']??''}','teacher'=>'${row['name']??''} · ${row['teacher_id']??''}','staff'=>'${row['name']??''} · ${row['staff_id']??''}','book'=>'${row['name']??''}','exam'=>'${row['name']??''}','subject'=>'${row['name']??''}','class'=>'${row['name']??''}',_=>''};
  void _searchChanged(String value){_debounce?.cancel();_debounce=Timer(const Duration(milliseconds:300),(){if(!mounted)return;setState(()=>_page=0);_load();});}
  Future<void> _edit([Map<String,Object?>? row])async{final result=await showDialog<Map<String,Object?>>(context:context,builder:(_)=>RecordEditor(module:widget.module,repository:widget.repository,record:row));if(result==null)return;try{await widget.repository.save(widget.module,result,id:row?['id']?.toString());_showMessage(context,row==null?'তথ্য সংরক্ষণ হয়েছে।':'পরিবর্তন সংরক্ষণ হয়েছে।');await _load();}catch(e){_showMessage(context,_friendly(e),error:true);}}
  Future<void> _delete(Map<String,Object?> row)async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('রেকর্ড মুছবেন?'),content:Text('“${_display(row,widget.module.columns.first)}” স্থায়ীভাবে মুছে যাবে।'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('বাতিল')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('মুছুন'))]));if(ok!=true)return;try{await widget.repository.delete(widget.module,row['id'].toString());_showMessage(context,'রেকর্ড মুছে ফেলা হয়েছে।');await _load();}catch(e){_showMessage(context,_friendly(e),error:true);}}
  String _display(Map<String,Object?> row,String col){if(col=='due'&&widget.module.table=='fees')return _money(((row['total'] as num?)??0)-((row['discount'] as num?)??0)-((row['paid'] as num?)??0));final value=row[col];if(value==null)return '—';for(final field in widget.module.fields){if(field.key==col&&_labels.containsKey(field.type))return _labels[field.type]![value.toString()]??value.toString();}if(value is num&&widget.module.fields.any((f)=>f.key==col&&f.type=='number'))return _money(value);return value.toString();}
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
        child: Row(children: [
          Expanded(child: Text(widget.module.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
          if (widget.module.table == 'attendance') OutlinedButton.icon(onPressed: _markClassPresent, icon: const Icon(Icons.done_all), label: const Text('শ্রেণির সবাই হাজির')),
          const SizedBox(width: 9),
          OutlinedButton.icon(onPressed: _printModule, icon: const Icon(Icons.print_outlined), label: const Text('প্রিন্ট')),
          const SizedBox(width: 9),
          FilledButton.icon(onPressed: _edit, icon: const Icon(Icons.add), label: Text(widget.module.key == 'students' ? 'ভর্তি / যোগ করুন' : 'নতুন যোগ করুন')),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Row(children: [
          SizedBox(width: 360, child: TextField(controller: _search, onChanged: _searchChanged, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'নাম, আইডি বা তথ্য খুঁজুন', isDense: true))),
          const Spacer(),
          Text('মোট ${_total}টি রেকর্ড  ·  প্রতি পৃষ্ঠায় $_pageSizeটি', style: const TextStyle(color: Colors.black54)),
        ]),
      ),
      Expanded(
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: _rows,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _ErrorPanel(message: _friendly(snapshot.error!), onRetry: _load);
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data!;
            final hasPhoto = {'students', 'teachers', 'staff'}.contains(widget.module.table);
            final cols = [...(hasPhoto ? ['photo_path'] : <String>[]), ...widget.module.columns, ...(widget.module.table == 'fees' ? ['due'] : <String>[])];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                child: Column(children: [
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('কোনো তথ্য পাওয়া যায়নি। নতুন রেকর্ড যোগ করুন।'))
                        : Scrollbar(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 23,
                                  headingRowHeight: 46,
                                  dataRowMinHeight: 47,
                                  dataRowMaxHeight: 64,
                                  columns: [
                                    ...cols.map((c) => DataColumn(label: Text(_columnLabel(c), style: const TextStyle(fontWeight: FontWeight.w700)))),
                                    const DataColumn(label: Text('কাজ', style: TextStyle(fontWeight: FontWeight.w700))),
                                  ],
                                  rows: rows.map((row) => DataRow(cells: [
                                    ...cols.map((c) => DataCell(c == 'photo_path'
                                        ? _photoCell(row[c])
                                        : ConstrainedBox(constraints: const BoxConstraints(maxWidth: 190), child: Text(_display(row, c), maxLines: 2, overflow: TextOverflow.ellipsis)))),
                                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                      IconButton(tooltip: 'সম্পাদনা', onPressed: () => _edit(row), icon: const Icon(Icons.edit_outlined, size: 18)),
                                      if (widget.module.table == 'students') IconButton(tooltip: 'শিক্ষার্থী profile/ID print', onPressed: () => _printStudent(row), icon: const Icon(Icons.badge_outlined, size: 18)),
                                      if (widget.module.table == 'fees') IconButton(tooltip: 'ফি রসিদ প্রিন্ট', onPressed: () => _printReceipt(row), icon: const Icon(Icons.receipt_long_outlined, size: 18)),
                                      IconButton(tooltip: 'মুছুন', onPressed: () => _delete(row), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 19)),
                                    ])),
                                  ])).toList(),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton.icon(onPressed: _page > 0 ? () { setState(() => _page--); _load(); } : null, icon: const Icon(Icons.chevron_left), label: const Text('আগের পৃষ্ঠা')),
                      Text('পৃষ্ঠা ${_page + 1} / ${(_total / _pageSize).ceil().clamp(1, 99999)}'),
                      TextButton.icon(onPressed: (_page + 1) * _pageSize < _total ? () { setState(() => _page++); _load(); } : null, icon: const Icon(Icons.chevron_right), label: const Text('পরের পৃষ্ঠা')),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
      if (_busy) const LinearProgressIndicator(minHeight: 2),
    ]);
  }  Widget _photoCell(Object? value){if(value==null||value.toString().isEmpty)return const SizedBox(width:38,height:38,child:CircleAvatar(child:Icon(Icons.person_outline,size:18)));final stored=value.toString();final file=File(p.isAbsolute(stored)?stored:p.join(AppPaths.root.path,stored));return ClipOval(child:SizedBox(width:38,height:38,child:Image.file(file,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const CircleAvatar(child:Icon(Icons.person_outline,size:18)))));}
  String _columnLabel(String key){for(final f in widget.module.fields){if(f.key==key)return f.label;}if(key=='due')return 'বকেয়া';return key;}
  Future<void> _markClassPresent()async{final classes=await MadrasaDatabase.instance.query('classes',orderBy:'sort_order');if(!mounted)return;if(classes.isEmpty)return _showMessage(context,'আগে শ্রেণি যোগ করুন।',error:true);final cls=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(title:const Text('শ্রেণির সবাইকে উপস্থিত দিন'),children:classes.map((r)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,r['id'].toString()),child:Text(r['name'].toString()))).toList()));if(cls==null)return;try{final count=await widget.repository.markClassPresent(cls,DateTime.now().toIso8601String().substring(0,10));_showMessage(context,'$count জন শিক্ষার্থীর উপস্থিতি সংরক্ষিত হয়েছে।');await _load();}catch(e){_showMessage(context,_friendly(e),error:true);}}
  Future<void> _printModule()async{try{final rows=await widget.repository.list(widget.module,page:0,pageSize:1000);await MadrasaPrint.table(widget.module.title,widget.module.columns.map(_columnLabel).toList(),rows.map((r)=>widget.module.columns.map((c)=>_display(r,c)).toList()).toList(),await widget.repository.settings());}catch(e){_showMessage(context,_friendly(e),error:true);}}
  Future<void> _printStudent(Map<String,Object?> row)async{try{await MadrasaPrint.student(row,await widget.repository.settings(),_labels['class']?[row['class_id']?.toString()]??'—');}catch(e){_showMessage(context,_friendly(e),error:true);}}
  Future<void> _printReceipt(Map<String,Object?> row)async{try{await MadrasaPrint.receipt(row,await widget.repository.settings(),_labels['student']?[row['student_id']?.toString()]??'—');}catch(e){_showMessage(context,_friendly(e),error:true);}}
}

String _money(Object? value)=>'৳ ${(value is num?value:double.tryParse(value?.toString()??'')??0).toStringAsFixed(2)}';

class RecordEditor extends StatefulWidget {
  const RecordEditor({super.key,required this.module,required this.repository,this.record});
  final ModuleSpec module;final MadrasaRepository repository;final Map<String,Object?>? record;
  @override State<RecordEditor> createState()=>_RecordEditorState();
}
class _RecordEditorState extends State<RecordEditor>{
  final _form=GlobalKey<FormState>();late final Map<String,TextEditingController> _controllers;final Map<String,String?> _selected={};bool _saving=false;
  @override void initState(){super.initState();_controllers={for(final f in widget.module.fields)f.key:TextEditingController(text:widget.record?[f.key]?.toString()??'')};for(final f in widget.module.fields){if(_relationTable.containsKey(f.type)||_choices(f.key).isNotEmpty)_selected[f.key]=widget.record?[f.key]?.toString();}}
  @override void dispose(){for(final c in _controllers.values)c.dispose();super.dispose();}
  Future<List<Map<String,Object?>>> _options(String type)async{final table=_relationTable[type];if(table==null)return [];String? order=table=='classes'?'sort_order':'name';return MadrasaDatabase.instance.query(table,orderBy:order);}
  Future<void> _save()async{if(!_form.currentState!.validate())return;_form.currentState!.save();setState(()=>_saving=true);final result=<String,Object?>{};for(final f in widget.module.fields){result[f.key]=_relationTable.containsKey(f.type)||_choices(f.key).isNotEmpty?_selected[f.key]:_controllers[f.key]!.text.trim();}if(widget.module.table=='classes'&&result['sort_order'].toString().isEmpty)result['sort_order']='0';if(widget.module.table=='books'){result['total']=result['total'].toString().isEmpty?'0':result['total'];result['available']=result['available'].toString().isEmpty?result['total']:result['available'];result['status']=result['status'].toString().isEmpty?'সক্রিয়':result['status'];}try{Navigator.pop(context,result);}finally{if(mounted)setState(()=>_saving=false);}}
  Future<void> _choosePhoto(FieldSpec field)async{try{final file=await openFile(acceptedTypeGroups:[const XTypeGroup(label:'ছবি',extensions:['jpg','jpeg','png','webp'])]);if(file==null)return;final ext=p.extension(file.name).toLowerCase();final sub=widget.module.table=='students'?'students':'staff';final name='${DateTime.now().microsecondsSinceEpoch}$ext';final out=File(p.join(AppPaths.photos.path,sub,name));await out.parent.create(recursive:true);await File(file.path).copy(out.path);setState(()=>_controllers[field.key]!.text='photos/$sub/$name');}catch(e){_showMessage(context,_friendly(e),error:true);}}
  List<String> _choices(String key)=>switch(key){'gender'=>['ছাত্র','ছাত্রী'],'status' when widget.module.table=='attendance'||widget.module.table.endsWith('attendance')=>['উপস্থিত','অনুপস্থিত','দেরিতে উপস্থিত','ছুটি'],'status'=>['সক্রিয়','নিষ্ক্রিয়','উত্তীর্ণ','স্থানান্তরিত'],'entry_type'=>['জমা','খরচ'],'method'=>['নগদ','বিকাশ','ব্যাংক','অন্যান্য'],'category' when widget.module.table=='fees'=>['ভর্তি ফি','মাসিক ফি','পরীক্ষার ফি','সেশন ফি','হোস্টেল ফি','পরিবহন ফি','লাইব্রেরি ফি','অন্যান্য'],'category' when widget.module.table=='expenses'=>['বেতন','বিদ্যুৎ','খাবার','মেরামত','স্টেশনারি','পরিবহন','অন্যান্য'],'priority'=>['সাধারণ','গুরুত্বপূর্ণ','জরুরি'],_=>[]};
  @override Widget build(BuildContext context)=>Dialog(child:SizedBox(width:720,height:MediaQuery.sizeOf(context).height*.86,child:Column(children:[Padding(padding:const EdgeInsets.fromLTRB(22,18,12,12),child:Row(children:[Expanded(child:Text(widget.record==null?'নতুন ${widget.module.title}':'${widget.module.title} সম্পাদনা',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700))),IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close))])),const Divider(height:1),Expanded(child:Form(key:_form,child:ListView(padding:const EdgeInsets.all(22),children:[Wrap(spacing:14,runSpacing:2,children:widget.module.fields.map((field)=>SizedBox(width:field.type=='multiline'?double.infinity:300,child:_field(field))).toList())]))),const Divider(height:1),Padding(padding:const EdgeInsets.all(14),child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[TextButton(onPressed:_saving?null:()=>Navigator.pop(context),child:const Text('বাতিল')),const SizedBox(width:8),FilledButton.icon(onPressed:_saving?null:_save,icon:_saving?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save_outlined),label:const Text('সংরক্ষণ'))]))])));
  Widget _field(FieldSpec field){final choices=_choices(field.key);if(_relationTable.containsKey(field.type)){return FutureBuilder<List<Map<String,Object?>>>(future:_options(field.type),builder:(context,snapshot){final rows=snapshot.data??[];final labelColumn=switch(field.type){'student'=>'name','teacher'=>'name','staff'=>'name','class'=>'name','subject'=>'name','exam'=>'name','book'=>'name',_=>'name'};return Padding(padding:const EdgeInsets.only(bottom:10),child:DropdownButtonFormField<String>(initialValue:rows.any((r)=>r['id'].toString()==_selected[field.key])?_selected[field.key]:null,decoration:InputDecoration(labelText:field.required?'${field.label} *':field.label),items:rows.map((r)=>DropdownMenuItem(value:r['id'].toString(),child:Text('${r[labelColumn]??''}${field.type=='student'?' · ${r['student_id']??''}':''}',overflow:TextOverflow.ellipsis))).toList(),onChanged:snapshot.connectionState==ConnectionState.done?(v)=>setState(()=>_selected[field.key]=v):null,validator:(v)=>field.required&&(v==null||v.isEmpty)?'${field.label} নির্বাচন করুন।':null));});}
    if(choices.isNotEmpty)return Padding(padding:const EdgeInsets.only(bottom:10),child:DropdownButtonFormField<String>(initialValue:choices.contains(_selected[field.key])?_selected[field.key]:null,decoration:InputDecoration(labelText:field.required?'${field.label} *':field.label),items:choices.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>_selected[field.key]=v),validator:(v)=>field.required&&(v==null||v.isEmpty)?'${field.label} নির্বাচন করুন।':null));
    if(field.type=='photo')return Padding(padding:const EdgeInsets.only(bottom:14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(field.label),const SizedBox(height:5),Wrap(spacing:10,crossAxisAlignment:WrapCrossAlignment.center,children:[OutlinedButton.icon(onPressed:()=>_choosePhoto(field),icon:const Icon(Icons.photo_library_outlined),label:const Text('ছবি নির্বাচন করুন')),if(_controllers[field.key]!.text.isNotEmpty)Text(p.basename(_controllers[field.key]!.text)),if(_controllers[field.key]!.text.isNotEmpty)IconButton(tooltip:'ছবি বাদ দিন',onPressed:()=>setState(()=>_controllers[field.key]!.clear()),icon:const Icon(Icons.close))]) ]));
    final date=field.type=='date';return Padding(padding:const EdgeInsets.only(bottom:10),child:TextFormField(controller:_controllers[field.key],maxLines:field.type=='multiline'?3:1,keyboardType:field.type=='number'?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,readOnly:date,onTap:date?()=>_pickDate(field):null,decoration:InputDecoration(labelText:field.required?'${field.label} *':field.label,suffixIcon:date?const Icon(Icons.calendar_month_outlined):null),validator:(v)=>field.required&&(v==null||v.trim().isEmpty)?'${field.label} লিখুন।':field.type=='number'&&v!=null&&v.trim().isNotEmpty&&double.tryParse(v.trim())==null?'সঠিক সংখ্যা লিখুন।':null));
  }
  Future<void> _pickDate(FieldSpec field)async{final current=DateTime.tryParse(_controllers[field.key]!.text)??DateTime.now();final chosen=await showDatePicker(context:context,initialDate:current,firstDate:DateTime(1950),lastDate:DateTime(2120),locale:const Locale('bn','BD'));if(chosen!=null)setState(()=>_controllers[field.key]!.text=chosen.toIso8601String().substring(0,10));}
}

const _relationTable=<String,String>{'class':'classes','student':'students','teacher':'teachers','staff':'staff','subject':'subjects','exam':'exams','book':'books'};

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key,required this.repository,required this.settings,required this.onChanged});
  final MadrasaRepository repository;final Map<String,String> settings;final VoidCallback onChanged;
  @override State<SettingsPage> createState()=>_SettingsPageState();
}
class _SettingsPageState extends State<SettingsPage>{
  final _form=GlobalKey<FormState>();late final Map<String,TextEditingController> _fields;bool _saving=false;String _storage='তথ্য পরীক্ষা করা হচ্ছে…';String _printer='';
  @override void initState(){super.initState();_fields={for(final key in ['school_name','school_address','school_phone','school_email','head_name','academic_year','logo_path'])key:TextEditingController(text:widget.settings[key]??'')};_loadStorage();}
  @override void dispose(){for(final c in _fields.values)c.dispose();super.dispose();}
  Future<void> _loadStorage()async{try{var bytes=0;await for(final f in AppPaths.root.list(recursive:true,followLinks:false)){if(f is File)bytes+=(await f.length());}if(mounted)setState(()=>_storage='${AppPaths.dataRoot}\n${_humanBytes(bytes)}');}catch(e){if(mounted)setState(()=>_storage=_friendly(e));}}
  String _humanBytes(int n)=>n<1024?'$n bytes':n<1024*1024?'${(n/1024).toStringAsFixed(1)} KB':n<1024*1024*1024?'${(n/1024/1024).toStringAsFixed(1)} MB':'${(n/1024/1024/1024).toStringAsFixed(2)} GB';
  Future<void> _save()async{if(!_form.currentState!.validate())return;setState(()=>_saving=true);try{await widget.repository.saveSettings({for(final e in _fields.entries)e.key:e.value.text.trim()});widget.onChanged();_showMessage(context,'মাদরাসার তথ্য সংরক্ষণ হয়েছে।');}catch(e){_showMessage(context,_friendly(e),error:true);}finally{if(mounted)setState(()=>_saving=false);}}
  Future<void> _pickLogo()async{try{final x=await openFile(acceptedTypeGroups:[const XTypeGroup(label:'Logo image',extensions:['png','jpg','jpeg','webp'])]);if(x==null)return;final out=File(p.join(AppPaths.photos.path,'madrasa-logo${p.extension(x.name).toLowerCase()}'));await out.parent.create(recursive:true);await File(x.path).copy(out.path);setState(()=>_fields['logo_path']!.text='photos/${p.basename(out.path)}');}catch(e){_showMessage(context,_friendly(e),error:true);}}
  Future<void> _changeFolder()async{final selected=await getDirectoryPath(confirmButtonText:'নতুন Data Folder ব্যবহার করুন');if(selected==null)return;final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Data Folder বদলাবেন?'),content:Text('Database, photos, documents ও backup copy হবে। পুরোনো তথ্য delete হবে না।\n\n$selected'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('বাতিল')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Copy ও পরিবর্তন'))]));if(ok!=true)return;try{await DataManager.changeDataFolder(selected);await _loadStorage();_showMessage(context,'নতুন Data Folder-এ তথ্য যাচাই করে চালু করা হয়েছে। পুরোনো folder-টি রেখে দেওয়া হয়েছে।');}catch(e){_showMessage(context,_friendly(e),error:true);}}
  Future<void> _openFolder()async{try{await Process.run('explorer.exe',[AppPaths.root.path]);}catch(e){_showMessage(context,_friendly(e),error:true);}}
  Future<void> _checkDb()async{try{await MadrasaDatabase.checkIntegrity();final tables=await MadrasaDatabase.instance.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");_showMessage(context,'Database ঠিক আছে · ${tables.length}টি table পাওয়া গেছে।');}catch(e){_showMessage(context,_friendly(e),error:true);}}
  Future<void> _showPrinters()async{try{final printers=await Printing.listPrinters();if(!mounted)return;await showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Windows Printer'),content:SizedBox(width:460,child:printers.isEmpty?const Text('কোনো printer পাওয়া যায়নি। Windows Settings-এ printer যোগ করুন।'):ListView(shrinkWrap:true,children:printers.map((x)=>ListTile(leading:const Icon(Icons.print_outlined),title:Text(x.name),subtitle:Text(x.isDefault?'Default printer':''),onTap:(){_printer=x.name;Navigator.pop(c);})).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('বন্ধ করুন'))]));if(_printer.isNotEmpty)_showMessage(context,'$_printer নির্বাচন করা হয়েছে। Print dialog-এ printer নিশ্চিত করুন।');}catch(e){_showMessage(context,'Printer list পাওয়া যায়নি: ${_friendly(e)}',error:true);}}
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('মাদরাসার তথ্য', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  ..._fields.entries.where((e) => e.key != 'logo_path').map((e) => SizedBox(
                    width: 390,
                    child: TextFormField(
                      controller: e.value,
                      decoration: InputDecoration(labelText: _settingLabel(e.key)),
                      validator: (value) => e.key == 'school_name' && (value == null || value.trim().isEmpty)
                          ? 'মাদরাসার নাম লিখুন।'
                          : null,
                    ),
                  )),
                  SizedBox(
                    width: 390,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('মাদরাসার লোগো'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 9,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickLogo,
                              icon: const Icon(Icons.image_outlined),
                              label: const Text('Logo নির্বাচন করুন'),
                            ),
                            if (_fields['logo_path']!.text.isNotEmpty)
                              Text(p.basename(_fields['logo_path']!.text)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('তথ্য সংরক্ষণ'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Data Location', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_storage),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(onPressed: _changeFolder, icon: const Icon(Icons.drive_file_move_outline), label: const Text('Change Data Folder')),
                    OutlinedButton.icon(onPressed: _openFolder, icon: const Icon(Icons.folder_open), label: const Text('Open Data Folder')),
                    OutlinedButton.icon(onPressed: _checkDb, icon: const Icon(Icons.fact_check_outlined), label: const Text('Check Database')),
                    OutlinedButton.icon(onPressed: _loadStorage, icon: const Icon(Icons.storage_outlined), label: const Text('Storage Information')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Printer', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Card(
          child: ListTile(
            leading: const Icon(Icons.print_outlined),
            title: Text(_printer.isEmpty ? 'Windows-এর local printer' : _printer),
            subtitle: const Text('PDF ও রসিদ print করলে Windows-এর printer dialog খুলবে।'),
            trailing: OutlinedButton(onPressed: _showPrinters, child: const Text('Printer দেখুন')),
          ),
        ),
        const SizedBox(height: 18),
        const _InfoBanner(text: 'Application folder থেকে Database, ছবি ও নথি আলাদা Data Folder-এ থাকে। App update বা reinstall করলে নির্বাচিত Data Folder আলাদা থাকবে।'),
      ],
    );
  }
  String _settingLabel(String key)=>switch(key){'school_name'=>'মাদরাসার নাম','school_address'=>'ঠিকানা','school_phone'=>'ফোন','school_email'=>'ইমেইল','head_name'=>'প্রধানের নাম','academic_year'=>'শিক্ষাবর্ষ',_=>key};
}

class BackupPage extends StatefulWidget {
  const BackupPage({super.key,required this.repository});final MadrasaRepository repository;
  @override State<BackupPage> createState()=>_BackupPageState();
}
class _BackupPageState extends State<BackupPage>{bool _busy=false;String _message='';
  Future<void> _backup()async{setState(()=>_busy=true);try{final path=await DataManager.createBackup();setState(()=>_message='Backup তৈরি হয়েছে:\n$path');}catch(e){_showMessage(context,_friendly(e),error:true);}finally{if(mounted)setState(()=>_busy=false);}}
  Future<void> _restore()async{try{final path=await DataManager.pickBackupFile();if(path==null)return;final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('ZIP backup Restore করবেন?'),content:const Text('Restore-এর আগে বর্তমান Data Folder-এর safety backup তৈরি হবে। Restore শেষ হলে এই database থেকে আগের তথ্য প্রতিস্থাপিত হবে।'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('বাতিল')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Restore করুন'))]));if(yes!=true)return;setState(()=>_busy=true);await DataManager.restoreBackup(path);setState(()=>_message='Backup restore হয়েছে। Database integrity পরীক্ষা পাস করেছে।');}catch(e){_showMessage(context,_friendly(e),error:true);}finally{if(mounted)setState(()=>_busy=false);}}
  Future<void> _importWebJson()async{try{final file=await openFile(acceptedTypeGroups:[const XTypeGroup(label:'JSON backup',extensions:['json'])]);if(file==null)return;final text=await File(file.path).readAsString(),decoded=jsonDecode(text);if(decoded is! Map)throw const FormatException('JSON backup-এর format সঠিক নয়।');final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('পুরোনো Web App-এর তথ্য আনবেন?'),content:const Text('বর্তমান Data Folder-এর আগে safety backup হবে। মিলে যাওয়া ID/রেকর্ড বাদ দিয়ে পুরোনো JSON তথ্য যোগ করা হবে।'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('বাতিল')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Import করুন'))]));if(yes!=true)return;await DataManager.createBackup();await widget.repository.importLegacyJson(Map<String,Object?>.from(decoded));setState(()=>_message='JSON data import হয়েছে। রেকর্ডের তালিকায় পরীক্ষা করুন।');}catch(e){_showMessage(context,_friendly(e),error:true);}}
  Future<void> _openFolder()async{try{await Process.run('explorer.exe',[AppPaths.backups.path]);}catch(e){_showMessage(context,_friendly(e),error:true);}}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(24),children:[Text('Backup ও Restore',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w700)),const SizedBox(height:14),Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.backup_outlined,color:_green,size:34),const SizedBox(height:10),const Text('পূর্ণাঙ্গ Local ZIP Backup',style:TextStyle(fontWeight:FontWeight.w700,fontSize:16)),const SizedBox(height:5),const Text('Database, settings, photos, documents, reports ও exports timestamp-সহ ZIP ফাইলে থাকবে।'),const SizedBox(height:14),Wrap(spacing:9,children:[FilledButton.icon(onPressed:_busy?null:_backup,icon:_busy?const SizedBox(width:15,height:15,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.download_outlined),label:const Text('এখনই Backup')),OutlinedButton.icon(onPressed:_busy?null:_openFolder,icon:const Icon(Icons.folder_open),label:const Text('Backup Folder খুলুন'))])]))),const SizedBox(height:14),Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.restore_page_outlined,color:_green,size:34),const SizedBox(height:10),const Text('ZIP Backup Restore',style:TextStyle(fontWeight:FontWeight.w700,fontSize:16)),const SizedBox(height:5),const Text('Restore করার আগে বর্তমান database-এর একটি safety backup তৈরি হয়। ফাইল validate হয় এবং database integrity পরীক্ষা করা হয়।'),const SizedBox(height:14),FilledButton.tonalIcon(onPressed:_busy?null:_restore,icon:const Icon(Icons.restore),label:const Text('ZIP Backup নির্বাচন ও Restore'))]))),const SizedBox(height:14),Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.language_outlined,color:_green,size:34),const SizedBox(height:10),const Text('পুরোনো Browser App থেকে JSON Import',style:TextStyle(fontWeight:FontWeight.w700,fontSize:16)),const SizedBox(height:5),const Text('পুরোনো app-এর Backup ও Restore পেজ থেকে JSON backup ডাউনলোড করে এখানে আনুন। Import বর্তমান records overwrite না করে merge করার জন্য।'),const SizedBox(height:14),OutlinedButton.icon(onPressed:_busy?null:_importWebJson,icon:const Icon(Icons.file_open_outlined),label:const Text('পুরোনো JSON Backup Import'))]))),if(_message.isNotEmpty)...[const SizedBox(height:13),SelectableText(_message)],if(_busy)const Padding(padding:EdgeInsets.all(14),child:LinearProgressIndicator())]);
}

class ReportsPage extends StatefulWidget {const ReportsPage({super.key,required this.repository});final MadrasaRepository repository;@override State<ReportsPage> createState()=>_ReportsPageState();}
class _ReportsPageState extends State<ReportsPage>{String _module='fees';DateTime? _from,_to;List<Map<String,Object?>> _rows=[];bool _busy=false;final _reportable=madrasaModules.where((m)=>!{'accounts','settings'}.contains(m.key)).toList();
  Future<void> _build()async{setState(()=>_busy=true);try{final m=madrasaModules.firstWhere((x)=>x.key==_module),rows=await widget.repository.list(m,pageSize:1000);final dateCol=m.fields.any((f)=>f.key=='date')?'date':m.fields.any((f)=>f.key=='start_date')?'start_date':null;setState(()=>_rows=rows.where((r){if(dateCol==null)return true;final value=DateTime.tryParse(r[dateCol]?.toString()??'');return value!=null&&(_from==null||!value.isBefore(_from!))&&(_to==null||!value.isAfter(_to!));}).toList());}catch(e){_showMessage(context,_friendly(e),error:true);}finally{if(mounted)setState(()=>_busy=false);}}
  Future<void> _date(bool from)async{final d=await showDatePicker(context:context,initialDate:DateTime.now(),firstDate:DateTime(1950),lastDate:DateTime(2120));if(d!=null)setState(()=>from?_from=d:_to=d);}
  Future<void> _exportCsv()async{if(_rows.isEmpty)return _showMessage(context,'CSV export করার মতো তথ্য নেই।',error:true);try{final m=madrasaModules.firstWhere((x)=>x.key==_module),headers=m.columns;final csv='\uFEFF${[headers.join(','),..._rows.map((r)=>headers.map((c)=>'"${(r[c]??'').toString().replaceAll('"','""')}"').join(','))].join('\r\n')}';final file=File(p.join(AppPaths.exports.path,'${m.key}_${DateTime.now().millisecondsSinceEpoch}.csv'));await file.writeAsString(csv,flush:true);_showMessage(context,'CSV ফাইল তৈরি হয়েছে: ${file.path}');}catch(e){_showMessage(context,_friendly(e),error:true);}}
  Future<void> _print()async{try{final m=madrasaModules.firstWhere((x)=>x.key==_module);final labels=<String>[];for(final c in m.columns){final matching=m.fields.where((f)=>f.key==c);labels.add(matching.isEmpty?c:matching.first.label);}await MadrasaPrint.table('রিপোর্ট · ${m.title}',labels,_rows.map((r)=>m.columns.map((c)=>r[c]?.toString()??'—').toList()).toList(),await widget.repository.settings());}catch(e){_showMessage(context,_friendly(e),error:true);}}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(24),children:[Text('রিপোর্ট',style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w700)),const SizedBox(height:12),Card(child:Padding(padding:const EdgeInsets.all(16),child:Wrap(spacing:11,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[SizedBox(width:250,child:DropdownButtonFormField<String>(initialValue:_module,decoration:const InputDecoration(labelText:'রিপোর্টের ধরন'),items:_reportable.map((m)=>DropdownMenuItem(value:m.key,child:Text(m.title))).toList(),onChanged:(v)=>setState(()=>_module=v??'fees'))),OutlinedButton.icon(onPressed:()=>_date(true),icon:const Icon(Icons.date_range),label:Text(_from==null?'শুরু তারিখ':_from!.toIso8601String().substring(0,10))),OutlinedButton.icon(onPressed:()=>_date(false),icon:const Icon(Icons.event),label:Text(_to==null?'শেষ তারিখ':_to!.toIso8601String().substring(0,10))),FilledButton.icon(onPressed:_build,icon:const Icon(Icons.search),label:const Text('রিপোর্ট দেখুন')),OutlinedButton.icon(onPressed:_exportCsv,icon:const Icon(Icons.table_view_outlined),label:const Text('CSV Export')),OutlinedButton.icon(onPressed:_print,icon:const Icon(Icons.print_outlined),label:const Text('Print'))]))),const SizedBox(height:12),if(_busy)const LinearProgressIndicator(),Card(child:Padding(padding:const EdgeInsets.all(15),child:Text('রেকর্ড: ${_rows.length}টি  ·  টাকার পরিমাণ ৳ ${_rows.fold<double>(0,(sum,r)=>sum+((r['amount']??r['paid']??0) as num).toDouble()).toStringAsFixed(2)}'))),if(_rows.isNotEmpty)SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(columns:madrasaModules.firstWhere((m)=>m.key==_module).columns.map((c)=>DataColumn(label:Text(c))).toList(),rows:_rows.take(300).map((r)=>DataRow(cells:madrasaModules.firstWhere((m)=>m.key==_module).columns.map((c)=>DataCell(Text(r[c]?.toString()??'—'))).toList())).toList()))else const Padding(padding:EdgeInsets.all(25),child:Text('Filter বেছে “রিপোর্ট দেখুন” চাপুন।'))]);}



class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key,required this.repository,required this.onLogout});
  final MadrasaRepository repository;final VoidCallback onLogout;
  @override State<DesktopShell> createState()=>_DesktopShellState();
}
class _DesktopShellState extends State<DesktopShell>{String _page='dashboard';Map<String,String> _settings={};
  @override void initState(){super.initState();_loadSettings();}
  Future<void> _loadSettings()async{try{final v=await widget.repository.settings();if(mounted)setState(()=>_settings=v);}catch(_){}}
  void _go(String id){setState(()=>_page=id);}
  Widget _logo(){final path=_settings['logo_path'];if(path==null||path.isEmpty)return const Icon(Icons.school,color:Colors.white);final file=File(p.isAbsolute(path)?path:p.join(AppPaths.root.path,path));return Image.file(file,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.school,color:Colors.white));}
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: width < 900 ? 218 : 252,
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 24, 14, 18),
                  child: Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)),
                        child: _logo(),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_settings['school_name'] ?? 'Sreerampur Madrasah', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            const Text('ম্যানেজমেন্ট সফটওয়্যার', style: TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    children: _modulesByGroup.entries.expand((group) => [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 8, 6),
                        child: Text(group.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54)),
                      ),
                      ...group.value.map((id) {
                        final selected = _page == id;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            dense: true,
                            selected: selected,
                            selectedColor: _green,
                            selectedTileColor: const Color(0xFFE8F3ED),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            leading: Icon(_iconFor(id), size: 19),
                            title: Text(titleOf(id), style: const TextStyle(fontSize: 13)),
                            onTap: () => _go(id),
                          ),
                        );
                      }),
                    ]).toList(),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(child: Text(AppPaths.dataRoot ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black54))),
                      IconButton(tooltip: 'লগ আউট', onPressed: widget.onLogout, icon: const Icon(Icons.logout, size: 19)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 70,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(titleOf(_page), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            Text(_settings['school_address'] ?? 'Offline · local SQLite', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                          ],
                        ),
                      ),
                      IconButton(tooltip: 'সেটিংস', onPressed: () => _go('settings'), icon: const Icon(Icons.settings_outlined)),
                      const SizedBox(width: 8),
                      const CircleAvatar(backgroundColor: Color(0xFFE8F3ED), foregroundColor: _green, child: Icon(Icons.person_outline)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: _page == 'dashboard'
                        ? DashboardPage(key: const ValueKey('dashboard'), repository: widget.repository, onNavigate: _go)
                        : _page == 'settings'
                            ? SettingsPage(key: const ValueKey('settings'), repository: widget.repository, settings: _settings, onChanged: _loadSettings)
                            : _page == 'backup'
                                ? BackupPage(key: const ValueKey('backup'), repository: widget.repository)
                                : _page == 'reports'
                                    ? ReportsPage(key: const ValueKey('reports'), repository: widget.repository)
                                    : _page == 'cloud_sync'
                                        ? CloudSyncPage(key: const ValueKey('cloud_sync'), repository: widget.repository)
                                        : RecordListPage(key: ValueKey(_page), module: madrasaModules.firstWhere((m) => m.key == _page), repository: widget.repository),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String key)=>switch(key){'dashboard'=>Icons.dashboard_outlined,'students'=>Icons.groups_outlined,'teachers'=>Icons.cast_for_education_outlined,'staff'=>Icons.badge_outlined,'classes'=>Icons.class_outlined,'subjects'=>Icons.menu_book_outlined,'attendance'||'teacher_attendance'||'staff_attendance'=>Icons.fact_check_outlined,'exams'||'marks'=>Icons.school_outlined,'fees'||'income'||'accounts'=>Icons.account_balance_wallet_outlined,'expenses'=>Icons.money_off_csred_outlined,'homework'=>Icons.edit_note,'notices'=>Icons.campaign_outlined,'books'||'library_transactions'=>Icons.local_library_outlined,'reports'=>Icons.bar_chart_outlined,'settings'=>Icons.settings_outlined,'backup'=>Icons.backup_outlined,'cloud_sync'=>Icons.cloud_sync_outlined,_=>Icons.circle_outlined};

String _friendly(Object error){unawaited(AppLogger.write(error,StackTrace.current));final x=error.toString();if(x.contains('UNIQUE constraint failed'))return 'একই ID বা নম্বর আগে থেকেই আছে। নতুন নম্বর ব্যবহার করুন।';if(x.contains('FOREIGN KEY constraint failed'))return 'অন্য রেকর্ডের সঙ্গে যুক্ত তথ্য মুছতে বা বদলাতে পারবেন না। আগে সম্পর্কিত রেকর্ড সামলান।';if(x.contains('CHECK constraint failed'))return 'টাকার পরিমাণ বা নির্বাচিত তথ্য সঠিক নয়।';if(x.contains('DatabaseException'))return 'Database-এর তথ্য সংরক্ষণ করা যায়নি। প্রয়োজনীয় ঘর ও সম্পর্কিত রেকর্ড পরীক্ষা করুন। বিস্তারিত technical.log-এ লেখা হয়েছে।';if(error is FormatException)return x.replaceFirst('FormatException: ','');if(error is FileSystemException)return 'Folder বা file-এ প্রবেশ করা যাচ্ছে না। Drive এবং permission পরীক্ষা করুন।';return x.replaceFirst('Exception: ','').replaceFirst('Bad state: ','');}

void _showMessage(BuildContext context,String message,{bool error=false}){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message),backgroundColor:error?Colors.red.shade700:null));}

/// Local PDF generation and the native Windows print dialog; no browser is used.
class MadrasaPrint {
  static Future<pw.Font> _font() async {
    const candidates = [r'C:\Windows\Fonts\Nirmala.ttf', r'C:\Windows\Fonts\NirmalaUI.ttf'];
    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) return pw.Font.ttf(await file.readAsBytes().then((b) => b.buffer.asByteData()));
    }
    throw StateError('Bangla PDF font পাওয়া যায়নি। Windows-এ Nirmala UI font থাকতে হবে।');
  }

  static Future<void> table(String title,List<String> headers,List<List<String>> rows,Map<String,String> settings) async {
    final font=await _font();
    final doc=pw.Document(theme:pw.ThemeData.withFont(base:font,bold:font));
    doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4.landscape,margin:const pw.EdgeInsets.all(28),theme:pw.ThemeData.withFont(base:font,bold:font),build:(context)=>[
      _heading(title,settings,font),pw.SizedBox(height:14),
      if(rows.isEmpty)pw.Text('কোনো তথ্য নেই') else pw.TableHelper.fromTextArray(headers:headers,data:rows,headerDecoration:const pw.BoxDecoration(color:PdfColor.fromInt(0xFFE8F3ED)),headerStyle:pw.TextStyle(font:font,fontWeight:pw.FontWeight.bold,fontSize:8),cellStyle:pw.TextStyle(font:font,fontSize:7),cellPadding:const pw.EdgeInsets.symmetric(horizontal:4,vertical:5),border:pw.TableBorder.all(color:const PdfColor.fromInt(0xFFCED8D2),width:.4)),
      pw.SizedBox(height:12),pw.Align(alignment:pw.Alignment.centerRight,child:pw.Text('প্রস্তুতের তারিখ: ${DateTime.now().toIso8601String().substring(0,10)}',style:pw.TextStyle(font:font,fontSize:8))),
    ]));
    await Printing.layoutPdf(onLayout:(_)=>doc.save(),name:'madrasa-report.pdf');
  }

  static Future<void> student(Map<String,Object?> row,Map<String,String> settings,String className) async {
    await table('শিক্ষার্থী প্রোফাইল',const ['তথ্য','বিবরণ'],[
      ['শিক্ষার্থী আইডি','${row['student_id']??'—'}'],['নাম','${row['name']??'—'}'],['পিতার নাম','${row['father_name']??'—'}'],['মাতার নাম','${row['mother_name']??'—'}'],['শ্রেণি',className],['রোল','${row['roll']??'—'}'],['অভিভাবকের মোবাইল','${row['guardian_phone']??row['phone']??'—'}'],['ঠিকানা','${row['address']??'—'}'],['অবস্থা','${row['status']??'—'}']],settings);
  }

  static Future<void> receipt(Map<String,Object?> row,Map<String,String> settings,String studentName) async {
    final amount=(row['paid'] as num? ?? 0).toDouble();
    await table('ফি জমার রসিদ',const ['বিবরণ','তথ্য'],[
      ['রসিদ নম্বর','${row['receipt_no']??'—'}'],['শিক্ষার্থী',studentName],['ফি-এর ধরন','${row['category']??'—'}'],['মোট','৳ ${row['total']??0}'],['ছাড়','৳ ${row['discount']??0}'],['জমা','৳ ${amount.toStringAsFixed(2)}'],['তারিখ','${row['date']??'—'}'],['পেমেন্ট','${row['method']??'—'}']],settings);
  }

  static pw.Widget _heading(String title,Map<String,String> settings,pw.Font font) {
    return pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
      pw.Text(settings['school_name']??'Sreerampur Madrasah',style:pw.TextStyle(font:font,fontSize:18,fontWeight:pw.FontWeight.bold)),
      if((settings['school_address']??'').isNotEmpty)pw.Text(settings['school_address']!,style:pw.TextStyle(font:font,fontSize:9)),
      if((settings['school_phone']??'').isNotEmpty)pw.Text(settings['school_phone']!,style:pw.TextStyle(font:font,fontSize:9)),
      pw.SizedBox(height:8),pw.Text(title,style:pw.TextStyle(font:font,fontSize:14,fontWeight:pw.FontWeight.bold)),pw.Divider(),
    ]);
  }
}

