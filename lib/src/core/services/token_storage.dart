import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class TokenStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clearToken();
}

class SharedPreferencesTokenStorage implements TokenStorage {
  static const String _tokenKey = 'aqari_plus_admin_jwt';
  static const String _adminDataKey = 'aqari_plus_admin_data';

  @override
  Future<String?> readToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_tokenKey);
  }

  @override
  Future<void> writeToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  @override
  Future<void> clearToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_adminDataKey);
  }

  Future<Map<String, dynamic>?> readAdminData() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_adminDataKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{'raw': decoded};
  }

  Future<void> writeAdminData(Map<String, dynamic> adminData) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_adminDataKey, jsonEncode(adminData));
  }
}
