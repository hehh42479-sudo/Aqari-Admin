import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminDataService = context.read<AdminDataService>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'سجل الأنشطة',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          const Text(
            'عرض أحدث الإجراءات التي تمت بواسطة النظام أو المشرفين.',
            style: TextStyle(fontSize: 16, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: adminDataService.fetchAdminActivityLog(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'فشل تحميل السجل',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final activities = snapshot.data ?? <Map<String, dynamic>>[];
              if (activities.isEmpty) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Center(
                      child: Text(
                        'لا توجد أنشطة مسجلة حالياً',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF3F4F6),
                  ),
                  columns: const <DataColumn>[
                    DataColumn(label: Text('التاريخ')),
                    DataColumn(label: Text('الإجراء')),
                    DataColumn(label: Text('المستخدم')),
                  ],
                  rows: activities.map((activity) {
                    return DataRow(
                      cells: <DataCell>[
                        DataCell(Text(_formattedDate(activity))),
                        DataCell(Text(_readAction(activity))),
                        DataCell(Text(_readUser(activity))),
                      ],
                    );
                  }).toList(growable: false),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _formattedDate(Map<String, dynamic> activity) {
    final dateValue = activity['createdAt'] ??
        activity['timestamp'] ??
        activity['date'] ??
        activity['time'] ??
        activity['created_at'];
    if (dateValue is String) {
      return dateValue.split('T').first;
    }

    if (dateValue is DateTime) {
      return dateValue.toIso8601String().split('T').first;
    }

    return dateValue?.toString() ?? '-';
  }

  static String _readAction(Map<String, dynamic> activity) {
    return activity['action'] ??
        activity['description'] ??
        activity['event'] ??
        activity['activity'] ??
        '-';
  }

  static String _readUser(Map<String, dynamic> activity) {
    final user = activity['user'] ??
        activity['performedBy'] ??
        activity['actor'] ??
        activity['name'];
    if (user is Map<String, dynamic>) {
      return user['name']?.toString() ?? user['id']?.toString() ?? '-';
    }
    return user?.toString() ?? '-';
  }
}
