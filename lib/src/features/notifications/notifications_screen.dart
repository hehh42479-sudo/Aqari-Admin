import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notifications Screen — Full Notification Center
// 8 audience targets, conditional value field, advanced options, rich history
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _targetValueController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _deepLinkController = TextEditingController();

  bool _isLoading = true;
  bool _isSending = false;
  bool _showAdvanced = false;
  String? _errorMessage;
  String _selectedTarget = 'all';
  List<NotificationRecord> _history = <NotificationRecord>[];

  static const List<_TargetOption> _targetOptions = <_TargetOption>[
    _TargetOption(
      label: 'الجميع',
      value: 'all',
      icon: Icons.public_rounded,
      color: Color(0xFF0B3A66),
      needsValue: false,
    ),
    _TargetOption(
      label: 'الباحثون',
      value: 'seeker',
      icon: Icons.search_rounded,
      color: Color(0xFF2563EB),
      needsValue: false,
    ),
    _TargetOption(
      label: 'الملاك',
      value: 'owner',
      icon: Icons.home_rounded,
      color: Color(0xFF059669),
      needsValue: false,
    ),
    _TargetOption(
      label: 'المكاتب',
      value: 'office',
      icon: Icons.apartment_rounded,
      color: Color(0xFF7C3AED),
      needsValue: false,
    ),
    _TargetOption(
      label: 'مستخدم محدد',
      value: 'user',
      icon: Icons.person_rounded,
      color: Color(0xFFDB6B1B),
      needsValue: true,
      valuePlaceholder: 'رقم الجوال أو المعرّف',
    ),
    _TargetOption(
      label: 'مدينة / منطقة',
      value: 'city',
      icon: Icons.location_city_rounded,
      color: Color(0xFF0891B2),
      needsValue: true,
      valuePlaceholder: 'اسم المدينة أو المنطقة',
    ),
    _TargetOption(
      label: 'اشتراكات نشطة',
      value: 'active_subs',
      icon: Icons.workspace_premium_rounded,
      color: Color(0xFF16A34A),
      needsValue: false,
    ),
    _TargetOption(
      label: 'اشتراكات منتهية',
      value: 'expired_subs',
      icon: Icons.timer_off_rounded,
      color: Color(0xFFDC2626),
      needsValue: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _targetValueController.dispose();
    _imageUrlController.dispose();
    _deepLinkController.dispose();
    super.dispose();
  }

  _TargetOption get _currentTarget =>
      _targetOptions.firstWhere((t) => t.value == _selectedTarget);

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      final rawHistory = await service.fetchNotifications();
      if (!mounted) return;

      setState(() {
        _history =
            rawHistory.map(NotificationRecord.fromJson).toList(growable: false);
        _isLoading = false;
      });
    } on DioException catch (error) {
      debugPrint(
        'Notifications load failed: ${error.response?.statusCode} '
        '${error.response?.data}',
      );
      if (!mounted) return;
      setState(() {
        _history = <NotificationRecord>[];
        _isLoading = false;
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Notifications load failed: $error');
      if (!mounted) return;
      setState(() {
        _history = <NotificationRecord>[];
        _isLoading = false;
        _errorMessage = 'تعذر تحميل الإشعارات حالياً. حاول تحديث الصفحة.';
      });
    }
  }

  Future<void> _showConfirmDialog() async {
    if (!_formKey.currentState!.validate()) return;

    final target = _currentTarget;
    final targetValueText = target.needsValue
        ? ' — ${_targetValueController.text.trim()}'
        : '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'تأكيد الإرسال',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ConfirmRow(
                label: 'العنوان',
                value: _titleController.text.trim(),
              ),
              const SizedBox(height: 8),
              _ConfirmRow(
                label: 'الجمهور',
                value: '${target.label}$targetValueText',
                valueColor: target.color,
              ),
              if (_showAdvanced && _imageUrlController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _ConfirmRow(
                  label: 'صورة',
                  value: _imageUrlController.text.trim(),
                  isTruncated: true,
                ),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B3A66),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _sendNotification();
    }
  }

  Future<void> _sendNotification() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      await service.sendNotification(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        audience: _selectedTarget,
        targetValue: _currentTarget.needsValue
            ? _targetValueController.text.trim()
            : null,
        imageUrl: _showAdvanced && _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : null,
        deepLink: _showAdvanced && _deepLinkController.text.trim().isNotEmpty
            ? _deepLinkController.text.trim()
            : null,
      );

      if (!mounted) return;

      _titleController.clear();
      _messageController.clear();
      _targetValueController.clear();
      _imageUrlController.clear();
      _deepLinkController.clear();
      setState(() {
        _selectedTarget = 'all';
        _showAdvanced = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: <Widget>[
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('تم إرسال الإشعار بنجاح'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF17B26A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      await _loadHistory();
    } on DioException catch (error) {
      debugPrint(
        'Notification send failed: ${error.response?.statusCode} '
        '${error.response?.data}',
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Notification send failed: $error');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر إرسال الإشعار حالياً. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _extractErrorMessage(DioException error) {
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
        return 'تعذر العثور على خدمة الإشعارات.';
      default:
        return 'تعذر تنفيذ العملية حالياً.';
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Page header
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B3A66).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF0B3A66),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'مركز الإشعارات',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  'إرسال التعميمات ومتابعة سجل الإشعارات المرسلة.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Left column: send form
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: _buildSendCard(),
                ),
              ),
              const SizedBox(width: 20),
              // Right column: history
              Expanded(
                flex: 6,
                child: _buildHistoryCard(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Send Card ───────────────────────────────────────────────────────────────

  Widget _buildSendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'إرسال إشعار جديد',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 18),

              // Title field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الإشعار *',
                  hintText: 'مثال: تحديث هام للنظام',
                  prefixIcon: Icon(Icons.title_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
              ),
              const SizedBox(height: 14),

              // Message field
              TextFormField(
                controller: _messageController,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'نص الرسالة *',
                  hintText: 'اكتب نص الإشعار هنا...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.message_rounded),
                  ),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'نص الرسالة مطلوب' : null,
              ),
              const SizedBox(height: 18),

              // Audience selector label
              Text(
                'الجمهور المستهدف',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF374151),
                    ),
              ),
              const SizedBox(height: 10),

              // 8-target grid
              _buildTargetGrid(),
              const SizedBox(height: 14),

              // Conditional target-value field
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: _currentTarget.needsValue
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextFormField(
                          controller: _targetValueController,
                          decoration: InputDecoration(
                            labelText: _currentTarget.valuePlaceholder ?? 'القيمة',
                            prefixIcon: Icon(
                              _selectedTarget == 'user'
                                  ? Icons.badge_rounded
                                  : Icons.location_on_rounded,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (_currentTarget.needsValue &&
                                (v == null || v.trim().isEmpty)) {
                              return 'هذا الحقل مطلوب للجمهور المختار';
                            }
                            return null;
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Advanced toggle
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _showAdvanced
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: const Color(0xFF0B3A66),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'خيارات متقدمة (صورة، رابط)',
                        style: TextStyle(
                          color: const Color(0xFF0B3A66),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Advanced fields
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _showAdvanced
                    ? Column(
                        children: <Widget>[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _imageUrlController,
                            decoration: const InputDecoration(
                              labelText: 'رابط الصورة (اختياري)',
                              hintText: 'https://example.com/image.jpg',
                              prefixIcon: Icon(Icons.image_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _deepLinkController,
                            decoration: const InputDecoration(
                              labelText: 'Deep Link (اختياري)',
                              hintText: 'aqari://screen/property/123',
                              prefixIcon: Icon(Icons.link_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // Error banner
              if (_errorMessage != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFB02A37), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB02A37),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Send button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B3A66),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: _isSending ? null : _showConfirmDialog,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(_isSending ? 'جاري الإرسال...' : 'إرسال الإشعار'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Target Grid ─────────────────────────────────────────────────────────────

  Widget _buildTargetGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: _targetOptions.length,
      itemBuilder: (context, index) {
        final option = _targetOptions[index];
        final isSelected = _selectedTarget == option.value;
        return _TargetTile(
          option: option,
          isSelected: isSelected,
          onTap: _isSending
              ? null
              : () {
                  setState(() {
                    _selectedTarget = option.value;
                    _targetValueController.clear();
                  });
                },
        );
      },
    );
  }

  // ─── History Card ────────────────────────────────────────────────────────────

  Widget _buildHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'سجل الإشعارات',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : _loadHistory,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  tooltip: 'تحديث',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_history.length} إشعار مرسل',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
            ),
            const Divider(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _history.isEmpty
                      ? _buildEmptyHistory()
                      : ListView.separated(
                          itemCount: _history.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) =>
                              _NotifHistoryCard(record: _history[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.notifications_off_outlined,
            size: 52,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد إشعارات مرسلة حالياً.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF94A3B8),
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _TargetOption option;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? option.color.withValues(alpha: 0.12)
        : const Color(0xFFF8FAFC);
    final borderColor =
        isSelected ? option.color : const Color(0xFFE2E8F0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isSelected ? 2 : 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: isSelected ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(option.icon, color: option.color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected ? option.color : const Color(0xFF374151),
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded,
                    color: option.color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifHistoryCard extends StatelessWidget {
  const _NotifHistoryCard({required this.record});

  final NotificationRecord record;

  @override
  Widget build(BuildContext context) {
    final targetColor = _audienceColor(record.audience);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  record.title.isNotEmpty ? record.title : '(بدون عنوان)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _AudienceBadge(
                label: record.audienceLabel,
                color: targetColor,
              ),
            ],
          ),
          // Body preview
          if (record.body.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              record.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Footer row
          Row(
            children: <Widget>[
              const Icon(Icons.schedule_rounded,
                  size: 13, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                record.dateLabel,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
              if (record.recipientCount != null) ...<Widget>[
                const SizedBox(width: 12),
                const Icon(Icons.people_outline_rounded,
                    size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  '${record.recipientCount} مستلم',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
              const Spacer(),
              // Copy title button
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: record.title));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم نسخ العنوان'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _audienceColor(String audience) {
    switch (audience) {
      case 'seeker':
        return const Color(0xFF2563EB);
      case 'owner':
        return const Color(0xFF059669);
      case 'office':
        return const Color(0xFF7C3AED);
      case 'user':
        return const Color(0xFFDB6B1B);
      case 'city':
        return const Color(0xFF0891B2);
      case 'active_subs':
        return const Color(0xFF16A34A);
      case 'expired_subs':
        return const Color(0xFFDC2626);
      case 'all':
      default:
        return const Color(0xFF0B3A66);
    }
  }
}

class _AudienceBadge extends StatelessWidget {
  const _AudienceBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isTruncated = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isTruncated;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: isTruncated ? 1 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class NotificationRecord {
  const NotificationRecord({
    required this.title,
    required this.body,
    required this.audience,
    required this.date,
    this.recipientCount,
    this.imageUrl,
    this.deepLink,
  });

  final String title;
  final String body;
  final String audience;
  final DateTime? date;
  final int? recipientCount;
  final String? imageUrl;
  final String? deepLink;

  String get audienceLabel {
    switch (audience) {
      case 'all':
        return 'الجميع';
      case 'office':
        return 'المكاتب';
      case 'owner':
        return 'الملاك';
      case 'seeker':
        return 'الباحثون';
      case 'user':
        return 'مستخدم محدد';
      case 'city':
        return 'مدينة / منطقة';
      case 'active_subs':
        return 'اشتراكات نشطة';
      case 'expired_subs':
        return 'اشتراكات منتهية';
      default:
        return audience.isNotEmpty ? audience : 'الجميع';
    }
  }

  String get dateLabel {
    final value = date;
    if (value == null) return '--';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year}  $hour:$min';
  }

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      title: _readText(json, <String>['title', 'subject', 'headline', 'name']),
      body: _readText(
          json, <String>['message', 'body', 'content', 'text', 'description']),
      audience: _readText(json, <String>[
        'audience',
        'target',
        'recipient',
        'role',
        'targetType',
        'target_type',
      ]),
      date: _parseDate(
          json['createdAt'] ??
              json['date'] ??
              json['sentAt'] ??
              json['time'] ??
              json['created_at']),
      recipientCount: _toInt(
          json['recipientCount'] ??
              json['recipient_count'] ??
              json['recipients'] ??
              json['count']),
      imageUrl: _readTextOrNull(
          json, <String>['imageUrl', 'image_url', 'image', 'thumbnail']),
      deepLink: _readTextOrNull(
          json, <String>['deepLink', 'deep_link', 'link', 'url']),
    );
  }

  static String _readText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    final nested = json['data'];
    if (nested is Map<String, dynamic>) {
      for (final key in keys) {
        final value = nested[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value != null) {
          final text = value.toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    }
    return '';
  }

  static String? _readTextOrNull(
      Map<String, dynamic> json, List<String> keys) {
    final result = _readText(json, keys);
    return result.isEmpty ? null : result;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final ms = int.tryParse(text);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    try {
      return DateTime.parse(text);
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class _TargetOption {
  const _TargetOption({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.needsValue,
    this.valuePlaceholder,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool needsValue;
  final String? valuePlaceholder;
}
