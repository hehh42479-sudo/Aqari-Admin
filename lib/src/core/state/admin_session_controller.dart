import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../services/token_storage.dart';

class AdminSessionController extends ChangeNotifier {
  AdminSessionController({
    required ApiService apiService,
    required TokenStorage tokenStorage,
  }) : _apiService = apiService,
       _tokenStorage = tokenStorage;

  final ApiService _apiService;
  final TokenStorage _tokenStorage;

  String? _token;
  Map<String, dynamic>? _adminData;
  bool _isReady = false;

  bool get isReady => _isReady;
  String? get token => _token;
  Map<String, dynamic>? get adminData => _adminData;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  String? get role =>
      _readString(_adminData, <String>['role', 'userRole', 'type']);
  bool get isSuperAdmin => role == 'super_admin';
  List<String> get permissions => _readPermissions(_adminData);

  Future<void> initialize() async {
    if (_isReady) {
      return;
    }

    _token = await _tokenStorage.readToken();
    _apiService.setAuthToken(_token);
    final storage = _tokenStorage;
    if (storage is SharedPreferencesTokenStorage) {
      _adminData = await storage.readAdminData();
    }
    _isReady = true;
    notifyListeners();
  }

  Future<void> setToken(String token) async {
    await setSession(token: token);
  }

  Future<void> setSession({
    required String token,
    Map<String, dynamic>? adminData,
    bool persistToken = true,
  }) async {
    _token = token;
    _adminData = adminData;
    if (persistToken) {
      await _tokenStorage.writeToken(token);
    }
    _apiService.setAuthToken(token);
    final storage = _tokenStorage;
    if (adminData != null && storage is SharedPreferencesTokenStorage) {
      await storage.writeAdminData(adminData);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _adminData = null;
    await _tokenStorage.clearToken();
    _apiService.clearAuthToken();
    notifyListeners();
  }

  String? _readString(Map<String, dynamic>? json, List<String> keys) {
    if (json == null) {
      return null;
    }

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

    final nestedUser = json['user'];
    if (nestedUser is Map<String, dynamic>) {
      for (final key in keys) {
        final value = nestedUser[key];
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

    return null;
  }

  List<String> _readPermissions(Map<String, dynamic>? json) {
    if (json == null) {
      return const <String>[];
    }

    final values = <String>[];
    final candidates = <dynamic>[
      json['permissions'],
      json['rolePermissions'],
    ];

    final nestedUser = json['user'];
    if (nestedUser is Map<String, dynamic>) {
      candidates.add(nestedUser['permissions']);
      candidates.add(nestedUser['rolePermissions']);
    }

    for (final raw in candidates) {
      if (raw is List) {
        for (final item in raw) {
          final text = item?.toString().trim() ?? '';
          if (text.isNotEmpty) {
            values.add(text);
          }
        }
      } else if (raw is String && raw.trim().isNotEmpty) {
        values.addAll(
          raw
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty),
        );
      } else if (raw != null) {
        final text = raw.toString().trim();
        if (text.isNotEmpty) {
          values.add(text);
        }
      }
    }

    return values.toSet().toList(growable: false);
  }
}
