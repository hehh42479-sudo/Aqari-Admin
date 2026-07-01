// ignore_for_file: use_build_context_synchronously
// ─────────────────────────────────────────────────────────────────────────────
// lib/src/features/properties/properties_screen.dart
//
// Phase-3 rewrite:
//  • 6 tabs: All / Pending / Active / Featured / Sold / Rented
//  • Single fetch + in-memory filter (zero extra API calls on tab switch)
//  • _isFetch debounce gate prevents parallel loads
//  • Search: ID, title, owner/publisher name, phone
//  • Image: resolveMediaUrl() + Image.network error/loading builders
//  • Full row-actions: Approve, Reject w/ reason, Request Edit, Feature,
//    Un-feature, Mark Sold, Mark Rented, Restore, Delete
//  • Property Detail Dialog: image carousel, owner info, stats, all actions
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';
import '../../core/services/api_service.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum PropertyStatus {
  all,
  pending,
  active,
  featured,
  sold,
  rented,
  suspended,
  unknown,
}

enum _PropertyAction {
  view,
  approve,
  reject,
  requestEdit,
  feature,
  unfeature,
  markSold,
  markRented,
  restore,
  delete,
}

// ── Property model ────────────────────────────────────────────────────────────

class Property {
  Property({
    required this.id,
    required this.title,
    required this.type,
    required this.operationType,
    required this.city,
    required this.district,
    required this.price,
    required this.currency,
    required this.publisher,
    required this.publisherPhone,
    required this.publisherEmail,
    required this.officeName,
    required this.postedAt,
    required this.status,
    required this.thumbnailUrl,
    required this.imageUrls,
    required this.featured,
    required this.isSuspended,
    required this.viewsCount,
    required this.callsCount,
    required this.favoritesCount,
    required this.reportsCount,
    required this.description,
    required this.rejectionReason,
    required this.rawJson,
  });

  final String id;
  final String title;
  final String type;
  final String operationType;
  final String city;
  final String district;
  final String price;
  final String currency;
  final String publisher;
  final String publisherPhone;
  final String publisherEmail;
  final String officeName;
  final DateTime? postedAt;
  final PropertyStatus status;
  final String thumbnailUrl;
  final List<String> imageUrls;
  final bool featured;
  final bool isSuspended;
  final int viewsCount;
  final int callsCount;
  final int favoritesCount;
  final int reportsCount;
  final String description;
  final String rejectionReason;
  final Map<String, dynamic> rawJson;

  bool get isPending  => status == PropertyStatus.pending;
  bool get isActive   => status == PropertyStatus.active;
  bool get isFeatured => status == PropertyStatus.featured || featured;
  bool get isSold     => status == PropertyStatus.sold;
  bool get isRented   => status == PropertyStatus.rented;

  Property copyWith({
    PropertyStatus? status,
    bool? featured,
    bool? isSuspended,
  }) {
    return Property(
      id: id,
      title: title,
      type: type,
      operationType: operationType,
      city: city,
      district: district,
      price: price,
      currency: currency,
      publisher: publisher,
      publisherPhone: publisherPhone,
      publisherEmail: publisherEmail,
      officeName: officeName,
      postedAt: postedAt,
      status: status ?? this.status,
      thumbnailUrl: thumbnailUrl,
      imageUrls: imageUrls,
      featured: featured ?? this.featured,
      isSuspended: isSuspended ?? this.isSuspended,
      viewsCount: viewsCount,
      callsCount: callsCount,
      favoritesCount: favoritesCount,
      reportsCount: reportsCount,
      description: description,
      rejectionReason: rejectionReason,
      rawJson: rawJson,
    );
  }

  // ── fromJson ──────────────────────────────────────────────────────────────
  factory Property.fromJson(Map<String, dynamic> json) {
    // Status parsing
    PropertyStatus parseStatus(dynamic raw) {
      final s = (raw?.toString() ?? '').toLowerCase().replaceAll(RegExp(r'[-\s]'), '_');
      switch (s) {
        case 'pending':
        case 'pending_review':
        case 'awaiting':
        case 'under_review':
        case 'pending_edit':
          return PropertyStatus.pending;
        case 'active':
        case 'approved':
          return PropertyStatus.active;
        case 'featured':
          return PropertyStatus.featured;
        case 'sold':
        case 'closed':
          return PropertyStatus.sold;
        case 'rented':
          return PropertyStatus.rented;
        case 'suspended':
        case 'rejected':
        case 'refused':
          return PropertyStatus.suspended;
        default:
          return PropertyStatus.unknown;
      }
    }

    // Pick first non-empty from several keys
    String pickStr(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
      }
      return '';
    }

    int pickInt(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is num) return v.toInt();
        final p = int.tryParse(v?.toString() ?? '');
        if (p != null) return p;
      }
      return 0;
    }

    // Owner from nested map or flat keys
    final ownerMap = json['owner'] is Map<String, dynamic>
        ? json['owner'] as Map<String, dynamic>
        : json['publisher'] is Map<String, dynamic>
            ? json['publisher'] as Map<String, dynamic>
            : null;
    final publisherName = ownerMap?['name']?.toString().trim() ??
        ownerMap?['fullName']?.toString().trim() ??
        pickStr(const ['publisherName', 'publisher_name', 'ownerName', 'owner_name', 'publisher', 'contact_name']);
    final publisherPhone = ownerMap?['phone']?.toString().trim() ??
        ownerMap?['mobile']?.toString().trim() ??
        pickStr(const ['publisherPhone', 'publisher_phone', 'ownerPhone', 'owner_phone', 'phone', 'mobile']);
    final publisherEmail = ownerMap?['email']?.toString().trim() ??
        pickStr(const ['publisherEmail', 'publisher_email', 'ownerEmail', 'email']);

    // Location
    final locationMap = json['location'] is Map<String, dynamic>
        ? json['location'] as Map<String, dynamic>
        : null;
    final city = locationMap?['city']?.toString().trim() ??
        locationMap?['governorate']?.toString().trim() ??
        pickStr(const ['city', 'governorate', 'region']);
    final district = locationMap?['district']?.toString().trim() ??
        pickStr(const ['district', 'neighborhood', 'area']);

    // Price formatting
    final priceRaw = json['price'];
    String priceStr = 'غير متاح';
    String currency = '';
    if (priceRaw is num) {
      priceStr = priceRaw.truncateToDouble() == priceRaw
          ? priceRaw.toStringAsFixed(0)
          : priceRaw.toStringAsFixed(2);
      currency = pickStr(const ['currency', 'currencyCode', 'currency_code']);
      if (currency.isEmpty) currency = 'ر.ي';
    } else if (priceRaw != null && priceRaw.toString().isNotEmpty) {
      priceStr = priceRaw.toString();
    }

    // Image URLs
    // Helper: parse a possibly-stringified JSON array/object string into List<String>.
    // Correctly handles backend JSONB format: '[{"url":"/uploads/img.jpg","isMain":true}]'
    // as well as plain string arrays: '["uploads/img.png","uploads/img2.png"]'
    List<String> unwrapStringifiedArray(String s) {
      final t = s.trim();
      if (t.isEmpty) return [];
      // Try proper JSON decode first (handles objects and arrays with nested commas)
      if (t.startsWith('[') || t.startsWith('{')) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is List) {
            return decoded.expand<String>((item) {
              if (item is String) return [item.trim()];
              if (item is Map) {
                final u = item['url']?.toString() ??
                    item['path']?.toString() ??
                    item['uri']?.toString() ??
                    '';
                return u.trim().isNotEmpty ? [u.trim()] : <String>[];
              }
              return <String>[];
            }).where((e) => e.isNotEmpty).toList();
          }
          if (decoded is Map) {
            final u = decoded['url']?.toString() ??
                decoded['path']?.toString() ??
                decoded['uri']?.toString() ??
                '';
            return u.trim().isNotEmpty ? [u.trim()] : [];
          }
        } catch (_) {
          // fall through to plain-text fallback
        }
      }
      // Plain string (not JSON) — return as single-element list
      return t.isNotEmpty ? [t] : [];
    }

    List<String> extractImages() {
      final urls = <String>[];
      const listKeys = ['images', 'image_urls', 'photos', 'media', 'gallery'];
      for (final key in listKeys) {
        final raw = json[key];
        if (raw is List && raw.isNotEmpty) {
          for (final item in raw) {
            if (item is String && item.trim().isNotEmpty) urls.add(item.trim());
            else if (item is Map) {
              final u = item['url']?.toString() ?? item['path']?.toString() ?? '';
              if (u.trim().isNotEmpty) urls.add(u.trim());
            }
          }
          if (urls.isNotEmpty) return urls;
        }
        // Handle stringified JSON array: '["uploads/img.png","uploads/img2.png"]'
        if (raw is String && raw.trim().isNotEmpty) {
          final parsed = unwrapStringifiedArray(raw.trim());
          if (parsed.isNotEmpty) {
            urls.addAll(parsed);
            return urls;
          }
        }
      }
      const singleKeys = ['thumbnail', 'image', 'imageUrl', 'image_url', 'cover', 'photo'];
      for (final key in singleKeys) {
        final v = json[key];
        if (v is String && v.trim().isNotEmpty) { urls.add(v.trim()); break; }
      }
      return urls;
    }

    final images = extractImages();
    final thumbnail = images.isNotEmpty ? images.first : '';

    // Status override: if is_featured=true and status=active → featured
    var parsedStatus = parseStatus(json['status'] ?? json['state']);
    final isFeaturedFlag = json['is_featured'] == true || json['isFeatured'] == true || json['featured'] == true;
    if (isFeaturedFlag && parsedStatus == PropertyStatus.active) {
      parsedStatus = PropertyStatus.featured;
    }

    return Property(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: pickStr(const ['title', 'name', 'propertyTitle', 'property_title']).let((s) => s.isEmpty ? 'بدون عنوان' : s),
      type: pickStr(const ['propertyType', 'type', 'property_type', 'category']).let((s) => s.isEmpty ? 'غير محدد' : s),
      operationType: pickStr(const ['operationType', 'operation_type', 'listingType', 'listing_type', 'purpose']),
      city: city.isEmpty ? 'غير محدد' : city,
      district: district,
      price: priceStr,
      currency: currency,
      publisher: publisherName.isEmpty ? 'غير معروف' : publisherName,
      publisherPhone: publisherPhone,
      publisherEmail: publisherEmail,
      officeName: pickStr(const ['officeName', 'office_name', 'companyName']),
      postedAt: _parseDate(json['createdAt'] ?? json['publishedAt'] ?? json['created_at'] ?? json['date']),
      status: parsedStatus,
      thumbnailUrl: thumbnail,
      imageUrls: images,
      featured: isFeaturedFlag,
      isSuspended: json['isSuspended'] == true || json['suspended'] == true,
      viewsCount: pickInt(const ['views_count', 'viewsCount', 'views', 'view_count']),
      callsCount: pickInt(const ['calls_count', 'callsCount', 'calls']),
      favoritesCount: pickInt(const ['favorites_count', 'favoritesCount', 'favorites']),
      reportsCount: pickInt(const ['reports_count', 'reportsCount', 'reports']),
      description: pickStr(const ['description', 'details', 'about']),
      rejectionReason: pickStr(const ['rejection_reason', 'rejectionReason', 'rejectReason', 'admin_note']),
      rawJson: json,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try { return DateTime.parse(value.toString()); } catch (_) { return null; }
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

// ── Tab definition ────────────────────────────────────────────────────────────

class _Tab {
  const _Tab(this.label, this.status, this.color);
  final String label;
  final PropertyStatus status;
  final Color color;
}

const List<_Tab> _kTabs = [
  _Tab('الكل',             PropertyStatus.all,      Color(0xFF0B3A66)),
  _Tab('قيد المراجعة',     PropertyStatus.pending,  Color(0xFFF39C12)),
  _Tab('نشطة',             PropertyStatus.active,   Color(0xFF17B26A)),
  _Tab('مميزة',            PropertyStatus.featured, Color(0xFF9A6B00)),
  _Tab('مُباعة',           PropertyStatus.sold,     Color(0xFF1D7CF2)),
  _Tab('مؤجرة',            PropertyStatus.rented,   Color(0xFF7B61FF)),
];

// ── Resolve media URL ─────────────────────────────────────────────────────────

/// Unwraps a possibly-stringified JSON array and returns the first element.
/// e.g. '["uploads/img.png"]' → 'uploads/img.png'
String _unwrapMediaString(String v) {
  final trimmed = v.trim();
  if (trimmed.startsWith('[')) {
    try {
      // Minimal JSON array parse without dart:convert import overhead —
      // strip brackets, split on commas, clean first item.
      final inner = trimmed.substring(1, trimmed.length - 1).trim();
      if (inner.isEmpty) return '';
      // Handle both ["path"] and ['path'] formats
      final first = inner.split(',').first.trim();
      return first.replaceAll('"', '').replaceAll("'", '').trim();
    } catch (_) {
      return trimmed;
    }
  }
  return trimmed;
}

String _resolveUrl(String? raw) {
  const base = 'https://aqari-backend.onrender.com';
  final v = _unwrapMediaString(raw?.trim() ?? '');
  if (v.isEmpty) return '';
  final lower = v.toLowerCase();
  if (lower == 'null' || lower == 'undefined') return '';
  final parsed = Uri.tryParse(v);
  if (parsed != null && parsed.hasScheme) return v;
  if (v.startsWith('//')) return 'https:$v';
  return '$base${v.startsWith('/') ? v : '/$v'}';
}

// ── PropertiesScreen ──────────────────────────────────────────────────────────

class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({super.key});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen>
    with SingleTickerProviderStateMixin {

  late final TabController _tabController;
  late final ApiService _apiService;

  // State
  List<Property> _all = [];
  bool _loading = true;
  bool _isFetch = false;
  bool _actionLoading = false;
  String? _error;

  // Search
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Sort
  int _sortCol = 1;
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kTabs.length, vsync: this);
    _tabController.addListener(() { if (!_tabController.indexIsChanging) setState(() {}); });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apiService = context.read<ApiService>();
      _loadProperties();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadProperties() async {
    if (_isFetch) return;
    _isFetch = true;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _apiService.get<dynamic>('/admin/properties');
      if (res.statusCode == 200 && res.data != null) {
        final list = ApiResponseNormalizer.asList(res.data);
        setState(() {
          _all = list.whereType<Map<String, dynamic>>().map(Property.fromJson).toList();
          _loading = false;
        });
      } else {
        setState(() { _all = []; _loading = false; _error = 'لا توجد عقارات مسجلة.'; });
      }
    } catch (e) {
      setState(() { _all = []; _loading = false; _error = 'فشل تحميل البيانات: ${e.toString().split('\n').first}'; });
    } finally {
      _isFetch = false;
    }
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<Property> _forTab(int tabIndex) {
    final tab = _kTabs[tabIndex];
    List<Property> list;
    switch (tab.status) {
      case PropertyStatus.all:      list = _all; break;
      case PropertyStatus.pending:  list = _all.where((p) => p.isPending).toList(); break;
      case PropertyStatus.active:   list = _all.where((p) => p.isActive).toList(); break;
      case PropertyStatus.featured: list = _all.where((p) => p.isFeatured).toList(); break;
      case PropertyStatus.sold:     list = _all.where((p) => p.isSold).toList(); break;
      case PropertyStatus.rented:   list = _all.where((p) => p.isRented).toList(); break;
      default:                      list = _all;
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
          p.id.toLowerCase().contains(q) ||
          p.title.toLowerCase().contains(q) ||
          p.publisher.toLowerCase().contains(q) ||
          p.publisherPhone.contains(q) ||
          p.city.toLowerCase().contains(q) ||
          p.officeName.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int _countFor(PropertyStatus st) {
    switch (st) {
      case PropertyStatus.all:      return _all.length;
      case PropertyStatus.pending:  return _all.where((p) => p.isPending).length;
      case PropertyStatus.active:   return _all.where((p) => p.isActive).length;
      case PropertyStatus.featured: return _all.where((p) => p.isFeatured).length;
      case PropertyStatus.sold:     return _all.where((p) => p.isSold).length;
      case PropertyStatus.rented:   return _all.where((p) => p.isRented).length;
      default:                      return 0;
    }
  }

  // ── Sort ──────────────────────────────────────────────────────────────────

  void _sort(List<Property> list, int col, bool asc) {
    final order = asc ? 1 : -1;
    list.sort((a, b) {
      switch (col) {
        case 0: return order * a.title.compareTo(b.title);
        case 1: return order * a.type.compareTo(b.type);
        case 2: return order * a.city.compareTo(b.city);
        case 3: return order * a.price.compareTo(b.price);
        case 4: return order * a.publisher.compareTo(b.publisher);
        case 5: return order * (a.postedAt?.compareTo(b.postedAt ?? DateTime(1900)) ?? 0);
        default: return 0;
      }
    });
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _handleAction(Property prop, _PropertyAction action) async {
    switch (action) {
      case _PropertyAction.view:
        _showDetail(prop);
        break;
      case _PropertyAction.approve:
        await _setStatus(prop, 'approved',
            confirm: 'هل تريد الموافقة على "${prop.title}"؟',
            title: 'تأكيد الموافقة',
            successMsg: 'تمت الموافقة بنجاح',
            newStatus: PropertyStatus.active);
        break;
      case _PropertyAction.reject:
        await _rejectWithReason(prop);
        break;
      case _PropertyAction.requestEdit:
        await _requestEditDialog(prop);
        break;
      case _PropertyAction.feature:
        await _setStatus(prop, 'featured',
            confirm: 'هل تريد تمييز "${prop.title}"؟',
            title: 'تأكيد التمييز',
            successMsg: 'تم تمييز العقار',
            newStatus: PropertyStatus.featured);
        break;
      case _PropertyAction.unfeature:
        await _setStatus(prop, 'approved',
            confirm: 'هل تريد إلغاء تمييز "${prop.title}"؟',
            title: 'إلغاء التمييز',
            successMsg: 'تم إلغاء التمييز',
            newStatus: PropertyStatus.active);
        break;
      case _PropertyAction.markSold:
        await _setStatus(prop, 'sold',
            confirm: 'هل تريد تعليم "${prop.title}" كمُباع؟',
            title: 'تعليم كمُباع',
            successMsg: 'تم تعليم العقار كمُباع',
            newStatus: PropertyStatus.sold);
        break;
      case _PropertyAction.markRented:
        await _setStatus(prop, 'rented',
            confirm: 'هل تريد تعليم "${prop.title}" كمؤجر؟',
            title: 'تعليم كمؤجر',
            successMsg: 'تم تعليم العقار كمؤجر',
            newStatus: PropertyStatus.rented);
        break;
      case _PropertyAction.restore:
        await _setStatus(prop, 'approved',
            confirm: 'هل تريد استعادة "${prop.title}" وتفعيله؟',
            title: 'استعادة العقار',
            successMsg: 'تم استعادة العقار',
            newStatus: PropertyStatus.active);
        break;
      case _PropertyAction.delete:
        await _deleteProperty(prop);
        break;
    }
  }

  Future<void> _setStatus(
    Property prop,
    String apiStatus, {
    required String confirm,
    required String title,
    required String successMsg,
    required PropertyStatus newStatus,
  }) async {
    final ok = await _confirm(title: title, content: confirm);
    if (ok != true) return;
    setState(() => _actionLoading = true);
    try {
      await _apiService.put('/admin/properties/${prop.id}/status',
          data: {'status': apiStatus});
      _updateLocal(prop.copyWith(
        status: newStatus,
        featured: apiStatus == 'featured',
      ));
      _snack(successMsg);
    } catch (e) {
      _snack('فشل تحديث الحالة: ${e.toString().split('\n').first}', error: true);
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _rejectWithReason(Property prop) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض العقار'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('يرجى إدخال سبب الرفض:'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'سبب الرفض...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD92D20)),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _actionLoading = true);
    try {
      await _apiService.put('/admin/properties/${prop.id}/status', data: {
        'status': 'rejected',
        'rejection_reason': ctrl.text.trim(),
        'rejectionReason': ctrl.text.trim(),
      });
      _updateLocal(prop.copyWith(status: PropertyStatus.suspended));
      _snack('تم رفض العقار وإرسال السبب');
    } catch (e) {
      _snack('فشل رفض العقار', error: true);
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _requestEditDialog(Property prop) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب تعديل'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('أدخل تعليمات التعديل المطلوبة:'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'ملاحظات التعديل...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _actionLoading = true);
    try {
      await _apiService.put('/admin/properties/${prop.id}/status', data: {
        'status': 'pending_edit',
        'admin_note': ctrl.text.trim(),
      });
      _snack('تم إرسال طلب التعديل للناشر');
    } catch (e) {
      _snack('فشل إرسال طلب التعديل', error: true);
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _deleteProperty(Property prop) async {
    final ok = await _confirm(
      title: 'حذف نهائي',
      content: 'هل تريد حذف "${prop.title}" نهائياً؟ لا يمكن التراجع.',
      destructive: true,
    );
    if (ok != true) return;
    setState(() => _actionLoading = true);
    try {
      await _apiService.delete('/admin/properties/${prop.id}');
      setState(() => _all.removeWhere((p) => p.id == prop.id));
      _snack('تم حذف العقار');
    } catch (e) {
      _snack('فشل حذف العقار', error: true);
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  void _updateLocal(Property updated) {
    setState(() {
      final i = _all.indexWhere((p) => p.id == updated.id);
      if (i >= 0) _all[i] = updated;
    });
  }

  // ── Detail dialog ─────────────────────────────────────────────────────────

  void _showDetail(Property prop) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _PropertyDetailDialog(
        property: prop,
        onAction: (action) {
          Navigator.of(ctx).pop();
          _handleAction(prop, action);
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool?> _confirm({
    required String title,
    required String content,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive
                ? ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD92D20))
                : null,
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFD92D20) : const Color(0xFF17B26A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Header ────────────────────────────────────────────────────────
        _ScreenHeader(onRefresh: _loadProperties),
        const SizedBox(height: 18),

        // ── Search bar ─────────────────────────────────────────────────
        TextField(
          controller: _searchCtrl,
          textDirection: TextDirection.rtl,
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
          decoration: InputDecoration(
            hintText: 'بحث بالمعرف، العنوان، الناشر، الهاتف، المدينة...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 16),

        // ── Main card ──────────────────────────────────────────────────
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // TabBar
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF0B3A66),
                  unselectedLabelColor: const Color(0xFF516174),
                  indicatorColor: const Color(0xFF1D7CF2),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tabs: _kTabs.map((t) {
                    final count = _loading ? 0 : _countFor(t.status);
                    return Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(t.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.color.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: t.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // TabBarView
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: List.generate(_kTabs.length, (i) {
                      if (_loading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (_error != null && _all.isEmpty) {
                        return Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.error_outline, size: 48, color: Color(0xFFD92D20)),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadProperties,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ]),
                        );
                      }
                      final props = _forTab(i);
                      if (props.isEmpty) {
                        return Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'لا توجد نتائج لـ "$_searchQuery"'
                                : 'لا توجد عقارات في هذا التبويب',
                          ),
                        );
                      }
                      final sorted = List<Property>.from(props);
                      _sort(sorted, _sortCol, _sortAsc);
                      return _buildTable(sorted);
                    }),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),

      // Action loading overlay
      if (_actionLoading)
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.06),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
    ]);
  }

  Widget _buildTable(List<Property> props) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _sortCol,
          sortAscending: _sortAsc,
          columnSpacing: 20,
          horizontalMargin: 16,
          headingRowHeight: 52,
          dataRowMinHeight: 68,
          dataRowMaxHeight: 88,
          showCheckboxColumn: false,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF13233B),
          ),
          columns: [
            const DataColumn(label: Text('الصورة')),
            DataColumn(
              label: const Text('العنوان / النوع'),
              onSort: (col, asc) => setState(() { _sortCol = 0; _sortAsc = asc; }),
            ),
            DataColumn(
              label: const Text('المدينة'),
              onSort: (col, asc) => setState(() { _sortCol = 2; _sortAsc = asc; }),
            ),
            DataColumn(
              label: const Text('السعر'),
              onSort: (col, asc) => setState(() { _sortCol = 3; _sortAsc = asc; }),
            ),
            DataColumn(
              label: const Text('الناشر'),
              onSort: (col, asc) => setState(() { _sortCol = 4; _sortAsc = asc; }),
            ),
            DataColumn(
              label: const Text('تاريخ النشر'),
              onSort: (col, asc) => setState(() { _sortCol = 5; _sortAsc = asc; }),
            ),
            const DataColumn(label: Text('الحالة')),
            const DataColumn(label: Text('الإجراءات')),
          ],
          rows: props.map((p) => DataRow(cells: [
            DataCell(_PropertyThumbnail(url: _resolveUrl(p.thumbnailUrl))),
            DataCell(
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    [p.type, if (p.operationType.isNotEmpty) p.operationType].join(' • '),
                    style: const TextStyle(color: Color(0xFF516174), fontSize: 12),
                  ),
                ]),
              ),
              onTap: () => _showDetail(p),
            ),
            DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(p.city),
              if (p.district.isNotEmpty)
                Text(p.district, style: const TextStyle(fontSize: 11, color: Color(0xFF8A98A9))),
            ])),
            DataCell(Text('${p.price}${p.currency.isNotEmpty ? ' ${p.currency}' : ''}')),
            DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(p.publisher, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (p.publisherPhone.isNotEmpty)
                Text(p.publisherPhone, style: const TextStyle(fontSize: 11, color: Color(0xFF8A98A9))),
            ])),
            DataCell(Text(_fmtDate(p.postedAt))),
            DataCell(_StatusBadge(status: p.status, featured: p.featured)),
            DataCell(_PropertyRowActions(property: p, onAction: _handleAction)),
          ])).toList(),
        ),
      ),
    );
  }
}

// ── Screen header ─────────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🏠 إدارة العقارات',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('تصفح العقارات، راجع الطلبات، وميّز العقارات.',
              style: Theme.of(context).textTheme.bodyLarge),
        ]),
        Wrap(spacing: 12, runSpacing: 8, children: [
          ElevatedButton.icon(
            onPressed: () => context.go('/properties/add'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة عقار'),
          ),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تحديث'),
          ),
        ]),
      ],
    );
  }
}

// ── Thumbnail widget ──────────────────────────────────────────────────────────

class _PropertyThumbnail extends StatelessWidget {
  const _PropertyThumbnail({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: url.isEmpty
          ? const Icon(Icons.home_work_outlined, color: Color(0xFF8A98A9), size: 28)
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFF0F4FB),
                    child: const Center(
                      child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded, color: Color(0xFF8A98A9), size: 28),
              ),
            ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.featured});
  final PropertyStatus status;
  final bool featured;

  static const Map<PropertyStatus, Color> _colors = {
    PropertyStatus.pending:  Color(0xFFF39C12),
    PropertyStatus.active:   Color(0xFF17B26A),
    PropertyStatus.featured: Color(0xFF9A6B00),
    PropertyStatus.sold:     Color(0xFF1D7CF2),
    PropertyStatus.rented:   Color(0xFF7B61FF),
    PropertyStatus.suspended:Color(0xFFB02A37),
    PropertyStatus.unknown:  Color(0xFF6E7F92),
  };

  static const Map<PropertyStatus, String> _labels = {
    PropertyStatus.pending:  'قيد المراجعة',
    PropertyStatus.active:   'نشط',
    PropertyStatus.featured: 'مميز ✦',
    PropertyStatus.sold:     'مُباع',
    PropertyStatus.rented:   'مؤجر',
    PropertyStatus.suspended:'موقوف',
    PropertyStatus.all:      'الكل',
    PropertyStatus.unknown:  'قيد التعديل',
  };

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = (featured && status == PropertyStatus.active)
        ? PropertyStatus.featured
        : status;
    final color = _colors[effectiveStatus] ?? const Color(0xFF6E7F92);
    final label = _labels[effectiveStatus] ?? 'غير محدد';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

// ── Row action buttons ────────────────────────────────────────────────────────

class _PropertyRowActions extends StatelessWidget {
  const _PropertyRowActions({required this.property, required this.onAction});
  final Property property;
  final void Function(Property, _PropertyAction) onAction;

  @override
  Widget build(BuildContext context) {
    final List<PopupMenuEntry<_PropertyAction>> items = [
      _menuItem(_PropertyAction.view, Icons.remove_red_eye_outlined, 'عرض التفاصيل'),
      const PopupMenuDivider(),
      if (property.isPending) ...[
        _menuItem(_PropertyAction.approve, Icons.check_circle_outline, 'موافقة', color: const Color(0xFF17B26A)),
        _menuItem(_PropertyAction.reject, Icons.cancel_outlined, 'رفض', color: const Color(0xFFD92D20)),
        _menuItem(_PropertyAction.requestEdit, Icons.edit_note_rounded, 'طلب تعديل', color: const Color(0xFF1D7CF2)),
      ],
      if (property.isActive && !property.isFeatured)
        _menuItem(_PropertyAction.feature, Icons.star_rounded, 'تمييز', color: const Color(0xFF9A6B00)),
      if (property.isFeatured)
        _menuItem(_PropertyAction.unfeature, Icons.star_border_rounded, 'إلغاء التمييز'),
      if (!property.isSold && !property.isRented && !property.isPending) ...[
        _menuItem(_PropertyAction.markSold, Icons.sell_outlined, 'تعليم كمُباع', color: const Color(0xFF1D7CF2)),
        _menuItem(_PropertyAction.markRented, Icons.key_outlined, 'تعليم كمؤجر', color: const Color(0xFF7B61FF)),
      ],
      if (property.isSuspended || property.isSold || property.isRented)
        _menuItem(_PropertyAction.restore, Icons.restore_rounded, 'استعادة / تفعيل', color: const Color(0xFF17B26A)),
      const PopupMenuDivider(),
      _menuItem(_PropertyAction.delete, Icons.delete_outline_rounded, 'حذف نهائي', color: const Color(0xFFD92D20)),
    ];

    return Row(mainAxisSize: MainAxisSize.min, children: [
      // ── Approve (قبول) — always visible ──────────────────────────────────
      _ActionBtn(
        icon: Icons.check_rounded,
        color: const Color(0xFF17B26A),
        tooltip: 'قبول',
        onTap: () => onAction(property, _PropertyAction.approve),
      ),
      const SizedBox(width: 5),

      // ── Request Edit (طلب تعديل) — always visible ─────────────────────────
      _ActionBtn(
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF1D7CF2),
        tooltip: 'طلب تعديل',
        onTap: () => onAction(property, _PropertyAction.requestEdit),
      ),
      const SizedBox(width: 5),

      // ── Delete (حذف) — always visible ────────────────────────────────────
      _ActionBtn(
        icon: Icons.delete_outline_rounded,
        color: const Color(0xFFD92D20),
        tooltip: 'حذف',
        onTap: () => onAction(property, _PropertyAction.delete),
      ),
      const SizedBox(width: 5),

      // ── More menu (remaining actions) ────────────────────────────────────
      PopupMenuButton<_PropertyAction>(
        tooltip: 'المزيد',
        icon: const Icon(Icons.more_horiz_rounded, size: 20),
        itemBuilder: (_) => items,
        onSelected: (a) => onAction(property, a),
      ),
    ]);
  }

  static PopupMenuItem<_PropertyAction> _menuItem(
      _PropertyAction value, IconData icon, String label, {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: color ?? const Color(0xFF516174)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ── Property Detail Dialog ────────────────────────────────────────────────────

class _PropertyDetailDialog extends StatefulWidget {
  const _PropertyDetailDialog({
    required this.property,
    required this.onAction,
  });
  final Property property;
  final void Function(_PropertyAction) onAction;

  @override
  State<_PropertyDetailDialog> createState() => _PropertyDetailDialogState();
}

class _PropertyDetailDialogState extends State<_PropertyDetailDialog> {
  late final PageController _pageCtrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final images = p.imageUrls.map(_resolveUrl).where((u) => u.isNotEmpty).toList();
    final screenW = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: screenW < 700 ? screenW * 0.95 : 780),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Gallery ────────────────────────────────────────────────────
            if (images.isNotEmpty)
              Stack(children: [
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (_, child, prog) {
                          if (prog == null) return child;
                          return Container(
                            color: const Color(0xFFF0F4FB),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF0F4FB),
                          child: const Icon(Icons.broken_image_rounded, size: 48, color: Color(0xFF8A98A9)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (images.length > 1) ...[
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(images.length, (i) => Container(
                        width: i == _page ? 16 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == _page ? Colors.white : Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 80,
                    child: _GalleryNavBtn(
                      icon: Icons.chevron_left_rounded,
                      onTap: () {
                        if (_page > 0) _pageCtrl.previousPage(
                            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                      },
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 80,
                    child: _GalleryNavBtn(
                      icon: Icons.chevron_right_rounded,
                      onTap: () {
                        if (_page < images.length - 1) _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                      },
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${_page + 1} / ${images.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                ],
              ]),

            // ── Thumbnail strip (shown when >1 image) ──────────────────────
            if (images.length > 1)
              Container(
                color: const Color(0xFF0B1E35),
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  itemCount: images.length,
                  itemBuilder: (_, i) {
                    final isSelected = i == _page;
                    return GestureDetector(
                      onTap: () => _pageCtrl.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFD4AF37)
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
                                  blurRadius: 6,
                                )]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            images[i],
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, prog) {
                              if (prog == null) return child;
                              return Container(
                                color: const Color(0xFF1A2F4A),
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF1A2F4A),
                              child: const Icon(
                                Icons.broken_image_rounded,
                                size: 22,
                                color: Color(0xFF8A98A9),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (images.isEmpty)
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F4FB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Center(child: Icon(Icons.home_work_outlined, size: 48, color: Color(0xFF8A98A9))),
              ),

            // ── Content ────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Title + status
                  Row(children: [
                    Expanded(
                      child: Text(p.title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF13233B))),
                    ),
                    const SizedBox(width: 12),
                    _StatusBadge(status: p.status, featured: p.featured),
                  ]),
                  const SizedBox(height: 18),

                  // ── Info grid ───────────────────────────────────────────
                  _InfoSection(title: 'معلومات العقار', rows: [
                    _InfoRow('النوع', '${p.type}${p.operationType.isNotEmpty ? ' • ${p.operationType}' : ''}'),
                    _InfoRow('الموقع', '${p.city}${p.district.isNotEmpty ? ' — ${p.district}' : ''}'),
                    _InfoRow('السعر', '${p.price}${p.currency.isNotEmpty ? ' ${p.currency}' : ''}'),
                    _InfoRow('المعرف', p.id),
                    _InfoRow('تاريخ النشر', _fmtDate(p.postedAt)),
                  ]),
                  const SizedBox(height: 16),

                  // ── Owner ────────────────────────────────────────────────
                  _InfoSection(title: 'بيانات الناشر / المالك', rows: [
                    _InfoRow('الاسم', p.publisher),
                    if (p.publisherPhone.isNotEmpty) _InfoRow('الهاتف', p.publisherPhone),
                    if (p.publisherEmail.isNotEmpty) _InfoRow('البريد', p.publisherEmail),
                    if (p.officeName.isNotEmpty) _InfoRow('المكتب', p.officeName),
                  ]),
                  const SizedBox(height: 16),

                  // ── Stats ─────────────────────────────────────────────────
                  _InfoSection(title: 'الإحصاءات', rows: [
                    _InfoRow('مشاهدات', '${p.viewsCount}'),
                    _InfoRow('مكالمات', '${p.callsCount}'),
                    _InfoRow('مفضّلة', '${p.favoritesCount}'),
                    _InfoRow('بلاغات', '${p.reportsCount}'),
                  ]),

                  // ── Description ───────────────────────────────────────────
                  if (p.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _InfoSection(title: 'الوصف', rows: [
                      _InfoRow('', p.description, multiline: true),
                    ]),
                  ],

                  // ── Rejection reason ──────────────────────────────────────
                  if (p.rejectionReason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD92D20).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD92D20).withValues(alpha: 0.2)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.info_outline, color: Color(0xFFD92D20), size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text('سبب الرفض: ${p.rejectionReason}',
                            style: const TextStyle(color: Color(0xFFB02A37)))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Action buttons ────────────────────────────────────────
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    if (p.isPending) ...[
                      _DetailActionBtn('موافقة', Icons.check_circle_outline, const Color(0xFF17B26A),
                          () => widget.onAction(_PropertyAction.approve)),
                      _DetailActionBtn('رفض', Icons.cancel_outlined, const Color(0xFFD92D20),
                          () => widget.onAction(_PropertyAction.reject)),
                      _DetailActionBtn('طلب تعديل', Icons.edit_note_rounded, const Color(0xFF1D7CF2),
                          () => widget.onAction(_PropertyAction.requestEdit)),
                    ],
                    if (p.isActive && !p.isFeatured)
                      _DetailActionBtn('تمييز', Icons.star_rounded, const Color(0xFF9A6B00),
                          () => widget.onAction(_PropertyAction.feature)),
                    if (p.isFeatured)
                      _DetailActionBtn('إلغاء التمييز', Icons.star_border_rounded, const Color(0xFF516174),
                          () => widget.onAction(_PropertyAction.unfeature)),
                    if (!p.isSold && !p.isRented && !p.isPending) ...[
                      _DetailActionBtn('تعليم كمُباع', Icons.sell_outlined, const Color(0xFF1D7CF2),
                          () => widget.onAction(_PropertyAction.markSold)),
                      _DetailActionBtn('تعليم كمؤجر', Icons.key_outlined, const Color(0xFF7B61FF),
                          () => widget.onAction(_PropertyAction.markRented)),
                    ],
                    if (p.isSuspended || p.isSold || p.isRented)
                      _DetailActionBtn('استعادة', Icons.restore_rounded, const Color(0xFF17B26A),
                          () => widget.onAction(_PropertyAction.restore)),
                    _DetailActionBtn('حذف نهائي', Icons.delete_outline_rounded, const Color(0xFFD92D20),
                        () => widget.onAction(_PropertyAction.delete)),
                  ]),
                ]),
              ),
            ),

            // ── Close ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5EAF2))),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _GalleryNavBtn extends StatelessWidget {
  const _GalleryNavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.rows});
  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xFF0B3A66), fontSize: 14)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5EAF2)),
        ),
        child: Column(children: rows.asMap().entries.map((e) {
          final row = e.value;
          final isLast = e.key == rows.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFE5EAF2))),
            ),
            child: row.multiline
                ? Text(row.value, style: const TextStyle(color: Color(0xFF35465E)))
                : Row(children: [
                    if (row.label.isNotEmpty) ...[
                      SizedBox(
                        width: 110,
                        child: Text(row.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, color: Color(0xFF516174), fontSize: 13)),
                      ),
                    ],
                    Expanded(
                      child: Text(row.value,
                          style: const TextStyle(color: Color(0xFF35465E), fontSize: 13)),
                    ),
                  ]),
          );
        }).toList()),
      ),
    ]);
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value, {this.multiline = false});
  final String label;
  final String value;
  final bool multiline;
}

class _DetailActionBtn extends StatelessWidget {
  const _DetailActionBtn(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Utility ───────────────────────────────────────────────────────────────────

String _fmtDate(DateTime? dt) {
  if (dt == null) return 'غير محدد';
  // Format: YYYY-MM-DD  HH:mm AM/PM
  final y  = dt.year.toString().padLeft(4, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final d  = dt.day.toString().padLeft(2, '0');
  final raw = dt.hour;
  final h  = (raw % 12 == 0 ? 12 : raw % 12).toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  final ampm = raw < 12 ? 'AM' : 'PM';
  return '$y-$mo-$d  $h:$mi $ampm';
}
