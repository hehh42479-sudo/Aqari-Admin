import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Content Pages Management Screen
// Dynamic CMS pages (about, terms, privacy, faq…) — upsert via PUT /slug
// ─────────────────────────────────────────────────────────────────────────────

class ContentPagesScreen extends StatefulWidget {
  const ContentPagesScreen({super.key});

  @override
  State<ContentPagesScreen> createState() => _ContentPagesScreenState();
}

class _ContentPagesScreenState extends State<ContentPagesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pages = [];
  Map<String, dynamic>? _editingPage;
  bool _isSaving = false;

  final _slugCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _slugCtrl.dispose();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchContentPages();
      if (!mounted) return;
      setState(() { _pages = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  void _startEdit(Map<String, dynamic>? page) {
    setState(() {
      _editingPage = page;
      _slugCtrl.text = _str(page?['slug'], '');
      _titleCtrl.text = _str(page?['title'], '');
      _bodyCtrl.text = _str(page?['content'] ?? page?['body'], '');
      _isActive = page?['is_active'] != false;
    });
  }

  Future<void> _save() async {
    if (_slugCtrl.text.trim().isEmpty || _titleCtrl.text.trim().isEmpty) {
      _showErr(context, 'الرابط والعنوان مطلوبان');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<AdminDataService>().upsertContentPage(
        _slugCtrl.text.trim(),
        {
          'title': _titleCtrl.text.trim(),
          'content': _bodyCtrl.text.trim(),
          'is_active': _isActive,
        },
      );
      if (mounted) {
        _showOk(context, 'تم الحفظ بنجاح');
        setState(() => _editingPage = null);
        _load();
      }
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('إدارة المحتوى',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('إنشاء وتعديل صفحات المحتوى الديناميكية (شروط، خصوصية، عن التطبيق…).',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: list
              SizedBox(
                width: 260,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text('الصفحات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
                          ],
                        ),
                        const Divider(),
                        ElevatedButton.icon(
                          onPressed: () => _startEdit(null),
                          icon: const Icon(Icons.add),
                          label: const Text('صفحة جديدة'),
                        ),
                        const SizedBox(height: 8),
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else if (_error != null)
                          Text(_error!, style: const TextStyle(color: Colors.red))
                        else
                          Expanded(
                            child: ListView.builder(
                              itemCount: _pages.length,
                              itemBuilder: (_, i) {
                                final p = _pages[i];
                                final isSelected = _editingPage?['id'] == p['id'];
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: const Color(0xFF082949).withOpacity(0.08),
                                  title: Text(_str(p['title']), maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(_str(p['slug'], ''), style: const TextStyle(fontSize: 12)),
                                  trailing: Icon(
                                    p['is_active'] != false ? Icons.check_circle_outline : Icons.cancel_outlined,
                                    size: 16,
                                    color: p['is_active'] != false ? const Color(0xFF17B26A) : Colors.grey,
                                  ),
                                  onTap: () => _startEdit(p),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Right: editor
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _editingPage == null && _slugCtrl.text.isEmpty
                        ? const Center(child: Text('اختر صفحة للتعديل أو أضف صفحة جديدة'))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(_editingPage == null ? 'صفحة جديدة' : 'تعديل الصفحة',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _slugCtrl,
                                readOnly: _editingPage != null,
                                decoration: const InputDecoration(
                                  labelText: 'الرابط (slug) *',
                                  hintText: 'about / terms / privacy',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _titleCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'العنوان *',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: TextField(
                                  controller: _bodyCtrl,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: const InputDecoration(
                                    labelText: 'المحتوى',
                                    alignLabelWithHint: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                title: const Text('الصفحة مفعّلة'),
                                value: _isActive,
                                onChanged: (v) => setState(() => _isActive = v),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => setState(() => _editingPage = null),
                                    child: const Text('إلغاء'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: _isSaving ? null : _save,
                                    child: _isSaving
                                        ? const SizedBox(width: 18, height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Text('حفظ'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
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
