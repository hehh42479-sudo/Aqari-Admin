import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Security Management Screen
// 3 tabs: Banned Users | Banned Devices | Login Attempts
// ─────────────────────────────────────────────────────────────────────────────

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('إدارة الأمان',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('مراقبة المستخدمين المحظورين والأجهزة ومحاولات الدخول.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF082949),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF082949),
          tabs: const [
            Tab(text: 'المستخدمون المحظورون'),
            Tab(text: 'الأجهزة المحظورة'),
            Tab(text: 'محاولات الدخول'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _BannedUsersTab(),
              _BannedDevicesTab(),
              _LoginAttemptsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banned Users Tab
// ─────────────────────────────────────────────────────────────────────────────

class _BannedUsersTab extends StatefulWidget {
  const _BannedUsersTab();

  @override
  State<_BannedUsersTab> createState() => _BannedUsersTabState();
}

class _BannedUsersTabState extends State<_BannedUsersTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchBannedUsers();
      if (!mounted) return;
      setState(() { _users = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _banUser() async {
    final idCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حظر مستخدم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'معرف المستخدم *'),
              keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'سبب الحظر')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (idCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('حظر'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AdminDataService>().banUser(idCtrl.text.trim(), reason: reasonCtrl.text.trim());
      if (mounted) _showOk(context, 'تم حظر المستخدم');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _unban(Map<String, dynamic> user) async {
    try {
      await context.read<AdminDataService>().unbanUser(user['user_id']?.toString() ?? user['id'].toString());
      if (mounted) _showOk(context, 'تم رفع الحظر');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('المستخدمون المحظورون',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _banUser,
                  icon: const Icon(Icons.person_add_disabled_outlined),
                  label: const Text('حظر مستخدم'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
            const Divider(),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
            else if (_users.isEmpty)
              const Expanded(child: Center(child: Text('لا يوجد مستخدمون محظورون')))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('الاسم')),
                        DataColumn(label: Text('السبب')),
                        DataColumn(label: Text('تاريخ الحظر')),
                        DataColumn(label: Text('الإجراء')),
                      ],
                      rows: _users.asMap().entries.map((e) {
                        final user = e.value;
                        return DataRow(cells: [
                          DataCell(Text('${e.key + 1}')),
                          DataCell(Text(_str(user['name'] ?? user['user_name']))),
                          DataCell(SizedBox(width: 200, child: Text(_str(user['reason'] ?? user['ban_reason'], ''), maxLines: 2))),
                          DataCell(Text(_fmtDate(user['banned_at'] ?? user['created_at']))),
                          DataCell(TextButton(
                            onPressed: () => _unban(user),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF17B26A)),
                            child: const Text('رفع الحظر'),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banned Devices Tab
// ─────────────────────────────────────────────────────────────────────────────

class _BannedDevicesTab extends StatefulWidget {
  const _BannedDevicesTab();

  @override
  State<_BannedDevicesTab> createState() => _BannedDevicesTabState();
}

class _BannedDevicesTabState extends State<_BannedDevicesTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchBannedDevices();
      if (!mounted) return;
      setState(() { _devices = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _unban(Map<String, dynamic> device) async {
    try {
      final id = device['device_id']?.toString() ?? device['id']?.toString() ?? '';
      await context.read<AdminDataService>().unbanDevice(id);
      if (mounted) _showOk(context, 'تم رفع الحظر عن الجهاز');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('الأجهزة المحظورة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              ],
            ),
            const Divider(),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
            else if (_devices.isEmpty)
              const Expanded(child: Center(child: Text('لا توجد أجهزة محظورة')))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('معرف الجهاز')),
                        DataColumn(label: Text('السبب')),
                        DataColumn(label: Text('تاريخ الحظر')),
                        DataColumn(label: Text('الإجراء')),
                      ],
                      rows: _devices.asMap().entries.map((e) {
                        final d = e.value;
                        return DataRow(cells: [
                          DataCell(Text('${e.key + 1}')),
                          DataCell(SizedBox(width: 180, child: Text(_str(d['device_id'] ?? d['id']), maxLines: 1, overflow: TextOverflow.ellipsis))),
                          DataCell(Text(_str(d['reason'] ?? d['ban_reason'], ''))),
                          DataCell(Text(_fmtDate(d['banned_at'] ?? d['created_at']))),
                          DataCell(TextButton(
                            onPressed: () => _unban(d),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF17B26A)),
                            child: const Text('رفع الحظر'),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Login Attempts Tab
// ─────────────────────────────────────────────────────────────────────────────

class _LoginAttemptsTab extends StatefulWidget {
  const _LoginAttemptsTab();

  @override
  State<_LoginAttemptsTab> createState() => _LoginAttemptsTabState();
}

class _LoginAttemptsTabState extends State<_LoginAttemptsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _attempts = [];
  bool _failedOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchLoginAttempts(failedOnly: _failedOnly ? true : null);
      if (!mounted) return;
      setState(() { _attempts = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('محاولات الدخول',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 16),
                FilterChip(
                  label: const Text('الفاشلة فقط'),
                  selected: _failedOnly,
                  onSelected: (v) { setState(() => _failedOnly = v); _load(); },
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              ],
            ),
            const Divider(),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
            else if (_attempts.isEmpty)
              const Expanded(child: Center(child: Text('لا توجد محاولات مسجلة')))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('المستخدم / الهاتف')),
                        DataColumn(label: Text('عنوان IP')),
                        DataColumn(label: Text('الحالة')),
                        DataColumn(label: Text('الوقت')),
                      ],
                      rows: _attempts.asMap().entries.map((e) {
                        final a = e.value;
                        final success = a['success'] == true || a['status']?.toString().toLowerCase() == 'success';
                        return DataRow(cells: [
                          DataCell(Text('${e.key + 1}')),
                          DataCell(Text(_str(a['phone'] ?? a['user'] ?? a['identifier']))),
                          DataCell(Text(_str(a['ip_address'] ?? a['ip'], ''))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (success ? const Color(0xFF17B26A) : Colors.red).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(success ? 'ناجح' : 'فاشل',
                                style: TextStyle(
                                    color: success ? const Color(0xFF17B26A) : Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                          )),
                          DataCell(Text(_fmtDate(a['created_at'] ?? a['timestamp']))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
