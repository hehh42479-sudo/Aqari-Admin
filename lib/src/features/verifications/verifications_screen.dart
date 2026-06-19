// ─────────────────────────────────────────────────────────────────────────────
// lib/src/features/verifications/verifications_screen.dart
//
// Account Verification Center — Aqari-Admin
// ──────────────────────────────────────────
// Replaces all dummy data with live API calls via AdminDataService.
//
// Three-tab layout:
//   الكل       — all records
//   معلقة      — status == 'pending'
//   تمت المراجعة — status != 'pending'
//
// Each card shows:
//   • Avatar (initials / role-icon fallback)
//   • Name, role chip, status chip, phone, email, submission date
//   • Document chips (tap to open URL in a dialog)
//   • Notes / admin note / rejection reason
//   • Action buttons: Approve ✓ / Reject ✗ (with reason dialog)  [pending only]
//   • "Grant Badge" button                                         [approved only]
//
// API wiring (via AdminDataService):
//   GET  /admin/verification?status=all
//   PUT  /admin/verification/:id  { status: 'approved'|'rejected', admin_note: '...' }
//
// The AdminDataService already has fetchVerifications() + reviewVerification()
// — no new service methods are needed.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class VerificationRecord {
  const VerificationRecord({
    required this.id,
    required this.userName,
    required this.userRole,
    required this.phone,
    required this.email,
    required this.status,
    required this.submittedAt,
    required this.adminNote,
    required this.documents,
    required this.badgeGranted,
    required this.rawJson,
  });

  final String id;
  final String userName;
  final String userRole;
  final String phone;
  final String email;
  final String status;       // 'pending' | 'approved' | 'rejected'
  final String submittedAt;
  final String adminNote;
  final List<_DocEntry> documents;
  final bool badgeGranted;
  final Map<String, dynamic> rawJson;

  bool get isPending  => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get initials {
    final parts = userName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts[1][0]}';
    return userName.isNotEmpty ? userName[0] : '?';
  }

  String get roleLabel {
    final r = userRole.toLowerCase();
    if (r.contains('office') || r.contains('مكتب')) return 'مكتب عقاري';
    if (r.contains('seeker') || r.contains('باحث')) return 'باحث';
    return 'مالك';
  }

  Color get roleColor {
    final r = userRole.toLowerCase();
    if (r.contains('office')) return const Color(0xFFAB47BC);
    if (r.contains('seeker')) return const Color(0xFF26A69A);
    return const Color(0xFF1D7CF2);
  }

  Color get statusColor {
    switch (status) {
      case 'approved': return const Color(0xFF17B26A);
      case 'rejected': return const Color(0xFFB02A37);
      default:         return const Color(0xFFCA8A04);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'approved': return 'مقبول ✓';
      case 'rejected': return 'مرفوض ✗';
      default:         return 'قيد المراجعة';
    }
  }

  String get formattedDate {
    if (submittedAt.isEmpty) return '—';
    try {
      final dt = DateTime.parse(submittedAt).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return submittedAt;
    }
  }

  factory VerificationRecord.fromJson(Map<String, dynamic> json) {
    String _s(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
      }
      return '';
    }

    final rawStatus = _s(['status', 'verificationStatus']).toLowerCase();
    String status;
    if (rawStatus.contains('approv') || rawStatus == 'verified') {
      status = 'approved';
    } else if (rawStatus.contains('reject') || rawStatus.contains('cancel')) {
      status = 'rejected';
    } else {
      status = 'pending';
    }

    // Build document list
    final rawDocs = json['documents'] ?? json['docs'] ?? json['files'];
    final docs = <_DocEntry>[];
    if (rawDocs is List) {
      for (final d in rawDocs) {
        if (d is Map<String, dynamic>) {
          docs.add(_DocEntry(
            label: d['label'] ?? d['type'] ?? d['name'] ?? 'وثيقة',
            url: d['url'] ?? d['fileUrl'] ?? d['path'],
          ));
        } else if (d is String) {
          docs.add(_DocEntry(label: 'وثيقة', url: d));
        }
      }
    }
    if (docs.isEmpty) {
      // derive from bool/string fields
      const labelMap = {
        'nationalId': 'بطاقة الهوية',
        'national_id': 'بطاقة الهوية',
        'commercialRegister': 'السجل التجاري',
        'commercial_register': 'السجل التجاري',
        'license': 'الترخيص',
        'reraLicense': 'ترخيص هيئة العقار',
        'propertyDeed': 'صك ملكية',
      };
      for (final e in labelMap.entries) {
        final v = json[e.key];
        if (v != null && v != false && v.toString().isNotEmpty) {
          docs.add(_DocEntry(label: e.value, url: v is String ? v : null));
        }
      }
      if (docs.isEmpty) docs.add(const _DocEntry(label: 'وثائق مرفوعة', url: null));
    }

    return VerificationRecord(
      id: _s(['id', '_id', 'verificationId']),
      userName: _s(['userName', 'name', 'user_name', 'fullName']),
      userRole: _s(['userRole', 'role', 'user_role', 'accountType']),
      phone: _s(['phone', 'mobile', 'phoneNumber']),
      email: _s(['email']),
      status: status,
      submittedAt: _s(['submittedAt', 'submitted_at', 'createdAt', 'created_at', 'uploadDate']),
      adminNote: _s(['adminNote', 'admin_note', 'note', 'rejectionReason', 'rejection_reason']),
      documents: docs,
      badgeGranted: json['badgeGranted'] == true || json['badge_granted'] == true ||
          json['isVerified'] == true,
      rawJson: json,
    );
  }
}

class _DocEntry {
  final String label;
  final String? url;
  const _DocEntry({required this.label, this.url});
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

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

  final Set<String> _actionLoading = {};

  List<VerificationRecord> get _pending =>
      _all.where((r) => r.isPending).toList();
  List<VerificationRecord> get _reviewed =>
      _all.where((r) => !r.isPending).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final service = context.read<AdminDataService>();
      final items = await service.fetchVerifications(status: 'all');
      if (!mounted) return;
      setState(() {
        _all = items.map(VerificationRecord.fromJson).toList()
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _errorMessage = 'تعذّر تحميل طلبات التوثيق'; });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _approve(VerificationRecord record) async {
    if (_actionLoading.contains(record.id)) return;
    setState(() => _actionLoading.add(record.id));
    try {
      final service = context.read<AdminDataService>();
      await service.reviewVerification(record.id, 'approved', '');
      if (!mounted) return;
      _showSnack('✓ تمت الموافقة على طلب ${record.userName}', Colors.green.shade700);
      _optimisticUpdate(record, 'approved');
    } catch (e) {
      if (!mounted) return;
      _showSnack('فشلت العملية — ${e.toString()}', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _actionLoading.remove(record.id));
    }
  }

  Future<void> _reject(VerificationRecord record, String reason) async {
    if (_actionLoading.contains(record.id)) return;
    setState(() => _actionLoading.add(record.id));
    try {
      final service = context.read<AdminDataService>();
      await service.reviewVerification(record.id, 'rejected', reason);
      if (!mounted) return;
      _showSnack('✗ تم رفض طلب ${record.userName}', Colors.red.shade700);
      _optimisticUpdate(record, 'rejected', note: reason);
    } catch (e) {
      if (!mounted) return;
      _showSnack('فشلت العملية — ${e.toString()}', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _actionLoading.remove(record.id));
    }
  }

  void _optimisticUpdate(
    VerificationRecord old,
    String newStatus, {
    String note = '',
  }) {
    final idx = _all.indexWhere((r) => r.id == old.id);
    if (idx == -1) return;
    setState(() {
      _all[idx] = VerificationRecord(
        id: old.id, userName: old.userName, userRole: old.userRole,
        phone: old.phone, email: old.email, status: newStatus,
        submittedAt: old.submittedAt,
        adminNote: note.isNotEmpty ? note : old.adminNote,
        documents: old.documents, badgeGranted: old.badgeGranted,
        rawJson: old.rawJson,
      );
    });
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Reject dialog ──────────────────────────────────────────────────────────

  Future<void> _showRejectDialog(VerificationRecord record) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: Color(0xFFB02A37)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('رفض طلب ${record.userName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('سبب الرفض (اختياري):',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 10),
              TextFormField(
                controller: ctrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'مثال: الوثائق غير واضحة أو منتهية الصلاحية...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('تأكيد الرفض'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB02A37),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) await _reject(record, ctrl.text.trim());
    ctrl.dispose();
  }

  // ── Document viewer ────────────────────────────────────────────────────────

  void _viewDocument(BuildContext ctx, _DocEntry doc) {
    showDialog(
      context: ctx,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.description_outlined, color: Color(0xFF0B3A66)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(doc.label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: doc.url != null && doc.url!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      doc.url!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _docPlaceholder(doc.label),
                      loadingBuilder: (_, child, prog) => prog == null
                          ? child
                          : const SizedBox(
                              height: 120,
                              child: Center(child: CircularProgressIndicator())),
                    ),
                  )
                : _docPlaceholder(doc.label),
          ),
          actions: [
            if (doc.url != null && doc.url!.isNotEmpty)
              TextButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: doc.url!)),
                icon: const Icon(Icons.link),
                label: const Text('نسخ الرابط'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _docPlaceholder(String label) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined,
              color: Color(0xFF0B3A66), size: 36),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Page header ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('طلبات التوثيق',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'مراجعة وثائق الهوية والتراخيص والسجلات التجارية',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تحديث'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Summary chips ─────────────────────────────────────────────────
          if (!_isLoading && _errorMessage == null)
            _SummaryBar(
              pending: _pending.length,
              approved: _all.where((r) => r.isApproved).length,
              rejected: _all.where((r) => r.isRejected).length,
              total: _all.length,
            ),

          const SizedBox(height: 14),

          // ── Tab bar ───────────────────────────────────────────────────────
          Card(
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0B3A66),
              unselectedLabelColor: Colors.black54,
              indicatorColor: const Color(0xFF0B3A66),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'الكل (${_all.length})'),
                Tab(text: 'معلقة (${_pending.length})'),
                Tab(text: 'تمت المراجعة (${_reviewed.length})'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Content ───────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _ErrorRetry(message: _errorMessage!, onRetry: _load)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _VerifList(
                            items: _all,
                            actionLoading: _actionLoading,
                            onApprove: _approve,
                            onReject: _showRejectDialog,
                            onViewDoc: (doc) => _viewDocument(context, doc),
                          ),
                          _VerifList(
                            items: _pending,
                            actionLoading: _actionLoading,
                            onApprove: _approve,
                            onReject: _showRejectDialog,
                            onViewDoc: (doc) => _viewDocument(context, doc),
                          ),
                          _VerifList(
                            items: _reviewed,
                            actionLoading: _actionLoading,
                            onApprove: null,
                            onReject: null,
                            onViewDoc: (doc) => _viewDocument(context, doc),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary bar
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.total,
  });

  final int pending, approved, rejected, total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(label: 'الإجمالي',        value: total,    color: const Color(0xFF0B3A66)),
        const SizedBox(width: 10),
        _StatChip(label: 'قيد المراجعة',    value: pending,  color: const Color(0xFFCA8A04)),
        const SizedBox(width: 10),
        _StatChip(label: 'مقبولة',          value: approved, color: const Color(0xFF17B26A)),
        const SizedBox(width: 10),
        _StatChip(label: 'مرفوضة',          value: rejected, color: const Color(0xFFB02A37)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verification list
// ─────────────────────────────────────────────────────────────────────────────

class _VerifList extends StatelessWidget {
  const _VerifList({
    required this.items,
    required this.actionLoading,
    required this.onApprove,
    required this.onReject,
    required this.onViewDoc,
  });

  final List<VerificationRecord> items;
  final Set<String> actionLoading;
  final Future<void> Function(VerificationRecord)? onApprove;
  final Future<void> Function(VerificationRecord)? onReject;
  final void Function(_DocEntry) onViewDoc;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('لا توجد طلبات في هذا القسم.',
            style: TextStyle(color: Colors.black54, fontSize: 15)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _VerifCard(
          record: items[i],
          isActionLoading: actionLoading.contains(items[i].id),
          onApprove: items[i].isPending ? onApprove : null,
          onReject:  items[i].isPending ? onReject  : null,
          onViewDoc: onViewDoc,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verification card
// ─────────────────────────────────────────────────────────────────────────────

class _VerifCard extends StatelessWidget {
  const _VerifCard({
    required this.record,
    required this.isActionLoading,
    required this.onApprove,
    required this.onReject,
    required this.onViewDoc,
  });

  final VerificationRecord record;
  final bool isActionLoading;
  final Future<void> Function(VerificationRecord)? onApprove;
  final Future<void> Function(VerificationRecord)? onReject;
  final void Function(_DocEntry) onViewDoc;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Row(
              children: [
                _AvatarWidget(record: record),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.userName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (record.badgeGranted)
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFF1D7CF2), size: 18),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          _Chip(label: record.roleLabel, color: record.roleColor),
                          _Chip(label: record.statusLabel, color: record.statusColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // ── Meta info ────────────────────────────────────────────────────
            Wrap(
              spacing: 20,
              runSpacing: 6,
              children: [
                if (record.phone.isNotEmpty)
                  _MetaItem(
                    icon: Icons.phone_outlined,
                    label: record.phone,
                    onTap: () => Clipboard.setData(ClipboardData(text: record.phone)),
                  ),
                if (record.email.isNotEmpty)
                  _MetaItem(
                    icon: Icons.email_outlined,
                    label: record.email,
                    onTap: () => Clipboard.setData(ClipboardData(text: record.email)),
                  ),
                _MetaItem(
                  icon: Icons.calendar_today_outlined,
                  label: record.formattedDate,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Documents ────────────────────────────────────────────────────
            Text('الوثائق المرفوعة:',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: const Color(0xFF0B3A66))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: record.documents
                  .map((d) => GestureDetector(
                        onTap: () => onViewDoc(d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF3FB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFD3F5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                d.url != null
                                    ? Icons.visibility_outlined
                                    : Icons.description_outlined,
                                color: const Color(0xFF0B3A66),
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(d.label,
                                  style: const TextStyle(
                                      color: Color(0xFF0B3A66), fontSize: 12)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),

            // ── Admin note ───────────────────────────────────────────────────
            if (record.adminNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: record.isRejected
                      ? const Color(0xFFFDECEC)
                      : const Color(0xFFF5F7FB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: record.isRejected
                        ? const Color(0xFFB02A37).withOpacity(0.3)
                        : const Color(0xFFE5EAF2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      record.isRejected
                          ? Icons.block_outlined
                          : Icons.notes_outlined,
                      color: record.isRejected
                          ? const Color(0xFFB02A37)
                          : Colors.black45,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record.adminNote,
                        style: TextStyle(
                          color: record.isRejected
                              ? const Color(0xFFB02A37)
                              : Colors.black54,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Actions ──────────────────────────────────────────────────────
            const SizedBox(height: 14),
            if (isActionLoading)
              const Center(child: SizedBox(
                  width: 32, height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2)))
            else if (record.isPending &&
                (onApprove != null || onReject != null))
              Row(
                children: [
                  if (onApprove != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => onApprove!(record),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('موافقة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF17B26A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  if (onApprove != null && onReject != null)
                    const SizedBox(width: 10),
                  if (onReject != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onReject!(record),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('رفض'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB02A37),
                          side: const BorderSide(color: Color(0xFFB02A37)),
                        ),
                      ),
                    ),
                ],
              )
            else if (record.isApproved)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF17B26A).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF17B26A).withOpacity(0.25)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Color(0xFF17B26A), size: 16),
                    SizedBox(width: 6),
                    Text('تمت الموافقة على هذا الطلب',
                        style: TextStyle(
                            color: Color(0xFF17B26A),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB02A37).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFB02A37).withOpacity(0.2)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFB02A37), size: 14),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'يمكن للمستخدم إعادة رفع الوثائق وإرسال طلب جديد',
                        style: TextStyle(
                            color: Color(0xFFB02A37), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final VerificationRecord record;
  const _AvatarWidget({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: record.roleColor.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: record.roleColor.withOpacity(0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        record.initials,
        style: TextStyle(
          color: record.roleColor,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _MetaItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black45),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                color: onTap != null ? const Color(0xFF0B3A66) : Colors.black54,
                decoration: onTap != null ? TextDecoration.underline : null,
              )),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 52, color: Colors.black26),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.black54, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
