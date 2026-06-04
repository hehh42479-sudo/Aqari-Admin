import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/core/services/admin_data_service.dart';
import 'src/core/services/auth_service.dart';
import 'src/core/services/api_service.dart';
import 'src/core/services/token_storage.dart';
import 'src/core/state/admin_session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiService = ApiService();
  final tokenStorage = SharedPreferencesTokenStorage();
  final sessionController = AdminSessionController(
    apiService: apiService,
    tokenStorage: tokenStorage,
  );
  final adminDataService = AdminDataService(apiService: apiService);
  final authService = AuthService();
  await sessionController.initialize();

  runApp(
    AqariAdminApp(
      sessionController: sessionController,
      authService: authService,
      apiService: apiService,
      adminDataService: adminDataService,
    ),
  );
}
