// lib/app/modules/face_attendance/repositories/mock_local_punch_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

class LocalPunchRecord {
  final String id;
  final DateTime timestamp;
  final String checkType; // 'I' or 'O'
  final String location;
  final String shiftDetails;
  final String punchMethod; // 'Face', 'Bluetooth', or 'Unknown'
  final String deviceId;
  final String address;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String status;
  final String? requestId;
  final String? employeeName;

  LocalPunchRecord({
    required this.id,
    required this.timestamp,
    required this.checkType,
    required this.location,
    required this.shiftDetails,
    this.punchMethod = 'Unknown',
    this.deviceId = 'Unknown',
    this.address = '',
    this.latitude,
    this.longitude,
    this.accuracy,
    this.status = 'Success',
    this.requestId,
    this.employeeName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'checkType': checkType,
      'location': location,
      'shiftDetails': shiftDetails,
      'punchMethod': punchMethod,
      'deviceId': deviceId,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'status': status,
      'requestId': requestId,
      'employeeName': employeeName,
    };
  }

  factory LocalPunchRecord.fromJson(Map<String, dynamic> json) {
    return LocalPunchRecord(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String) 
          : DateTime.now(),
      checkType: json['checkType'] as String? ?? 'I',
      location: json['location'] as String? ?? '',
      shiftDetails: json['shiftDetails'] as String? ?? '',
      punchMethod: json['punchMethod'] as String? ?? 'Unknown',
      deviceId: json['deviceId'] as String? ?? 'Unknown',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
      status: json['status'] as String? ?? 'Success',
      requestId: json['requestId'] as String?,
      employeeName: json['employeeName'] as String?,
    );
  }
}

class MockLocalPunchRepository {
  static const String _storageKey = 'local_punch_history';
  static const int _maxRecords = 50;
  final GetStorage _storage = GetStorage();

  // In-memory cache (static so all instances share the same state)
  static List<LocalPunchRecord> _punches = [];
  static bool _isLoaded = false;

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    try {
      final String? data = _storage.read<String>(_storageKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(data);
        _punches = decoded
            .map((e) => LocalPunchRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[MockLocalPunchRepository] Error loading history: $e');
      // On error, start fresh to prevent crashes
      _punches = [];
    }
    _isLoaded = true;
  }

  /// Forces the repository to reload data from disk. Useful for syncing data written by background isolates.
  Future<void> reload() async {
    _isLoaded = false;
    await _ensureLoaded();
  }

  Future<void> savePunch(LocalPunchRecord record) async {
    await _ensureLoaded();

    // Prevent duplicates by requestId if it exists
    if (record.requestId != null && _punches.any((p) => p.requestId == record.requestId)) {
      debugPrint('[MockLocalPunchRepository] Duplicate record ignored.');
      return;
    }

    _punches.insert(0, record); // Latest first

    // Enforce max limit
    if (_punches.length > _maxRecords) {
      _punches = _punches.sublist(0, _maxRecords);
    }

    // Persist to GetStorage
    try {
      final String encoded = jsonEncode(_punches.map((e) => e.toJson()).toList());
      await _storage.write(_storageKey, encoded);
      debugPrint('[MockLocalPunchRepository] Saved punch: ${record.checkType} at ${record.timestamp}');
    } catch (e) {
      debugPrint('[MockLocalPunchRepository] Error saving history: $e');
    }
  }

  Future<List<LocalPunchRecord>> getPunches() async {
    await _ensureLoaded();
    return List.unmodifiable(_punches);
  }
}
