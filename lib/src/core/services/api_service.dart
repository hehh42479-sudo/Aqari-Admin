import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiConfig {
  const ApiConfig({
    this.baseUrl = 'https://aqari-backend.onrender.com/api',
  });

  final String baseUrl;
}

class ApiResponseNormalizer {
  const ApiResponseNormalizer._();

  static const List<String> _preferredListKeys = <String>[
    'data',
    'items',
    'results',
    'result',
    'rows',
    'records',
    'properties',
    'users',
    'subscriptions',
    'notifications',
    'payments',
    'complaints',
    'messages',
    'supervisors',
    'logs',
    'activityLogs',
  ];

  static const List<String> _preferredMapKeys = <String>[
    'data',
    'result',
    'results',
    'item',
    'payload',
    'record',
  ];

  static Map<String, dynamic> asMap(dynamic data) {
    final normalized = unwrap(data);

    if (normalized is Map<String, dynamic>) {
      return normalized;
    }

    if (normalized is Map) {
      return normalized.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    return <String, dynamic>{};
  }

  static List<dynamic> asList(dynamic data) {
    final normalized = unwrap(data);

    if (normalized is List<dynamic>) {
      return normalized;
    }

    if (normalized is Map<String, dynamic>) {
      return _findFirstList(normalized) ?? <dynamic>[];
    }

    if (normalized is Map) {
      return _findFirstList(
            normalized.map((key, value) => MapEntry(key.toString(), value)),
          ) ??
          <dynamic>[];
    }

    return <dynamic>[];
  }

  static dynamic unwrap(dynamic data, {int depth = 0}) {
    if (depth > 8) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      for (final key in _preferredMapKeys) {
        final nested = data[key];
        if (nested == null) {
          continue;
        }

        if (nested is Map || nested is List) {
          return unwrap(nested, depth: depth + 1);
        }
      }

      if (data.length == 1) {
        final nested = data.values.first;
        if (nested is Map || nested is List) {
          return unwrap(nested, depth: depth + 1);
        }
      }

      return data;
    }

    if (data is Map) {
      return unwrap(
        data.map((key, value) => MapEntry(key.toString(), value)),
        depth: depth,
      );
    }

    return data;
  }

  static List<dynamic>? _findFirstList(dynamic value, {int depth = 0}) {
    if (depth > 8) {
      return null;
    }

    if (value is List<dynamic>) {
      return value;
    }

    if (value is Map<String, dynamic>) {
      for (final key in _preferredListKeys) {
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

class ApiService {
  ApiService({ApiConfig config = const ApiConfig()})
    : _dio = Dio(
        BaseOptions(
          baseUrl: config.baseUrl,
          connectTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 25),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            clearAuthToken();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  String? _token;

  void setAuthToken(String? token) {
    _token = token;
  }

  void clearAuthToken() {
    _token = null;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<http.MultipartFile> createMultipartFile(
    String fieldName,
    String filePath,
  ) async {
    final extension = filePath.split('.').last.toLowerCase();
    final mimeType = extension == 'png'
        ? 'image/png'
        : extension == 'jpg' || extension == 'jpeg'
            ? 'image/jpeg'
            : 'application/octet-stream';
    final mediaType = MediaType(
      mimeType.split('/').first,
      mimeType.split('/').last,
    );

    return await http.MultipartFile.fromPath(
      fieldName,
      filePath,
      contentType: mediaType,
    );
  }
}
