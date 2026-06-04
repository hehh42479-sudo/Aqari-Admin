import 'package:go_router/go_router.dart';

import '../../features/admin_records/admin_endpoint_table_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/placeholders/admin_placeholder_screen.dart';
import '../../features/properties/properties_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/subscriptions/subscriptions_screen.dart';
import '../../features/supervisors/supervisors_screen.dart';
import '../../features/users/user_management_screen.dart';
import '../../../screens/login_screen.dart';
import '../state/admin_session_controller.dart';
import '../widgets/admin_layout.dart';

GoRouter createAdminRouter(AdminSessionController sessionController) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      if (!sessionController.isReady) {
        await sessionController.initialize();
      }

      final loggingIn = state.matchedLocation == '/login';
      final hasToken = sessionController.isAuthenticated;

      if (!hasToken) {
        return loggingIn ? null : '/login';
      }

      if (loggingIn) {
        return '/dashboard';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => '/login'),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/packages', redirect: (context, state) => '/subscriptions'),
      ShellRoute(
        builder: (context, state, child) {
          return AdminLayout(currentLocation: state.uri.path, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/properties',
            builder: (context, state) => const PropertiesScreen(),
          ),
          GoRoute(
            path: '/owners',
            builder: (context, state) => const UserManagementScreen(
              title: 'المالك',
              role: 'owner',
            ),
          ),
          GoRoute(
            path: '/offices',
            builder: (context, state) => const UserManagementScreen(
              title: 'المكاتب العقارية',
              role: 'office',
            ),
          ),
          GoRoute(
            path: '/seekers',
            builder: (context, state) => const UserManagementScreen(
              title: 'الباحثون',
              role: 'seeker',
            ),
          ),
          GoRoute(
            path: '/supervisors',
            builder: (context, state) => const SupervisorsScreen(),
          ),
          GoRoute(
            path: '/subscriptions',
            builder: (context, state) => const SubscriptionsScreen(),
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) => AdminEndpointTableScreen(
              title: 'المدفوعات',
              subtitle: 'عرض سجلات المدفوعات المرتبطة بالحسابات والإعلانات.',
              emptyMessage: 'لا توجد بيانات حالياً.',
              fetchRecords: (service) => service.fetchPayments(),
              titleKeys: const <String>['title', 'name', 'user', 'payer'],
              subtitleKeys: const <String>[
                'amount',
                'price',
                'method',
                'phone',
              ],
              statusKeys: const <String>['status', 'state'],
            ),
          ),
          GoRoute(
            path: '/featured-properties',
            builder: (context, state) => AdminEndpointTableScreen(
              title: 'العقارات المميزة',
              subtitle:
                  'إدارة قائمة العقارات المميزة القادمة من قاعدة البيانات.',
              emptyMessage: 'لا توجد بيانات حالياً.',
              fetchRecords: (service) => service.fetchFeaturedProperties(),
              titleKeys: const <String>['title', 'name', 'propertyTitle'],
              subtitleKeys: const <String>[
                'city',
                'location',
                'price',
                'type',
              ],
              statusKeys: const <String>['status', 'featured', 'state'],
            ),
          ),
          GoRoute(
            path: '/complaints',
            builder: (context, state) => AdminEndpointTableScreen(
              title: 'البلاغات والشكاوي',
              subtitle:
                  'مراجعة البلاغات والشكاوي وإدارتها من لوحة التحكم.',
              emptyMessage: 'لا توجد بيانات حالياً.',
              fetchRecords: (service) => service.fetchComplaints(),
              titleKeys: const <String>['title', 'subject', 'name', 'type'],
              subtitleKeys: const <String>[
                'description',
                'message',
                'details',
                'createdAt',
              ],
              statusKeys: const <String>['status', 'state', 'priority'],
            ),
          ),
          GoRoute(
            path: '/messages-support',
            builder: (context, state) => AdminEndpointTableScreen(
              title: 'الرسائل والدعم',
              subtitle:
                  'الرسائل الواردة من المستخدمين وطلبات الدعم الفني.',
              emptyMessage: 'لا توجد بيانات حالياً.',
              fetchRecords: (service) => service.fetchMessages(),
              titleKeys: const <String>['title', 'subject', 'name', 'sender'],
              subtitleKeys: const <String>[
                'message',
                'body',
                'description',
                'email',
              ],
              statusKeys: const <String>['status', 'state', 'readStatus'],
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const AdminPlaceholderScreen(
              title: 'التقارير والإحصائيات',
            ),
          ),
          GoRoute(
            path: '/activity-logs',
            builder: (context, state) =>
                const AdminPlaceholderScreen(title: 'سجل الأنشطة'),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    refreshListenable: sessionController,
    debugLogDiagnostics: false,
  );
}
