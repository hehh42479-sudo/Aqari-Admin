import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../../core/services/admin_data_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// App Config Screen — Branding, Social Links, Contact Info
// Backed by app_config table via /admin/app-config endpoint
// ─────────────────────────────────────────────────────────────────────────────

class AppConfigScreen extends StatefulWidget {
  const AppConfigScreen({super.key});

  @override
  State<AppConfigScreen> createState() => _AppConfigScreenState();
}

class _AppConfigScreenState extends State<AppConfigScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Branding
  final _appNameCtrl   = TextEditingController();
  final _logoUrlCtrl   = TextEditingController();
  final _primaryColorCtrl = TextEditingController();
  // Contact
  final _phoneCtrl     = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _addressCtrl   = TextEditingController();
  // Social
  final _facebookCtrl  = TextEditingController();
  final _twitterCtrl   = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _whatsappCtrl  = TextEditingController();
  // Store links
  final _playStoreCtrl = TextEditingController();
  final _appStoreCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in [_appNameCtrl, _logoUrlCtrl, _primaryColorCtrl,
        _phoneCtrl, _emailCtrl, _addressCtrl,
        _facebookCtrl, _twitterCtrl, _instagramCtrl, _whatsappCtrl,
        _playStoreCtrl, _appStoreCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(Map<String, dynamic> data) {
    String r(List<String> keys, [String fb = '']) {
      for (final k in keys) {
        final v = data[k]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
      return fb;
    }
    _appNameCtrl.text   = r(['app_name', 'appName', 'name']);
    _logoUrlCtrl.text   = r(['logo_url', 'logoUrl', 'logo']);
    _primaryColorCtrl.text = r(['primary_color', 'primaryColor', 'color']);
    _phoneCtrl.text     = r(['phone', 'contact_phone', 'contactPhone']);
    _emailCtrl.text     = r(['email', 'contact_email', 'contactEmail']);
    _addressCtrl.text   = r(['address', 'contact_address']);
    _facebookCtrl.text  = r(['facebook', 'facebook_url']);
    _twitterCtrl.text   = r(['twitter', 'twitter_url']);
    _instagramCtrl.text = r(['instagram', 'instagram_url']);
    _whatsappCtrl.text  = r(['whatsapp', 'whatsapp_number']);
    _playStoreCtrl.text = r(['play_store_url', 'playStoreUrl', 'android_url']);
    _appStoreCtrl.text  = r(['app_store_url', 'appStoreUrl', 'ios_url']);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AdminDataService>().fetchAppConfig();
      if (!mounted) return;
      _populate(data);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = _extractError(e); _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AdminDataService>().updateAppConfig({
        'app_name': _appNameCtrl.text.trim(),
        'logo_url': _logoUrlCtrl.text.trim(),
        'primary_color': _primaryColorCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'facebook': _facebookCtrl.text.trim(),
        'twitter': _twitterCtrl.text.trim(),
        'instagram': _instagramCtrl.text.trim(),
        'whatsapp': _whatsappCtrl.text.trim(),
        'play_store_url': _playStoreCtrl.text.trim(),
        'app_store_url': _appStoreCtrl.text.trim(),
      });
      if (mounted) _showOk(context, 'تم حفظ إعدادات التطبيق');
    } catch (e) {
      if (mounted) _showErr(context, _extractError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl, {TextInputType? type, String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF082949))),
      const SizedBox(height: 12),
      ...children,
      const SizedBox(height: 8),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('إعدادات التطبيق',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('تخصيص هوية التطبيق وبيانات التواصل والروابط الاجتماعية.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))))
        else
          Expanded(
            child: Card(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section('الهوية والعلامة التجارية', [
                      _field('اسم التطبيق', _appNameCtrl),
                      _field('رابط الشعار (URL)', _logoUrlCtrl, hint: 'https://...'),
                      _field('اللون الأساسي', _primaryColorCtrl, hint: '#082949'),
                    ]),
                    _section('معلومات التواصل', [
                      _field('رقم الهاتف', _phoneCtrl, type: TextInputType.phone),
                      _field('البريد الإلكتروني', _emailCtrl, type: TextInputType.emailAddress),
                      _field('العنوان', _addressCtrl),
                    ]),
                    _section('روابط التواصل الاجتماعي', [
                      _field('فيسبوك', _facebookCtrl, hint: 'https://facebook.com/...'),
                      _field('تويتر / X', _twitterCtrl, hint: 'https://twitter.com/...'),
                      _field('انستغرام', _instagramCtrl, hint: 'https://instagram.com/...'),
                      _field('واتساب', _whatsappCtrl, hint: '+967xxxxxxxxx'),
                    ]),
                    _section('روابط المتاجر', [
                      _field('Google Play Store', _playStoreCtrl, hint: 'https://play.google.com/...'),
                      _field('Apple App Store', _appStoreCtrl, hint: 'https://apps.apple.com/...'),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('حفظ التغييرات', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── helpers ─────────────────────────────────────────────────────────────────
String _extractError(dynamic err) {
  if (err is DioException) {
    final d = err.response?.data;
    if (d is Map) {
      final msg = d['message'] ?? d['error'] ?? d['msg'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
  }
  return err.toString();
}

void _showErr(BuildContext ctx, String msg) => ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));

void _showOk(BuildContext ctx, String msg) => ScaffoldMessenger.of(ctx).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: const Color(0xFF17B26A), behavior: SnackBarBehavior.floating));
