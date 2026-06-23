import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// All Employees Management Screen
// Global list of employees across all offices, with activate/deactivate/delete
// ─────────────────────────────────────────────────────────────────────────────

class AllEmployeesScreen extends StatefulWidget {
  const AllEmployeesScreen({super.key});

  @override
  State<AllEmployeesScreen> createState() => _AllEmployeesScreenState();
}

class _AllEmployeesScreenState extends State<AllEmployeesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _employees = [];
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = context.read<AdminDataService>();
      final data = await svc.fetchAllEmployees(
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() { _employees = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _toggle(Map<String, dynamic> emp) async {
    try {
      await context.read<AdminDataService>().toggleEmployeeStatus(emp['id'].toString());
      if (mounted) _showOk(context, 'تم تحديث حالة الموظف');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> emp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الموظف'),
        content: Text('هل تريد حذف "${_str(emp['name'])}"؟'),
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
      await context.read<AdminDataService>().deleteEmployeeAdmin(emp['id'].toString());
      if (mounted) _showOk(context, 'تم حذف الموظف');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Color _statusColor(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case 'active': return const Color(0xFF17B26A);
      case 'inactive': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _statusLabel(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case 'active': return 'نشط';
      case 'inactive': return 'غير نشط';
      default: return status?.toString() ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('إدارة الموظفين',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('عرض وإدارة جميع الموظفين عبر المكاتب العقارية.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        // Filter bar
        Row(
          children: [
            const Text('الحالة: ', style: TextStyle(fontWeight: FontWeight.w600)),
            ChoiceChip(
              label: const Text('الكل'),
              selected: _statusFilter == 'all',
              onSelected: (_) { setState(() => _statusFilter = 'all'); _load(); },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('نشط'),
              selected: _statusFilter == 'active',
              onSelected: (_) { setState(() => _statusFilter = 'active'); _load(); },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('غير نشط'),
              selected: _statusFilter == 'inactive',
              onSelected: (_) { setState(() => _statusFilter = 'inactive'); _load(); },
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'تحديث'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : _employees.isEmpty
                          ? const Center(child: Text('لا يوجد موظفون'))
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 20,
                                  columns: const [
                                    DataColumn(label: Text('#')),
                                    DataColumn(label: Text('الاسم')),
                                    DataColumn(label: Text('المكتب')),
                                    DataColumn(label: Text('الدور')),
                                    DataColumn(label: Text('الحالة')),
                                    DataColumn(label: Text('الإجراءات')),
                                  ],
                                  rows: _employees.asMap().entries.map((e) {
                                    final i = e.key;
                                    final emp = e.value;
                                    final isActive = emp['status']?.toString().toLowerCase() == 'active';
                                    return DataRow(cells: [
                                      DataCell(Text('${i + 1}')),
                                      DataCell(Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_str(emp['name']), style: const TextStyle(fontWeight: FontWeight.w600)),
                                          Text(_str(emp['phone'], ''), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      )),
                                      DataCell(Text(_str(emp['office_name'] ?? emp['office'], ''))),
                                      DataCell(Text(_str(emp['role'], ''))),
                                      DataCell(Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _statusColor(emp['status']).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(_statusLabel(emp['status']),
                                            style: TextStyle(color: _statusColor(emp['status']), fontWeight: FontWeight.w600)),
                                      )),
                                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(
                                          icon: Icon(isActive ? Icons.toggle_on : Icons.toggle_off,
                                              color: isActive ? const Color(0xFF17B26A) : Colors.grey),
                                          tooltip: isActive ? 'تعطيل' : 'تفعيل',
                                          onPressed: () => _toggle(emp),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          tooltip: 'حذف',
                                          onPressed: () => _delete(emp),
                                        ),
                                      ])),
                                    ]);
                                  }).toList(),
                                ),
                              ),
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
