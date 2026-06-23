import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ratings Management Screen
// View all ratings, approve/reject, delete
// ─────────────────────────────────────────────────────────────────────────────

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _ratings = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchRatings();
      if (!mounted) return;
      setState(() { _ratings = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _toggle(Map<String, dynamic> rating) async {
    try {
      await context.read<AdminDataService>().toggleRatingApproval(rating['id'].toString());
      if (mounted) _showOk(context, 'تم تحديث حالة التقييم');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> rating) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التقييم'),
        content: const Text('هل تريد حذف هذا التقييم نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AdminDataService>().deleteRating(rating['id'].toString());
      if (mounted) _showOk(context, 'تم حذف التقييم');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Widget _buildStars(dynamic rating) {
    final val = double.tryParse(rating?.toString() ?? '0') ?? 0;
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) =>
      Icon(i < val.round() ? Icons.star_rounded : Icons.star_border_rounded,
          size: 16, color: Colors.amber)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('إدارة التقييمات',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('مراجعة تقييمات المستخدمين والموافقة عليها أو حذفها.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('التقييمات',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'تحديث'),
                    ],
                  ),
                  const Divider(),
                  if (_loading)
                    const Expanded(child: Center(child: CircularProgressIndicator()))
                  else if (_error != null)
                    Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
                  else if (_ratings.isEmpty)
                    const Expanded(child: Center(child: Text('لا توجد تقييمات')))
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('المُقيِّم')),
                              DataColumn(label: Text('المُقيَّم')),
                              DataColumn(label: Text('النجوم')),
                              DataColumn(label: Text('التعليق')),
                              DataColumn(label: Text('الحالة')),
                              DataColumn(label: Text('الإجراءات')),
                            ],
                            rows: _ratings.asMap().entries.map((e) {
                              final i = e.key;
                              final r = e.value;
                              final isApproved = r['is_approved'] == true || r['approved'] == true;
                              return DataRow(cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(Text(_str(r['reviewer_name'] ?? r['from_name'] ?? r['rater_name'], ''))),
                                DataCell(Text(_str(r['target_name'] ?? r['to_name'] ?? r['rated_name'], ''))),
                                DataCell(_buildStars(r['rating'] ?? r['score'] ?? r['stars'])),
                                DataCell(SizedBox(
                                  width: 200,
                                  child: Text(_str(r['comment'] ?? r['review'], ''),
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
                                )),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isApproved ? const Color(0xFF17B26A) : Colors.orange).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(isApproved ? 'معتمد' : 'معلق',
                                      style: TextStyle(
                                          color: isApproved ? const Color(0xFF17B26A) : Colors.orange,
                                          fontWeight: FontWeight.w600)),
                                )),
                                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(
                                    icon: Icon(isApproved ? Icons.visibility_off_outlined : Icons.check_circle_outline,
                                        color: isApproved ? Colors.orange : const Color(0xFF17B26A)),
                                    tooltip: isApproved ? 'إلغاء الموافقة' : 'موافقة',
                                    onPressed: () => _toggle(r),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'حذف',
                                    onPressed: () => _delete(r),
                                  ),
                                ])),
                              ]);
                            }).toList(),
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
}

// ─── helpers ─────────────────────────────────────────────────────────────────
String _str(dynamic v, [String fallback = '-']) =>
    v?.toString().trim().isEmpty == false ? v.toString().trim() : fallback;

String _extractError(dynamic err) {
  if (err is DioException) {
    final d = err.response?.data;
    if (d is Map) {
      final msg = d['message'] ?? d['error'] ?? d['msg'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
  }
  return err.toString();
}

void _showErr(BuildContext ctx, String msg) => ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));

void _showOk(BuildContext ctx, String msg) => ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: const Color(0xFF17B26A), behavior: SnackBarBehavior.floating));
