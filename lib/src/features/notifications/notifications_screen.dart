import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  String _selectedAudience = 'all';
  List<NotificationRecord> _history = <NotificationRecord>[];

  static const List<_AudienceOption> _audienceOptions = <_AudienceOption>[
    _AudienceOption(label: 'الجميع', value: 'all'),
    _AudienceOption(label: 'المكاتب', value: 'office'),
    _AudienceOption(label: 'الملاك', value: 'owner'),
    _AudienceOption(label: 'الباحثون', value: 'seeker'),
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
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      final rawHistory = await service.fetchNotifications();
      if (!mounted) {
        return;
      }

      setState(() {
        _history = rawHistory
            .map(NotificationRecord.fromJson)
            .toList(growable: false);
        _isLoading = false;
      });
    } on DioException catch (error) {
      debugPrint(
        'Notifications load failed: ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _history = <NotificationRecord>[];
        _isLoading = false;
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Notifications load failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _history = <NotificationRecord>[];
        _isLoading = false;
        _errorMessage = 'تعذر تحميل الإشعارات حالياً. حاول تحديث الصفحة.';
      });
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      await service.sendNotification(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        audience: _selectedAudience,
      );

      if (!mounted) {
        return;
      }

      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedAudience = 'all';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الإشعار بنجاح'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF17B26A),
        ),
      );

      await _loadHistory();
    } on DioException catch (error) {
      debugPrint(
        'Notification send failed: ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Notification send failed: $error');
      if (!mounted) {
        return;
      }

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

  List<DataColumn> _buildColumns() {
    return const <DataColumn>[
      DataColumn(label: Text('العنوان')),
      DataColumn(label: Text('الجمهور')),
      DataColumn(label: Text('التاريخ')),
    ];
  }

  Widget _buildHistoryTable(List<NotificationRecord> records) {
    return SizedBox(
      height: 420,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
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
            rows: records.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value;

              return DataRow.byIndex(
                index: index,
                cells: <DataCell>[
                  DataCell(
                    SizedBox(
                      width: 320,
                      child: Text(
                        record.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  DataCell(Text(record.audienceLabel)),
                  DataCell(Text(record.dateLabel)),
                ],
              );
            }).toList(growable: false),
          ),
        ),
      ),
    );
  }

  Widget _buildSendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'إرسال إشعار جديد',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الإشعار',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'العنوان مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'نص الرسالة',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'نص الرسالة مطلوب';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedAudience,
                decoration: const InputDecoration(
                  labelText: 'الجمهور المستهدف',
                  border: OutlineInputBorder(),
                ),
                items: _audienceOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.value,
                        child: Text(option.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _isSending
                    ? null
                    : (value) {
                        setState(() {
                          _selectedAudience = value ?? 'all';
                        });
                      },
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendNotification,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إرسال الإشعار'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildSendCard(),
          const SizedBox(height: 20),
          Text(
            'سجل الإشعارات',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null) ...<Widget>[
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
            const SizedBox(height: 16),
          ],
          if (_isLoading)
            const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_history.isEmpty)
            const SizedBox(
              height: 180,
              child: Center(
                child: Text('لا توجد إشعارات مرسلة حالياً.'),
              ),
            )
          else
            _buildHistoryTable(_history),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '📢 الإشعارات',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'إرسال التعميمات ومتابعة سجل الإشعارات المرسلة.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _buildBody(),
            ),
          ),
        ),
      ],
    );
  }
}

class NotificationRecord {
  NotificationRecord({
    required this.title,
    required this.audience,
    required this.date,
  });

  final String title;
  final String audience;
  final DateTime? date;

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
      default:
        return audience.isEmpty ? '--' : audience;
    }
  }

  String get dateLabel {
    final value = date;
    if (value == null) {
      return '--';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      title: _readText(json, <String>[
        'title',
        'subject',
        'headline',
        'name',
      ]),
      audience: _readText(json, <String>[
        'audience',
        'target',
        'recipient',
        'role',
      ]),
      date: _parseDate(
        json['createdAt'] ?? json['date'] ?? json['sentAt'] ?? json['time'],
      ),
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

    final nested = json['data'];
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

    return '';
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
}

class _AudienceOption {
  const _AudienceOption({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}
