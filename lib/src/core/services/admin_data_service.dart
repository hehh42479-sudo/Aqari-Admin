import '../../features/properties/properties_screen.dart';
import 'api_service.dart';

class AdminStats {
  const AdminStats({
    required this.totalProperties,
    required this.activeProperties,
    required this.pendingProperties,
    required this.ownersCount,
    required this.officesCount,
    required this.seekersCount,
    required this.featuredProperties,
    required this.monthlyRevenue,
    required this.raw,
  });

  final int totalProperties;
  final int activeProperties;
  final int pendingProperties;
  final int ownersCount;
  final int officesCount;
  final int seekersCount;
  final int featuredProperties;
  final double monthlyRevenue;
  final Map<String, dynamic> raw;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalProperties: _readInt(json, <String>[
        'totalProperties',
        'propertiesTotal',
        'total_properties',
        'properties',
        'total',
      ]),
      activeProperties: _readInt(json, <String>[
        'activeProperties',
        'active_properties',
        'active',
      ]),
      pendingProperties: _readInt(json, <String>[
        'pendingProperties',
        'pending_properties',
        'pending',
      ]),
      ownersCount: _readInt(json, <String>[
        'ownersCount',
        'owners',
        'totalOwners',
        'owners_total',
      ]),
      officesCount: _readInt(json, <String>[
        'officesCount',
        'offices',
        'totalOffices',
        'offices_total',
      ]),
      seekersCount: _readInt(json, <String>[
        'seekersCount',
        'seekers',
        'totalSeekers',
        'seekers_total',
      ]),
      featuredProperties: _readInt(json, <String>[
        'featuredProperties',
        'featured_properties',
        'featured',
      ]),
      monthlyRevenue: _readDouble(json, <String>[
        'monthlyRevenue',
        'revenue',
        'totalRevenue',
        'monthly_revenue',
      ]),
      raw: json,
    );
  }

  static int _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final parsed = _toInt(value);
      if (parsed != null) {
        return parsed;
      }
    }

    final nested = json['data'];
    if (nested is Map<String, dynamic>) {
      for (final key in keys) {
        final parsed = _toInt(nested[key]);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  static double _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final parsed = _toDouble(value);
      if (parsed != null) {
        return parsed;
      }
    }

    final nested = json['data'];
    if (nested is Map<String, dynamic>) {
      for (final key in keys) {
        final parsed = _toDouble(nested[key]);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  static int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), ''));
    }
    return int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9-]'), ''));
  }

  static double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), ''));
    }
    return double.tryParse(value.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
  }
}

class AdminDataService {
  AdminDataService({required ApiService apiService}) : _apiService = apiService;

  final ApiService _apiService;

  Future<AdminStats> fetchStats() async {
    final response = await _apiService.get<dynamic>('/admin/stats');
    return AdminStats.fromJson(_asMap(response.data));
  }

  Future<List<Property>> fetchProperties() async {
    final response = await _apiService.get<dynamic>('/admin/properties');
    final list = _asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Property.fromJson)
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchUsersByRole(String role) async {
    final response = await _apiService.get<dynamic>(
      '/admin/users',
      queryParameters: <String, dynamic>{'role': role},
    );
    final list = _asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchSubscriptions() async {
    final response = await _apiService.get<dynamic>('/admin/subscriptions');
    final list = _asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<void> activateManualSubscription({
    required String userIdentifier,
    required String packageType,
    required String duration,
  }) async {
    await _apiService.post<dynamic>(
      '/admin/subscriptions/manual',
      data: <String, dynamic>{
        'userIdentifier': userIdentifier,
        'packageType': packageType,
        'duration': duration,
      },
    );
  }

  Future<Map<String, dynamic>> fetchAppSettings() async {
    final response = await _apiService.get<dynamic>('/admin/settings');
    return _asMap(response.data);
  }

  Future<void> saveAppSettings({
    required String termsAndConditions,
    required String privacyPolicy,
    required String contactPhone,
    required String contactEmail,
  }) async {
    await _apiService.put<dynamic>(
      '/admin/settings',
      data: <String, dynamic>{
        'termsAndConditions': termsAndConditions,
        'privacyPolicy': privacyPolicy,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final response = await _apiService.get<dynamic>('/admin/notifications');
    final list = _asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchPayments() async {
    final response = await _apiService.get<dynamic>('/admin/payments');
    final list = _asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchComplaints() async {
    final response = await _apiService.get<dynamic>('/admin/complaints');
    final list = _asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchMessages() async {
    final response = await _apiService.get<dynamic>('/admin/messages');
    final list = _asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchFeaturedProperties() async {
    final response = await _apiService.get<dynamic>('/admin/properties/featured');
    final list = _asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<void> sendNotification({
    required String title,
    required String message,
    required String audience,
  }) async {
    await _apiService.post<dynamic>(
      '/admin/notifications',
      data: <String, dynamic>{
        'title': title,
        'message': message,
        'audience': audience,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchSupervisors() async {
    final response = await _apiService.get<dynamic>('/admin/supervisors');
    final list = _asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<void> createSupervisor({
    required String name,
    required String phone,
    String? password,
    required List<String> permissions,
    String? supervisorId,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'phone': phone,
      'permissions': permissions,
    };

    final trimmedPassword = password?.trim();
    if (trimmedPassword != null && trimmedPassword.isNotEmpty) {
      payload['password'] = trimmedPassword;
    }

    if (supervisorId != null && supervisorId.trim().isNotEmpty) {
      payload['id'] = supervisorId.trim();
    }

    await _apiService.post<dynamic>(
      '/admin/supervisors',
      data: payload,
    );
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final nested = data['data'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
      return data;
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    return <String, dynamic>{'raw': data};
  }

  List<dynamic> _asList(dynamic data) {
    final list = _findFirstList(data);
    return list ?? <dynamic>[];
  }

  List<dynamic>? _findFirstList(dynamic value, {int depth = 0}) {
    if (value is List<dynamic>) {
      return value;
    }

    if (value is Map<String, dynamic>) {
      final preferredKeys = <String>[
        'data',
        'properties',
        'users',
        'subscriptions',
        'items',
        'results',
        'result',
        'rows',
      ];

      for (final key in preferredKeys) {
        final nested = value[key];
        final nestedList = _findFirstList(nested, depth: depth + 1);
        if (nestedList != null) {
          return nestedList;
        }
      }

      for (final nested in value.values) {
        final nestedList = _findFirstList(nested, depth: depth + 1);
        if (nestedList != null) {
          return nestedList;
        }
      }
    }

    return null;
  }
}
