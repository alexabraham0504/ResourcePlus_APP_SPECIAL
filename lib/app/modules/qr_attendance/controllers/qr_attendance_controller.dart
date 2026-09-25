import 'dart:async';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:resource_plus/app/modules/face_attendance/services/attendance_security_service.dart';
import 'package:resource_plus/app/modules/face_attendance/repositories/mock_local_punch_repository.dart';

class QRAttendanceController extends GetxController {
  final MobileScannerController scannerController = MobileScannerController();
  final AttendanceSecurityService _securityService = AttendanceSecurityService();
  final MockLocalPunchRepository _punchRepo = MockLocalPunchRepository();

  RxBool isScanning = true.obs;
  RxString statusMessage = 'Align the QR code within the frame'.obs;
  RxString foundQrData = ''.obs;

  @override
  void onClose() {
    scannerController.dispose();
    super.onClose();
  }

  void onDetect(BarcodeCapture capture) async {
    if (!isScanning.value) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        isScanning.value = false; // Stop scanning immediately
        foundQrData.value = barcode.rawValue!;
        statusMessage.value = 'QR Code Detected: Processing...';

        // Add a slight delay for UI feedback
        await Future.delayed(const Duration(milliseconds: 800));
        await _processQRPunch(foundQrData.value);
      }
    }
  }

  Future<void> _processQRPunch(String qrData) async {
    try {
      final deviceMetadata = await _securityService.buildDeviceMetadata();
      final locationMetadata = await _securityService.buildLocationMetadata();

      // Basic local check for mock location as planned
      if (locationMetadata.contains('MockLocation:true')) {
        statusMessage.value = 'Punch Rejected: Mock GPS Detected!';
        return;
      }

      final record = LocalPunchRecord(
        id: _securityService.generateRequestId(),
        requestId: _securityService.generateRequestId(),
        deviceId: deviceMetadata.split('|').first, 
        timestamp: DateTime.now(),
        checkType: 'I', // Or determine dynamically if possible
        punchMethod: 'QR', 
        latitude: double.tryParse(locationMetadata.split('|')[0]),
        longitude: double.tryParse(locationMetadata.split('|')[1]),
        location: qrData, // Use QR data as the location ID for demo
        address: locationMetadata.split('|')[2].replaceAll(' Address : ', ''),
        status: 'Success',
        shiftDetails: '09:00 AM - 06:00 PM',
      );

      await _punchRepo.savePunch(record);
      
      statusMessage.value = 'Punch Successful!';
      
      // Give the user time to read the success message before going back
      await Future.delayed(const Duration(seconds: 2));
      Get.back(result: true); // Return to home

    } catch (e) {
      statusMessage.value = 'Error: Failed to process punch.';
      isScanning.value = true; // allow retry
    }
  }
}
