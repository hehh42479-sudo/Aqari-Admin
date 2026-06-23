import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// System Monitoring Screen
// Real-time server health: CPU, memory, DB connections, uptime
// ─────────────────────────────────────────────────────────────────────────────

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _health = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchSystemHealth();
      if (!mounted) return;
      setState(() { _health = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Widget _metricCard(String label, dynamic value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value?.toString() ?? '-',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthTable() {
    final entries = _health.entries.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('المؤشر')),
          DataColumn(label: Text('القيمة')),
        ],
        rows: entries.map((e) => DataRow(cells: [
          DataCell(Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
          DataCell(Text(e.value?.toString() ?? '-')),
        ])).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uptime   = _health['uptime'] ?? _health['serverUptime'] ?? _health['server_uptime'];
    final mem      = _health['memoryUsage'] ?? _health['memory'] ?? _health['memory_usage'];
    final cpu      = _health['cpuLoad'] ?? _health['cpu'] ?? _health['cpu_load'];
    final dbStatus = _health['database'] ?? _health['db'] ?? _health['db_status'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('مراقبة النظام',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'تحديث'),
          ],
        ),
        const SizedBox(height: 8),
        Text('حالة الخادم والذاكرة والمعالج وقاعدة البيانات في الوقت الفعلي.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 20),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
        else ...[
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(width: 200,
                child: _metricCard('الخادم', dbStatus != null ? (dbStatus.toString().toLowerCase().contains('ok') || dbStatus.toString().toLowerCase().contains('connect') ? 'متصل ✓' : dbStatus) : 'نشط', Icons.dns_outlined, const Color(0xFF17B26A))),
              SizedBox(width: 200, child: _metricCard('وقت التشغيل', uptime, Icons.timer_outlined, const Color(0xFF0B3A66))),
              SizedBox(width: 200, child: _metricCard('استخدام الذاكرة', mem, Icons.memory_outlined, Colors.orange)),
              SizedBox(width: 200, child: _metricCard('حمل المعالج', cpu, Icons.speed_outlined, Colors.purple)),
            ],
          ),
          const SizedBox(height: 24),
          Text('تفاصيل كاملة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(child: _buildHealthTable()),
              ),
            ),
          ),
        ],
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
