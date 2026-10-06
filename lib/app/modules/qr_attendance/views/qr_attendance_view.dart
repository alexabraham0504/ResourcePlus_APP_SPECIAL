import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../controllers/qr_attendance_controller.dart';
import '../../home/views/widgets/shift_location_block.dart';

class QRAttendanceView extends GetView<QRAttendanceController> {
  const QRAttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera View
          MobileScanner(
            controller: controller.scannerController,
            onDetect: controller.onDetect,
          ),

          // 2. Custom Overlay with Cutout
          _buildOverlay(context),

          // 3. Top AppBar (Custom)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
                Text(
                  'qr_attendance'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.flash_on, color: Colors.white),
                  onPressed: () => controller.scannerController.toggleTorch(),
                ),
              ],
            ),
          ),

          // 4. Status Card (Glassmorphism)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShiftLocationBlock(
                  colorScheme: Theme.of(context).colorScheme,
                  isDark: true, // Force dark text visibility over camera
                ),
                const SizedBox(height: 16),
                Obx(() {
              final isSuccess = controller.statusMessage.value == 'punch_success'.tr;
              return Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    decoration: BoxDecoration(
                      color: isSuccess 
                          ? const Color(0xFF10B981).withValues(alpha: 0.2) 
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSuccess 
                            ? const Color(0xFF10B981).withValues(alpha: 0.5) 
                            : Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSuccess ? Icons.check_circle_outline : Icons.qr_code_scanner,
                          color: isSuccess ? const Color(0xFF10B981) : Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          controller.statusMessage.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanAreaSize = constraints.maxWidth * 0.7;
        return Stack(
          children: [
            // Darkened background outside the scan area
            Positioned.fill(
              child: CustomPaint(
                painter: _OverlayPainter(scanAreaSize),
              ),
            ),
            // Scanner borders (corners)
            Center(
              child: CustomPaint(
                size: Size(scanAreaSize, scanAreaSize),
                painter: _ScannerBorderPainter(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScannerBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D96F2) // Premium blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final length = size.width * 0.2; // length of the corner lines
    final w = size.width;
    final h = size.height;

    // Top Left
    canvas.drawLine(const Offset(0, 0), Offset(length, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, length), paint);

    // Top Right
    canvas.drawLine(Offset(w, 0), Offset(w - length, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, length), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, h), Offset(length, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - length), paint);

    // Bottom Right
    canvas.drawLine(Offset(w, h), Offset(w - length, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - length), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OverlayPainter extends CustomPainter {
  final double scanAreaSize;

  _OverlayPainter(this.scanAreaSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: scanAreaSize,
          height: scanAreaSize,
        ),
        const Radius.circular(20),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) {
    return oldDelegate.scanAreaSize != scanAreaSize;
  }
}
