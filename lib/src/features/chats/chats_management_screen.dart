import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Chat Rooms Management Screen
// List, close, delete chat rooms; ban users from chat
// ─────────────────────────────────────────────────────────────────────────────

class ChatsManagementScreen extends StatefulWidget {
  const ChatsManagementScreen({super.key});

  @override
  State<ChatsManagementScreen> createState() => _ChatsManagementScreenState();
}

class _ChatsManagementScreenState extends State<ChatsManagementScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchAdminChatRooms();
      if (!mounted) return;
      setState(() { _rooms = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _closeRoom(Map<String, dynamic> room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إغلاق المحادثة'),
        content: const Text('هل تريد إغلاق هذه المحادثة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إغلاق')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AdminDataService>().closeChatRoom(room['id'].toString());
      if (mounted) _showOk(context, 'تم إغلاق المحادثة');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _deleteRoom(Map<String, dynamic> room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المحادثة'),
        content: const Text('هل تريد حذف هذه المحادثة نهائياً؟'),
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
      await context.read<AdminDataService>().deleteChatRoom(room['id'].toString());
      if (mounted) _showOk(context, 'تم حذف المحادثة');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _banUser(Map<String, dynamic> room) async {
    final userId = room['user1_id']?.toString() ?? room['user_id']?.toString();
    if (userId == null) {
      _showErr(context, 'لا يمكن تحديد المستخدم');
      return;
    }
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حظر المستخدم من المحادثات'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'سبب الحظر (اختياري)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حظر'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AdminDataService>().banUserFromChat(userId, reason: reasonCtrl.text.trim());
      if (mounted) _showOk(context, 'تم حظر المستخدم');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Color _statusColor(dynamic s) {
    switch (s?.toString().toLowerCase()) {
      case 'open': return const Color(0xFF17B26A);
      case 'closed': return Colors.grey;
      default: return Colors.orange;
    }
  }

  String _statusLabel(dynamic s) {
    switch (s?.toString().toLowerCase()) {
      case 'open': return 'مفتوحة';
      case 'closed': return 'مغلقة';
      default: return s?.toString() ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('إدارة المحادثات',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('مراقبة وإدارة محادثات المستخدمين.',
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
                      Text('غرف المحادثة',
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
                  else if (_rooms.isEmpty)
                    const Expanded(child: Center(child: Text('لا توجد محادثات')))
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
                              DataColumn(label: Text('المشاركون')),
                              DataColumn(label: Text('آخر رسالة')),
                              DataColumn(label: Text('الحالة')),
                              DataColumn(label: Text('الإجراءات')),
                            ],
                            rows: _rooms.asMap().entries.map((e) {
                              final i = e.key;
                              final room = e.value;
                              return DataRow(cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(SizedBox(
                                  width: 200,
                                  child: Text(
                                    '${_str(room['user1_name'] ?? room['participant1'], '')} ↔ ${_str(room['user2_name'] ?? room['participant2'], '')}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                                DataCell(SizedBox(
                                  width: 220,
                                  child: Text(
                                    _str(room['last_message'] ?? room['lastMessage'], ''),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                )),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(room['status']).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(_statusLabel(room['status']),
                                      style: TextStyle(color: _statusColor(room['status']), fontWeight: FontWeight.w600)),
                                )),
                                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                  if (room['status']?.toString().toLowerCase() == 'open')
                                    IconButton(
                                      icon: const Icon(Icons.lock_outline, color: Colors.orange),
                                      tooltip: 'إغلاق',
                                      onPressed: () => _closeRoom(room),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.person_off_outlined, color: Colors.purple),
                                    tooltip: 'حظر مستخدم',
                                    onPressed: () => _banUser(room),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'حذف',
                                    onPressed: () => _deleteRoom(room),
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
