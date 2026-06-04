import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../src/core/services/auth_service.dart';
import '../src/core/state/admin_session_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _statusMessage;
  String? _errorMessage;
  String _sentPhone = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    try {
      final sessionController = context.read<AdminSessionController>();
      if (sessionController.isAuthenticated && mounted) {
        context.go('/dashboard');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'تعذر التحقق من حالة الدخول: $error';
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _cleanPhone(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').trim();
  }

  bool _isValidPhone(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length >= 9;
  }

  void _showSnackBar(String message, {Color color = const Color(0xFFB42318)}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
      ),
    );
  }

  Widget _buildBrandLogo(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 92,
          height: 92,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FB),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0x1A0B3A66)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/logo.png.jpg',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B3A66),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text(
                      'AP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Aqari Plus Admin',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF102A43),
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'لوحة الإدارة والأمان والتحكم',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF52606D),
              ),
        ),
      ],
    );
  }

  Future<void> _sendOtp() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final phone = _cleanPhone(_phoneController.text);
    final authService = context.read<AuthService>();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await authService.sendOtp(phone);
      if (!mounted) {
        return;
      }

      setState(() {
        _otpSent = true;
        _sentPhone = phone;
        _statusMessage = 'تم إرسال رمز التحقق إلى رقم الجوال.';
        _otpController.clear();
      });

      _showSnackBar(
        'تم إرسال رمز التحقق بنجاح',
        color: const Color(0xFF067647),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
      _showSnackBar(_errorMessage ?? 'تعذر إرسال رمز التحقق');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (!_otpSent) {
      _showSnackBar('أرسل رمز التحقق أولاً');
      return;
    }

    final phone = _cleanPhone(_phoneController.text);
    final otp = _otpController.text.trim();
    final authService = context.read<AuthService>();
    final sessionController = context.read<AdminSessionController>();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await authService.verifyOtp(phone, otp);
      final role = result.userData['role']?.toString();
      const allowedRoles = <String>{'admin', 'super_admin', 'supervisor'};

      if (role == null || !allowedRoles.contains(role)) {
        throw Exception('هذا الحساب لا يمتلك صلاحيات الإدارة.');
      }

      await sessionController.setSession(
        token: result.token,
        adminData: result.userData,
      );

      if (!mounted) {
        return;
      }

      context.go('/dashboard');
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = message;
      });
      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildBrandLogo(context),
          const SizedBox(height: 28),
          Text(
            'تسجيل الدخول',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أدخل رقم الجوال ثم رمز التحقق للوصول إلى لوحة الإدارة.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF52606D),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: (value) {
              final cleaned = _cleanPhone(value);
              if (_otpSent && cleaned != _sentPhone) {
                setState(() {
                  _otpSent = false;
                  _sentPhone = '';
                  _statusMessage = null;
                  _otpController.clear();
                });
              }
            },
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              hintText: '05xxxxxxxx',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_android_rounded),
            ),
            validator: (value) {
              final text = _cleanPhone(value ?? '');
              if (text.isEmpty) {
                return 'يرجى إدخال رقم الجوال';
              }
              if (!_isValidPhone(text)) {
                return 'أدخل رقم جوال صحيح';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            child: _isLoading && !_otpSent
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('إرسال رمز التحقق'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            enabled: _otpSent,
            decoration: InputDecoration(
              labelText: 'رمز التحقق',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.pin_rounded),
              helperText: _otpSent ? null : 'أرسل رمز التحقق أولاً',
            ),
            validator: (value) {
              if (!_otpSent) {
                return null;
              }
              if ((value ?? '').trim().isEmpty) {
                return 'يرجى إدخال رمز التحقق';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _isLoading ? null : _login,
            child: _isLoading && _otpSent
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('تسجيل الدخول'),
          ),
          if (_statusMessage != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAFBF2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF067647),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFB02A37),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0x1A0B3A66)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildForm(context),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Login render error: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }
}
