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
    required this.supervisorsCount,
    required this.featuredProperties,
    required this.soldProperties,
    required this.rentedProperties,
    required this.monthlyRevenue,
    required this.raw,
  });

  final int totalProperties;
  final int activeProperties;
  final int pendingProperties;
  final int ownersCount;
  final int officesCount;
  final int seekersCount;
  final int supervisorsCount;
  final int featuredProperties;
  final int soldProperties;
  final int rentedProperties;
  final double monthlyRevenue;
  final Map<String, dynamic> raw;

  int get totalUsers => ownersCount + officesCount + seekersCount;

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
      supervisorsCount: _readInt(json, <String>[
        'supervisorsCount',
        'supervisors',
        'totalSupervisors',
        'supervisors_total',
      ]),
      featuredProperties: _readInt(json, <String>[
        'featuredProperties',
        'featured_properties',
        'featured',
      ]),
      soldProperties: _readInt(json, <String>[
        'soldProperties',
        'sold_properties',
        'sold',
      ]),
      rentedProperties: _readInt(json, <String>[
        'rentedProperties',
        'rented_properties',
        'rented',
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

  factory AdminStats.mock() {
    return const AdminStats(
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
    return AdminStats.fromJson(ApiResponseNormalizer.asMap(response.data));
  }

  Future<AdminStats> fetchStatistics() async {
    try {
      final response = await _apiService.get<dynamic>('/admin/statistics');
      return AdminStats.fromJson(ApiResponseNormalizer.asMap(response.data));
    } catch (_) {
      try {
        return await fetchStats();
      } catch (_) {
        return AdminStats.mock();
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchActivityLogs() async {
    try {
      final response = await _apiService.get<dynamic>('/admin/activity-logs');
      final list = ApiResponseNormalizer.asList(response.data);
      return list
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Property>> fetchProperties() async {
    final response = await _apiService.get<dynamic>('/admin/properties');
    final list = ApiResponseNormalizer.asList(response.data);
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
    final list = ApiResponseNormalizer.asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchSubscriptions() async {
    final response = await _apiService.get<dynamic>('/admin/subscriptions');
    final list = ApiResponseNormalizer.asList(response.data);
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
    return ApiResponseNormalizer.asMap(response.data);
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
    final list = ApiResponseNormalizer.asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchPayments() async {
    final response = await _apiService.get<dynamic>('/admin/payments');
    final list = ApiResponseNormalizer.asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchComplaints() async {
    final response = await _apiService.get<dynamic>('/admin/complaints');
    final list = ApiResponseNormalizer.asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchMessages() async {
    final response = await _apiService.get<dynamic>('/admin/messages');
    final list = ApiResponseNormalizer.asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchFeaturedProperties() async {
    final response = await _apiService.get<dynamic>('/admin/properties/featured');
    final list = ApiResponseNormalizer.asList(response.data);
    return list
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// Send a push notification.
  ///
  /// [audience] — one of: all | seeker | owner | office | user | city |
  ///   active_subs | expired_subs
  /// [targetValue] — required when audience is 'user' (phone/id) or 'city'
  /// [imageUrl]   — optional banner image URL
  /// [deepLink]   — optional in-app deep-link
  Future<void> sendNotification({
    required String title,
    required String message,
    required String audience,
    String? targetValue,
    String? imageUrl,
    String? deepLink,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'message': message,
      'audience': audience,
      // Backend key aliases — send both so whichever the server expects works
      'target': audience,
      'targetType': audience,
      'target_type': audience,
    };

    if (targetValue != null && targetValue.isNotEmpty) {
      payload['targetValue'] = targetValue;
      payload['target_value'] = targetValue;
      // For 'user' audience send userId/phone separately too
      if (audience == 'user') {
        payload['userId'] = targetValue;
        payload['user_id'] = targetValue;
        payload['phone'] = targetValue;
      }
      // For 'city' audience
      if (audience == 'city') {
        payload['city'] = targetValue;
      }
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      payload['imageUrl'] = imageUrl;
      payload['image_url'] = imageUrl;
      payload['image'] = imageUrl;
    }

    if (deepLink != null && deepLink.isNotEmpty) {
      payload['deepLink'] = deepLink;
      payload['deep_link'] = deepLink;
      payload['link'] = deepLink;
    }

    await _apiService.post<dynamic>(
      '/admin/notifications',
      data: payload,
    );
  }

  // ─── Seeker Requests ─────────────────────────────────────────────────────────

  /// Fetch seeker property-search requests.
  /// Optional [status]: new | processing | completed | cancelled
  /// Optional [city]: filter by city name
  Future<List<Map<String, dynamic>>> fetchSeekerRequests({
    String? status,
    String? city,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status.isNotEmpty && status != 'all') {
      queryParams['status'] = status;
    }
    if (city != null && city.isNotEmpty) {
      queryParams['city'] = city;
    }

    final response = await _apiService.get<dynamic>(
      '/admin/requests',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final list = ApiResponseNormalizer.asList(response.data);
    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  /// Update the status of a seeker request.
  /// [status]: processing | completed | cancelled
  Future<void> updateSeekerRequestStatus(
    String id,
    String status, {
    String? rejectionReason,
  }) async {
    final data = <String, dynamic>{
      'status': status,
    };
    if (rejectionReason != null && rejectionReason.isNotEmpty) {
      data['rejection_reason'] = rejectionReason;
      data['rejectionReason'] = rejectionReason;
      data['reason'] = rejectionReason;
    }
    await _apiService.patch<dynamic>(
      '/admin/requests/$id',
      data: data,
    );
  }

  /// Permanently delete a seeker request.
  Future<void> deleteSeekerRequest(String id) async {
    await _apiService.delete<dynamic>('/admin/requests/$id');
  }

  Future<List<Map<String, dynamic>>> fetchSupervisors() async {
    final response = await _apiService.get<dynamic>('/admin/supervisors');
    final list = ApiResponseNormalizer.asList(response.data);
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

  // ─── Verification requests ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchVerifications({
    String status = 'all',
  }) async {
    final response = await _apiService.get<dynamic>(
      '/admin/verification',
      queryParameters: status != 'all' ? {'status': status} : null,
    );
    final list = ApiResponseNormalizer.asList(response.data);
    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<void> reviewVerification(
    String id,
    String decision, // 'approved' | 'rejected'
    String note,
  ) async {
    await _apiService.put<dynamic>(
      '/admin/verification/$id',
      data: {
        'status': decision,
        'admin_note': note,
        'adminNote': note,
      },
    );
  }

  // ─── Employee subscription payments ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchEmployeePayments() async {
    try {
      final response =
          await _apiService.get<dynamic>('/admin/employee-payments');
      final list = ApiResponseNormalizer.asList(response.data);
      return list.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (_) {
      // Fallback: return empty list if endpoint not yet wired
      return [];
    }
  }

  Future<void> confirmEmployeePayment(String paymentId) async {
    await _apiService.put<dynamic>(
      '/employees/confirm-payment',
      data: {'payment_id': paymentId, 'status': 'paid'},
    );
  }

  // ─── Property management convenience methods ─────────────────────────────────

  /// Update a property's status on the backend.
  /// [apiStatus] values: 'approved', 'rejected', 'featured', 'sold', 'rented',
  ///   'pending_edit', 'suspended'.
  /// Pass optional [rejectionReason] or [adminNote] for rejection / edit-request.
  Future<void> updatePropertyStatus(
    String propertyId,
    String apiStatus, {
    String? rejectionReason,
    String? adminNote,
  }) async {
    final data = <String, dynamic>{'status': apiStatus};
    if (rejectionReason != null && rejectionReason.isNotEmpty) {
      data['rejection_reason'] = rejectionReason;
      data['rejectionReason'] = rejectionReason;
    }
    if (adminNote != null && adminNote.isNotEmpty) {
      data['admin_note'] = adminNote;
    }
    await _apiService.put<dynamic>(
      '/admin/properties/$propertyId/status',
      data: data,
    );
  }

  /// Permanently delete a property.
  Future<void> deleteProperty(String propertyId) async {
    await _apiService.delete<dynamic>('/admin/properties/$propertyId');
  }

  /// Fetch a single property's details.
  Future<Map<String, dynamic>> fetchPropertyDetails(String propertyId) async {
    final response =
        await _apiService.get<dynamic>('/admin/properties/$propertyId');
    return ApiResponseNormalizer.asMap(response.data);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LOCATIONS — governorates / cities / districts / neighborhoods
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchGovernorates() async {
    final r = await _apiService.get<dynamic>('/admin/locations/governorates');
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createGovernorate(Map<String, dynamic> data) async {
    final r = await _apiService.post<dynamic>('/admin/locations/governorates', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<Map<String, dynamic>> updateGovernorate(String id, Map<String, dynamic> data) async {
    final r = await _apiService.put<dynamic>('/admin/locations/governorates/$id', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<void> deleteGovernorate(String id) async {
    await _apiService.delete<dynamic>('/admin/locations/governorates/$id');
  }

  Future<List<Map<String, dynamic>>> fetchAdminCities({String? governorateId}) async {
    final r = await _apiService.get<dynamic>('/admin/locations/cities',
        queryParameters: governorateId != null ? {'governorate_id': governorateId} : null);
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createCity(Map<String, dynamic> data) async {
    final r = await _apiService.post<dynamic>('/admin/locations/cities', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<Map<String, dynamic>> updateCity(String id, Map<String, dynamic> data) async {
    final r = await _apiService.put<dynamic>('/admin/locations/cities/$id', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<void> deleteCity(String id) async {
    await _apiService.delete<dynamic>('/admin/locations/cities/$id');
  }

  Future<List<Map<String, dynamic>>> fetchAdminDistricts({String? cityId}) async {
    final r = await _apiService.get<dynamic>('/admin/locations/districts',
        queryParameters: cityId != null ? {'city_id': cityId} : null);
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createDistrict(Map<String, dynamic> data) async {
    final r = await _apiService.post<dynamic>('/admin/locations/districts', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<Map<String, dynamic>> updateDistrict(String id, Map<String, dynamic> data) async {
    final r = await _apiService.put<dynamic>('/admin/locations/districts/$id', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<void> deleteDistrict(String id) async {
    await _apiService.delete<dynamic>('/admin/locations/districts/$id');
  }

  Future<List<Map<String, dynamic>>> fetchAdminNeighborhoods({String? districtId}) async {
    final r = await _apiService.get<dynamic>('/admin/locations/neighborhoods',
        queryParameters: districtId != null ? {'district_id': districtId} : null);
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createNeighborhood(Map<String, dynamic> data) async {
    final r = await _apiService.post<dynamic>('/admin/locations/neighborhoods', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<Map<String, dynamic>> updateNeighborhood(String id, Map<String, dynamic> data) async {
    final r = await _apiService.put<dynamic>('/admin/locations/neighborhoods/$id', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<void> deleteNeighborhood(String id) async {
    await _apiService.delete<dynamic>('/admin/locations/neighborhoods/$id');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PROPERTY TYPES
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchPropertyTypes() async {
    final r = await _apiService.get<dynamic>('/admin/property-types');
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createPropertyType(Map<String, dynamic> data) async {
    final r = await _apiService.post<dynamic>('/admin/property-types', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<Map<String, dynamic>> updatePropertyType(String id, Map<String, dynamic> data) async {
    final r = await _apiService.put<dynamic>('/admin/property-types/$id', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<void> deletePropertyType(String id) async {
    await _apiService.delete<dynamic>('/admin/property-types/$id');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ALL EMPLOYEES (global)
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchAllEmployees({String? officeId, String? status}) async {
    final Map<String, dynamic> params = {};
    if (officeId != null) params['office_id'] = officeId;
    if (status != null) params['status'] = status;
    final r = await _apiService.get<dynamic>('/admin/all-employees',
        queryParameters: params.isNotEmpty ? params : null);
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> toggleEmployeeStatus(String id) async {
    final r = await _apiService.patch<dynamic>('/admin/all-employees/$id/toggle');
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<void> deleteEmployeeAdmin(String id) async {
    await _apiService.delete<dynamic>('/admin/all-employees/$id');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CHAT ROOMS (admin management)
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchAdminChatRooms({String? role, String? status}) async {
    final Map<String, dynamic> params = {};
    if (role != null) params['role'] = role;
    if (status != null) params['status'] = status;
    final r = await _apiService.get<dynamic>('/admin/chats',
        queryParameters: params.isNotEmpty ? params : null);
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> deleteChatRoom(String roomId) async {
    await _apiService.delete<dynamic>('/admin/chats/$roomId');
  }

  Future<void> closeChatRoom(String roomId) async {
    await _apiService.patch<dynamic>('/admin/chats/$roomId/close');
  }

  Future<void> banUserFromChat(String userId, {String? reason}) async {
    await _apiService.post<dynamic>('/admin/chats/$userId/ban',
        data: {'reason': reason ?? ''});
  }

  // ════════════════════════════════════════════════════════════════════════════
  // RATINGS
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchRatings({String? targetType}) async {
    final r = await _apiService.get<dynamic>('/admin/ratings',
        queryParameters: targetType != null ? {'target_type': targetType} : null);
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> toggleRatingApproval(String id) async {
    await _apiService.patch<dynamic>('/admin/ratings/$id/toggle');
  }

  Future<void> deleteRating(String id) async {
    await _apiService.delete<dynamic>('/admin/ratings/$id');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CONTENT PAGES
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchContentPages() async {
    final r = await _apiService.get<dynamic>('/admin/content');
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> upsertContentPage(String slug, Map<String, dynamic> data) async {
    final r = await _apiService.put<dynamic>('/admin/content/$slug', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ADVERTISEMENTS
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchAds({String? placement}) async {
    final r = await _apiService.get<dynamic>('/admin/ads',
        queryParameters: placement != null ? {'placement': placement} : null);
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createAd(Map<String, dynamic> data) async {
    final r = await _apiService.post<dynamic>('/admin/ads', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<Map<String, dynamic>> updateAd(String id, Map<String, dynamic> data) async {
    final r = await _apiService.put<dynamic>('/admin/ads/$id', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<void> deleteAd(String id) async {
    await _apiService.delete<dynamic>('/admin/ads/$id');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SYSTEM MONITORING
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> fetchSystemHealth() async {
    final r = await _apiService.get<dynamic>('/admin/monitoring/health');
    return ApiResponseNormalizer.asMap(r.data);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BACKUP
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchBackupLogs() async {
    final r = await _apiService.get<dynamic>('/admin/backup/logs');
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  // createBackup returns raw bytes (JSON file download) — handled in screen via dio directly
  Future<String> triggerBackupDownloadUrl() => Future.value(
    'https://aqari-backend.onrender.com/api/admin/backup/create',
  );

  // ════════════════════════════════════════════════════════════════════════════
  // SECURITY — banned users / devices / login attempts
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchBannedUsers() async {
    final r = await _apiService.get<dynamic>('/admin/security/banned-users');
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> banUser(String userId, {String? reason}) async {
    await _apiService.post<dynamic>('/admin/security/ban-user',
        data: {'user_id': int.tryParse(userId) ?? userId, 'reason': reason ?? ''});
  }

  Future<void> unbanUser(String userId) async {
    await _apiService.delete<dynamic>('/admin/security/ban-user/$userId');
  }

  Future<List<Map<String, dynamic>>> fetchBannedDevices() async {
    final r = await _apiService.get<dynamic>('/admin/security/banned-devices');
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> unbanDevice(String deviceId) async {
    await _apiService.delete<dynamic>('/admin/security/ban-device/${Uri.encodeComponent(deviceId)}');
  }

  Future<List<Map<String, dynamic>>> fetchLoginAttempts({bool? failedOnly}) async {
    final r = await _apiService.get<dynamic>('/admin/security/login-attempts',
        queryParameters: failedOnly == true ? {'success': 'false'} : null);
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // EMERGENCY CONTROLS — system flags
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> fetchSystemFlags() async {
    final r = await _apiService.get<dynamic>('/admin/emergency/flags');
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<Map<String, dynamic>> updateSystemFlags(Map<String, dynamic> data) async {
    final r = await _apiService.patch<dynamic>('/admin/emergency/flags', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // APP CONFIG — branding / social / contact
  // ════════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> fetchAppConfig() async {
    final r = await _apiService.get<dynamic>('/admin/app-config');
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<Map<String, dynamic>> updateAppConfig(Map<String, dynamic> data) async {
    final r = await _apiService.put<dynamic>('/admin/app-config', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // APP UPDATES — version management
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchAppUpdates() async {
    final r = await _apiService.get<dynamic>('/admin/app-updates');
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createAppUpdate(Map<String, dynamic> data) async {
    final r = await _apiService.post<dynamic>('/admin/app-updates', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<Map<String, dynamic>> updateAppUpdate(String id, Map<String, dynamic> data) async {
    final r = await _apiService.put<dynamic>('/admin/app-updates/$id', data: data);
    return ApiResponseNormalizer.asMap(r.data);
  }

  Future<void> deleteAppUpdate(String id) async {
    await _apiService.delete<dynamic>('/admin/app-updates/$id');
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ACTIVITY LOG (real endpoint)
  // ════════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchAdminActivityLog({
    String? action,
    String? entityType,
    int limit = 200,
  }) async {
    final Map<String, dynamic> params = {'limit': limit};
    if (action != null) params['action'] = action;
    if (entityType != null) params['entity_type'] = entityType;
    final r = await _apiService.get<dynamic>('/admin/activity-log', queryParameters: params);
    return ApiResponseNormalizer.asList(r.data).whereType<Map<String, dynamic>>().toList();
  }
}
