import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

import '../data/appwrite_sync.dart';
import '../data/madrasa_repository.dart';

class CloudSyncPage extends StatefulWidget {
  const CloudSyncPage({super.key, required this.repository});
  final MadrasaRepository repository;

  @override
  State<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends State<CloudSyncPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _signedIn = false;
  String _message = 'একই Appwrite account Web ও Windows app-এ ব্যবহার করুন।';

  @override
  void initState() {
    super.initState();
    _refreshSession();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _refreshSession() async {
    try {
      await AppwriteCloudSync.instance.currentUser();
      if (mounted) setState(() => _signedIn = true);
    } catch (_) {
      if (mounted) setState(() => _signedIn = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _message = 'Appwrite-এর সঙ্গে যোগাযোগ হচ্ছে…'; });
    try {
      await action();
      await _refreshSession();
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object error) {
    if (error is AppwriteException) {
      if (error.code == 401) return 'ইমেইল বা পাসওয়ার্ড সঠিক নয়।';
      if (error.code == 409) return 'এই ইমেইলে account আগে থেকেই আছে—লগইন করুন।';
      return 'Appwrite error: ${error.message ?? error.type ?? error.code}';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<String?> _chooseConflict(SyncConflict conflict) async {
    final result = await showDialog<String>(context: context, barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('দুই app-এ তথ্য আলাদা'),
        content: Text('${conflict.collection} / ${conflict.id}\n\nকোন তথ্যটি রাখবেন?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Sync থামান')),
          TextButton(onPressed: () => Navigator.pop(context, 'cloud'), child: const Text('Web / Cloud-এরটি রাখুন')),
          FilledButton(onPressed: () => Navigator.pop(context, 'local'), child: const Text('এই Windows-এরটি রাখুন')),
        ],
      ));
    return result;
  }

  Future<void> _sync() async {
    await _run(() async {
      final report = await AppwriteCloudSync.instance.synchronize(widget.repository, _chooseConflict);
      if (!mounted) return;
      setState(() => _message = 'Sync সম্পন্ন · ${report.records}টি record · পাঠানো ${report.pushed} · আনা ${report.pulled} · conflict সমাধান ${report.conflictsResolved}।');
    });
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 660),
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Web ও Windows-এর তথ্য Appwrite-এ মিলিয়ে নিন। Sync চালালে দুই app-এ একই Appwrite account ব্যবহার করুন।', style: TextStyle(height: 1.5)),
            const SizedBox(height: 20),
            if (!_signedIn) ...[
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'ইমেইল / Gmail')),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'পাসওয়ার্ড')),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 8, children: [
                FilledButton(onPressed: _busy ? null : () => _run(() => AppwriteCloudSync.instance.signIn(_email.text, _password.text)), child: const Text('লগইন')),
                OutlinedButton(onPressed: _busy ? null : () => _run(() => AppwriteCloudSync.instance.createAccount(_email.text, _password.text)), child: const Text('নতুন account তৈরি')),
              ]),
            ] else ...[
              const Row(children: [Icon(Icons.cloud_done_outlined, color: Colors.green), SizedBox(width: 8), Text('Appwrite account সংযুক্ত')]),
              const SizedBox(height: 14),
              Wrap(spacing: 10, children: [
                FilledButton.icon(onPressed: _busy ? null : _sync, icon: const Icon(Icons.sync), label: const Text('এখন Sync করুন')),
                OutlinedButton(onPressed: _busy ? null : () => _run(() async { await AppwriteCloudSync.instance.signOut(); if (mounted) setState(() => _message = 'Appwrite থেকে লগআউট হয়েছে।'); }), child: const Text('লগআউট')),
              ]),
            ],
            const SizedBox(height: 18),
            Text(_message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            const Text('তথ্য আগে স্থানীয়ভাবে সংরক্ষিত হবে। Conflict দেখা দিলে আপনার পছন্দ ছাড়া কোনো দিকের তথ্য replace হবে না।', style: TextStyle(color: Colors.black54, fontSize: 12, height: 1.5)),
          ]),
        ),
      ),
    ),
  );
}
