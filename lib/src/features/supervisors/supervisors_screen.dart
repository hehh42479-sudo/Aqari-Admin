import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

class SupervisorsScreen extends StatefulWidget {
  const SupervisorsScreen({super.key});

  @override
  State<SupervisorsScreen> createState() => _SupervisorsScreenState();
}

class _SupervisorsScreenState extends State<SupervisorsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SupervisorRecord> _supervisors = <SupervisorRecord>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSupervisors();
    });
  }

  Future<void> _loadSupervisors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      final rawSupervisors = await service.fetchSupervisors();
      if (!mounted) {
        return;
      }

      setState(() {
        _supervisors = rawSupervisors
            .map(SupervisorRecord.fromJson)
            .toList(growable: false);
        _isLoading = false;
      });
    } on DioException catch (error) {
      debugPrint(
        'Supervisors load failed: ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _supervisors = <SupervisorRecord>[];
        _isLoading = false;
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Supervisors load failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _supervisors = <SupervisorRecord>[];
        _isLoading = false;
        _errorMessage = 'تعذر تحميل بيانات المشرفين حالياً. حاول تحديث الصفحة.';
      });
    }
  }

  Future<void> _openSupervisorDialog({SupervisorRecord? supervisor}) async {
    final service = context.read<AdminDataService>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _SupervisorDialog(
          service: service,
          existingSupervisor: supervisor,
          onSaved: () async {
            await _loadSupervisors();
            if (!mounted) {
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  supervisor == null
                      ? 'تم إضافة المشرف بنجاح'
                      : 'تم حفظ التعديلات بنجاح',
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF17B26A),
              ),
            );
          },
        );
      },
    );
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
        return 'تعذر العثور على خدمة المشرفين.';
      default:
        return 'تعذر تحميل بيانات المشرفين حالياً.';
    }
  }

  List<DataColumn> _buildColumns() {
    return const <DataColumn>[
      DataColumn(label: Text('اسم المشرف')),
      DataColumn(label: Text('رقم الهاتف')),
      DataColumn(label: Text('الصلاحيات')),
      DataColumn(label: Text('الإجراءات')),
    ];
  }

  Widget _buildTablePane(List<SupervisorRecord> supervisors) {
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
              dataRowMinHeight: 68,
              dataRowMaxHeight: 104,
              columnSpacing: 24,
              horizontalMargin: 20,
              showCheckboxColumn: false,
              columns: _buildColumns(),
              rows: supervisors.asMap().entries.map((entry) {
                final index = entry.key;
                final supervisor = entry.value;

                return DataRow.byIndex(
                  index: index,
                  cells: <DataCell>[
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          supervisor.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    DataCell(Text(supervisor.phone)),
                    DataCell(
                      SizedBox(
                        width: 320,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: supervisor.permissions
                              .map(
                                (permission) => Chip(
                                  label: Text(
                                    _permissionLabel(permission),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'تعديل',
                            onPressed: () => _openSupervisorDialog(
                              supervisor: supervisor,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () => _showSnackBar('سيتم الحذف قريباً'),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'المشرفون والصلاحيات',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'إدارة المشرفين وتوزيع الصلاحيات الممنوحة لكل حساب.',
              style: Theme.of(context).textTheme.bodyLarge,
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
                        'قائمة المشرفين',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'عرض المشرفين المعتمدين وإدارة الصلاحيات المرتبطة بهم.',
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
                      else if (_supervisors.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              'لا توجد بيانات مشرفين متاحة حالياً.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        )
                      else
                        _buildTablePane(_supervisors),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: FloatingActionButton.extended(
            onPressed: () => _openSupervisorDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة مشرف'),
          ),
        ),
      ],
    );
  }
}

class _SupervisorDialog extends StatefulWidget {
  const _SupervisorDialog({
    required this.service,
    required this.onSaved,
    this.existingSupervisor,
  });

  final AdminDataService service;
  final SupervisorRecord? existingSupervisor;
  final Future<void> Function()? onSaved;

  @override
  State<_SupervisorDialog> createState() => _SupervisorDialogState();
}

class _SupervisorDialogState extends State<_SupervisorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final Set<String> _selectedPermissions = <String>{};

  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<_PermissionItem> _permissionItems = <_PermissionItem>[
    _PermissionItem(
      label: 'إدارة العقارات',
      value: 'manage_properties',
    ),
    _PermissionItem(
      label: 'إدارة المستخدمين',
      value: 'manage_users',
    ),
    _PermissionItem(
      label: 'إدارة الاشتراكات والمدفوعات',
      value: 'manage_subscriptions',
    ),
    _PermissionItem(
      label: 'إدارة الطلبات',
      value: 'manage_requests',
    ),
    _PermissionItem(
      label: 'إعدادات النظام',
      value: 'manage_settings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingSupervisor;
    if (existing != null) {
      _nameController.text = existing.name;
      _phoneController.text = existing.phone;
      _selectedPermissions.addAll(existing.permissions);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_selectedPermissions.isEmpty) {
      setState(() {
        _errorMessage = 'اختر صلاحية واحدة على الأقل';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.service.createSupervisor(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        permissions: _selectedPermissions.toList(growable: false),
        supervisorId: widget.existingSupervisor?.id,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      final onSaved = widget.onSaved;
      if (onSaved != null) {
        await onSaved();
      }
    } on DioException catch (error) {
      debugPrint(
        'Supervisor save failed: ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Supervisor save failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorMessage =
            'تعذر حفظ بيانات المشرف حالياً. حاول مرة أخرى.';
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
        return 'تعذر العثور على خدمة المشرفين.';
      default:
        return 'تعذر حفظ بيانات المشرف حالياً.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingSupervisor == null
            ? 'إضافة مشرف جديد'
            : 'تعديل بيانات المشرف',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الاسم مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'رقم الهاتف مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  'الصلاحيات الممنوحة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ..._permissionItems.map(
                  (permission) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(permission.label),
                    value: _selectedPermissions.contains(permission.value),
                    onChanged: _isSubmitting
                        ? null
                        : (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedPermissions.add(permission.value);
                              } else {
                                _selectedPermissions.remove(permission.value);
                              }
                            });
                          },
                  ),
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 10),
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
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
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
              : const Text('حفظ'),
        ),
      ],
    );
  }
}

class SupervisorRecord {
  SupervisorRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.permissions,
  });

  final String id;
  final String name;
  final String phone;
  final List<String> permissions;

  factory SupervisorRecord.fromJson(Map<String, dynamic> json) {
    return SupervisorRecord(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: _readText(json, <String>[
        'name',
        'fullName',
        'displayName',
        'username',
      ]),
      phone: _readText(json, <String>[
        'phone',
        'phoneNumber',
        'mobile',
        'mobileNumber',
      ]),
      permissions: _readPermissions(json),
    );
  }

  static String _readText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    final nested = json['user'];
    if (nested is Map<String, dynamic>) {
      for (final key in keys) {
        final value = nested[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
        if (value != null) {
          final text = value.toString().trim();
          if (text.isNotEmpty) {
            return text;
          }
        }
      }
    }

    return '--';
  }

  static List<String> _readPermissions(Map<String, dynamic> json) {
    final values = <String>[];
    final raw = json['permissions'];
    if (raw is List) {
      for (final item in raw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          values.add(text);
        }
      }
    } else if (raw is String && raw.trim().isNotEmpty) {
      values.addAll(
        raw
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      );
    } else if (raw != null) {
      final text = raw.toString().trim();
      if (text.isNotEmpty) {
        values.add(text);
      }
    }

    final nested = json['rolePermissions'];
    if (values.isEmpty && nested is List) {
      for (final item in nested) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          values.add(text);
        }
      }
    }

    return values.toList(growable: false);
  }
}

class _PermissionItem {
  const _PermissionItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

String _permissionLabel(String value) {
  switch (value) {
    case 'manage_properties':
      return 'إدارة العقارات';
    case 'manage_users':
      return 'إدارة المستخدمين';
    case 'manage_subscriptions':
      return 'إدارة الاشتراكات والمدفوعات';
    case 'manage_requests':
      return 'إدارة الطلبات';
    case 'manage_settings':
      return 'إعدادات النظام';
    default:
      return value;
  }
}
