import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Determines the type of error to show appropriate messaging.
enum ErrorType {
  connection,
  server,
  unknown,
}

/// A premium futuristic animated error page widget.
///
/// Features:
/// - Animated floating orbs background
/// - 3D-style pulsing/rotating error icon
/// - Glassmorphism card with blur
/// - User-friendly messages (no raw errors)
/// - Tappable support email link
/// - Gradient animated retry button
class FuturisticErrorPage extends StatefulWidget {
  final VoidCallback onRetry;
  final ErrorType errorType;
  final String? customMessage;

  const FuturisticErrorPage({
    super.key,
    required this.onRetry,
    this.errorType = ErrorType.connection,
    this.customMessage,
  });

  @override
  State<FuturisticErrorPage> createState() => _FuturisticErrorPageState();
}

class _FuturisticErrorPageState extends State<FuturisticErrorPage>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _iconController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  static const String supportEmail = 'info@netsoftpro.net';

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _iconController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.errorType) {
      case ErrorType.connection:
        return 'Connection Lost';
      case ErrorType.server:
        return 'Service Unavailable';
      case ErrorType.unknown:
        return 'Something Went Wrong';
    }
  }

  String get _subtitle {
    if (widget.customMessage != null) return widget.customMessage!;
    switch (widget.errorType) {
      case ErrorType.connection:
        return 'Please check your internet connection\nand try again.';
      case ErrorType.server:
        return 'Our servers are temporarily unavailable.\nPlease try again in a moment.';
      case ErrorType.unknown:
        return 'An unexpected error occurred.\nPlease try again.';
    }
  }

  IconData get _icon {
    switch (widget.errorType) {
      case ErrorType.connection:
        return Icons.wifi_off_rounded;
      case ErrorType.server:
        return Icons.cloud_off_rounded;
      case ErrorType.unknown:
        return Icons.error_outline_rounded;
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {'subject': 'ResourcePlus App - Support Request'},
    );
    try {
      await launchUrl(emailUri);
    } catch (_) {
      // Silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force clean light corporate theme regardless of system setting
    final isDark = false;
    final size = MediaQuery.of(context).size;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF4F7FB), // Soft corporate white
            const Color(0xFFE5EDF4), // Very light ice blue
            const Color(0xFFF0F5FA), // Soft corporate white
          ],
        ),
      ),
      child: Stack(
        children: [
          // Animated floating orbs
          ..._buildFloatingOrbs(size, isDark),

          // App Logo at top left
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, top: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/app_logo.png',
                    height: 26,
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Animated 3D Icon
                    _buildAnimatedIcon(isDark),
                    const SizedBox(height: 36),
                  // Glass card
                  _buildGlassCard(isDark),
                  const SizedBox(height: 32),
                  // Retry button
                  _buildRetryButton(isDark),
                  const SizedBox(height: 20),
                  // Support section
                  _buildSupportSection(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFloatingOrbs(Size size, bool isDark) {
    final orbs = <_OrbConfig>[
      _OrbConfig(
        size: 120,
        color: const Color(0xFF004A77), // Corporate Blue
        left: -30,
        top: size.height * 0.1,
        phaseOffset: 0,
      ),
      _OrbConfig(
        size: 80,
        color: const Color(0xFF006E1C), // Primary Green
        right: -20,
        top: size.height * 0.2,
        phaseOffset: 2.0,
      ),
      _OrbConfig(
        size: 60,
        color: const Color(0xFF5D9ECC), // Light Blue
        left: size.width * 0.6,
        bottom: size.height * 0.15,
        phaseOffset: 4.0,
      ),
      _OrbConfig(
        size: 100,
        color: const Color(0xFFE5A93D), // Soft Amber
        right: size.width * 0.5,
        bottom: size.height * 0.05,
        phaseOffset: 1.5,
      ),
    ];

    return orbs.map((orb) {
      return AnimatedBuilder(
        animation: _orbController,
        builder: (context, child) {
          final t = _orbController.value * 2 * pi + orb.phaseOffset;
          final dx = sin(t) * 15;
          final dy = cos(t * 0.7) * 20;

          return Positioned(
            left: orb.left != null ? orb.left! + dx : null,
            right: orb.right != null ? orb.right! + dx : null,
            top: orb.top != null ? orb.top! + dy : null,
            bottom: orb.bottom != null ? orb.bottom! + dy : null,
            child: Container(
              width: orb.size,
              height: orb.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    orb.color.withValues(alpha: 0.25),
                    orb.color.withValues(alpha: 0.05),
                    orb.color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildAnimatedIcon(bool isDark) {
    return AnimatedBuilder(
      animation: _iconController,
      builder: (context, child) {
        final rotateY = sin(_iconController.value * 2 * pi) * 0.15;
        final rotateX = cos(_iconController.value * 2 * pi) * 0.1;
        final scale = 1.0 + sin(_pulseController.value * pi) * 0.08;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(rotateY)
            ..rotateX(rotateX)
            ..scale(scale),
          child: child,
        );
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.9),
              const Color(0xFFE5EDF4).withValues(alpha: 0.8),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF004A77).withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF004A77).withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: const Color(0xFF006E1C).withValues(alpha: 0.08),
              blurRadius: 50,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Icon(
          _icon,
          size: 52,
          color: const Color(0xFF004A77),
        ),
      ),
    );
  }

  Widget _buildGlassCard(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Title
              Text(
                _title,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: const Color(0xFF004A77),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              // Animated divider line
              AnimatedBuilder(
                animation: _shimmerController,
                builder: (context, child) {
                  return Container(
                    height: 3,
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF004A77).withValues(alpha: 0.2),
                          const Color(0xFF004A77),
                          const Color(0xFF006E1C),
                          const Color(0xFF006E1C).withValues(alpha: 0.2),
                        ],
                        stops: [
                          0.0,
                          _shimmerController.value,
                          _shimmerController.value + 0.1 > 1.0
                              ? 1.0
                              : _shimmerController.value + 0.1,
                          1.0,
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              // Subtitle
              Text(
                _subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.6,
                  color: const Color(0xFF475569),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRetryButton(bool isDark) {
    return GestureDetector(
      onTap: widget.onRetry,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final glowIntensity = 0.2 + (_pulseController.value * 0.15);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004A77).withValues(alpha: glowIntensity),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF004A77), Color(0xFF006E1C)],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                'Try Again',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportSection(bool isDark) {
    return Column(
      children: [
        Text(
          'If the issue persists, contact support',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _launchEmail,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF004A77).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF004A77).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  size: 16,
                  color: const Color(0xFF004A77),
                ),
                const SizedBox(width: 8),
                Text(
                  supportEmail,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF004A77),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Configuration for floating background orbs.
class _OrbConfig {
  final double size;
  final Color color;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double phaseOffset;

  const _OrbConfig({
    required this.size,
    required this.color,
    this.left,
    this.right,
    this.top,
    this.bottom,
    this.phaseOffset = 0,
  });
}
