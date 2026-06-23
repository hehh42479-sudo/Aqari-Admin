import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Advertisements Management Screen — full CRUD backed by real DB
// ─────────────────────────────────────────────────────────────────────────────

class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _ads = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchAds();
      if (!mounted) return;
      setState(() { _ads = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _showForm({Map<String, dynamic>? item}) async {
    final titleCtrl = TextEditingController(text: _str(item?['title'], ''));
    final urlCtrl   = TextEditingController(text: _str(item?['link_url'] ?? item?['url'], ''));
    final imgCtrl   = TextEditingController(text: _str(item?['image_url'], ''));
    String placement = _str(item?['placement'], 'banner');
    bool isActive = item?['is_active'] != false;
    final id = item?['id']?.toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(id == null ? 'إضافة إعلان' : 'تعديل الإعلان'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'العنوان *')),
              const SizedBox(height: 10),
              TextField(controller: imgCtrl,
                  decoration: const InputDecoration(labelText: 'رابط الصورة')),
              const SizedBox(height: 10),
              TextField(controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'رابط الوجهة')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: placement,
                decoration: const InputDecoration(labelText: 'الموضع'),
                items: ['banner', 'popup', 'sidebar', 'footer']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setSt(() => placement = v ?? 'banner'),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                title: const Text('مفعّل'),
                value: isActive,
                onChanged: (v) => setSt(() => isActive = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
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
      'title': titleCtrl.text.trim(),
      'placement': placement,
      'is_active': isActive,
      if (imgCtrl.text.trim().isNotEmpty) 'image_url': imgCtrl.text.trim(),
      if (urlCtrl.text.trim().isNotEmpty) 'link_url': urlCtrl.text.trim(),
    };
    try {
      final svc = context.read<AdminDataService>();
      if (id == null) {
        await svc.createAd(payload);
      } else {
        await svc.updateAd(id, payload);
      }
      if (mounted) _showOk(context, id == null ? 'تمت الإضافة بنجاح' : 'تم التعديل بنجاح');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> ad) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: Text('هل تريد حذف "${_str(ad['title'])}"؟'),
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
      await context.read<AdminDataService>().deleteAd(ad['id'].toString());
      if (mounted) _showOk(context, 'تم حذف الإعلان');
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
        Text('إدارة الإعلانات',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('إضافة وتعديل وحذف الإعلانات التي تظهر في التطبيق.',
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
                      Text('الإعلانات',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'تحديث'),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة إعلان'),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_loading)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
                  else if (_ads.isEmpty)
                    const Expanded(child: Center(child: Text('لا توجد إعلانات')))
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
                              DataColumn(label: Text('العنوان')),
                              DataColumn(label: Text('الموضع')),
                              DataColumn(label: Text('الحالة')),
                              DataColumn(label: Text('الإجراءات')),
                            ],
                            rows: _ads.asMap().entries.map((e) {
                              final i = e.key;
                              final ad = e.value;
                              final isActive = ad['is_active'] != false;
                              return DataRow(cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(SizedBox(
                                  width: 200,
                                  child: Text(_str(ad['title']),
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                )),
                                DataCell(Text(_str(ad['placement'], ''))),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isActive ? const Color(0xFF17B26A) : Colors.grey).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(isActive ? 'نشط' : 'معطل',
                                      style: TextStyle(
                                          color: isActive ? const Color(0xFF17B26A) : Colors.grey,
                                          fontWeight: FontWeight.w600)),
                                )),
                                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: 'تعديل',
                                    onPressed: () => _showForm(item: ad),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'حذف',
                                    onPressed: () => _delete(ad),
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
