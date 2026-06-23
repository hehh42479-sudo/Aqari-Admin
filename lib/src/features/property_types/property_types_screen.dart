import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Property Types Management Screen — full CRUD backed by real DB
// ─────────────────────────────────────────────────────────────────────────────

class PropertyTypesScreen extends StatefulWidget {
  const PropertyTypesScreen({super.key});

  @override
  State<PropertyTypesScreen> createState() => _PropertyTypesScreenState();
}

class _PropertyTypesScreenState extends State<PropertyTypesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchPropertyTypes();
      if (!mounted) return;
      setState(() { _items = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _showForm({Map<String, dynamic>? item}) async {
    final nameAr = TextEditingController(text: _str(item?['name_ar'], ''));
    final nameEn = TextEditingController(text: _str(item?['name_en'], ''));
    final icon  = TextEditingController(text: _str(item?['icon'], ''));
    final id = item?['id']?.toString();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id == null ? 'إضافة نوع عقار' : 'تعديل نوع عقار'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameAr, decoration: const InputDecoration(labelText: 'الاسم بالعربية *')),
          const SizedBox(height: 12),
          TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية')),
          const SizedBox(height: 12),
          TextField(controller: icon, decoration: const InputDecoration(labelText: 'الأيقونة (اختياري)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameAr.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final payload = <String, dynamic>{
      'name_ar': nameAr.text.trim(),
      'name_en': nameEn.text.trim(),
      if (icon.text.trim().isNotEmpty) 'icon': icon.text.trim(),
    };
    try {
      final svc = context.read<AdminDataService>();
      if (id == null) {
        await svc.createPropertyType(payload);
      } else {
        await svc.updatePropertyType(id, payload);
      }
      if (mounted) _showOk(context, id == null ? 'تمت الإضافة بنجاح' : 'تم التعديل بنجاح');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف نوع العقار'),
        content: Text('هل تريد حذف "${_str(item['name_ar'])}"؟ قد يؤثر ذلك على العقارات المرتبطة.'),
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
      await context.read<AdminDataService>().deletePropertyType(item['id'].toString());
      if (mounted) _showOk(context, 'تم الحذف بنجاح');
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
        Text(
          'إدارة أنواع العقارات',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text('إضافة وتعديل وحذف أنواع العقارات المتاحة في المنصة.',
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
                      Text('أنواع العقارات',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'تحديث'),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة نوع'),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_loading)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
                  else if (_items.isEmpty)
                    const Expanded(child: Center(child: Text('لا توجد أنواع عقارات مسجلة')))
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(_str(item['icon'], _str(item['name_ar'], '?').characters.first)),
                            ),
                            title: Text(_str(item['name_ar'])),
                            subtitle: Text(_str(item['name_en'], '')),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(item: item)),
                              IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _delete(item)),
                            ]),
                          );
                        },
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

void _showErr(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: Colors.redAccent,
    behavior: SnackBarBehavior.floating,
  ));
}

void _showOk(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: const Color(0xFF17B26A),
    behavior: SnackBarBehavior.floating,
  ));
}
