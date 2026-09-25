// lib/app/modules/face_attendance/repositories/face_template_repository.dart
//
// PRODUCTION MODE: ApiFaceTemplateRepository calls the real RplusWebAPIV2 endpoints:
//   - Enroll → POST /api/FaceEnroll?instanceName=... { usrEmail, embedding, modelVersion, templateVersion }
//   - Punch  → GET  /api/FaceTemplate?usrEmail=...&instanceName=...
//
// DEMO/FALLBACK: MockFaceTemplateRepository uses GetStorage (device local storage)
//   - Enroll once → template saved on phone → punch works every time

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import '../../../config/api_endpoints.dart';
import '../models/face_enrollment_template_request.dart';
import '../models/face_template_response.dart';

/// Clean repository abstraction for saving and loading face templates.
abstract class FaceTemplateRepository {
  /// Save the enrollment template (called during enrollment).
  Future<bool> saveTemplate(FaceEnrollmentTemplateRequest request);

  /// Retrieve the enrolled template for the authenticated user (called during punch).
  Future<FaceTemplateResponse?> getTemplate();

  /// Check if the user has an enrolled face template.
  Future<bool> hasTemplate();

  /// Delete the enrolled template (for re-enrollment or logout).
  Future<void> clearTemplate();
}

// ──────────────────────────────────────────────────────────────────────────────
// PRODUCTION IMPLEMENTATION — RplusWebAPIV2 real API
// Enroll → POST /api/FaceEnroll?instanceName=...
// Fetch  → GET  /api/FaceTemplate?usrEmail=...&instanceName=...
// ──────────────────────────────────────────────────────────────────────────────
class ApiFaceTemplateRepository implements FaceTemplateRepository {
  final GetStorage _storage = GetStorage();

  /// Build an IOClient that accepts self-signed certificates (same as hr_portal_controller)
  http.Client _buildClient() {
    final ioClient = HttpClient()..badCertificateCallback = (_, __, ___) => true;
    return io_client.IOClient(ioClient);
  }

  String get _instanceName => _storage.read('instanceName') ?? '';
  String get _usrEmail =>
      (_storage.read('username') ?? _storage.read('userEmail') ?? '').toString();

  @override
  Future<bool> saveTemplate(FaceEnrollmentTemplateRequest request) async {
    final client = _buildClient();
    try {
      final uri = Uri.parse(ApiEndpoints.faceEnroll)
          .replace(queryParameters: {'instanceName': _instanceName});

      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usrEmail': _usrEmail,
          'embedding': jsonDecode(request.template), // List<double>
          'modelVersion': request.modelVersion,
          'templateVersion': request.templateVersion,
        }),
      );

      debugPrint('[FaceTemplate] POST ${uri.toString()} → ${response.statusCode}');
      debugPrint('[FaceTemplate] Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Server returns plain `true` or `"true"` (spec says: Example response: true)
        final body = response.body.replaceAll('"', '').trim().toLowerCase();
        final success = body == 'true' || body.contains('success');
        if (success) {
          // Cache locally so we can punch even when offline
          await _storage.write('api_face_template_embedding_v2', request.template);
          await _storage.write('api_face_template_model_version_v2', request.modelVersion);
          await _storage.write('api_face_template_version_v2', request.templateVersion);
          debugPrint('[FaceTemplate] ✅ Template enrolled and cached locally');
          return true;
        }
      }
      debugPrint('[FaceTemplate] ❌ Enroll failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[FaceTemplate] ❌ Network error during enroll: $e');
      return false;
    } finally {
      client.close();
    }
  }

  @override
  Future<FaceTemplateResponse?> getTemplate() async {
    // 1. Try to fetch from server
    final client = _buildClient();
    try {
      final uri = Uri.parse(ApiEndpoints.faceGetTemplate).replace(
        queryParameters: {
          'usrEmail': _usrEmail,
          'instanceName': _instanceName,
        },
      );

      final response = await client.get(uri);
      debugPrint('[FaceTemplate] GET ${uri.toString()} → ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        // API returns: { "embedding": [...], "modelVersion": "facenet-v2" }
        final embedding = json['embedding'];
        final modelVersion = (json['modelVersion'] ?? 'facenet-v2').toString();

        if (embedding != null && embedding is List && embedding.isNotEmpty) {
          final templateJson = jsonEncode(embedding);
          // Cache fresh template locally
          await _storage.write('api_face_template_embedding_v2', templateJson);
          await _storage.write('api_face_template_model_version_v2', modelVersion);
          await _storage.write('api_face_template_version_v2', 1);
          debugPrint('[FaceTemplate] ✅ Template fetched from server (${embedding.length} dims)');
          return FaceTemplateResponse(
            template: templateJson,
            modelVersion: modelVersion,
            templateVersion: 1,
          );
        }
      }
    } catch (e) {
      debugPrint('[FaceTemplate] ⚠️ Server fetch failed, falling back to local cache: $e');
    } finally {
      client.close();
    }

    // 2. Fall back to local cache (allows punch when offline)
    final templateJson = _storage.read<String>('api_face_template_embedding_v2');
    final modelVersion = _storage.read<String>('api_face_template_model_version_v2');
    final templateVersion = _storage.read<int>('api_face_template_version_v2');

    if (templateJson != null && modelVersion != null) {
      debugPrint('[FaceTemplate] ✅ Template loaded from local cache (offline fallback)');
      return FaceTemplateResponse(
        template: templateJson,
        modelVersion: modelVersion,
        templateVersion: templateVersion ?? 1,
      );
    }

    debugPrint('[FaceTemplate] ❌ No template found on server or local cache');
    return null;
  }

  @override
  Future<bool> hasTemplate() async {
    // Check server AND local cache by calling getTemplate
    final template = await getTemplate();
    return template != null;
  }

  @override
  Future<void> clearTemplate() async {
    await _storage.remove('api_face_template_embedding_v2');
    await _storage.remove('api_face_template_model_version_v2');
    await _storage.remove('api_face_template_version_v2');
    debugPrint('[FaceTemplate] Template cleared from local cache');
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// DEMO/OFFLINE FALLBACK — Persistent local storage via GetStorage
// Template survives app restarts. ONE employee per device.
// ──────────────────────────────────────────────────────────────────────────────
class MockFaceTemplateRepository implements FaceTemplateRepository {
  static const String _kTemplateKey        = 'api_face_template_embedding_v2';
  static const String _kModelVersionKey    = 'face_template_model_version';
  static const String _kTemplateVersionKey = 'face_template_version';

  final GetStorage _storage = GetStorage();

  @override
  Future<bool> saveTemplate(FaceEnrollmentTemplateRequest request) async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      await _storage.write(_kTemplateKey,        request.template);
      await _storage.write(_kModelVersionKey,    request.modelVersion);
      await _storage.write(_kTemplateVersionKey, request.templateVersion);
      debugPrint('[FaceTemplate] ✅ Template saved to local storage (DEMO mode)');
      return true;
    } catch (e) {
      debugPrint('[FaceTemplate] ❌ Failed to save template: $e');
      return false;
    }
  }

  @override
  Future<FaceTemplateResponse?> getTemplate() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final String? templateJson    = _storage.read<String>(_kTemplateKey);
      final String? modelVersion    = _storage.read<String>(_kModelVersionKey);
      final int?    templateVersion = _storage.read<int>(_kTemplateVersionKey);

      if (templateJson == null || modelVersion == null || templateVersion == null) {
        debugPrint('[FaceTemplate] No enrolled template found in local storage');
        return null;
      }
      final List<dynamic> decoded = jsonDecode(templateJson);
      if (decoded.isEmpty) {
        await clearTemplate();
        return null;
      }
      debugPrint('[FaceTemplate] ✅ Template loaded from local storage (${decoded.length} dims)');
      return FaceTemplateResponse(
        template:        templateJson,
        modelVersion:    modelVersion,
        templateVersion: templateVersion,
      );
    } catch (e) {
      debugPrint('[FaceTemplate] ❌ Failed to load template: $e');
      return null;
    }
  }

  @override
  Future<bool> hasTemplate() async {
    final String? templateJson = _storage.read<String>(_kTemplateKey);
    return templateJson != null && templateJson.isNotEmpty;
  }

  @override
  Future<void> clearTemplate() async {
    await _storage.remove(_kTemplateKey);
    await _storage.remove(_kModelVersionKey);
    await _storage.remove(_kTemplateVersionKey);
    debugPrint('[FaceTemplate] Template cleared from local storage');
  }

  static Future<void> clearMockStorageForTests() async {
    final s = GetStorage();
    await s.remove(_kTemplateKey);
    await s.remove(_kModelVersionKey);
    await s.remove(_kTemplateVersionKey);
  }
}
