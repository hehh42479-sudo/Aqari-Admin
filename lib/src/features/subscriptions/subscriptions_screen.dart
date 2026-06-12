import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SubscriptionRecord> _subscriptions = <SubscriptionRecord>[];

  // Employee payment section
  bool _empLoading = false;
  List<Map<String, dynamic>> _empPayments = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSubscriptions();
    });
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      final rawSubscriptions = await service.fetchSubscriptions();
      if (!mounted) {
        return;
      }

      setState(() {
        _subscriptions = rawSubscriptions
            .map(SubscriptionRecord.fromJson)
            .toList(growable: false);
        _isLoading = false;
        _errorMessage = null;
      });
    } on DioException catch (error) {
      debugPrint(
        'Subscriptions load failed: ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _subscriptions = <SubscriptionRecord>[];
        _isLoading = false;
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Subscriptions load failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _subscriptions = <SubscriptionRecord>[];
        _isLoading = false;
        _errorMessage = 'تعذر تحميل الاشتراكات حالياً. حاول تحديث الصفحة.';
      });
    }
  }

  Future<void> _openManualActivationDialog() async {
    final service = context.read<AdminDataService>();
    final activated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ManualSubscriptionDialog(service: service);
      },
    );

    if (!mounted) {
      return;
    }

    if (activated == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل الاشتراك بنجاح'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF17B26A),
        ),
      );
      await _loadSubscriptions();
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
      case 404:
        return 'تعذر العثور على بيانات الاشتراكات.';
      case 401:
        return 'انتهت صلاحية الدخول. يرجى تسجيل الدخول مرة أخرى.';
      default:
        return 'تعذر تحميل الاشتراكات حالياً. حاول تحديث الصفحة.';
    }
  }

  Future<void> _loadEmployeePayments() async {
    setState(() => _empLoading = true);
    try {
      final service = context.read<AdminDataService>();
      final items = await service.fetchEmployeePayments();
      if (mounted) setState(() => _empPayments = items);
    } catch (_) {
      if (mounted) setState(() => _empPayments = []);
    } finally {
      if (mounted) setState(() => _empLoading = false);
    }
  }

  Future<void> _confirmEmployeePayment(String paymentId) async {
    try {
      final service = context.read<AdminDataService>();
      await service.confirmEmployeePayment(paymentId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تأكيد الدفع ✓'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadEmployeePayments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تأكيد الدفع: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<DataColumn> _buildColumns() {    return const <DataColumn>[
      DataColumn(label: Text('اسم المشترك')),
      DataColumn(label: Text('نوع الباقة')),
      DataColumn(label: Text('تاريخ البداية')),
      DataColumn(label: Text('تاريخ النهاية')),
      DataColumn(label: Text('الحالة')),
    ];
  }

  Widget _buildTablePane(List<SubscriptionRecord> subscriptions) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 56,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 82,
              columnSpacing: 24,
              horizontalMargin: 20,
              showCheckboxColumn: false,
              columns: _buildColumns(),
              rows: subscriptions.asMap().entries.map((entry) {
                final index = entry.key;
                final subscription = entry.value;

                return DataRow.byIndex(
                  index: index,
                  cells: <DataCell>[
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          subscription.subscriberName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    DataCell(Text(subscription.packageType)),
                    DataCell(Text(subscription.startDateLabel)),
                    DataCell(Text(subscription.endDateLabel)),
                    DataCell(
                      _SubscriptionStatusBadge(
                        label: subscription.statusLabel,
                        isActive: subscription.isActive,
                      ),
                    ),
                  ],
                );
              }).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SubscriptionsHeader(
          title: 'الاشتراكات',
          subtitle: 'عرض ومتابعة جميع الاشتراكات النشطة والمنتهية.',
          onRefresh: _loadSubscriptions,
          onManualActivate: _openManualActivationDialog,
          count: _subscriptions.length,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // ── Main subscriptions card ──────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'الاشتراكات',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'عرض ومتابعة جميع الاشتراكات النشطة والمنتهية.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_errorMessage != null)
                        Center(
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      else if (_subscriptions.isEmpty)
                        Center(
                          child: Text(
                            'لا توجد اشتراكات متاحة حالياً.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      else
                        SizedBox(
                          height: 320,
                          child: _buildTablePane(_subscriptions),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── Employee subscription payments card ──────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'دفعات اشتراكات الموظفين',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '20 دولار لكل موظف شهرياً — تحقق من الحوالات وأكّدها.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _loadEmployeePayments,
                            icon: const Icon(Icons.refresh),
                            tooltip: 'تحديث',
                          ),
                          if (_empPayments.isEmpty)
                            TextButton.icon(
                              onPressed: _loadEmployeePayments,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('تحميل'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_empLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_empPayments.isEmpty)
                        Center(
                          child: Text(
                            'اضغط "تحميل" لعرض دفعات الموظفين.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      else
                        ..._empPayments.map((p) {
                          final id = p['id']?.toString() ?? '';
                          final officeId = p['office_id']?.toString() ?? '';
                          final amount = p['amount_usd']?.toString() ?? '0';
                          final status = p['status']?.toString() ?? 'pending';
                          final ref = p['payment_ref']?.toString() ?? '';
                          final createdAt = p['created_at']?.toString() ?? '';
                          final isPending = status == 'pending';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isPending
                                    ? Colors.orange.withValues(alpha: 0.4)
                                    : Colors.green.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('مكتب #$officeId',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      Text('\$$amount',
                                          style: const TextStyle(
                                              fontSize: 13)),
                                      if (ref.isNotEmpty)
                                        Text('حوالة: $ref',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54)),
                                      Text(createdAt,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black38)),
                                    ],
                                  ),
                                ),
                                if (isPending)
                                  ElevatedButton(
                                    onPressed: id.isNotEmpty
                                        ? () => _confirmEmployeePayment(id)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                    ),
                                    child: const Text('تأكيد الدفع'),
                                  )
                                else
                                  const Chip(
                                    label: Text('مدفوع ✓'),
                                    backgroundColor: Color(0xFFE8F5E9),
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
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

class _SubscriptionsHeader extends StatelessWidget {
  const _SubscriptionsHeader({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.onManualActivate,
    required this.count,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onManualActivate;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '$subtitle - إجمالي السجلات: $count',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          children: <Widget>[
            ElevatedButton.icon(
              onPressed: onManualActivate,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('➕ تفعيل اشتراك يدوي'),
            ),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تحديث البيانات'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ManualSubscriptionDialog extends StatefulWidget {
  const _ManualSubscriptionDialog({required this.service});

  final AdminDataService service;

  @override
  State<_ManualSubscriptionDialog> createState() =>
      _ManualSubscriptionDialogState();
}

class _ManualSubscriptionDialogState extends State<_ManualSubscriptionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifierController = TextEditingController();
  String? _selectedPackageType = 'basic';
  String? _selectedDuration = '1 month';
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _packageOptions = <String>[
    'basic',
    'premium',
    'vip',
  ];

  static const List<String> _durationOptions = <String>[
    '1 month',
    '3 months',
    '1 year',
  ];

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.service.activateManualSubscription(
        userIdentifier: _identifierController.text.trim(),
        packageType: _selectedPackageType ?? 'basic',
        duration: _selectedDuration ?? '1 month',
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on DioException catch (error) {
      debugPrint(
        'Manual subscription activation failed: ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Manual subscription activation failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage = 'تعذر تفعيل الاشتراك الآن. حاول مرة أخرى.';
      });
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
      case 400:
        return 'البيانات المدخلة غير صحيحة.';
      case 401:
        return 'انتهت صلاحية الدخول. يرجى تسجيل الدخول مرة أخرى.';
      case 404:
        return 'تعذر الوصول إلى خدمة التفعيل اليدوي.';
      default:
        return 'تعذر تفعيل الاشتراك الآن. حاول مرة أخرى.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تفعيل اشتراك يدوي'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _identifierController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'User ID أو رقم الهاتف',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'أدخل رقم المستخدم أو الهاتف';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedPackageType,
                  decoration: const InputDecoration(
                    labelText: 'نوع الباقة',
                    border: OutlineInputBorder(),
                  ),
                  items: _packageOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() {
                            _selectedPackageType = value;
                          });
                        },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedDuration,
                  decoration: const InputDecoration(
                    labelText: 'المدة',
                    border: OutlineInputBorder(),
                  ),
                  items: _durationOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() {
                            _selectedDuration = value;
                          });
                        },
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB02A37),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: <Widget>[
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تأكيد التفعيل'),
        ),
      ],
    );
  }
}

class _SubscriptionStatusBadge extends StatelessWidget {
  const _SubscriptionStatusBadge({
    required this.label,
    required this.isActive,
  });

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF17B26A) : const Color(0xFFB02A37);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class SubscriptionRecord {
  SubscriptionRecord({
    required this.id,
    required this.subscriberName,
    required this.packageType,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  final String id;
  final String subscriberName;
  final String packageType;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;

  String get startDateLabel => _formatDate(startDate);

  String get endDateLabel => _formatDate(endDate);

  String get statusLabel => isActive ? 'نشط' : 'منتهي';

  factory SubscriptionRecord.fromJson(Map<String, dynamic> json) {
    final active = _resolveIsActive(json);

    return SubscriptionRecord(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      subscriberName: _resolveSubscriberName(json),
      packageType: _resolvePackageType(json),
      startDate: _parseDate(
        json['startDate'] ??
            json['startsAt'] ??
            json['startAt'] ??
            json['beginDate'] ??
            json['createdAt'],
      ),
      endDate: _parseDate(
        json['endDate'] ??
            json['expiresAt'] ??
            json['expiryDate'] ??
            json['expiredAt'] ??
            json['dueDate'],
      ),
      isActive: active,
    );
  }

  static String _resolveSubscriberName(Map<String, dynamic> json) {
    final candidates = <String?>[
      json['subscriberName']?.toString(),
      json['name']?.toString(),
      json['fullName']?.toString(),
      json['displayName']?.toString(),
      json['username']?.toString(),
    ];

    final user = json['user'];
    if (user is Map<String, dynamic>) {
      candidates.addAll(<String?>[
        user['name']?.toString(),
        user['fullName']?.toString(),
        user['displayName']?.toString(),
        user['username']?.toString(),
      ]);
    }

    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'بدون اسم';
  }

  static String _resolvePackageType(Map<String, dynamic> json) {
    final candidates = <String?>[
      json['packageType']?.toString(),
      json['package']?.toString(),
      json['plan']?.toString(),
      json['subscriptionPlan']?.toString(),
      json['packageName']?.toString(),
      json['package_name']?.toString(),
    ];

    final package = json['package'];
    if (package is Map<String, dynamic>) {
      candidates.addAll(<String?>[
        package['name']?.toString(),
        package['title']?.toString(),
        package['type']?.toString(),
      ]);
    }

    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'غير محدد';
  }

  static bool _resolveIsActive(Map<String, dynamic> json) {
    final status = _statusText(json);
    if (json['isActive'] == true || json['active'] == true) {
      return true;
    }
    if (status.contains('active') ||
        status.contains('valid') ||
        status.contains('current') ||
        status.contains('running')) {
      return true;
    }

    final endDate = _parseDate(
      json['endDate'] ??
          json['expiresAt'] ??
          json['expiryDate'] ??
          json['expiredAt'] ??
          json['dueDate'],
    );
    if (endDate != null && endDate.isAfter(DateTime.now())) {
      return true;
    }

    return false;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    final parsedMilliseconds = int.tryParse(text);
    if (parsedMilliseconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(parsedMilliseconds);
    }

    try {
      return DateTime.parse(text);
    } catch (_) {
      return null;
    }
  }

  static String _statusText(Map<String, dynamic> json) {
    return (json['status'] ?? json['state'] ?? json['subscriptionStatus'] ?? '')
        .toString()
        .toLowerCase();
  }

  static String _formatDate(DateTime? date) {
    if (date == null) {
      return '--';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
