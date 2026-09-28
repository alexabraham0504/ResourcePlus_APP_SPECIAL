// lib/app/modules/face_attendance/views/face_attendance_view.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/face_attendance_controller.dart';
import '../../home/views/widgets/shift_location_block.dart';

class FaceAttendanceView extends GetView<FaceAttendanceController> {
  const FaceAttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await controller.cameraService.dispose();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Obx(() {
        final state = controller.verificationState.value;
        Widget bodyContent;

        if (state == VerificationState.permissionDenied ||
            state == VerificationState.modelLoadFailed) {
          bodyContent = _buildErrorState();
        } else if (!controller.cameraService.isInitialized ||
            state == VerificationState.idle ||
            state == VerificationState.initializingCamera) {
          bodyContent = _buildLoadingState();
        } else {
          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Camera Feed (Full Screen)
              CameraPreview(controller.cameraService.controller!),
              
              // 2. Animated Scanner Overlay
              _AnimatedScannerOverlay(
                isMatched: state == VerificationState.faceMatched,
                isProcessing: _isProcessingState(state),
              ),
              
              // 3. UI Elements Overlays
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassHeader(),
                    _buildStatusBanner(),
                    const Spacer(),
                    _buildInfoOverlay(),
                    _buildActionArea(),
                  ],
                ),
              ),
            ],
          );
        }

        // For states without camera feed, show the header at the top
        return SafeArea(
          child: Column(
            children: [
              _buildGlassHeader(),
              Expanded(child: bodyContent),
            ],
          ),
        );
      }),
    ));
  }

  bool _isProcessingState(VerificationState state) {
    return state == VerificationState.generatingEmbedding ||
        state == VerificationState.loadingEnrolledTemplate ||
        state == VerificationState.comparingFace ||
        state == VerificationState.punching;
  }

  Widget _buildGlassHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () async {
                    await controller.cameraService.dispose();
                    Get.back();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'face_verification_title'.tr,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Obx(() {
      final state = controller.verificationState.value;
      final isMatched = state == VerificationState.faceMatched;
      final isError = state == VerificationState.faceNotMatched ||
          state == VerificationState.noEnrollment ||
          state == VerificationState.error;
      final isProcessing = _isProcessingState(state);

      Color accentColor = Colors.white;
      if (isMatched) accentColor = const Color(0xFF10B981);
      if (isError) accentColor = const Color(0xFFEF4444);
      if (isProcessing) accentColor = Colors.amber;

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(controller.statusMessage.value),
          margin: const EdgeInsets.only(top: 16, left: 24, right: 24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 2)
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isProcessing) ...[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Text(
                        controller.statusMessage.value,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildInfoOverlay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ShiftLocationBlock(
        colorScheme: Theme.of(Get.context!).colorScheme,
        isDark: true, // Force dark mode for camera overlay
      ),
    );
  }

  Widget _buildActionArea() {
    return Obx(() {
      final isPunchEnabled = controller.isPunchEnabled.value;
      final isProcessing = controller.isProcessing.value;
      final state = controller.verificationState.value;

      final isPunchIn = controller.checkType.value == 'I';
      final punchColor = isPunchIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      final punchText = isPunchIn ? 'punch_in_caps'.tr : 'punch_out_caps'.tr;

      return Padding(
        padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
        child: Column(
          children: [
            if (state == VerificationState.noEnrollment)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      controller.cameraService.dispose();
                      await Get.toNamed('/face-enrollment');
                      controller.restartScanner();
                    },
                    icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                    label: Text('enroll_face'.tr, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
              ),
            
            AnimatedOpacity(
              opacity: isPunchEnabled ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          colors: isPunchEnabled 
                              ? [const Color(0xFF10B981), const Color(0xFF10B981).withValues(alpha: 0.8)]
                              : [Colors.grey.withValues(alpha: 0.5), Colors.grey.withValues(alpha: 0.3)],
                        ),
                        boxShadow: isPunchEnabled ? [
                          BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))
                        ] : [],
                      ),
                      child: ElevatedButton(
                        onPressed: isPunchEnabled && !isProcessing ? () => controller.submitPunch('0') : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: isProcessing && controller.checkType.value == '0'
                            ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : Text('punch_in_caps'.tr, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          colors: isPunchEnabled 
                              ? [const Color(0xFFEF4444), const Color(0xFFEF4444).withValues(alpha: 0.8)]
                              : [Colors.grey.withValues(alpha: 0.5), Colors.grey.withValues(alpha: 0.3)],
                        ),
                        boxShadow: isPunchEnabled ? [
                          BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))
                        ] : [],
                      ),
                      child: ElevatedButton(
                        onPressed: isPunchEnabled && !isProcessing ? () => controller.submitPunch('1') : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: isProcessing && controller.checkType.value == '1'
                            ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : Text('punch_out_caps'.tr, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // --- States (Error, Loading) redesigned with Outfit font ---
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF10B981)),
          const SizedBox(height: 24),
          Obx(() => Text(
                controller.statusMessage.value,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, letterSpacing: 1),
                textAlign: TextAlign.center,
              )),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 64),
            ),
            const SizedBox(height: 24),
            Obx(() => Text(
                  controller.statusMessage.value,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                )),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text('go_back'.tr, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stateful widget to handle the smooth scanning animation
class _AnimatedScannerOverlay extends StatefulWidget {
  final bool isMatched;
  final bool isProcessing;

  const _AnimatedScannerOverlay({required this.isMatched, required this.isProcessing});

  @override
  State<_AnimatedScannerOverlay> createState() => _AnimatedScannerOverlayState();
}

class _AnimatedScannerOverlayState extends State<_AnimatedScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ModernScannerPainter(
            animationValue: _controller.value,
            isMatched: widget.isMatched,
            isProcessing: widget.isProcessing,
          ),
        );
      },
    );
  }
}

class _ModernScannerPainter extends CustomPainter {
  final double animationValue;
  final bool isMatched;
  final bool isProcessing;

  _ModernScannerPainter({
    required this.animationValue,
    required this.isMatched,
    required this.isProcessing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boxW = size.width * 0.70;
    final boxH = boxW * 1.3;
    
    // Position scanner slightly higher than true center for better framing
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: boxW,
      height: boxH,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(40));

    // 1. Draw the dimmed background with frosted cutout
    final cutout = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    
    canvas.drawPath(cutout, Paint()..color = Colors.black.withValues(alpha: 0.65));

    // Determine color based on state
    Color boxColor;
    if (isMatched) {
      boxColor = const Color(0xFF10B981);
    } else if (isProcessing) {
      boxColor = Colors.amber;
    } else {
      boxColor = Colors.white54;
    }

    // 2. Draw the glowing border
    final borderPaint = Paint()
      ..color = boxColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
      
    // Add glow effect using shadow
    final glowPaint = Paint()
      ..color = boxColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 15.0);

    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, borderPaint);

    // 3. Draw corner accents for high-tech feel
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
      
    final double cl = 35.0; // corner length
    
    // Top Left
    canvas.drawPath(Path()..moveTo(rect.left, rect.top + cl)..lineTo(rect.left, rect.top + 20)..quadraticBezierTo(rect.left, rect.top, rect.left + 20, rect.top)..lineTo(rect.left + cl, rect.top), cornerPaint);
    // Top Right
    canvas.drawPath(Path()..moveTo(rect.right - cl, rect.top)..lineTo(rect.right - 20, rect.top)..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + 20)..lineTo(rect.right, rect.top + cl), cornerPaint);
    // Bottom Left
    canvas.drawPath(Path()..moveTo(rect.left, rect.bottom - cl)..lineTo(rect.left, rect.bottom - 20)..quadraticBezierTo(rect.left, rect.bottom, rect.left + 20, rect.bottom)..lineTo(rect.left + cl, rect.bottom), cornerPaint);
    // Bottom Right
    canvas.drawPath(Path()..moveTo(rect.right - cl, rect.bottom)..lineTo(rect.right - 20, rect.bottom)..quadraticBezierTo(rect.right, rect.bottom, rect.right, rect.bottom - 20)..lineTo(rect.right, rect.bottom - cl), cornerPaint);

    // 4. Draw Animated Sweeping Laser Line & Mesh when processing
    if (isProcessing) {
      final scanLineY = rect.top + (rect.height * animationValue);
      
      final laserRect = Rect.fromCenter(
        center: Offset(rect.center.dx, scanLineY),
        width: rect.width - 10,
        height: 4.0,
      );
      
      final laserPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(laserRect.left, laserRect.top),
          Offset(laserRect.right, laserRect.top),
          [
            boxColor.withValues(alpha: 0.0),
            boxColor.withValues(alpha: 0.8),
            boxColor.withValues(alpha: 0.0),
          ],
          [0.0, 0.5, 1.0],
        )
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.0);

      canvas.drawOval(laserRect, laserPaint);
      
      // Draw sweeping gradient glow area above the laser
      final glowRect = Rect.fromLTRB(rect.left, scanLineY - 40, rect.right, scanLineY);
      final sweepGlowPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.center.dx, scanLineY - 40),
          Offset(rect.center.dx, scanLineY),
          [
            boxColor.withValues(alpha: 0.0),
            boxColor.withValues(alpha: 0.15),
          ],
        );
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(glowRect, sweepGlowPaint);
      canvas.restore();

      // --- Facial Mesh ---
      final meshPaint = Paint()
        ..color = boxColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
        
      final cx = rect.center.dx;
      final cy = rect.center.dy - (rect.height * 0.05);
      final w = rect.width * 0.70;
      final h = rect.height * 0.70;
      
      final List<Offset> points = [
        Offset(cx - w*0.4, cy - h*0.3), // Left eye
        Offset(cx + w*0.4, cy - h*0.3), // Right eye
        Offset(cx, cy - h*0.05),        // Nose bridge
        Offset(cx - w*0.45, cy + h*0.1),// Left cheek
        Offset(cx + w*0.45, cy + h*0.1),// Right cheek
        Offset(cx, cy + h*0.3),         // Nose tip
        Offset(cx - w*0.25, cy + h*0.55), // Left mouth
        Offset(cx + w*0.25, cy + h*0.55), // Right mouth
        Offset(cx, cy + h*0.8),         // Chin
        Offset(cx - w*0.6, cy - h*0.1), // Far left cheek
        Offset(cx + w*0.6, cy - h*0.1), // Far right cheek
      ];

      final nodePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      for (final p in points) {
        canvas.drawCircle(p, 2.5, nodePaint);
      }

      final List<List<int>> edges = [
        [0, 2], [1, 2], [0, 3], [1, 4], [3, 5], [4, 5], [2, 5],
        [3, 6], [4, 7], [5, 6], [5, 7], [6, 8], [7, 8],
        [0, 9], [3, 9], [6, 9], [1, 10], [4, 10], [7, 10]
      ];

      for (final edge in edges) {
        canvas.drawLine(points[edge[0]], points[edge[1]], meshPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ModernScannerPainter old) => 
      old.animationValue != animationValue || 
      old.isMatched != isMatched || 
      old.isProcessing != isProcessing;
}
