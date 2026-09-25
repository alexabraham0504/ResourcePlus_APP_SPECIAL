// lib/app/modules/face_attendance/views/face_enrollment_view.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/face_enrollment_controller.dart';

class FaceEnrollmentView extends GetView<FaceEnrollmentController> {
  const FaceEnrollmentView({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await controller.cameraService.dispose();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, // Key for full-screen camera
      body: Obx(() {
        final state = controller.enrollmentState.value;
        Widget bodyContent;

        if (state == EnrollmentState.permissionDenied ||
            state == EnrollmentState.modelLoadFailed) {
          bodyContent = _buildErrorState();
        } else if (state == EnrollmentState.alreadyEnrolled) {
          bodyContent = _buildAlreadyEnrolledState();
        } else if (state == EnrollmentState.success) {
          bodyContent = _buildSuccessState();
        } else if (!controller.cameraService.isInitialized ||
            state == EnrollmentState.idle ||
            state == EnrollmentState.initializingCamera) {
          bodyContent = _buildLoadingState();
        } else {
          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Camera Feed (Full Screen)
              CameraPreview(controller.cameraService.controller!),
              
              // 2. Animated Scanner Overlay
              const _AnimatedScannerOverlay(),
              
              // 3. UI Elements Overlays
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassHeader(),
                    _buildStatusBanner(state),
                    const Spacer(),
                    _buildProgressArea(state),
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
                    'Face Enrollment',
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

  Widget _buildStatusBanner(EnrollmentState state) {
    final isProcessing = state == EnrollmentState.generatingEmbedding ||
        state == EnrollmentState.processingTemplate ||
        state == EnrollmentState.submitting;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(controller.statusMessage.value),
        margin: const EdgeInsets.only(top: 16, left: 24, right: 24),
        decoration: BoxDecoration(
          color: isProcessing 
              ? const Color(0xFF10B981).withValues(alpha: 0.2) 
              : Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isProcessing 
                ? const Color(0xFF10B981).withValues(alpha: 0.5) 
                : Colors.white.withValues(alpha: 0.2), 
            width: 1.5
          ),
          boxShadow: isProcessing ? [
             BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.2), blurRadius: 15, spreadRadius: 2)
          ] : [],
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
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF10B981),
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
  }

  Widget _buildProgressArea(EnrollmentState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Obx(() {
            final count = controller.capturedSamplesCount.value;
            final max = controller.maxSamples;
            final progress = max > 0 ? (count / max) : 0.0;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enrollment Progress',
                      style: GoogleFonts.outfit(
                        color: Colors.white70, 
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF10B981), 
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      height: 10,
                      width: (Get.width - 96) * progress, // roughly screen width minus padding
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34D399), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Slowly turn your head to complete the circle.',
                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // --- States (Error, Success, Loading) redesigned with Outfit font ---
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
              child: Text('Go Back', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyEnrolledState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)
                ]
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.amber, size: 72),
            ),
            const SizedBox(height: 32),
            Text(
              'Already Enrolled',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Obx(() => Text(
              controller.statusMessage.value,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            )),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text('Return to Punch', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              boxShadow: [
                BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 10)
              ]
            ),
            child: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 80),
          ),
          const SizedBox(height: 32),
          Text(
            'Enrollment Complete',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your face is securely registered.\nYou can now use Face Punch.',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                // Ensure camera is fully disposed before navigating away
                await controller.cameraService.dispose();
                Get.back();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text('Finish', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stateful widget to handle the smooth scanning animation
class _AnimatedScannerOverlay extends StatefulWidget {
  const _AnimatedScannerOverlay();

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
      duration: const Duration(seconds: 2),
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
          ),
        );
      },
    );
  }
}

class _ModernScannerPainter extends CustomPainter {
  final double animationValue;

  _ModernScannerPainter({required this.animationValue});

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

    // 2. Draw the glowing border
    final borderPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
      
    // Add glow effect using shadow
    final glowPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.4)
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

    // 4. Draw Animated Sweeping Laser Line
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
          const Color(0xFF10B981).withValues(alpha: 0.0),
          const Color(0xFF34D399).withValues(alpha: 0.8),
          const Color(0xFF10B981).withValues(alpha: 0.0),
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
          const Color(0xFF10B981).withValues(alpha: 0.0),
          const Color(0xFF10B981).withValues(alpha: 0.15),
        ],
      );
    // Clip the glow to stay inside the scanner squircle
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(glowRect, sweepGlowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ModernScannerPainter old) => old.animationValue != animationValue;
}
