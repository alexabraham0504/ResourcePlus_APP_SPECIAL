import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;

void showBetaNoticePopup(BuildContext context, {required String featureType}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (BuildContext ctx) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: _FuturisticBetaDialog(featureType: featureType),
      );
    },
  );
}

class _FuturisticBetaDialog extends StatefulWidget {
  final String featureType;
  const _FuturisticBetaDialog({required this.featureType});

  @override
  State<_FuturisticBetaDialog> createState() => _FuturisticBetaDialogState();
}

class _FuturisticBetaDialogState extends State<_FuturisticBetaDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Only repeat the animation if it's NOT the QR page.
    // Overlaying a continuously redrawing animation on top of an active 
    // Android Camera PlatformView crashes the GPU on many devices.
    if (widget.featureType != 'qr') {
      _animController.repeat(reverse: true);
    } else {
      _animController.forward();
    }

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );
    
    _rotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Glowing Icon
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                // Ensure opacity is safely clamped
                final double shadowOpacity = (0.4 * (_pulseAnimation.value - 1.0) * 5).clamp(0.0, 1.0);
                
                return Transform.rotate(
                  angle: _rotateAnimation.value,
                  child: Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withValues(alpha: shadowOpacity),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: Color(0xFFF9A8D4),
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Neon Title
            Text(
              'beta_access'.tr,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3.0,
                color: const Color(0xFFF9A8D4),
                shadows: [
                  Shadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
                    blurRadius: 15,
                  )
                ],
              ),
            ),
                const SizedBox(height: 16),
                
                // Futuristic Message
                Text(
                  widget.featureType == 'ai' ? 'beta_msg_ai'.tr : 'beta_msg_qr'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 36),
                
                // Gradient Button
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'proceed_btn'.tr,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ], // end children
            ), // end Column
          ), // end Container
    ); // end Dialog
  } // end build
} // end _FuturisticBetaDialogState
