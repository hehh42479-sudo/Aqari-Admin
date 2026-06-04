import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/services/admin_data_service.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/state/admin_session_controller.dart';
import 'core/theme/admin_theme.dart';

class AqariAdminApp extends StatelessWidget {
  const AqariAdminApp({
    super.key,
    required this.sessionController,
    required this.authService,
    required this.apiService,
    required this.adminDataService,
  });

  final AdminSessionController sessionController;
  final AuthService authService;
  final ApiService apiService;
  final AdminDataService adminDataService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AdminSessionController>.value(
          value: sessionController,
        ),
        Provider<AuthService>.value(value: authService),
        Provider<ApiService>.value(value: apiService),
        Provider<AdminDataService>.value(value: adminDataService),
      ],
      child: Consumer<AdminSessionController>(
        builder: (context, session, _) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Aqari Plus Admin',
            theme: buildAdminTheme(),
            routerConfig: createAdminRouter(session),
            locale: const Locale('ar', 'SA'),
            supportedLocales: const [Locale('ar', 'SA')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
