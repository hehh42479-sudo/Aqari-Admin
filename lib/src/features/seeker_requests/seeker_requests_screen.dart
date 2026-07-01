import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Seeker Requests Screen  (طلبات الباحثين)
// Displays property-search requests submitted by seekers with full management.
// ─────────────────────────────────────────────────────────────────────────────

class SeekerRequestsScreen extends StatefulWidget {
  const SeekerRequestsScreen({super.key});

  @override
  State<SeekerRequestsScreen> createState() => _SeekerRequestsScreenState();
}

class _SeekerRequestsScreenState extends State<SeekerRequestsScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  String _selectedStatus = 'all';
  List<SeekerRequest> _allRequests = <SeekerRequest>[];
  List<SeekerRequest> _filtered = <SeekerRequest>[];
  final Set<String> _actionLoadingIds = <String>{};

  static const List<_StatusFilter> _statusFilters = <_StatusFilter>[
    _StatusFilter(label: 'الكل', value: 'all', color: Color(0xFF64748B)),
    _StatusFilter(label: 'جديد', value: 'new', color: Color(0xFF2563EB)),
    _StatusFilter(
        label: 'قيد المعالجة', value: 'processing', color: Color(0xFFD97706)),
    _StatusFilter(
        label: 'مكتمل', value: 'completed', color: Color(0xFF059669)),
    _StatusFilter(
        label: 'ملغى', value: 'cancelled', color: Color(0xFFDC2626)),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilters);
    _searchController.dispose();
    super.dispose();
  }

  // ─── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      final raw = await service.fetchSeekerRequests();
      if (!mounted) return;

      setState(() {
        _allRequests =
            raw.map(SeekerRequest.fromJson).toList(growable: false);
        _isLoading = false;
      });
      _applyFilters();
    } on DioException catch (error) {
      debugPrint(
        'SeekerRequests load failed: ${error.response?.statusCode} '
        '${error.response?.data}',
      );
      if (!mounted) return;
      setState(() {
        _allRequests = <SeekerRequest>[];
        _filtered = <SeekerRequest>[];
        _isLoading = false;
        _errorMessage = _dioErrorMsg(error);
      });
    } catch (error) {
      debugPrint('SeekerRequests load failed: $error');
      if (!mounted) return;
      setState(() {
        _allRequests = <SeekerRequest>[];
        _filtered = <SeekerRequest>[];
        _isLoading = false;
        _errorMessage = 'تعذر تحميل الطلبات حالياً. حاول تحديث الصفحة.';
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _allRequests.where((req) {
        // Status filter
        if (_selectedStatus != 'all' && req.status != _selectedStatus) {
          return false;
        }
        // Search filter
        if (query.isNotEmpty) {
          return req.seekerName.toLowerCase().contains(query) ||
              req.seekerPhone.toLowerCase().contains(query) ||
              req.city.toLowerCase().contains(query);
        }
        return true;
      }).toList(growable: false);
    });
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _approveRequest(SeekerRequest req) async {
    if (_actionLoadingIds.contains(req.id)) return;
    setState(() => _actionLoadingIds.add(req.id));

    try {
      final service = context.read<AdminDataService>();
      await service.updateSeekerRequestStatus(req.id, 'processing');
      if (!mounted) return;

      // Optimistic update
      setState(() {
        final idx = _allRequests.indexWhere((r) => r.id == req.id);
        if (idx != -1) {
          _allRequests[idx] = req.copyWith(status: 'processing');
        }
      });
      _applyFilters();

      ScaffoldMessenger.of(context).showSnackBar(
        _successSnackbar('تم قبول الطلب وتحويله للمعالجة'),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      _showErrorSnack(_dioErrorMsg(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('تعذر تنفيذ العملية.');
    } finally {
      if (mounted) setState(() => _actionLoadingIds.remove(req.id));
    }
  }

  Future<void> _completeRequest(SeekerRequest req) async {
    if (_actionLoadingIds.contains(req.id)) return;
    setState(() => _actionLoadingIds.add(req.id));

    try {
      final service = context.read<AdminDataService>();
      await service.updateSeekerRequestStatus(req.id, 'completed');
      if (!mounted) return;

      setState(() {
        final idx = _allRequests.indexWhere((r) => r.id == req.id);
        if (idx != -1) {
          _allRequests[idx] = req.copyWith(status: 'completed');
        }
      });
      _applyFilters();

      ScaffoldMessenger.of(context).showSnackBar(
        _successSnackbar('تم تحديث الطلب إلى مكتمل'),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      _showErrorSnack(_dioErrorMsg(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('تعذر تنفيذ العملية.');
    } finally {
      if (mounted) setState(() => _actionLoadingIds.remove(req.id));
    }
  }

  Future<void> _showRejectDialog(SeekerRequest req) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cancel_outlined,
                    color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'إلغاء الطلب',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'طلب: ${req.seekerName}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'سبب الإلغاء (اختياري)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('رجوع'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('إلغاء الطلب'),
            ),
          ],
        ),
      ),
    );

    reasonController.dispose();
    if (confirmed == true && mounted) {
      await _cancelRequest(req, reason: reasonController.text.trim());
    }
  }

  Future<void> _cancelRequest(SeekerRequest req, {String? reason}) async {
    if (_actionLoadingIds.contains(req.id)) return;
    setState(() => _actionLoadingIds.add(req.id));

    try {
      final service = context.read<AdminDataService>();
      await service.updateSeekerRequestStatus(
        req.id,
        'cancelled',
        rejectionReason: reason,
      );
      if (!mounted) return;

      setState(() {
        final idx = _allRequests.indexWhere((r) => r.id == req.id);
        if (idx != -1) {
          _allRequests[idx] = req.copyWith(status: 'cancelled');
        }
      });
      _applyFilters();

      ScaffoldMessenger.of(context).showSnackBar(
        _successSnackbar('تم إلغاء الطلب'),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      _showErrorSnack(_dioErrorMsg(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('تعذر تنفيذ العملية.');
    } finally {
      if (mounted) setState(() => _actionLoadingIds.remove(req.id));
    }
  }

  Future<void> _showDeleteDialog(SeekerRequest req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'حذف الطلب',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(
                  color: Color(0xFF374151), fontSize: 14, height: 1.6),
              children: <TextSpan>[
                const TextSpan(text: 'هل أنت متأكد من حذف طلب '),
                TextSpan(
                  text: req.seekerName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const TextSpan(
                    text:
                        ' نهائياً؟\nلا يمكن التراجع عن هذا الإجراء.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('رجوع'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteRequest(req);
    }
  }

  Future<void> _deleteRequest(SeekerRequest req) async {
    if (_actionLoadingIds.contains(req.id)) return;
    setState(() => _actionLoadingIds.add(req.id));

    try {
      final service = context.read<AdminDataService>();
      await service.deleteSeekerRequest(req.id);
      if (!mounted) return;

      setState(() {
        _allRequests.removeWhere((r) => r.id == req.id);
      });
      _applyFilters();

      ScaffoldMessenger.of(context).showSnackBar(
        _successSnackbar('تم حذف الطلب بنجاح'),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      _showErrorSnack(_dioErrorMsg(e));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('تعذر حذف الطلب.');
    } finally {
      if (mounted) setState(() => _actionLoadingIds.remove(req.id));
    }
  }

  void _showDetailsDialog(SeekerRequest req) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _RequestDetailsDialog(request: req),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _dioErrorMsg(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final candidate =
          data['message'] ?? data['error'] ?? data['details'] ?? data['msg'];
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    switch (error.response?.statusCode) {
      case 401:
        return 'انتهت صلاحية الدخول. يرجى تسجيل الدخول مرة أخرى.';
      case 404:
        return 'الطلب غير موجود.';
      default:
        return 'تعذر تنفيذ العملية حالياً.';
    }
  }

  SnackBar _successSnackbar(String text) {
    return SnackBar(
      content: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Text(text),
        ],
      ),
      backgroundColor: const Color(0xFF17B26A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Summary counts
    final total = _allRequests.length;
    final pending = _allRequests.where((r) => r.status == 'new').length;
    final processing =
        _allRequests.where((r) => r.status == 'processing').length;
    final completed =
        _allRequests.where((r) => r.status == 'completed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ── Page header
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B3A66).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                color: Color(0xFF0B3A66),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'طلبات الباحثين',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'إدارة طلبات البحث عن عقارات المقدمة من المستخدمين.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF0B3A66),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isLoading ? null : _loadRequests,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Summary chips
        if (!_isLoading && _errorMessage == null) ...<Widget>[
          _SummaryBar(
            total: total,
            pending: pending,
            processing: processing,
            completed: completed,
          ),
          const SizedBox(height: 16),
        ],

        // ── Status filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _statusFilters.map((filter) {
              final isSelected = _selectedStatus == filter.value;
              final count = filter.value == 'all'
                  ? total
                  : _allRequests
                      .where((r) => r.status == filter.value)
                      .length;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilterChip(
                  label: Text('${filter.label} ($count)'),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedStatus = filter.value);
                    _applyFilters();
                  },
                  selectedColor: filter.color.withValues(alpha: 0.15),
                  checkmarkColor: filter.color,
                  labelStyle: TextStyle(
                    color: isSelected ? filter.color : const Color(0xFF64748B),
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? filter.color
                        : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 12),

        // ── Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'بحث باسم الباحث أو الجوال أو المدينة...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Body
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _ErrorRetry(
        message: _errorMessage!,
        onRetry: _loadRequests,
      );
    }
    if (_filtered.isEmpty) {
      return _EmptyState(
        hasSearch: _searchController.text.isNotEmpty ||
            _selectedStatus != 'all',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        padding: const EdgeInsets.only(bottom: 20),
        itemBuilder: (context, index) {
          final req = _filtered[index];
          return _SeekerRequestCard(
            request: req,
            isActionLoading: _actionLoadingIds.contains(req.id),
            onView: () => _showDetailsDialog(req),
            onApprove: req.status == 'new'
                ? () => _approveRequest(req)
                : null,
            onComplete: req.status == 'processing'
                ? () => _completeRequest(req)
                : null,
            onCancel: (req.status == 'new' || req.status == 'processing')
                ? () => _showRejectDialog(req)
                : null,
            onDelete: () => _showDeleteDialog(req),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Bar
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.total,
    required this.pending,
    required this.processing,
    required this.completed,
  });

  final int total;
  final int pending;
  final int processing;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _SummaryChip(
            label: 'الإجمالي', count: total, color: const Color(0xFF0B3A66)),
        const SizedBox(width: 10),
        _SummaryChip(
            label: 'جديد', count: pending, color: const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        _SummaryChip(
            label: 'معالجة',
            count: processing,
            color: const Color(0xFFD97706)),
        const SizedBox(width: 10),
        _SummaryChip(
            label: 'مكتمل', count: completed, color: const Color(0xFF059669)),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Request Card
// ─────────────────────────────────────────────────────────────────────────────

class _SeekerRequestCard extends StatelessWidget {
  const _SeekerRequestCard({
    required this.request,
    required this.isActionLoading,
    required this.onView,
    required this.onDelete,
    this.onApprove,
    this.onComplete,
    this.onCancel,
  });

  final SeekerRequest request;
  final bool isActionLoading;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback? onApprove;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final req = request;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: req.statusColor.withValues(alpha: 0.25),
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Left status accent bar
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: req.statusColor,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ── Row 1: Avatar + Name + Status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Avatar
                    _AvatarWidget(
                      initials: req.initials,
                      color: req.statusColor,
                    ),
                    const SizedBox(width: 12),
                    // Name + phone + date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            req.seekerName.isNotEmpty
                                ? req.seekerName
                                : 'باحث مجهول',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (req.seekerPhone.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: () => Clipboard.setData(
                                ClipboardData(text: req.seekerPhone),
                              ),
                              child: Text(
                                req.seekerPhone,
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            req.formattedDate,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    _StatusBadge(
                      label: req.statusLabel,
                      color: req.statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Row 2: Property specs grid
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    if (req.city.isNotEmpty)
                      _SpecChip(
                          icon: Icons.location_city_rounded,
                          label: req.city),
                    if (req.district.isNotEmpty)
                      _SpecChip(
                          icon: Icons.map_outlined, label: req.district),
                    if (req.propertyType.isNotEmpty)
                      _SpecChip(
                          icon: Icons.home_work_outlined,
                          label: req.propertyType),
                    if (req.purpose.isNotEmpty)
                      _SpecChip(
                          icon: req.purpose == 'rent'
                              ? Icons.vpn_key_outlined
                              : Icons.sell_outlined,
                          label:
                              req.purpose == 'rent' ? 'للإيجار' : 'للبيع'),
                    if (req.budgetLabel.isNotEmpty)
                      _SpecChip(
                          icon: Icons.attach_money_rounded,
                          label: req.budgetLabel),
                    if (req.bedroomsLabel.isNotEmpty)
                      _SpecChip(
                          icon: Icons.bed_outlined,
                          label: req.bedroomsLabel),
                  ],
                ),

                // ── Row 3: Tracking / offices info
                if (req.hasTracking) ...<Widget>[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      if (req.officesCount > 0) ...<Widget>[
                        const Icon(Icons.apartment_rounded,
                            size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '${req.officesCount} مكتب تلقى الطلب',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (req.acceptedBy.isNotEmpty) ...<Widget>[
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'قبله: ${req.acceptedBy}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (req.gpsLocation.isNotEmpty) ...<Widget>[
                        const Icon(Icons.gps_fixed_rounded,
                            size: 14, color: Color(0xFF0891B2)),
                        const SizedBox(width: 4),
                        Text(
                          req.gpsLocation,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF0891B2)),
                        ),
                      ],
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // ── Row 4: Action buttons
                isActionLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : _ActionRow(
                        onView: onView,
                        onApprove: onApprove,
                        onComplete: onComplete,
                        onCancel: onCancel,
                        onDelete: onDelete,
                        status: req.status,
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
// Action Row
// ─────────────────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onView,
    required this.onDelete,
    required this.status,
    this.onApprove,
    this.onComplete,
    this.onCancel,
  });

  final String status;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final VoidCallback? onApprove;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: <Widget>[
        // View details
        _ActionBtn(
          label: 'عرض',
          icon: Icons.visibility_outlined,
          color: const Color(0xFF0B3A66),
          onTap: onView,
        ),
        // Approve (new → processing)
        if (onApprove != null)
          _ActionBtn(
            label: 'قبول',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF059669),
            onTap: onApprove,
          ),
        // Complete (processing → completed)
        if (onComplete != null)
          _ActionBtn(
            label: 'إكمال',
            icon: Icons.done_all_rounded,
            color: const Color(0xFF0891B2),
            onTap: onComplete,
          ),
        // Cancel
        if (onCancel != null)
          _ActionBtn(
            label: 'إلغاء',
            icon: Icons.cancel_outlined,
            color: const Color(0xFFD97706),
            onTap: onCancel,
          ),
        // Delete
        _ActionBtn(
          label: 'حذف',
          icon: Icons.delete_forever_outlined,
          color: const Color(0xFFDC2626),
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Details Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _RequestDetailsDialog extends StatelessWidget {
  const _RequestDetailsDialog({required this.request});

  final SeekerRequest request;

  @override
  Widget build(BuildContext context) {
    final req = request;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Header
                Row(
                  children: <Widget>[
                    _AvatarWidget(
                        initials: req.initials, color: req.statusColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            req.seekerName.isNotEmpty
                                ? req.seekerName
                                : 'باحث مجهول',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          Text(
                            req.formattedDate,
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(
                        label: req.statusLabel, color: req.statusColor),
                  ],
                ),
                const Divider(height: 24),

                // Details
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        _DetailRow(
                            label: 'الجوال', value: req.seekerPhone),
                        _DetailRow(label: 'المدينة', value: req.city),
                        _DetailRow(
                            label: 'الحي / المنطقة', value: req.district),
                        _DetailRow(
                            label: 'نوع العقار', value: req.propertyType),
                        _DetailRow(
                            label: 'الغرض',
                            value:
                                req.purpose == 'rent' ? 'إيجار' : 'شراء'),
                        _DetailRow(
                            label: 'الميزانية', value: req.budgetLabel),
                        _DetailRow(
                            label: 'غرف النوم', value: req.bedroomsLabel),
                        if (req.notes.isNotEmpty)
                          _DetailRow(label: 'ملاحظات', value: req.notes),
                        if (req.officesCount > 0)
                          _DetailRow(
                            label: 'المكاتب',
                            value: '${req.officesCount} مكتب تلقى الطلب',
                          ),
                        if (req.acceptedBy.isNotEmpty)
                          _DetailRow(
                              label: 'قبله', value: req.acceptedBy),
                        if (req.gpsLocation.isNotEmpty)
                          _DetailRow(
                              label: 'الموقع', value: req.gpsLocation),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إغلاق'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty || value == '--') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({required this.initials, required this.color});

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded, size: 52, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            hasSearch ? Icons.search_off_rounded : Icons.assignment_outlined,
            size: 56,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            hasSearch
                ? 'لا توجد نتائج تطابق البحث.'
                : 'لا توجد طلبات حالياً.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class SeekerRequest {
  const SeekerRequest({
    required this.id,
    required this.seekerName,
    required this.seekerPhone,
    required this.seekerEmail,
    required this.city,
    required this.district,
    required this.propertyType,
    required this.purpose,
    required this.budgetMin,
    required this.budgetMax,
    required this.bedrooms,
    required this.status,
    required this.notes,
    required this.officesCount,
    required this.acceptedBy,
    required this.gpsLocation,
    required this.date,
    required this.rawJson,
  });

  final String id;
  final String seekerName;
  final String seekerPhone;
  final String seekerEmail;
  final String city;
  final String district;
  final String propertyType;
  final String purpose; // 'rent' | 'buy'
  final double? budgetMin;
  final double? budgetMax;
  final int? bedrooms;
  final String status; // new | processing | completed | cancelled
  final String notes;
  final int officesCount;
  final String acceptedBy;
  final String gpsLocation;
  final DateTime? date;
  final Map<String, dynamic> rawJson;

  bool get hasTracking =>
      officesCount > 0 || acceptedBy.isNotEmpty || gpsLocation.isNotEmpty;

  String get initials {
    final parts = seekerName.trim().split(' ');
    if (parts.isEmpty || seekerName.trim().isEmpty) return '؟';
    if (parts.length == 1) return parts[0][0];
    return '${parts[0][0]}${parts[1][0]}';
  }

  Color get statusColor {
    switch (status) {
      case 'new':
        return const Color(0xFF2563EB);
      case 'processing':
        return const Color(0xFFD97706);
      case 'completed':
        return const Color(0xFF059669);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'new':
        return 'جديد';
      case 'processing':
        return 'قيد المعالجة';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }

  String get budgetLabel {
    if (budgetMin != null && budgetMax != null) {
      return '${_formatNum(budgetMin!)} - ${_formatNum(budgetMax!)} ر.س';
    }
    if (budgetMax != null) return 'حتى ${_formatNum(budgetMax!)} ر.س';
    if (budgetMin != null) return 'من ${_formatNum(budgetMin!)} ر.س';
    return '';
  }

  String get bedroomsLabel {
    if (bedrooms == null) return '';
    return '$bedrooms غرفة';
  }

  String get formattedDate {
    final d = date;
    if (d == null) return '--';
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  static String _formatNum(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}م';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}ك';
    return n.toStringAsFixed(0);
  }

  SeekerRequest copyWith({String? status}) {
    return SeekerRequest(
      id: id,
      seekerName: seekerName,
      seekerPhone: seekerPhone,
      seekerEmail: seekerEmail,
      city: city,
      district: district,
      propertyType: propertyType,
      purpose: purpose,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      bedrooms: bedrooms,
      status: status ?? this.status,
      notes: notes,
      officesCount: officesCount,
      acceptedBy: acceptedBy,
      gpsLocation: gpsLocation,
      date: date,
      rawJson: rawJson,
    );
  }

  factory SeekerRequest.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    // Seeker info — may be nested under seeker/user/requester
    final seekerNode = _nestedMap(data, <String>[
          'seeker',
          'user',
          'requester',
          'client',
          'applicant',
        ]) ??
        data;

    return SeekerRequest(
      id: _str(data, <String>['_id', 'id', 'requestId', 'request_id']),
      seekerName: _str(seekerNode, <String>[
        'name',
        'fullName',
        'full_name',
        'displayName',
        'username',
      ]),
      seekerPhone: _str(seekerNode, <String>[
        'phone',
        'phoneNumber',
        'phone_number',
        'mobile',
      ]),
      seekerEmail: _str(seekerNode, <String>['email', 'emailAddress']),
      city: _str(data, <String>['city', 'cityName', 'location']),
      district: _str(data, <String>[
        'district',
        'area',
        'neighborhood',
        'region',
      ]),
      propertyType: _str(data, <String>[
        'propertyType',
        'property_type',
        'type',
        'category',
      ]),
      purpose: _str(data, <String>[
        'purpose',
        'listingType',
        'listing_type',
        'rentOrSale',
      ]),
      budgetMin: _toDouble(
          data['budgetMin'] ?? data['budget_min'] ?? data['minPrice']),
      budgetMax: _toDouble(
          data['budgetMax'] ?? data['budget_max'] ?? data['maxPrice'] ??
              data['budget']),
      bedrooms: _toInt(
          data['bedrooms'] ?? data['rooms'] ?? data['bedroomsCount']),
      status: _str(data, <String>['status', 'state', 'requestStatus']),
      notes: _str(data, <String>['notes', 'note', 'description', 'remarks']),
      officesCount:
          _toInt(data['officesCount'] ?? data['offices_count'] ??
              data['officesReceived']) ??
          0,
      acceptedBy: _str(data, <String>[
        'acceptedBy',
        'accepted_by',
        'officeName',
        'office',
      ]),
      gpsLocation: _str(data, <String>[
        'gpsLocation',
        'gps',
        'coordinates',
        'lat_lng',
      ]),
      date: _parseDate(data['createdAt'] ??
          data['created_at'] ??
          data['submittedAt'] ??
          data['date']),
      rawJson: json,
    );
  }

  static String _str(Map<String, dynamic> m, List<String> keys) {
    for (final key in keys) {
      final v = m[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v != null) {
        final t = v.toString().trim();
        if (t.isNotEmpty) return t;
      }
    }
    return '';
  }

  static Map<String, dynamic>? _nestedMap(
      Map<String, dynamic> m, List<String> keys) {
    for (final key in keys) {
      final v = m[key];
      if (v is Map<String, dynamic>) return v;
    }
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    final t = v.toString().trim();
    if (t.isEmpty) return null;
    final ms = int.tryParse(t);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    try {
      return DateTime.parse(t);
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilter {
  const _StatusFilter(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;
}
