import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../controllers/auth_controller.dart';
import '../../../routes/app_routes.dart';

class CodeVerificationView extends StatefulWidget {
  const CodeVerificationView({super.key});

  @override
  State<CodeVerificationView> createState() => _CodeVerificationViewState();
}

class _CodeVerificationViewState extends State<CodeVerificationView> with TickerProviderStateMixin {
  late TextEditingController codeController;
  late FocusNode _focusNode;
  bool isVerified = false;
  bool isLocalLoading = false; // Guarantees a minimum loading duration for visual feedback
  late AnimationController _loadingController;

  @override
  void initState() {
    super.initState();
    codeController = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);

    // Controller for the rotating border loading animation (spins the orange outline)
    // 1000ms per rotation
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  void dispose() {
    codeController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _handleVerification(String code) async {
    final AuthController controller = Get.find();
    if (isLocalLoading || controller.isLoading.value) return;

    if (code.isEmpty) {
      controller.errorMessage.value = 'Please enter the verification code';
      Get.snackbar('Error', 'Please enter the verification code',
          backgroundColor: Colors.red[800], colorText: Colors.white);
      return;
    }

    if (code.length != 6) {
      controller.errorMessage.value = 'Please enter a 6-digit verification code';
      Get.snackbar('Error', 'Please enter a 6-digit verification code',
          backgroundColor: Colors.red[800], colorText: Colors.white);
      return;
    }

    controller.errorMessage.value = '';

    setState(() {
      isLocalLoading = true;
    });

    final startTime = DateTime.now();

    // Call authentication API
    final success = await controller.validateVerificationCode(code);

    // Guarantee that loading spinners rotate exactly ~3 times (3 seconds total)
    final elapsed = DateTime.now().difference(startTime);
    final minimumLoadingDuration = const Duration(seconds: 3);
    if (elapsed < minimumLoadingDuration) {
      await Future.delayed(minimumLoadingDuration - elapsed);
    }

    setState(() {
      isLocalLoading = false;
    });

    if (success) {
      controller.verificationCode.value = code;
      // Mark OTP verification as complete
      await GetStorage().write('otpVerified', true);

      // Play success animation
      setState(() {
        isVerified = true;
      });

      // Wait for checkmark drawing animation to complete before transitioning
      await Future.delayed(const Duration(milliseconds: 1600));
      Get.toNamed(AppRoutes.password);
    } else {
      Get.snackbar(
          'Error',
          controller.errorMessage.value.isNotEmpty
              ? controller.errorMessage.value
              : 'Invalid verification code',
          backgroundColor: Colors.red[800],
          colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthController controller = Get.find();
    final theme = Theme.of(context);

    // Responsive design dimensions for square OTP fields (rounded corners)
    double cardWidth = MediaQuery.of(context).size.width - 96;
    double boxSize = (cardWidth - (5 * 8)) / 6; // spacing is 8px between 6 squares
    if (boxSize > 50) boxSize = 50; // Increased max size to look bigger and bolder

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: Image.asset(
                    'assets/app_logo.png',
                    height: 80,
                    width: 280,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withOpacity(0.1),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated Title transition
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: isVerified
                                  ? Text(
                                      'verified_successfully'.tr,
                                      key: const ValueKey('success_title'),
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 22,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                  : Text(
                                      'enter_verification_code'.tr,
                                      key: const ValueKey('input_title'),
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 22,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                            const SizedBox(height: 8),
                            // Animated Subtitle transition
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              transitionBuilder: (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.2),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: isVerified
                                  ? Text(
                                      'phone_verified_subtitle'.tr,
                                      key: ValueKey('success_subtitle'),
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    )
                                  : Text(
                                      '${'code_sent_to'.tr}${controller.emailOrPhone.value}',
                                      key: const ValueKey('input_subtitle'),
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                            const SizedBox(height: 32),

                            // Hidden overlay text field to handle keyboard inputs
                            Stack(
                              children: [
                                BoxPositioned(
                                  width: double.infinity,
                                  height: boxSize,
                                  child: Opacity(
                                    opacity: 0,
                                    child: TextField(
                                      controller: codeController,
                                      focusNode: _focusNode,
                                      enabled: !isLocalLoading,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      autofillHints: const [AutofillHints.oneTimeCode],
                                      decoration: const InputDecoration(
                                        counterText: '',
                                        border: InputBorder.none,
                                      ),
                                      style: const TextStyle(color: Colors.transparent),
                                      cursorColor: Colors.transparent,
                                      showCursor: false,
                                      onChanged: (val) {
                                        if (isLocalLoading) return;
                                        setState(() {});
                                        if (val.length == 6) {
                                          _handleVerification(val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                // Swappable content area (OTP input fields or Success Indicator)
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  child: isVerified
                                      ? const Center(
                                          key: ValueKey('success_state'),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(vertical: 24.0),
                                            child: _SuccessCheckmarkWidget(),
                                          ),
                                        )
                                      : Column(
                                          key: const ValueKey('input_state'),
                                          children: [
                                            AnimatedBuilder(
                                              animation: _loadingController,
                                              builder: (context, child) {
                                                if (isLocalLoading && !_loadingController.isAnimating) {
                                                  _loadingController.repeat();
                                                } else if (!isLocalLoading && _loadingController.isAnimating) {
                                                  _loadingController.stop();
                                                }

                                                return _OtpInputRow(
                                                  text: codeController.text,
                                                  hasFocus: _focusNode.hasFocus,
                                                  boxWidth: boxSize,
                                                  boxHeight: boxSize,
                                                  isLoading: isLocalLoading,
                                                  loadingProgress: _loadingController.value,
                                                  onTap: () {
                                                    _focusNode.requestFocus();
                                                  },
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 24),
                                            // Error message display
                                            Obx(() => controller.errorMessage.value.isNotEmpty
                                                ? Padding(
                                                    padding: const EdgeInsets.only(bottom: 16.0),
                                                    child: Text(
                                                      controller.errorMessage.value,
                                                      style: const TextStyle(
                                                        color: Color(0xFFBA1A1A),
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  )
                                                : const SizedBox.shrink()),
                                            // Verify Button
                                            SizedBox(
                                              width: double.infinity,
                                              height: 52,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFFFF5E3A), Color(0xFFBA1A1A)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: BorderRadius.circular(16),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFFFF5E3A).withOpacity(0.35),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.transparent,
                                                    shadowColor: Colors.transparent,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                  ),
                                                  onPressed: isLocalLoading
                                                      ? null
                                                      : () => _handleVerification(codeController.text.trim()),
                                                  child: isLocalLoading
                                                      ? const SizedBox(
                                                          width: 24,
                                                          height: 24,
                                                          child: CircularProgressIndicator(
                                                            color: Colors.white,
                                                            strokeWidth: 2.5,
                                                          ),
                                                        )
                                                      : Text(
                                                          'verify'.tr,
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            // Resend option
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'did_not_receive_code'.tr,
                                                  style: TextStyle(
                                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () async {
                                                    controller.errorMessage.value = '';
                                                    final success = await controller.sendVerificationCode(
                                                        controller.emailOrPhone.value);
                                                    if (success) {
                                                      Get.snackbar(
                                                        'Success',
                                                        'Verification code resent successfully',
                                                        backgroundColor: const Color(0xFF00FF64),
                                                        colorText: Colors.black,
                                                      );
                                                    } else {
                                                      Get.snackbar(
                                                        'Error',
                                                        controller.errorMessage.value.isNotEmpty
                                                            ? controller.errorMessage.value
                                                            : 'Failed to resend code',
                                                        backgroundColor: const Color(0xFFBA1A1A),
                                                        colorText: Colors.white,
                                                      );
                                                    }
                                                  },
                                                  child: Text(
                                                    'resend'.tr,
                                                    style: TextStyle(
                                                      color: theme.colorScheme.onSurface,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: TextDecoration.underline,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
}

// Blinking Cursor for active inputs
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 24,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

// Row layout for individual OTP pin boxes
class _OtpInputRow extends StatelessWidget {
  final String text;
  final bool hasFocus;
  final double boxWidth;
  final double boxHeight;
  final bool isLoading;
  final double loadingProgress;
  final VoidCallback onTap;

  const _OtpInputRow({
    required this.text,
    required this.hasFocus,
    required this.boxWidth,
    required this.boxHeight,
    required this.isLoading,
    required this.loadingProgress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          final isFilled = index < text.length;
          final isCurrent = index == text.length;
          final char = isFilled ? text[index] : '';

          Color boxBg;
          Border? border;
          List<BoxShadow>? shadow;

          final onSurface = Theme.of(context).colorScheme.onSurface;
          if (isLoading) {
            boxBg = onSurface.withOpacity(0.04);
            border = Border.all(color: const Color(0xFFFF5E3A).withOpacity(0.15), width: 1.5);
            shadow = null;
          } else if (hasFocus && isCurrent) {
            boxBg = onSurface.withOpacity(0.06);
            border = Border.all(color: const Color(0xFFFF5E3A), width: 2.2);
            shadow = [
              BoxShadow(
                color: const Color(0xFFFF5E3A).withOpacity(0.2),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ];
          } else if (isFilled) {
            boxBg = onSurface.withOpacity(0.04);
            border = Border.all(color: const Color(0xFFFF5E3A).withOpacity(0.6), width: 1.5);
            shadow = null;
          } else {
            boxBg = onSurface.withOpacity(0.04);
            border = Border.all(color: onSurface.withOpacity(0.12), width: 1.5);
            shadow = null;
          }

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: boxWidth,
                height: boxHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: border,
                  boxShadow: shadow,
                ),
                child: isCurrent && hasFocus && !isLoading
                    ? const _BlinkingCursor()
                    : Text(
                        char,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
              ),
              if (isLoading)
                CustomPaint(
                  size: Size(boxWidth, boxHeight),
                  painter: RotatingSquareBorderPainter(
                    progress: loadingProgress,
                    color: const Color(0xFFFF5E3A),
                    strokeWidth: 2.2,
                    borderRadius: 12,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

// Custom Painter to draw a loading segment rotating around a rounded rectangle (square box)
class RotatingSquareBorderPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;
  final double strokeWidth;
  final double borderRadius;

  RotatingSquareBorderPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 2.2,
    this.borderRadius = 12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw slightly outside the box boundaries (3.5px margin on all sides)
    const margin = 3.5;
    final rect = Rect.fromLTWH(
      -margin,
      -margin,
      size.width + 2 * margin,
      size.height + 2 * margin,
    );

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        rect,
        Radius.circular(borderRadius + margin),
      ));

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      final totalLength = metric.length;
      final segmentLength = totalLength * 0.32; // 32% segment length wrapping around
      final start = (totalLength * progress) % totalLength;
      final end = (start + segmentLength) % totalLength;

      if (start < end) {
        final extractPath = metric.extractPath(start, end);
        canvas.drawPath(extractPath, paint);
      } else {
        final extractPath1 = metric.extractPath(start, totalLength);
        final extractPath2 = metric.extractPath(0.0, end);
        canvas.drawPath(extractPath1, paint);
        canvas.drawPath(extractPath2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RotatingSquareBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// Success indicator drawing checkmark elastically inside a rounded square box
class _SuccessCheckmarkWidget extends StatefulWidget {
  const _SuccessCheckmarkWidget();

  @override
  State<_SuccessCheckmarkWidget> createState() => _SuccessCheckmarkWidgetState();
}

class _SuccessCheckmarkWidgetState extends State<_SuccessCheckmarkWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _controller.forward();
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF00FF64).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16), // Rounded square matching the OTP cells
              border: Border.all(
                color: const Color(0xFF00FF64),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF64).withOpacity(0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CustomPaint(
              painter: CheckmarkPainter(
                progress: _checkAnimation.value,
                color: Colors.white,
                strokeWidth: 4.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

// Custom Painter to draw checkmark path line segment
class CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CheckmarkPainter({required this.progress, required this.color, this.strokeWidth = 4.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final startX = size.width * 0.28;
    final startY = size.height * 0.5;
    final midX = size.width * 0.44;
    final midY = size.height * 0.66;
    final endX = size.width * 0.72;
    final endY = size.height * 0.34;

    path.moveTo(startX, startY);
    path.lineTo(midX, midY);
    path.lineTo(endX, endY);

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      final extractPath = metric.extractPath(0.0, metric.length * progress);
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// Helper class for position
class BoxPositioned extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const BoxPositioned({super.key, required this.width, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: child,
    );
  }
}
