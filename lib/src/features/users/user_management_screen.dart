import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    super.key,
    required this.title,
    required this.role,
  });

  final String title;
  final String role;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<UserRecord> _users = <UserRecord>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      final rawUsers = await service.fetchUsersByRole(widget.role);
      if (!mounted) {
        return;
      }

      setState(() {
        _users = rawUsers.map(UserRecord.fromJson).toList(growable: false);
        _isLoading = false;
        _errorMessage = null;
      });
    } on DioException catch (error) {
      debugPrint(
        'Users load failed (${widget.role}): ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _users = <UserRecord>[];
        _isLoading = false;
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Users load failed (${widget.role}): $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _users = <UserRecord>[];
        _isLoading = false;
        _errorMessage = 'تعذر تحميل البيانات حالياً. حاول تحديث الصفحة.';
      });
    }
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final candidate = data['message'] ??
          data['error'] ??
          data['details'] ??
          data['msg'];
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    switch (error.response?.statusCode) {
      case 404:
        return 'تعذر العثور على بيانات هذا القسم.';
      case 401:
        return 'انتهت صلاحية الدخول. يرجى تسجيل الدخول مرة أخرى.';
      default:
        return 'تعذر تحميل البيانات حالياً. حاول تحديث الصفحة.';
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    return const <DataColumn>[
      DataColumn(label: Text('الاسم')),
      DataColumn(label: Text('رقم الهاتف')),
      DataColumn(label: Text('تاريخ التسجيل')),
      DataColumn(label: Text('الحالة')),
      DataColumn(label: Text('الإجراءات')),
    ];
  }

  Widget _buildTablePane(List<UserRecord> users) {
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
              rows: users.asMap().entries.map((entry) {
                final index = entry.key;
                final user = entry.value;

                return DataRow.byIndex(
                  index: index,
                  cells: <DataCell>[
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          user.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    DataCell(Text(user.phone)),
                    DataCell(Text(user.joinDateLabel)),
                    DataCell(
                      _StatusBadge(
                        label: user.statusLabel,
                        isSuspended: user.isSuspended,
                      ),
                    ),
                    DataCell(
                      _UserActionsCell(
                        onView: () => _showSnackBar('سيتم عرض الملف قريباً'),
                        onSuspend: () => _showSnackBar('سيتم إيقاف الحساب قريباً'),
                        onDelete: () => _showSnackBar('سيتم حذف الحساب قريباً'),
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
    final isOwner = widget.role == 'owner';
    final summaryText = isOwner
        ? 'عرض ومتابعة الملاك المسجلين في النظام.'
        : widget.role == 'office'
        ? 'عرض ومتابعة المكاتب العقارية المسجلة في النظام.'
        : 'عرض ومتابعة الباحثين المسجلين في النظام.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _UsersHeader(
          title: widget.title,
          subtitle: summaryText,
          onRefresh: _loadUsers,
          count: _users.length,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summaryText,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 18),
                  if (_isLoading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    Expanded(
                      child: Center(
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    )
                  else if (_users.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'لا توجد بيانات متاحة حالياً.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    )
                  else
                    _buildTablePane(_users),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UsersHeader extends StatelessWidget {
  const _UsersHeader({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
    required this.count,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
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
        ElevatedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تحديث البيانات'),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.isSuspended,
  });

  final String label;
  final bool isSuspended;

  @override
  Widget build(BuildContext context) {
    final color = isSuspended ? const Color(0xFFB02A37) : const Color(0xFF17B26A);
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

class _UserActionsCell extends StatelessWidget {
  const _UserActionsCell({
    required this.onView,
    required this.onSuspend,
    required this.onDelete,
  });

  final VoidCallback onView;
  final VoidCallback onSuspend;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_UserAction>(
      tooltip: 'الإجراءات',
      icon: const Icon(Icons.more_horiz_rounded, size: 22),
      itemBuilder: (context) {
        return <PopupMenuEntry<_UserAction>>[
          const PopupMenuItem<_UserAction>(
            value: _UserAction.view,
            child: ListTile(
              leading: Icon(Icons.remove_red_eye_outlined),
              title: Text('عرض الملف'),
            ),
          ),
          const PopupMenuItem<_UserAction>(
            value: _UserAction.suspend,
            child: ListTile(
              leading: Icon(Icons.block_outlined),
              title: Text('إيقاف الحساب'),
            ),
          ),
          const PopupMenuItem<_UserAction>(
            value: _UserAction.delete,
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('حذف الحساب'),
            ),
          ),
        ];
      },
      onSelected: (action) {
        switch (action) {
          case _UserAction.view:
            onView();
            break;
          case _UserAction.suspend:
            onSuspend();
            break;
          case _UserAction.delete:
            onDelete();
            break;
        }
      },
    );
  }
}

enum _UserAction { view, suspend, delete }

class UserRecord {
  UserRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.joinedAt,
    required this.statusLabel,
    required this.isSuspended,
  });

  final String id;
  final String name;
  final String phone;
  final DateTime? joinedAt;
  final String statusLabel;
  final bool isSuspended;

  String get joinDateLabel {
    final date = joinedAt;
    if (date == null) {
      return 'غير محدد';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  factory UserRecord.fromJson(Map<String, dynamic> json) {
    final isSuspended =
        json['isSuspended'] == true ||
        json['suspended'] == true ||
        json['blocked'] == true ||
        _statusText(json).contains('suspend') ||
        _statusText(json).contains('block');

    return UserRecord(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: _resolveName(json),
      phone: _resolvePhone(json),
      joinedAt: _parseDate(
        json['createdAt'] ?? json['joinedAt'] ?? json['registrationDate'] ?? json['date'],
      ),
      statusLabel: _resolveStatusLabel(json, isSuspended: isSuspended),
      isSuspended: isSuspended,
    );
  }

  static String _resolveName(Map<String, dynamic> json) {
    final candidates = <String?>[
      json['name']?.toString(),
      json['fullName']?.toString(),
      json['displayName']?.toString(),
      json['username']?.toString(),
    ];

    final firstName = json['firstName']?.toString();
    final lastName = json['lastName']?.toString();
    final nameParts = <String>[];
    if (firstName != null && firstName.trim().isNotEmpty) {
      nameParts.add(firstName.trim());
    }
    if (lastName != null && lastName.trim().isNotEmpty) {
      nameParts.add(lastName.trim());
    }

    final combined = nameParts.join(' ');
    if (combined.isNotEmpty) {
      candidates.insert(0, combined);
    }

    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'بدون اسم';
  }

  static String _resolvePhone(Map<String, dynamic> json) {
    final candidates = <String?>[
      json['phone']?.toString(),
      json['phoneNumber']?.toString(),
      json['mobile']?.toString(),
      json['mobileNumber']?.toString(),
    ];

    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return 'غير متوفر';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static String _statusText(Map<String, dynamic> json) {
    return (json['status'] ?? json['state'] ?? json['accountStatus'] ?? '')
        .toString()
        .toLowerCase();
  }

  static String _resolveStatusLabel(
    Map<String, dynamic> json, {
    required bool isSuspended,
  }) {
    if (isSuspended) {
      return 'موقوف';
    }

    final status = _statusText(json);
    if (status.contains('pending')) {
      return 'قيد المراجعة';
    }
    if (status.contains('active') || status.contains('verified')) {
      return 'نشط';
    }
    if (status.contains('inactive')) {
      return 'غير نشط';
    }

    return 'نشط';
  }
}
