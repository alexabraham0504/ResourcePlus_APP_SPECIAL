import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized API service with Dio configuration
/// Handles SSL certificate issues for development/testing
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Dio? _dio;
  bool _initialized = false;

  Dio get dio {
    if (!_initialized) {
      initialize();
    }
    return _dio!;
  }

  void initialize() {
    if (_initialized) return;

    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Configure SSL certificate handling
    // This allows expired certificates for development/testing
    // WARNING: This should be removed or made conditional for production
    if (!kIsWeb) {
      (_dio!.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
              // Allow expired certificates for development
              // In production, you should validate certificates properly
              return true;
            };
        return client;
      };
    }

    _initialized = true;
  }
}
