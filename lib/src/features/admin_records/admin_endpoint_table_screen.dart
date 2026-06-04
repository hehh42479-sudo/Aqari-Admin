import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

class AdminEndpointTableScreen extends StatefulWidget {
  const AdminEndpointTableScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.fetchRecords,
    required this.titleKeys,
    this.subtitleKeys = const <String>[],
    this.statusKeys = const <String>[],
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final Future<List<Map<String, dynamic>>> Function(AdminDataService service)
      fetchRecords;
  final List<String> titleKeys;
  final List<String> subtitleKeys;
  final List<String> statusKeys;

  @override
  State<AdminEndpointTableScreen> createState() =>
      _AdminEndpointTableScreenState();
}

class _AdminEndpointTableScreenState extends State<AdminEndpointTableScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _records = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecords();
    });
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      final records = await widget.fetchRecords(service);
      if (!mounted) {
        return;
      }

      setState(() {
        _records = records;
        _isLoading = false;
      });
    } on DioException catch (error) {
      debugPrint(
        '${widget.title} load failed: ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      final statusCode = error.response?.statusCode;
      setState(() {
        _records = <Map<String, dynamic>>[];
        _isLoading = false;
        _errorMessage = statusCode == 404 ? null : _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('${widget.title} load failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _records = <Map<String, dynamic>>[];
        _isLoading = false;
        _errorMessage =
            'تعذر تحميل البيانات حالياً. حاول تحديث الصفحة.';
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
      case 401:
        return 'انتهت صلاحية الدخول. يرجى تسجيل الدخول مرة أخرى.';
      case 404:
        return 'لا توجد بيانات حالياً.';
      default:
        return 'تعذر تحميل البيانات حالياً.';
    }
  }

  List<DataColumn> _buildColumns() {
    return const <DataColumn>[
      DataColumn(label: Text('#')),
      DataColumn(label: Text('العنوان')),
      DataColumn(label: Text('التفاصيل')),
      DataColumn(label: Text('الحالة')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.subtitle,
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
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'عرض السجلات المرتبطة بهذه الخدمة.',
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
                  else if (_records.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.emptyMessage,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 56,
                            dataRowMinHeight: 68,
                            dataRowMaxHeight: 96,
                            columnSpacing: 24,
                            horizontalMargin: 20,
                            showCheckboxColumn: false,
                            columns: _buildColumns(),
                            rows: _records.asMap().entries.map((entry) {
                              final index = entry.key;
                              final record = entry.value;
                              return DataRow.byIndex(
                                index: index,
                                cells: <DataCell>[
                                  DataCell(Text('${index + 1}')),
                                  DataCell(
                                    SizedBox(
                                      width: 260,
                                      child: Text(
                                        _readText(record, widget.titleKeys),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 420,
                                      child: Text(
                                        _buildDetails(record),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(_readStatus(record))),
                                ],
                              );
                            }).toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _readStatus(Map<String, dynamic> record) {
    final value = _readText(record, widget.statusKeys);
    return value.isEmpty ? '--' : value;
  }

  String _buildDetails(Map<String, dynamic> record) {
    final parts = <String>[];
    if (widget.subtitleKeys.isNotEmpty) {
      final subtitle = _readText(record, widget.subtitleKeys);
      if (subtitle.isNotEmpty) {
        parts.add(subtitle);
      }
    }

    final value = _firstMeaningfulValue(record);
    if (value.isNotEmpty && !parts.contains(value)) {
      parts.add(value);
    }

    return parts.isEmpty ? '--' : parts.join(' • ');
  }

  String _firstMeaningfulValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key == 'id' ||
            key == '_id' ||
            key == '__v' ||
            key == 'createdat' ||
            key == 'updatedat') {
          continue;
        }

        final text = _stringify(entry.value);
        if (text.isNotEmpty) {
          return '$key: $text';
        }
      }
    }

    if (value is List) {
      for (final item in value) {
        final text = _stringify(item);
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    return '';
  }

  String _readText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final text = _stringify(value);
      if (text.isNotEmpty) {
        return text;
      }
    }

    final nested = json['data'];
    if (nested is Map<String, dynamic>) {
      for (final key in keys) {
        final text = _stringify(nested[key]);
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    return '';
  }

  String _stringify(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value.trim();
    }
    if (value is num || value is bool) {
      return value.toString().trim();
    }
    if (value is Map<String, dynamic>) {
      return _firstMeaningfulValue(value);
    }
    if (value is List) {
      final values = value
          .map(_stringify)
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      return values.join(', ');
    }
    return value.toString().trim();
  }
}
