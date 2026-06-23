import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Backup Screen
// View backup logs + trigger a new backup (downloads via browser link)
// ─────────────────────────────────────────────────────────────────────────────

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];
  String? _downloadUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = context.read<AdminDataService>();
      final results = await Future.wait([
        svc.fetchBackupLogs(),
        svc.triggerBackupDownloadUrl().then((u) => <Map<String, dynamic>>[{'_url': u}]),
      ]);
      if (!mounted) return;
      setState(() {
        _logs = results[0];
        _downloadUrl = results[1].firstOrNull?['_url']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  String _fmtDate(dynamic v) {
    final s = v?.toString() ?? '';
    if (s.contains('T')) return s.split('T').first;
    return s.isEmpty ? '-' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('النسخ الاحتياطي',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('عرض سجلات النسخ الاحتياطي وتنزيل نسخة احتياطية جديدة من قاعدة البيانات.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),

        // Download card
        Card(
          color: const Color(0xFF082949),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.cloud_download_outlined, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('تنزيل نسخة احتياطية كاملة',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('يتم تصدير جميع جداول قاعدة البيانات بصيغة JSON.',
                          style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF082949),
                  ),
                  onPressed: _downloadUrl == null
                      ? null
                      : () {
                          // Show URL in a dialog — the admin can open it in a browser tab
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('رابط التنزيل'),
                              content: SelectableText(_downloadUrl!),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('إغلاق'),
                                ),
                              ],
                            ),
                          );
                        },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('تنزيل'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Logs table
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('سجلات النسخ الاحتياطي',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'تحديث'),
                    ],
                  ),
                  const Divider(),
                  if (_loading)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
                  else if (_logs.isEmpty)
                    const Expanded(child: Center(child: Text('لا توجد سجلات نسخ احتياطي')))
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('تاريخ النسخ')),
                              DataColumn(label: Text('الحجم')),
                              DataColumn(label: Text('الحالة')),
                              DataColumn(label: Text('منفذ بواسطة')),
                            ],
                            rows: _logs.asMap().entries.map((e) {
                              final i = e.key;
                              final log = e.value;
                              return DataRow(cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(Text(_fmtDate(log['created_at'] ?? log['timestamp']))),
                                DataCell(Text(log['file_size']?.toString() ?? '-')),
                                DataCell(Text(log['status']?.toString() ?? 'مكتمل')),
                                DataCell(Text(log['triggered_by']?.toString() ?? log['admin_name']?.toString() ?? '-')),
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
