import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/api_service.dart';

enum PropertyStatus { pending, active, sold, rented, suspended, unknown }

enum _PropertyAction {
  view,
  edit,
  approve,
  reject,
  delete,
  toggleFeature,
  suspend,
}

class Property {
  Property({
    required this.id,
    required this.title,
    required this.type,
    required this.city,
    required this.price,
    required this.publisher,
    required this.postedAt,
    required this.status,
    required this.thumbnailUrl,
    required this.featured,
    required this.isSuspended,
  });

  final String id;
  final String title;
  final String type;
  final String city;
  final String price;
  final String publisher;
  final DateTime? postedAt;
  final PropertyStatus status;
  final String thumbnailUrl;
  final bool featured;
  final bool isSuspended;

  bool get isPending => status == PropertyStatus.pending;
  bool get isActive => status == PropertyStatus.active;
  bool get isSoldOrRented => status == PropertyStatus.sold || status == PropertyStatus.rented;

  Property copyWith({
    String? title,
    String? type,
    String? city,
    String? price,
    String? publisher,
    DateTime? postedAt,
    PropertyStatus? status,
    String? thumbnailUrl,
    bool? featured,
    bool? isSuspended,
  }) {
    return Property(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      city: city ?? this.city,
      price: price ?? this.price,
      publisher: publisher ?? this.publisher,
      postedAt: postedAt ?? this.postedAt,
      status: status ?? this.status,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      featured: featured ?? this.featured,
      isSuspended: isSuspended ?? this.isSuspended,
    );
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status'] ?? json['state'] ?? '').toString().toLowerCase();
    return Property(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'بدون عنوان',
      type: json['type']?.toString() ?? json['propertyType']?.toString() ?? 'غير محدد',
      city: json['city']?.toString() ?? json['location']?.toString() ?? 'غير محدد',
      price: _formatPrice(json['price']) ?? json['price']?.toString() ?? 'غير متاح',
      publisher: json['publisher'] is Map<String, dynamic>
          ? (json['publisher']['name']?.toString() ?? json['publisher']['email']?.toString() ?? 'غير معروف')
          : json['publisher']?.toString() ?? 'غير معروف',
      postedAt: _parseDate(json['createdAt'] ?? json['publishedAt'] ?? json['date']),
      status: _statusFromString(_normalizeStatusRaw(statusRaw)),
      thumbnailUrl: _extractThumbnail(json),
      featured: json['featured'] == true || json['isFeatured'] == true,
      isSuspended: json['isSuspended'] == true || json['suspended'] == true,
    );
  }

  static String? _formatPrice(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)} ر.س';
    }
    final stringValue = value.toString();
    if (stringValue.isEmpty) {
      return null;
    }
    return stringValue.contains('ر.س') ? stringValue : '$stringValue ر.س';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  static PropertyStatus _statusFromString(String value) {
    switch (value) {
      case 'pending':
      case 'awaiting':
      case 'awaiting approval':
      case 'بانتظار المراجعة':
        return PropertyStatus.pending;
      case 'active':
      case 'نشط':
        return PropertyStatus.active;
      case 'sold':
      case 'مباعة':
        return PropertyStatus.sold;
      case 'rented':
      case 'مؤجرة':
        return PropertyStatus.rented;
      case 'suspended':
      case 'موقوف':
        return PropertyStatus.suspended;
      default:
        return PropertyStatus.unknown;
    }
  }

  static String _normalizeStatusRaw(String value) {
    switch (value) {
      case 'approved':
        return 'active';
      case 'rejected':
      case 'refused':
        return 'suspended';
      default:
        return value;
    }
  }

  static String _extractThumbnail(Map<String, dynamic> json) {
    if (json['thumbnail'] is String && (json['thumbnail'] as String).isNotEmpty) {
      return json['thumbnail'] as String;
    }
    if (json['image'] is String && (json['image'] as String).isNotEmpty) {
      return json['image'] as String;
    }
    final images = json['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String && first.isNotEmpty) {
        return first;
      }
      if (first is Map<String, dynamic>) {
        return first['url']?.toString() ?? '';
      }
    }
    return '';
  }
}

class PropertyDataSource extends DataTableSource {
  PropertyDataSource({
    required this.properties,
    required this.onAction,
  });

  final List<Property> properties;
  final void Function(Property property, _PropertyAction action) onAction;

  @override
  DataRow getRow(int index) {
    if (index < 0 || index >= properties.length) {
      return DataRow(cells: List<DataCell>.generate(
        9,
        (_) => const DataCell(Text('')),
      ));
    }

    final property = properties[index];

    return DataRow.byIndex(
      index: index,
      cells: <DataCell>[
        DataCell(
          _PropertyThumbnail(url: property.thumbnailUrl),
        ),
        DataCell(Text(property.title, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(property.type)),
        DataCell(Text(property.city)),
        DataCell(Text(property.price)),
        DataCell(Text(property.publisher)),
        DataCell(Text(_formatDate(property.postedAt))),
        DataCell(_StatusBadge(status: property.status, featured: property.featured, suspended: property.isSuspended)),
        DataCell(_PropertyRowActions(property: property, onAction: onAction)),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => properties.length;

  @override
  int get selectedRowCount => 0;

  static String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'غير محدد';
    const months = <String>[
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${dateTime.day.toString().padLeft(2, '0')} ${months[dateTime.month - 1]} ${dateTime.year}';
  }
}

class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({super.key});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ApiService _apiService;

  bool _isLoading = true;
  bool _isActionLoading = false;
  String? _errorMessage;
  List<Property> _properties = <Property>[];
  int _sortColumnIndex = 1;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _apiService = context.read<ApiService>();
      _loadProperties();
    });
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.get<dynamic>('/admin/properties');
      if (response.statusCode == 200 && response.data != null) {
        final rawList = _extractPropertyList(response.data);
        final properties = rawList
            .whereType<Map<String, dynamic>>()
            .map(Property.fromJson)
            .toList();
        setState(() {
          _properties = properties;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _properties = <Property>[];
          _isLoading = false;
          _errorMessage = 'لا توجد عقارات مسجلة حالياً';
        });
      }
    } catch (error) {
      setState(() {
        _properties = <Property>[];
        _isLoading = false;
        _errorMessage = 'فشل تحميل البيانات. حاول مرة أخرى.';
      });
      _showSnackBar(error.toString());
    }
  }

  List<Property> _propertiesForTab(int index) {
    switch (index) {
      case 1:
        return _properties.where((property) => property.isPending).toList();
      case 2:
        return _properties.where((property) => property.isActive).toList();
      case 3:
        return _properties.where((property) => property.featured).toList();
      case 4:
        return _properties.where((property) => property.isSoldOrRented).toList();
      default:
        return _properties;
    }
  }

  Future<void> _handleAction(Property property, _PropertyAction action) async {
    switch (action) {
      case _PropertyAction.view:
        _showViewDetails(property);
        break;
      case _PropertyAction.edit:
        _showEditDialog(property);
        break;
      case _PropertyAction.approve:
        await _setPropertyStatus(
          property,
          status: 'approved',
          confirmationTitle: 'تأكيد الموافقة',
          confirmationContent: 'هل تريد الموافقة على العقار "${property.title}"؟',
        );
        break;
      case _PropertyAction.reject:
        await _setPropertyStatus(
          property,
          status: 'rejected',
          confirmationTitle: 'تأكيد الرفض',
          confirmationContent: 'هل تريد رفض العقار "${property.title}"؟',
        );
        break;
      case _PropertyAction.delete:
        await _deletePropertyNow(property);
        break;
      case _PropertyAction.toggleFeature:
        await _toggleFeature(property);
        break;
      case _PropertyAction.suspend:
        await _suspendProperty(property);
        break;
    }
  }

  Future<void> _approveProperty(Property property) async {
    final confirmed = await _showConfirmationDialog(
      title: 'تأكيد الموافقة',
      content: 'هل تريد موافقة العقار "${property.title}"؟',
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _apiService.put('/admin/properties/${property.id}/approve');
      _updateProperty(property.copyWith(status: PropertyStatus.active));
      _showSnackBar('تمت الموافقة على العقار بنجاح.');
    } catch (_) {
      _showSnackBar('فشل تحديث حالة العقار. حاول مرة أخرى.');
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _rejectProperty(Property property) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('رفض العقار'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('يرجى إدخال سبب الرفض:'),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'سبب الرفض...',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('إرسال الرفض'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _apiService.put(
        '/admin/properties/${property.id}/reject',
        data: {'reason': reasonController.text.trim()},
      );
      _updateProperty(property.copyWith(status: PropertyStatus.suspended));
      _showSnackBar('تم رفض العقار وإرسال السبب بنجاح.');
    } catch (_) {
      _showSnackBar('فشل إرسال الرفض. حاول مرة أخرى.');
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deleteProperty(Property property) async {
    final confirmed = await _showConfirmationDialog(
      title: 'حذف العقار',
      content: 'هل أنت متأكد من حذف العقار "${property.title}" بشكل نهائي؟',
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _apiService.delete('/admin/properties/${property.id}');
      setState(() {
        _properties.removeWhere((item) => item.id == property.id);
      });
      _showSnackBar('تم حذف العقار بنجاح.');
    } catch (_) {
      _showSnackBar('فشل حذف العقار. حاول مرة أخرى.');
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _toggleFeature(Property property) async {
    setState(() => _isActionLoading = true);
    try {
      await _apiService.put(
        '/admin/properties/${property.id}/feature',
        data: {'featured': !property.featured},
      );
      _updateProperty(property.copyWith(featured: !property.featured));
      _showSnackBar(property.featured ? 'تم إزالة التمييز عن العقار.' : 'تم تمييز العقار بنجاح.');
    } catch (_) {
      _showSnackBar('فشل تحديث حالة التمييز. حاول مرة أخرى.');
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _suspendProperty(Property property) async {
    final confirmed = await _showConfirmationDialog(
      title: 'إيقاف العقار',
      content: 'هل تريد إيقاف العقار "${property.title}" مؤقتًا؟',
    );
    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _apiService.put('/admin/properties/${property.id}/suspend');
      _updateProperty(property.copyWith(isSuspended: true, status: PropertyStatus.suspended));
      _showSnackBar('تم إيقاف العقار مؤقتًا.');
    } catch (_) {
      _showSnackBar('فشل إيقاف العقار. حاول مرة أخرى.');
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _showViewDetails(Property property) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('عرض التفاصيل'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (property.thumbnailUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      property.thumbnailUrl,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: const Color(0xFFE5EAF2),
                        child: const Icon(Icons.image_not_supported_rounded, size: 48),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                _DetailRow(label: 'عنوان العقار', value: property.title),
                _DetailRow(label: 'نوع العقار', value: property.type),
                _DetailRow(label: 'المدينة', value: property.city),
                _DetailRow(label: 'السعر', value: property.price),
                _DetailRow(label: 'الناشر', value: property.publisher),
                _DetailRow(label: 'التاريخ', value: PropertyDataSource._formatDate(property.postedAt)),
                _DetailRow(label: 'الحالة', value: _statusLabel(property.status)),
                _DetailRow(label: 'مميز', value: property.featured ? 'نعم' : 'لا'),
                _DetailRow(label: 'معلق', value: property.isSuspended ? 'نعم' : 'لا'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(Property property) async {
    final titleController = TextEditingController(text: property.title);
    final typeController = TextEditingController(text: property.type);
    final cityController = TextEditingController(text: property.city);
    final priceController = TextEditingController(text: property.price.replaceAll(' ر.س', ''));
    final publisherController = TextEditingController(text: property.publisher);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل العقار'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'عنوان العقار'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(labelText: 'نوع العقار'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'المدينة'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'السعر'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: publisherController,
                  decoration: const InputDecoration(labelText: 'الناشر'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('حفظ التعديلات'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      final updatedProperty = property.copyWith(
        title: titleController.text.trim(),
        type: typeController.text.trim(),
        city: cityController.text.trim(),
        price: '${priceController.text.trim()} ر.س',
        publisher: publisherController.text.trim(),
      );
      await _apiService.put(
        '/admin/properties/${property.id}',
        data: {
          'title': updatedProperty.title,
          'type': updatedProperty.type,
          'city': updatedProperty.city,
          'price': updatedProperty.price.replaceAll(' ر.س', ''),
          'publisher': updatedProperty.publisher,
        },
      );
      _updateProperty(updatedProperty);
      _showSnackBar('تم حفظ التعديلات بنجاح.');
    } catch (_) {
      _showSnackBar('فشل حفظ التعديلات. حاول مرة أخرى.');
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _setPropertyStatus(
    Property property, {
    required String status,
    required String confirmationTitle,
    required String confirmationContent,
  }) async {
    final confirmed = await _showConfirmationDialog(
      title: confirmationTitle,
      content: confirmationContent,
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _apiService.put(
        '/admin/properties/${property.id}/status',
        data: <String, dynamic>{'status': status},
      );
      await _loadProperties();
      _showSnackBar('تم تحديث حالة العقار');
    } catch (error) {
      debugPrint('Property status update failed: $error');
      _showSnackBar('فشل تحديث حالة العقار. حاول مرة أخرى.');
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deletePropertyNow(Property property) async {
    final confirmed = await _showConfirmationDialog(
      title: 'تأكيد الحذف',
      content: 'هل تريد حذف العقار "${property.title}" نهائياً؟',
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      await _apiService.delete('/admin/properties/${property.id}');
      await _loadProperties();
      _showSnackBar('تم تحديث حالة العقار');
    } catch (error) {
      debugPrint('Property delete failed: $error');
      _showSnackBar('فشل حذف العقار. حاول مرة أخرى.');
    } finally {
      setState(() => _isActionLoading = false);
    }
  }

  void _updateProperty(Property property) {
    setState(() {
      final index = _properties.indexWhere((item) => item.id == property.id);
      if (index >= 0) {
        _properties[index] = property;
      }
    });
  }

  Future<bool?> _showConfirmationDialog({required String title, required String content}) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<dynamic> _extractPropertyList(dynamic data) {
    return ApiResponseNormalizer.asList(data);
  }

  void _sortProperties(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _properties.sort((a, b) {
        final order = ascending ? 1 : -1;
        switch (columnIndex) {
          case 1:
            return order * a.title.compareTo(b.title);
          case 2:
            return order * a.type.compareTo(b.type);
          case 3:
            return order * a.city.compareTo(b.city);
          case 4:
            return order * a.price.compareTo(b.price);
          case 6:
            return order * (a.postedAt?.compareTo(b.postedAt ?? DateTime(1900)) ?? 0);
          default:
            return 0;
        }
      });
    });
  }

  Widget _buildTablePane(BuildContext context, List<Property> properties) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  columnSpacing: 20,
                  horizontalMargin: 20,
                  headingRowHeight: 56,
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 84,
                  showCheckboxColumn: false,
                  columns: <DataColumn>[
                    const DataColumn(label: Text('صورة العقار')),
                    DataColumn(
                      label: const Text('عنوان العقار'),
                      onSort: (columnIndex, ascending) =>
                          _sortProperties(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text('نوع العقار'),
                      onSort: (columnIndex, ascending) =>
                          _sortProperties(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text('المدينة'),
                      onSort: (columnIndex, ascending) =>
                          _sortProperties(columnIndex, ascending),
                    ),
                    DataColumn(
                      label: const Text('السعر'),
                      onSort: (columnIndex, ascending) =>
                          _sortProperties(columnIndex, ascending),
                    ),
                    const DataColumn(label: Text('الناشر')),
                    DataColumn(
                      label: const Text('تاريخ النشر'),
                      onSort: (columnIndex, ascending) =>
                          _sortProperties(columnIndex, ascending),
                    ),
                    const DataColumn(label: Text('الحالة')),
                    const DataColumn(label: Text('الإجراءات')),
                  ],
                  rows: properties.asMap().entries.map((entry) {
                    final index = entry.key;
                    final property = entry.value;

                    return DataRow.byIndex(
                      index: index,
                      cells: <DataCell>[
                        DataCell(_PropertyThumbnail(url: property.thumbnailUrl)),
                        DataCell(
                          Text(
                            property.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(Text(property.type)),
                        DataCell(Text(property.city)),
                        DataCell(Text(property.price)),
                        DataCell(Text(property.publisher)),
                        DataCell(Text(PropertyDataSource._formatDate(property.postedAt))),
                        DataCell(
                          _StatusBadge(
                            status: property.status,
                            featured: property.featured,
                            suspended: property.isSuspended,
                          ),
                        ),
                        DataCell(
                          _PropertyRowActions(
                            property: property,
                            onAction: _handleAction,
                          ),
                        ),
                      ],
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ScreenHeader(onRefresh: _loadProperties),
            const SizedBox(height: 18),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'إدارة العقارات',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تصفح العقارات، وافق على الطلبات، وميز العقارات المميزة مباشرة من لوحة الإدارة.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: const Color(0xFF0B3A66),
                        unselectedLabelColor: const Color(0xFF516174),
                        indicatorColor: const Color(0xFF1D7CF2),
                        tabs: const <Tab>[
                          Tab(text: 'جميع العقارات'),
                          Tab(text: 'بانتظار المراجعة'),
                          Tab(text: 'العقارات النشطة'),
                          Tab(text: 'العقارات المميزة'),
                          Tab(text: 'العقارات المباعة/المؤجرة'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: List<Widget>.generate(
                            5,
                            (tabIndex) {
                              final tabProperties = _propertiesForTab(tabIndex);
                              if (_isLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (_errorMessage != null) {
                                return Center(
                                  child: Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                );
                              }

                              if (tabProperties.isEmpty) {
                                return Center(
                                  child: Text(
                                    'لا توجد عقارات مسجلة حالياً',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                );
                              }

                              return _buildTablePane(context, tabProperties);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isActionLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.06),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '🏠 العقارات',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'إدارة جميع العقارات ومتابعة وضعها في لوحة التحكم.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            ElevatedButton.icon(
              onPressed: () => context.go('/properties/add'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة عقار'),
            ),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تحديث البيانات'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PropertyThumbnail extends StatelessWidget {
  const _PropertyThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: url.isEmpty
          ? const Icon(Icons.image_not_supported_rounded, color: Color(0xFF8A98A9), size: 30)
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Color(0xFF8A98A9), size: 30),
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.featured, required this.suspended});

  final PropertyStatus status;
  final bool featured;
  final bool suspended;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
    final color = _statusColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
            color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _statusLabel(status, featured: featured, suspended: suspended),
        style: style?.copyWith(color: color),
      ),
    );
  }

  Color _statusColor() {
    if (suspended) return const Color(0xFFB02A37);
    switch (status) {
      case PropertyStatus.pending:
        return const Color(0xFFF39C12);
      case PropertyStatus.active:
        return const Color(0xFF17B26A);
      case PropertyStatus.sold:
      case PropertyStatus.rented:
        return const Color(0xFF1D7CF2);
      default:
        return const Color(0xFF6E7F92);
    }
  }
}

String _statusLabel(PropertyStatus status, {bool featured = false, bool suspended = false}) {
  if (suspended) {
    return 'موقوف';
  }
  switch (status) {
    case PropertyStatus.pending:
      return 'بإنتظار المراجعة';
    case PropertyStatus.active:
      return featured ? 'نشط - مميز' : 'نشط';
    case PropertyStatus.sold:
      return 'مباعة';
    case PropertyStatus.rented:
      return 'مؤجرة';
    default:
      return 'غير محدد';
  }
}

class _PropertyActionsCell extends StatelessWidget {
  const _PropertyActionsCell({required this.property, required this.onAction});

  final Property property;
  final void Function(Property property, _PropertyAction action) onAction;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PropertyAction>(
      tooltip: 'الإجراءات',
      icon: const Icon(Icons.more_horiz_rounded, size: 22),
      onCanceled: () {},
      itemBuilder: (context) {
        return <PopupMenuEntry<_PropertyAction>>[
          PopupMenuItem<_PropertyAction>(
            value: _PropertyAction.view,
            child: const ListTile(
              leading: Icon(Icons.remove_red_eye_outlined),
              title: Text('عرض'),
            ),
          ),
          PopupMenuItem<_PropertyAction>(
            value: _PropertyAction.edit,
            child: const ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('تعديل'),
            ),
          ),
          if (property.isPending)
            PopupMenuItem<_PropertyAction>(
              value: _PropertyAction.approve,
              child: const ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('موافقة'),
              ),
            ),
          PopupMenuItem<_PropertyAction>(
            value: _PropertyAction.reject,
            child: const ListTile(
              leading: Icon(Icons.cancel_outlined),
              title: Text('رفض'),
            ),
          ),
          PopupMenuItem<_PropertyAction>(
            value: _PropertyAction.delete,
            child: const ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('حذف'),
            ),
          ),
          PopupMenuItem<_PropertyAction>(
            value: _PropertyAction.toggleFeature,
            child: ListTile(
              leading: const Icon(Icons.star_border),
              title: Text(property.featured ? 'إلغاء التمييز' : 'تمييز'),
            ),
          ),
          PopupMenuItem<_PropertyAction>(
            value: _PropertyAction.suspend,
            child: const ListTile(
              leading: Icon(Icons.block_outlined),
              title: Text('إيقاف'),
            ),
          ),
        ];
      },
      onSelected: (action) => onAction(property, action),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyRowActions extends StatelessWidget {
  const _PropertyRowActions({
    required this.property,
    required this.onAction,
  });

  final Property property;
  final void Function(Property property, _PropertyAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final canModerate = property.isPending;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ActionButton(
          tooltip: canModerate ? 'الموافقة' : 'الموافقة متاحة فقط للحالات المعلقة',
          icon: Icons.check_rounded,
          color: const Color(0xFF17B26A),
          enabled: canModerate,
          onPressed:
              canModerate ? () => onAction(property, _PropertyAction.approve) : null,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          tooltip: canModerate ? 'الرفض' : 'الرفض متاح فقط للحالات المعلقة',
          icon: Icons.close_rounded,
          color: const Color(0xFFD92D20),
          enabled: canModerate,
          onPressed:
              canModerate ? () => onAction(property, _PropertyAction.reject) : null,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          tooltip: 'الحذف',
          icon: Icons.delete_outline_rounded,
          color: const Color(0xFF667085),
          enabled: true,
          onPressed: () => onAction(property, _PropertyAction.delete),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final background =
      enabled ? color.withOpacity(0.12) : const Color(0xFFF1F5F9);
    final borderColor =
      enabled ? color.withOpacity(0.28) : const Color(0xFFE2E8F0);
    final iconColor = enabled ? color : const Color(0xFF98A2B3);

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: iconColor),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          splashRadius: 18,
        ),
      ),
    );
  }
}
