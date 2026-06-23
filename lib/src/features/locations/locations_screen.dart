import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Locations Management Screen
// CRUD for governorates → cities → districts → neighborhoods (4 tabs)
// All data comes from real DB via AdminDataService
// ─────────────────────────────────────────────────────────────────────────────

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'إدارة المواقع الجغرافية',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'إدارة المحافظات والمدن والمديريات والأحياء.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF082949),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF082949),
          tabs: const <Tab>[
            Tab(text: 'المحافظات'),
            Tab(text: 'المدن'),
            Tab(text: 'المديريات'),
            Tab(text: 'الأحياء'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const <Widget>[
              _GovernoratesTab(),
              _CitiesTab(),
              _DistrictsTab(),
              _NeighborhoodsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Shared CRUD helpers ──────────────────────────────────────────────────────

String _str(dynamic v, [String fallback = '-']) =>
    v?.toString().trim().isEmpty == false ? v.toString().trim() : fallback;

String _extractError(dynamic err) {
  if (err is DioException) {
    final d = err.response?.data;
    if (d is Map) {
      final msg = d['message'] ?? d['error'] ?? d['msg'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    switch (err.response?.statusCode) {
      case 401:
        return 'انتهت صلاحية الجلسة.';
      case 404:
        return 'لم يُعثر على العنصر.';
      case 409:
        return 'هذا العنصر موجود بالفعل.';
    }
  }
  return err.toString();
}

void _showErr(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void _showOk(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF17B26A),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GOVERNORATES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _GovernoratesTab extends StatefulWidget {
  const _GovernoratesTab();

  @override
  State<_GovernoratesTab> createState() => _GovernoratesTabState();
}

class _GovernoratesTabState extends State<_GovernoratesTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = context.read<AdminDataService>();
      final data = await svc.fetchGovernorates();
      if (!mounted) return;
      setState(() { _items = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _showForm({Map<String, dynamic>? item}) async {
    final nameAr = TextEditingController(text: _str(item?['name_ar'], ''));
    final nameEn = TextEditingController(text: _str(item?['name_en'], ''));
    final id = item?['id']?.toString();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id == null ? 'إضافة محافظة' : 'تعديل محافظة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameAr, decoration: const InputDecoration(labelText: 'الاسم بالعربية *')),
          const SizedBox(height: 12),
          TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameAr.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final payload = {'name_ar': nameAr.text.trim(), 'name_en': nameEn.text.trim()};
    try {
      final svc = context.read<AdminDataService>();
      if (id == null) {
        await svc.createGovernorate(payload);
      } else {
        await svc.updateGovernorate(id, payload);
      }
      if (mounted) _showOk(context, id == null ? 'تمت الإضافة بنجاح' : 'تم التعديل بنجاح');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المحافظة'),
        content: Text('هل تريد حذف "${_str(item['name_ar'])}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AdminDataService>().deleteGovernorate(item['id'].toString());
      if (mounted) _showOk(context, 'تم الحذف بنجاح');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  @override
  Widget build(BuildContext context) => _CrudTabScaffold(
    title: 'المحافظات',
    loading: _loading,
    error: _error,
    onRefresh: _load,
    onAdd: () => _showForm(),
    child: _loading
        ? const SizedBox.shrink()
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            : _items.isEmpty
                ? const Center(child: Text('لا توجد محافظات مسجلة'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.location_city)),
                        title: Text(_str(item['name_ar'])),
                        subtitle: Text(_str(item['name_en'], '')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(item: item)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(item)),
                        ]),
                      );
                    },
                  ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CITIES TAB
// ─────────────────────────────────────────────────────────────────────────────

class _CitiesTab extends StatefulWidget {
  const _CitiesTab();

  @override
  State<_CitiesTab> createState() => _CitiesTabState();
}

class _CitiesTabState extends State<_CitiesTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _governorates = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = context.read<AdminDataService>();
      final results = await Future.wait([svc.fetchAdminCities(), svc.fetchGovernorates()]);
      if (!mounted) return;
      setState(() {
        _items = results[0];
        _governorates = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _showForm({Map<String, dynamic>? item}) async {
    final nameAr = TextEditingController(text: _str(item?['name_ar'], ''));
    final nameEn = TextEditingController(text: _str(item?['name_en'], ''));
    String? selectedGov = item?['governorate_id']?.toString();
    final id = item?['id']?.toString();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(id == null ? 'إضافة مدينة' : 'تعديل مدينة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameAr, decoration: const InputDecoration(labelText: 'الاسم بالعربية *')),
            const SizedBox(height: 12),
            TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedGov,
              decoration: const InputDecoration(labelText: 'المحافظة'),
              items: _governorates.map((g) => DropdownMenuItem(
                value: g['id'].toString(),
                child: Text(_str(g['name_ar'])),
              )).toList(),
              onChanged: (v) => setSt(() => selectedGov = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameAr.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final payload = <String, dynamic>{
      'name_ar': nameAr.text.trim(),
      'name_en': nameEn.text.trim(),
      if (selectedGov != null) 'governorate_id': int.tryParse(selectedGov!) ?? selectedGov,
    };
    try {
      final svc = context.read<AdminDataService>();
      if (id == null) {
        await svc.createCity(payload);
      } else {
        await svc.updateCity(id, payload);
      }
      if (mounted) _showOk(context, id == null ? 'تمت الإضافة بنجاح' : 'تم التعديل بنجاح');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المدينة'),
        content: Text('هل تريد حذف "${_str(item['name_ar'])}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AdminDataService>().deleteCity(item['id'].toString());
      if (mounted) _showOk(context, 'تم الحذف بنجاح');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  @override
  Widget build(BuildContext context) => _CrudTabScaffold(
    title: 'المدن',
    loading: _loading,
    error: _error,
    onRefresh: _load,
    onAdd: () => _showForm(),
    child: _loading
        ? const SizedBox.shrink()
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            : _items.isEmpty
                ? const Center(child: Text('لا توجد مدن مسجلة'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.location_on_outlined)),
                        title: Text(_str(item['name_ar'])),
                        subtitle: Text(_str(item['governorate_name'] ?? item['name_en'], '')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(item: item)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(item)),
                        ]),
                      );
                    },
                  ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DISTRICTS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _DistrictsTab extends StatefulWidget {
  const _DistrictsTab();

  @override
  State<_DistrictsTab> createState() => _DistrictsTabState();
}

class _DistrictsTabState extends State<_DistrictsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _cities = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = context.read<AdminDataService>();
      final results = await Future.wait([svc.fetchAdminDistricts(), svc.fetchAdminCities()]);
      if (!mounted) return;
      setState(() {
        _items = results[0];
        _cities = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _showForm({Map<String, dynamic>? item}) async {
    final nameAr = TextEditingController(text: _str(item?['name_ar'], ''));
    final nameEn = TextEditingController(text: _str(item?['name_en'], ''));
    String? selectedCity = item?['city_id']?.toString();
    final id = item?['id']?.toString();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(id == null ? 'إضافة مديرية' : 'تعديل مديرية'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameAr, decoration: const InputDecoration(labelText: 'الاسم بالعربية *')),
            const SizedBox(height: 12),
            TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedCity,
              decoration: const InputDecoration(labelText: 'المدينة'),
              items: _cities.map((c) => DropdownMenuItem(
                value: c['id'].toString(),
                child: Text(_str(c['name_ar'])),
              )).toList(),
              onChanged: (v) => setSt(() => selectedCity = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameAr.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final payload = <String, dynamic>{
      'name_ar': nameAr.text.trim(),
      'name_en': nameEn.text.trim(),
      if (selectedCity != null) 'city_id': int.tryParse(selectedCity!) ?? selectedCity,
    };
    try {
      final svc = context.read<AdminDataService>();
      if (id == null) {
        await svc.createDistrict(payload);
      } else {
        await svc.updateDistrict(id, payload);
      }
      if (mounted) _showOk(context, id == null ? 'تمت الإضافة بنجاح' : 'تم التعديل بنجاح');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المديرية'),
        content: Text('هل تريد حذف "${_str(item['name_ar'])}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AdminDataService>().deleteDistrict(item['id'].toString());
      if (mounted) _showOk(context, 'تم الحذف بنجاح');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  @override
  Widget build(BuildContext context) => _CrudTabScaffold(
    title: 'المديريات',
    loading: _loading,
    error: _error,
    onRefresh: _load,
    onAdd: () => _showForm(),
    child: _loading
        ? const SizedBox.shrink()
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            : _items.isEmpty
                ? const Center(child: Text('لا توجد مديريات مسجلة'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.map_outlined)),
                        title: Text(_str(item['name_ar'])),
                        subtitle: Text(_str(item['city_name'] ?? item['name_en'], '')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(item: item)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(item)),
                        ]),
                      );
                    },
                  ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// NEIGHBORHOODS TAB
// ─────────────────────────────────────────────────────────────────────────────

class _NeighborhoodsTab extends StatefulWidget {
  const _NeighborhoodsTab();

  @override
  State<_NeighborhoodsTab> createState() => _NeighborhoodsTabState();
}

class _NeighborhoodsTabState extends State<_NeighborhoodsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _districts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = context.read<AdminDataService>();
      final results = await Future.wait([svc.fetchAdminNeighborhoods(), svc.fetchAdminDistricts()]);
      if (!mounted) return;
      setState(() {
        _items = results[0];
        _districts = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _showForm({Map<String, dynamic>? item}) async {
    final nameAr = TextEditingController(text: _str(item?['name_ar'], ''));
    final nameEn = TextEditingController(text: _str(item?['name_en'], ''));
    String? selectedDistrict = item?['district_id']?.toString();
    final id = item?['id']?.toString();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(id == null ? 'إضافة حي' : 'تعديل حي'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameAr, decoration: const InputDecoration(labelText: 'الاسم بالعربية *')),
            const SizedBox(height: 12),
            TextField(controller: nameEn, decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedDistrict,
              decoration: const InputDecoration(labelText: 'المديرية'),
              items: _districts.map((d) => DropdownMenuItem(
                value: d['id'].toString(),
                child: Text(_str(d['name_ar'])),
              )).toList(),
              onChanged: (v) => setSt(() => selectedDistrict = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameAr.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final payload = <String, dynamic>{
      'name_ar': nameAr.text.trim(),
      'name_en': nameEn.text.trim(),
      if (selectedDistrict != null) 'district_id': int.tryParse(selectedDistrict!) ?? selectedDistrict,
    };
    try {
      final svc = context.read<AdminDataService>();
      if (id == null) {
        await svc.createNeighborhood(payload);
      } else {
        await svc.updateNeighborhood(id, payload);
      }
      if (mounted) _showOk(context, id == null ? 'تمت الإضافة بنجاح' : 'تم التعديل بنجاح');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحي'),
        content: Text('هل تريد حذف "${_str(item['name_ar'])}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<AdminDataService>().deleteNeighborhood(item['id'].toString());
      if (mounted) _showOk(context, 'تم الحذف بنجاح');
      _load();
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    }
  }

  @override
  Widget build(BuildContext context) => _CrudTabScaffold(
    title: 'الأحياء',
    loading: _loading,
    error: _error,
    onRefresh: _load,
    onAdd: () => _showForm(),
    child: _loading
        ? const SizedBox.shrink()
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
            : _items.isEmpty
                ? const Center(child: Text('لا توجد أحياء مسجلة'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.house_outlined)),
                        title: Text(_str(item['name_ar'])),
                        subtitle: Text(_str(item['district_name'] ?? item['name_en'], '')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showForm(item: item)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(item)),
                        ]),
                      );
                    },
                  ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared scaffold for each CRUD tab
// ─────────────────────────────────────────────────────────────────────────────

class _CrudTabScaffold extends StatelessWidget {
  const _CrudTabScaffold({
    required this.title,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onAdd,
    required this.child,
  });

  final String title;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.refresh), onPressed: onRefresh, tooltip: 'تحديث'),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            const Divider(),
            if (loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
