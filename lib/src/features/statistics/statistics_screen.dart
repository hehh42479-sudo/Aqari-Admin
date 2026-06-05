import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminDataService = context.read<AdminDataService>();
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1200
        ? 4
        : width >= 900
            ? 3
            : width >= 640
                ? 2
                : 1;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'التقارير والإحصائيات',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          const Text(
            'نظرة سريعة على مؤشرات لوحة التحكم وإجمالي الحسابات.',
            style: TextStyle(fontSize: 16, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 24),
          FutureBuilder<AdminStats>(
            future: adminDataService.fetchStatistics(),
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
                          'فشل تحميل البيانات',
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

              final stats = snapshot.data!;
              final items = <_StatCardData>[
                _StatCardData(
                  label: 'إجمالي المستخدمين',
                  value: stats.totalUsers.toString(),
                  icon: Icons.people_alt_outlined,
                  color: const Color(0xFF2F80ED),
                ),
                _StatCardData(
                  label: 'إجمالي العقارات',
                  value: stats.totalProperties.toString(),
                  icon: Icons.home_work_outlined,
                  color: const Color(0xFF219653),
                ),
                _StatCardData(
                  label: 'العقارات النشطة',
                  value: stats.activeProperties.toString(),
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF56CCF2),
                ),
                _StatCardData(
                  label: 'العقارات المعلقة',
                  value: stats.pendingProperties.toString(),
                  icon: Icons.pending_actions_outlined,
                  color: const Color(0xFFF2994A),
                ),
                _StatCardData(
                  label: 'إجمالي المشرفين',
                  value: stats.supervisorsCount.toString(),
                  icon: Icons.admin_panel_settings_outlined,
                  color: const Color(0xFF9B51E0),
                ),
                _StatCardData(
                  label: 'إجمالي العقارات المميزة',
                  value: stats.featuredProperties.toString(),
                  icon: Icons.star_border_outlined,
                  color: const Color(0xFFF2C94C),
                ),
                _StatCardData(
                  label: 'إيرادات الشهر',
                  value: '${stats.monthlyRevenue.toStringAsFixed(0)} ر.س',
                  icon: Icons.monetization_on_outlined,
                  color: const Color(0xFF27AE60),
                ),
              ];

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.48,
                children: items
                    .map((item) => _StatisticCard(item: item))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({required this.item});

  final _StatCardData item;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.color, size: 26),
            ),
            const SizedBox(height: 18),
            Text(
              item.label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: item.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
