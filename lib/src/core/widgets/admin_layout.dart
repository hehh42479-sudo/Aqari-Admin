import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/admin_session_controller.dart';

class AdminLayout extends StatelessWidget {
  const AdminLayout({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  final Widget child;
  final String currentLocation;

  static const double _desktopBreakpoint = 1024;
  static const double _sidebarWidth = 296;

  static const List<_AdminRouteData> _routes = <_AdminRouteData>[
    _AdminRouteData(
      label: 'لوحة التحكم',
      route: '/dashboard',
      icon: Icons.dashboard_outlined,
    ),
    _AdminRouteData(
      label: 'العقارات',
      route: '/properties',
      icon: Icons.home_work_outlined,
    ),
    _AdminRouteData(
      label: 'الملاك',
      route: '/owners',
      icon: Icons.person_outline,
    ),
    _AdminRouteData(
      label: 'المكاتب العقارية',
      route: '/offices',
      icon: Icons.apartment_outlined,
    ),
    _AdminRouteData(
      label: 'الباحثون',
      route: '/seekers',
      icon: Icons.manage_search_outlined,
    ),
    _AdminRouteData(
      label: 'طلبات الباحثين',
      route: '/seeker-requests',
      icon: Icons.assignment_outlined,
    ),
    _AdminRouteData(
      label: 'المشرفون والصلاحيات',
      route: '/supervisors',
      icon: Icons.group_outlined,
    ),
    _AdminRouteData(
      label: 'الباقات والاشتراكات',
      route: '/subscriptions',
      icon: Icons.workspace_premium_outlined,
    ),
    _AdminRouteData(
      label: 'المدفوعات',
      route: '/payments',
      icon: Icons.payments_outlined,
    ),
    _AdminRouteData(
      label: 'العقارات المميزة',
      route: '/featured-properties',
      icon: Icons.star_border_outlined,
    ),
    _AdminRouteData(
      label: 'البلاغات والشكاوى',
      route: '/complaints',
      icon: Icons.report_outlined,
    ),
    _AdminRouteData(
      label: 'الرسائل والدعم',
      route: '/messages-support',
      icon: Icons.support_agent_outlined,
    ),
    _AdminRouteData(
      label: 'الإشعارات',
      route: '/notifications',
      icon: Icons.notifications_outlined,
    ),
    _AdminRouteData(
      label: 'طلبات التوثيق',
      route: '/verifications',
      icon: Icons.verified_user_outlined,
    ),
    _AdminRouteData(
      label: 'التقارير والإحصائيات',
      route: '/reports',
      icon: Icons.bar_chart_outlined,
    ),
    _AdminRouteData(
      label: 'سجل الأنشطة',
      route: '/activity-logs',
      icon: Icons.receipt_long_outlined,
    ),
    _AdminRouteData(
      label: 'الإعدادات',
      route: '/settings',
      icon: Icons.settings_outlined,
    ),
    _AdminRouteData(
      label: 'المواقع الجغرافية',
      route: '/locations',
      icon: Icons.map_outlined,
    ),
    _AdminRouteData(
      label: 'أنواع العقارات',
      route: '/property-types',
      icon: Icons.category_outlined,
    ),
    _AdminRouteData(
      label: 'إدارة الموظفين',
      route: '/all-employees',
      icon: Icons.badge_outlined,
    ),
    _AdminRouteData(
      label: 'إدارة المحادثات',
      route: '/chats-management',
      icon: Icons.chat_outlined,
    ),
    _AdminRouteData(
      label: 'إدارة التقييمات',
      route: '/ratings',
      icon: Icons.star_half_outlined,
    ),
    _AdminRouteData(
      label: 'إدارة المحتوى',
      route: '/content-pages',
      icon: Icons.article_outlined,
    ),
    _AdminRouteData(
      label: 'الإعلانات',
      route: '/ads',
      icon: Icons.campaign_outlined,
    ),
    _AdminRouteData(
      label: 'مراقبة النظام',
      route: '/monitoring',
      icon: Icons.monitor_heart_outlined,
    ),
    _AdminRouteData(
      label: 'النسخ الاحتياطي',
      route: '/backup',
      icon: Icons.backup_outlined,
    ),
    _AdminRouteData(
      label: 'إدارة الأمان',
      route: '/security',
      icon: Icons.security_outlined,
    ),
    _AdminRouteData(
      label: 'مركز الطوارئ',
      route: '/emergency',
      icon: Icons.emergency_outlined,
    ),
    _AdminRouteData(
      label: 'إعدادات التطبيق',
      route: '/app-config',
      icon: Icons.tune_outlined,
    ),
    _AdminRouteData(
      label: 'إدارة التحديثات',
      route: '/app-updates',
      icon: Icons.system_update_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSessionController>();
    final visibleRoutes = _visibleRoutes(session);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F7FB),
            body: Row(
              children: <Widget>[
                _AdminSidebar(
                  currentLocation: currentLocation,
                  routes: visibleRoutes,
                  width: _sidebarWidth,
                  isCompact: false,
                ),
                Expanded(child: _AdminContentScaffold(child: child)),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          endDrawer: Drawer(
            child: _AdminSidebar(
              currentLocation: currentLocation,
              routes: visibleRoutes,
              width: _sidebarWidth,
              isCompact: true,
            ),
          ),
          appBar: AppBar(
            title: const Text('Aqari Plus Admin'),
            leading: Builder(
              builder: (context) {
                return IconButton(
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'القائمة',
                );
              },
            ),
          ),
          body: _AdminContentScaffold(isCompact: true, child: child),
        );
      },
    );
  }

  List<_AdminRouteData> _visibleRoutes(AdminSessionController session) {
    if (session.isSuperAdmin || session.role != 'supervisor') {
      return _routes;
    }

    final permissions = session.permissions.toSet();
    return _routes.where((route) {
      final requiredPermission = _requiredPermissionFor(route.route);
      return requiredPermission == null ||
          permissions.contains(requiredPermission);
    }).toList(growable: false);
  }

  String? _requiredPermissionFor(String route) {
    switch (route) {
      case '/properties':
      case '/featured-properties':
        return 'manage_properties';
      case '/owners':
      case '/offices':
      case '/seekers':
      case '/seeker-requests':
      case '/supervisors':
        return 'manage_users';
      case '/subscriptions':
        return 'manage_subscriptions';
      case '/payments':
      case '/notifications':
      case '/reports':
      case '/activity-logs':
      case '/settings':
        return 'manage_settings';
      case '/complaints':
      case '/messages-support':
        return 'manage_requests';
      case '/verifications':
        return 'manage_users';
      case '/locations':
      case '/property-types':
        return 'manage_properties';
      case '/all-employees':
        return 'manage_users';
      case '/chats-management':
      case '/ratings':
        return 'manage_requests';
      case '/content-pages':
      case '/ads':
      case '/app-config':
      case '/app-updates':
        return 'manage_settings';
      case '/monitoring':
      case '/backup':
      case '/security':
      case '/emergency':
        return 'manage_settings';
      default:
        return null;
    }
  }
}

class _AdminContentScaffold extends StatelessWidget {
  const _AdminContentScaffold({required this.child, this.isCompact = false});

  final Widget child;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 24),
        // SizedBox.expand ensures every child screen receives tight height
        // constraints so that Column + Expanded children never overflow on web.
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.currentLocation,
    required this.routes,
    required this.width,
    required this.isCompact,
  });

  final String currentLocation;
  final List<_AdminRouteData> routes;
  final double width;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF082949), Color(0xFF0B3A66)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 20,
                18,
                isCompact ? 16 : 20,
                12,
              ),
              child: _BrandHeader(isCompact: isCompact),
            ),
            const Divider(color: Color(0x1AFFFFFF), height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 16,
                  vertical: 16,
                ),
                children: <Widget>[
                  ...routes.map(
                    (route) => _SidebarItem(
                      route: route,
                      isActive: currentLocation == route.route,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0x1AFFFFFF), height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 12 : 16,
                14,
                isCompact ? 12 : 16,
                isCompact ? 14 : 18,
              ),
              child: _LogoutButton(isCompact: isCompact),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: isCompact ? 40 : 48,
          height: isCompact ? 40 : 48,
            decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.apartment_rounded, color: Colors.white),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text(
                'Aqari Plus Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Admin Panel',
                style: TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.route, required this.isActive});

  final _AdminRouteData route;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : const Color(0xFFDDE8F4);
    final background = isActive
      ? Colors.white.withValues(alpha: 0.14)
      : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go(route.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.transparent,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(route.icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    route.label,
                    style: TextStyle(
                      color: color,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFD4D4),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 14,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () async {
          await context.read<AdminSessionController>().logout();
          if (context.mounted) {
            context.go('/login');
          }
        },
        icon: const Icon(Icons.logout_rounded, size: 22),
        label: const Text(
          'تسجيل الخروج',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AdminRouteData {
  const _AdminRouteData({
    required this.label,
    required this.route,
    required this.icon,
  });

  final String label;
  final String route;
  final IconData icon;
}
