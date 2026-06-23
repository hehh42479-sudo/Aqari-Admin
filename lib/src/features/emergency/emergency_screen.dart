import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Emergency Controls Screen
// Maintenance mode, registration lock, booking lock — backed by system_flags table
// ─────────────────────────────────────────────────────────────────────────────

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _flags = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchSystemFlags();
      if (!mounted) return;
      setState(() { _flags = Map<String, dynamic>.from(data); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _saveFlag(String key, bool value) async {
    setState(() => _saving = true);
    try {
      final updated = await context.read<AdminDataService>().updateSystemFlags({key: value});
      if (!mounted) return;
      setState(() {
        _flags = Map<String, dynamic>.from(updated.isNotEmpty ? updated : {..._flags, key: value});
        _saving = false;
      });
      _showOk(context, 'تم تحديث الإعداد بنجاح');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showErr(context, _extractError(e));
      }
    }
  }

  bool _getBool(String key) {
    final v = _flags[key];
    if (v is bool) return v;
    if (v is String) return v == 'true' || v == '1';
    if (v is int) return v == 1;
    return false;
  }

  Widget _flagTile({
    required String label,
    required String description,
    required String flagKey,
    required Color activeColor,
    required IconData icon,
  }) {
    final isOn = _getBool(flagKey);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOn ? activeColor.withOpacity(0.4) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isOn ? activeColor : Colors.grey).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isOn ? activeColor : Colors.grey, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Switch(
                  value: isOn,
                  activeColor: activeColor,
                  onChanged: _saving ? null : (v) => _saveFlag(flagKey, v),
                ),
                Text(
                  isOn ? 'مفعّل' : 'معطّل',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOn ? activeColor : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('مركز الطوارئ',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            if (_saving)
              const Padding(padding: EdgeInsets.only(left: 12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load, tooltip: 'تحديث'),
          ],
        ),
        const SizedBox(height: 8),
        Text('التحكم الفوري في حالات الطوارئ وإيقاف التشغيل.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 20),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
        else
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _flagTile(
                    label: 'وضع الصيانة',
                    description: 'تعطيل التطبيق مؤقتاً وعرض رسالة صيانة للمستخدمين.',
                    flagKey: 'maintenance_mode',
                    activeColor: Colors.orange,
                    icon: Icons.construction_outlined,
                  ),
                  _flagTile(
                    label: 'تعطيل التسجيل',
                    description: 'منع إنشاء حسابات جديدة في التطبيق.',
                    flagKey: 'disable_registration',
                    activeColor: Colors.red,
                    icon: Icons.person_add_disabled_outlined,
                  ),
                  _flagTile(
                    label: 'تعطيل إضافة العقارات',
                    description: 'منع المستخدمين من نشر عقارات جديدة.',
                    flagKey: 'disable_property_posting',
                    activeColor: Colors.red,
                    icon: Icons.home_outlined,
                  ),
                  _flagTile(
                    label: 'تعطيل المحادثات',
                    description: 'إيقاف خاصية المحادثة بين المستخدمين.',
                    flagKey: 'disable_chat',
                    activeColor: Colors.purple,
                    icon: Icons.chat_bubble_outline,
                  ),
                  _flagTile(
                    label: 'وضع القراءة فقط',
                    description: 'السماح بالعرض فقط دون إجراء أي تعديلات.',
                    flagKey: 'read_only_mode',
                    activeColor: Colors.blue,
                    icon: Icons.visibility_outlined,
                  ),
                ],
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

void _showErr(BuildContext ctx, String msg) => ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));

void _showOk(BuildContext ctx, String msg) => ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: const Color(0xFF17B26A), behavior: SnackBarBehavior.floating));
