import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/admin_data_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _termsController = TextEditingController();
  final TextEditingController _privacyController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  void dispose() {
    _termsController.dispose();
    _privacyController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      final data = await service.fetchAppSettings();
      if (!mounted) {
        return;
      }

      setState(() {
        _termsController.text = _resolveText(data, <String>[
          'termsAndConditions',
          'terms',
          'termsConditions',
          'terms_and_conditions',
        ]);
        _privacyController.text = _resolveText(data, <String>[
          'privacyPolicy',
          'privacy',
          'privacy_policy',
        ]);
        _phoneController.text = _resolveText(data, <String>[
          'contactPhone',
          'phone',
          'contact_phone',
        ]);
        _emailController.text = _resolveText(data, <String>[
          'contactEmail',
          'email',
          'contact_email',
        ]);
        _isLoading = false;
      });
    } on DioException catch (error) {
      debugPrint(
        'Settings load failed: ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Settings load failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل إعدادات التطبيق حالياً. حاول تحديث الصفحة.';
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AdminDataService>();
      await service.saveAppSettings(
        termsAndConditions: _termsController.text.trim(),
        privacyPolicy: _privacyController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        contactEmail: _emailController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التعديلات بنجاح'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF17B26A),
        ),
      );
    } on DioException catch (error) {
      debugPrint(
        'Settings save failed: ${error.response?.statusCode} ${error.response?.data}',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _extractErrorMessage(error);
      });
    } catch (error) {
      debugPrint('Settings save failed: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'تعذر حفظ التعديلات حالياً. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _resolveText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
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

    final nested = data['data'];
    if (nested is Map<String, dynamic>) {
      for (final key in keys) {
        final value = nested[key];
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

    return '';
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final candidate =
          data['message'] ?? data['error'] ?? data['details'] ?? data['msg'];
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    switch (error.response?.statusCode) {
      case 401:
        return 'انتهت صلاحية الدخول. يرجى تسجيل الدخول مرة أخرى.';
      case 404:
        return 'تعذر العثور على إعدادات التطبيق.';
      default:
        return 'تعذر تحميل إعدادات التطبيق حالياً.';
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required int minLines,
    required int maxLines,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '⚙️ إعدادات التطبيق',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'تحديث بيانات التواصل وشروط الاستخدام وسياسة الخصوصية.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (_isLoading) ...<Widget>[
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 18),
                      ],
                      if (_errorMessage != null) ...<Widget>[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB02A37),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _buildField(
                        label: 'شروط الاستخدام',
                        controller: _termsController,
                        minLines: 6,
                        maxLines: 10,
                        hintText: 'اكتب شروط الاستخدام هنا',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'شروط الاستخدام مطلوبة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        label: 'سياسة الخصوصية',
                        controller: _privacyController,
                        minLines: 6,
                        maxLines: 10,
                        hintText: 'اكتب سياسة الخصوصية هنا',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'سياسة الخصوصية مطلوبة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        label: 'رقم التواصل',
                        controller: _phoneController,
                        minLines: 1,
                        maxLines: 1,
                        hintText: '05xxxxxxxx',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'رقم التواصل مطلوب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        label: 'البريد الإلكتروني',
                        controller: _emailController,
                        minLines: 1,
                        maxLines: 1,
                        hintText: 'admin@example.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'البريد الإلكتروني مطلوب';
                          }
                          if (!text.contains('@')) {
                            return 'أدخل بريد إلكتروني صحيح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('حفظ التعديلات'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
