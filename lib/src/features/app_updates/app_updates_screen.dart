import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// App Updates Management Screen — version management CRUD
// Backed by app_updates table via /admin/app-updates endpoints
// ─────────────────────────────────────────────────────────────────────────────

class AppUpdatesScreen extends StatefulWidget {
  const AppUpdatesScreen({super.key});

  @override
  State<AppUpdatesScreen> createState() => _AppUpdatesScreenState();
}

class _AppUpdatesScreenState extends State<AppUpdatesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _updates = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchAppUpdates();
      if (!mounted) return;
      setState(() { _updates = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _showForm({Map<String, dynamic>? item}) async {
    final versionCtrl   = TextEditingController(text: _str(item?['version_name'] ?? item?['version'], ''));
    final buildCtrl     = TextEditingController(text: _str(item?['build_number'] ?? item?['build'], ''));
    final notesCtrl     = TextEditingController(text: _str(item?['release_notes'] ?? item?['notes'], ''));
    final playStoreCtrl = TextEditingController(text: _str(item?['play_store_url'], ''));
    final appStoreCtrl  = TextEditingController(text: _str(item?['app_store_url'], ''));
    String platform     = _str(item?['platform'], 'both');
    bool isForced       = item?['is_forced'] == true;
    final id = item?['id']?.toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(id == null ? 'إضافة إصدار جديد' : 'تعديل الإصدار'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: versionCtrl,
                    decoration: const InputDecoration(labelText: 'اسم الإصدار *', hintText: '1.2.3')),
                const SizedBox(height: 10),
                TextField(controller: buildCtrl,
                    decoration: const InputDecoration(labelText: 'رقم البناء', hintText: '42'),
                    keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: platform,
                  decoration: const InputDecoration(labelText: 'المنصة'),
                  items: ['both', 'android', 'ios']
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p == 'both' ? 'كلتا المنصتين' : p == 'android' ? 'Android' : 'iOS'),
                          ))
                      .toList(),
                  onChanged: (v) => setSt(() => platform = v ?? 'both'),
                ),
                const SizedBox(height: 10),
                TextField(controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'ملاحظات الإصدار', alignLabelWithHint: true,
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: playStoreCtrl,
                    decoration: const InputDecoration(labelText: 'رابط Google Play')),
                const SizedBox(height: 10),
                TextField(controller: appStoreCtrl,
                    decoration: const InputDecoration(labelText: 'رابط App Store')),
                const SizedBox(height: 6),
                SwitchListTile(
                  title: const Text('تحديث إجباري'),
                  value: isForced,
                  onChanged: (v) => setSt(() => isForced = v),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (versionCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final payload = <String, dynamic>{
      'version_name': versionCtrl.text.trim(),
      'platform': platform,
      'is_forced': isForced,
      if (buildCtrl.text.trim().isNotEmpty) 'build_number': int.tryParse(buildCtrl.text.trim()),
      if (notesCtrl.text.trim().isNotEmpty) 'release_notes': notesCtrl.text.trim(),
      if (playStoreCtrl.text.trim().isNotEmpty) 'play_store_url': playStoreCtrl.text.trim(),
      if (appStoreCtrl.text.trim().isNotEmpty) 'app_store_url': appStoreCtrl.text.trim(),
    };
    try {
      final svc = context.read<AdminDataService>();
      if (id == null) {
        await svc.createAppUpdate(payload);
      } else {
        await svc.updateAppUpdate(id, payload);
      }
      if (mounted) _showOk(context, id == null ? 'تم إضافة الإصدار' : 'تم تحديث الإصدار');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> update) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإصدار'),
        content: Text('هل تريد حذف الإصدار "${_str(update['version_name'] ?? update['version'])}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AdminDataService>().deleteAppUpdate(update['id'].toString());
      if (mounted) _showOk(context, 'تم حذف الإصدار');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('إدارة التحديثات',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('إدارة إصدارات التطبيق وروابط التحديث والتحديثات الإجبارية.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('الإصدارات',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'تحديث'),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('إصدار جديد'),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_loading)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
                  else if (_updates.isEmpty)
                    const Expanded(child: Center(child: Text('لا توجد إصدارات مسجلة')))
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('الإصدار')),
                              DataColumn(label: Text('البناء')),
                              DataColumn(label: Text('المنصة')),
                              DataColumn(label: Text('إجباري')),
                              DataColumn(label: Text('تاريخ النشر')),
                              DataColumn(label: Text('الإجراءات')),
                            ],
                            rows: _updates.asMap().entries.map((e) {
                              final i = e.key;
                              final u = e.value;
                              final isForced = u['is_forced'] == true;
                              return DataRow(cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(Text(_str(u['version_name'] ?? u['version']),
                                    style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text(u['build_number']?.toString() ?? '-')),
                                DataCell(Text(_str(u['platform'], ''))),
                                DataCell(Icon(isForced ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                    color: isForced ? Colors.orange : Colors.grey, size: 20)),
                                DataCell(Text(_fmtDate(u['created_at'] ?? u['released_at']))),
                                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'تعديل',
                                    onPressed: () => _showForm(item: u),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'حذف',
                                    onPressed: () => _delete(u),
                                  ),
                                ])),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── helpers ─────────────────────────────────────────────────────────────────
String _str(dynamic v, [String fallback = '-']) =>
    v?.toString().trim().isEmpty == false ? v.toString().trim() : fallback;

String _fmtDate(dynamic v) {
  final s = v?.toString() ?? '';
  return s.contains('T') ? s.split('T').first : (s.isEmpty ? '-' : s);
}

String _extractError(dynamic err) {
  if (err is DioException) {
    final d = err.response?.data;
    if (d is Map) {
      final msg = d['message'] ?? d['error'] ?? d['msg'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
  }
  return err.toString();
}

void _showErr(BuildContext ctx, String msg) => ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));

void _showOk(BuildContext ctx, String msg) => ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: const Color(0xFF17B26A), behavior: SnackBarBehavior.floating));
