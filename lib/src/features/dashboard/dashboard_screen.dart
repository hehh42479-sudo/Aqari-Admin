import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AdminStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _loadStats() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      final stats = await service.fetchStats();
      if (!mounted) {
        return;
      }

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } on DioException catch (error) {
      debugPrint(
        'Dashboard stats load failed: ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _stats = null;
        _isLoading = false;
        _errorMessage = 'تعذر تحميل بيانات لوحة التحكم. حاول تحديث الصفحة.';
      });
    } catch (error) {
      debugPrint('Dashboard stats load failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _stats = null;
        _isLoading = false;
        _errorMessage = 'تعذر تحميل بيانات لوحة التحكم. حاول تحديث الصفحة.';
      });
    }
  }

  List<_SummaryItem> _buildSummaryItems(AdminStats? stats) {
    final effectiveStats = stats ?? const AdminStats(
      totalProperties: 0,
      activeProperties: 0,
      pendingProperties: 0,
      ownersCount: 0,
      officesCount: 0,
      seekersCount: 0,
      supervisorsCount: 0,
      featuredProperties: 0,
      soldProperties: 0,
      rentedProperties: 0,
      monthlyRevenue: 0,
      raw: <String, dynamic>{},
    );

    return <_SummaryItem>[
      _SummaryItem(
        title: 'إجمالي العقارات',
        value: _formatNumber(effectiveStats.totalProperties),
        icon: Icons.home_work_outlined,
        accent: const Color(0xFF1D7CF2),
      ),
      _SummaryItem(
        title: 'العقارات النشطة',
        value: _formatNumber(effectiveStats.activeProperties),
        icon: Icons.check_circle_outline,
        accent: const Color(0xFF17B26A),
      ),
      _SummaryItem(
        title: 'بانتظار المراجعة',
        value: _formatNumber(effectiveStats.pendingProperties),
        icon: Icons.pending_actions_outlined,
        accent: const Color(0xFFF39C12),
      ),
      _SummaryItem(
        title: 'إجمالي الملاك',
        value: _formatNumber(effectiveStats.ownersCount),
        icon: Icons.group_outlined,
        accent: const Color(0xFF7B61FF),
      ),
      _SummaryItem(
        title: 'إجمالي المكاتب',
        value: _formatNumber(effectiveStats.officesCount),
        icon: Icons.business_outlined,
        accent: const Color(0xFF0F9D90),
      ),
      _SummaryItem(
        title: 'الباحثون',
        value: _formatNumber(effectiveStats.seekersCount),
        icon: Icons.manage_search_outlined,
        accent: const Color(0xFFDE6C3D),
      ),
      _SummaryItem(
        title: 'العقارات المميزة',
        value: _formatNumber(effectiveStats.featuredProperties),
        icon: Icons.star_outline_rounded,
        accent: const Color(0xFF9A6B00),
      ),
      _SummaryItem(
        title: 'العقارات المُباعة',
        value: _formatNumber(effectiveStats.soldProperties),
        icon: Icons.sell_outlined,
        accent: const Color(0xFF1D7CF2),
      ),
      _SummaryItem(
        title: 'العقارات المؤجرة',
        value: _formatNumber(effectiveStats.rentedProperties),
        icon: Icons.key_outlined,
        accent: const Color(0xFF7B61FF),
      ),
      _SummaryItem(
        title: 'الإيراد الشهري',
        value: _formatCurrency(effectiveStats.monthlyRevenue),
        icon: Icons.account_balance_wallet_outlined,
        accent: const Color(0xFF0B3A66),
      ),
    ];
  }

  String _formatNumber(int value) {
    return value.toString();
  }

  String _formatCurrency(double value) {
    if (value <= 0) {
      return 'SAR 0';
    }

    final isWhole = value.truncateToDouble() == value;
    final formatted = isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    return 'SAR $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final summaryItems = _buildSummaryItems(stats);

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _DashboardHeader(
              title: 'لوحة التحكم',
              subtitle: 'نظرة مباشرة على مؤشرات الأداء من API الإدارة الحي.',
              onRefresh: _loadStats,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const _LoadingPanel()
            else if (_errorMessage != null)
              _ErrorPanel(message: _errorMessage!, onRetry: _loadStats)
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth >= 1280
                      ? 4
                      : constraints.maxWidth >= 900
                      ? 3
                      : constraints.maxWidth >= 640
                      ? 2
                      : 1;

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: summaryItems.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.55,
                    ),
                    itemBuilder: (context, index) {
                      final item = summaryItems[index];
                      return _SummaryCard(item: item);
                    },
                  );
                },
              ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1000;
                final leftPanel = _InsightsPanel(
                  title: 'الملاحة السريعة',
                  rows: <_InsightRow>[
                    _InsightRow(label: 'العقارات النشطة', value: _formatNumber(stats?.activeProperties ?? 0)),
                    _InsightRow(label: 'بانتظار المراجعة', value: _formatNumber(stats?.pendingProperties ?? 0)),
                    _InsightRow(label: 'العقارات المميزة', value: _formatNumber(stats?.featuredProperties ?? 0)),
                    _InsightRow(label: 'المُباعة', value: _formatNumber(stats?.soldProperties ?? 0)),
                    _InsightRow(label: 'المؤجرة', value: _formatNumber(stats?.rentedProperties ?? 0)),
                  ],
                );
                final rightPanel = _InsightsPanel(
                  title: 'بيانات مباشرة',
                  rows: <_InsightRow>[
                    _InsightRow(label: 'إجمالي العقارات', value: _formatNumber(stats?.totalProperties ?? 0)),
                    _InsightRow(label: 'إجمالي الملاك', value: _formatNumber(stats?.ownersCount ?? 0)),
                    _InsightRow(label: 'إجمالي المكاتب', value: _formatNumber(stats?.officesCount ?? 0)),
                    _InsightRow(label: 'الباحثون', value: _formatNumber(stats?.seekersCount ?? 0)),
                  ],
                );

                if (isWide) {
                  return Row(
                    children: <Widget>[
                      Expanded(child: leftPanel),
                      const SizedBox(width: 18),
                      Expanded(child: rightPanel),
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    leftPanel,
                    const SizedBox(height: 18),
                    rightPanel,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0B3A66), Color(0xFF144C82)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تحديث'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0B3A66),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFB42318),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item});

  final _SummaryItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(item.icon, color: item.accent),
            ),
            const SizedBox(height: 20),
            Text(
              item.value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(item.title, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_InsightRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        row.label,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      row.value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0B3A66),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightRow {
  const _InsightRow({required this.label, required this.value});

  final String label;
  final String value;
}

class _SummaryItem {
  const _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
}
