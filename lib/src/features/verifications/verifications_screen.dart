import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';
import '../../core/services/api_service.dart';

/// Admin screen for reviewing account verification requests.
/// Endpoint: GET /admin/verification?status=pending|all
///           PUT /admin/verification/:id  { status: 'approved'|'rejected', note: '...' }
class VerificationsScreen extends StatefulWidget {
  const VerificationsScreen({super.key});

  @override
  State<VerificationsScreen> createState() => _VerificationsScreenState();
}

class _VerificationsScreenState extends State<VerificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  List<VerificationRecord> _all = [];
  List<VerificationRecord> _pending = [];
  List<VerificationRecord> _reviewed = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final service = context.read<AdminDataService>();
      final items = await service.fetchVerifications();
      if (!mounted) return;
      final records = items.map(VerificationRecord.fromJson).toList();
      setState(() {
        _all = records;
        _pending = records.where((r) => r.status == 'pending').toList();
        _reviewed = records.where((r) => r.status != 'pending').toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل طلبات التوثيق';
      });
    }
  }

  Future<void> _review(
      VerificationRecord record, String decision, String note) async {
    try {
      final service = context.read<AdminDataService>();
      await service.reviewVerification(record.id, decision, note);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decision == 'approved'
              ? 'تم قبول طلب التوثيق ✓'
              : 'تم رفض طلب التوثيق'),
          backgroundColor:
              decision == 'approved' ? Colors.green.shade700 : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحديث القرار: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showReviewDialog(VerificationRecord record) async {
    final noteController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A120B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('مراجعة طلب التوثيق',
              style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المستخدم: ${record.userName}',
                  style: const TextStyle(color: Colors.white70)),
              Text('الدور: ${record.userRole}',
                  style: const TextStyle(color: Colors.white70)),
              Text('تاريخ الطلب: ${record.submittedAt}',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  labelStyle: const TextStyle(color: Color(0xFFD4AF37)),
                  filled: true,
                  fillColor: const Color(0xFF2C1A0E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'rejected'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white),
              child: const Text('رفض'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'approved'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF1A120B)),
              child: const Text('قبول'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
    if (result != null && mounted) {
      await _review(record, result, noteController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C1A0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A120B),
        foregroundColor: const Color(0xFFD4AF37),
        centerTitle: true,
        title: const Text('طلبات التوثيق',
            style: TextStyle(
                color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: [
            Tab(text: 'الكل (${_all.length})'),
            Tab(text: 'معلقة (${_pending.length})'),
            Tab(text: 'تمت المراجعة (${_reviewed.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _errorMessage != null
              ? _ErrorView(message: _errorMessage!, onRetry: _load)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _VerificationList(
                        items: _all, onReview: _showReviewDialog),
                    _VerificationList(
                        items: _pending, onReview: _showReviewDialog),
                    _VerificationList(
                        items: _reviewed, onReview: null),
                  ],
                ),
    );
  }
}

class _VerificationList extends StatelessWidget {
  const _VerificationList({required this.items, this.onReview});
  final List<VerificationRecord> items;
  final Future<void> Function(VerificationRecord)? onReview;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('لا توجد طلبات',
            style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {},
      color: const Color(0xFFD4AF37),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) =>
            _VerificationCard(record: items[i], onReview: onReview),
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.record, this.onReview});
  final VerificationRecord record;
  final Future<void> Function(VerificationRecord)? onReview;

  Color get _statusColor {
    switch (record.status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return const Color(0xFFD4AF37);
    }
  }

  String get _statusLabel {
    switch (record.status) {
      case 'approved':
        return 'مقبول ✓';
      case 'rejected':
        return 'مرفوض ✗';
      default:
        return 'قيد المراجعة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3D2510),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _statusColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined,
                  color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.userName,
                  style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: _statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(_statusLabel,
                    style: TextStyle(
                        color: _statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow('الدور', record.userRole),
          _infoRow('رقم الهاتف', record.phone),
          _infoRow('تاريخ الطلب', record.submittedAt),
          if (record.adminNote.isNotEmpty)
            _infoRow('ملاحظة الأدمن', record.adminNote),
          if (record.status == 'pending' && onReview != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onReview!(record),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('مراجعة الطلب'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF1A120B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF1A120B)),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class VerificationRecord {
  const VerificationRecord({
    required this.id,
    required this.userName,
    required this.userRole,
    required this.phone,
    required this.status,
    required this.submittedAt,
    required this.adminNote,
  });

  final String id;
  final String userName;
  final String userRole;
  final String phone;
  final String status;
  final String submittedAt;
  final String adminNote;

  factory VerificationRecord.fromJson(Map<String, dynamic> json) {
    String _s(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    return VerificationRecord(
      id: _s(['id']),
      userName: _s(['userName', 'name', 'user_name', 'fullName']),
      userRole: _s(['userRole', 'role', 'user_role']),
      phone: _s(['phone', 'mobile', 'phoneNumber']),
      status: _s(['status']),
      submittedAt: _s(['submitted_at', 'submittedAt', 'created_at']),
      adminNote: _s(['admin_note', 'adminNote', 'note']),
    );
  }
}
