import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OtpVerificationResult {
  OtpVerificationResult({
    required this.token,
    required this.userData,
    required this.rawResponse,
  });

  final String token;
  final Map<String, dynamic> userData;
  final Map<String, dynamic> rawResponse;
}

class AuthService {
  AuthService({
    String? baseUrl,
  }) : _baseUrl = baseUrl ?? 'https://aqari-backend.onrender.com/api';

  final String _baseUrl;

  // Render.com free-tier services spin down after inactivity and can take up
  // to 30 seconds to cold-start. We use a 45-second timeout + 1 auto-retry to
  // survive cold-start delays without showing a timeout error to the user.
  static const _timeout = Duration(seconds: 45);
  static const _maxRetries = 1;

  Future<void> sendOtp(String phone) async {
    final uri = Uri.parse('$_baseUrl/auth/send-otp');
    final payload = <String, String>{'phone': phone.trim()};

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              uri,
              headers: const <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(_timeout);

        if (response.statusCode == 200 || response.statusCode == 201) {
          return;
        }

        debugPrint('Send OTP failed: ${response.statusCode} ${response.body}');
        throw Exception(
          _extractErrorMessage(
            response.body,
            fallback: 'تعذر إرسال رمز التحقق. حاول مرة أخرى.',
          ),
        );
      } on TimeoutException {
        debugPrint('Send OTP timeout (attempt ${attempt + 1})');
        if (attempt < _maxRetries) {
          // Silent retry — server may be waking up
          await Future<void>.delayed(const Duration(seconds: 3));
          continue;
        }
        throw Exception(
          'الخادم يستغرق وقتاً للاستجابة (cold start). يرجى المحاولة مرة أخرى بعد لحظات.',
        );
      } on http.ClientException catch (e) {
        debugPrint('Send OTP client error: $e');
        if (attempt < _maxRetries) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        throw Exception('تعذر الاتصال بالخادم. تحقق من عنوان الـ API والاتصال.');
      }
    }
  }

  Future<OtpVerificationResult> verifyOtp(String phone, String otp) async {
    final uri = Uri.parse('$_baseUrl/auth/verify-otp');
    final payload = <String, String>{
      'phone': phone.trim(),
      'otp': otp.trim(),
    };

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              uri,
              headers: const <String, String>{
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(_timeout);

        if (response.statusCode == 200) {
          final decoded = _decodeJson(response.body);
          final token = _extractToken(decoded);

          if (token == null || token.isEmpty) {
            throw Exception('فشل التحقق: لم يتم إرجاع رمز JWT من الخادم.');
          }

          final userData = _extractUserData(decoded);
          return OtpVerificationResult(
            token: token,
            userData: userData,
            rawResponse: decoded,
          );
        }

        if (response.statusCode == 401 ||
            response.statusCode == 404 ||
            response.statusCode == 500) {
          debugPrint('Verify OTP failed: ${response.statusCode} ${response.body}');
          throw Exception(
            _extractErrorMessage(
              response.body,
              fallback: 'بيانات الدخول غير صحيحة أو لا تملك صلاحية الإدارة',
            ),
          );
        }

        debugPrint('Verify OTP failed: ${response.statusCode} ${response.body}');
        throw Exception(
          _extractErrorMessage(
            response.body,
            fallback: 'بيانات الدخول غير صحيحة أو لا تملك صلاحية الإدارة',
          ),
        );
      } on TimeoutException {
        debugPrint('Verify OTP timeout (attempt ${attempt + 1})');
        if (attempt < _maxRetries) {
          await Future<void>.delayed(const Duration(seconds: 3));
          continue;
        }
        throw Exception(
          'الخادم يستغرق وقتاً للاستجابة (cold start). يرجى المحاولة مرة أخرى بعد لحظات.',
        );
      } on http.ClientException catch (e) {
        debugPrint('Verify OTP client error: $e');
        if (attempt < _maxRetries) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        throw Exception('تعذر الاتصال بالخادم. تحقق من عنوان الـ API والاتصال.');
      }
    }

    // Should never reach here
    throw Exception('خطأ غير متوقع في إرسال OTP.');
  }

  Map<String, dynamic> _decodeJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('استجابة غير صالحة من الخادم.');
  }

  String? _extractToken(Map<String, dynamic> json) {
    final directToken =
        json['token'] ?? json['jwtToken'] ?? json['accessToken'];
    if (directToken is String && directToken.isNotEmpty) {
      return directToken;
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final nestedToken =
          data['token'] ?? data['jwtToken'] ?? data['accessToken'];
      if (nestedToken is String && nestedToken.isNotEmpty) {
        return nestedToken;
      }
    }

    return null;
  }

  Map<String, dynamic> _extractUserData(Map<String, dynamic> json) {
    final user = json['user'] ?? json['admin'] ?? json['data'];
    if (user is Map<String, dynamic>) {
      return user;
    }
    return json;
  }

  String _extractErrorMessage(String body, {required String fallback}) {
    if (body.isEmpty) return fallback;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final dynamic candidate = decoded['message'] ??
            decoded['error'] ??
            decoded['details'] ??
            decoded['msg'];
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
    } catch (_) {
      // Body is not JSON — use fallback.
    }

    return fallback;
  }
}
