import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import '../controllers/hr_portal_controller.dart';
import 'widgets/tab_header.dart';
import 'package:resource_plus/app/routes/app_routes.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/shift_location_block.dart';
import 'widgets/home_bottom_navigation.dart';
import '../controllers/home_controller.dart';

class HrPortalView extends GetView<HrPortalController> {
  const HrPortalView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final primaryGreen = const Color(0xFF10B981);
    final primaryRed = const Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: TabHeader(title: ''),
            ),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refreshData,
                color: colorScheme.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 600),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, val, child) => Opacity(
                              opacity: val,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - val)),
                                child: child,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.face_rounded, color: colorScheme.primary, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'attendance_punch'.tr,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12), // Reduced from 16

                          // Camera Preview Frame
                          _buildCameraPreview(context, colorScheme),
                          const SizedBox(height: 12), // Reduced from 16

                          // Animated Clock Section
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 800),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOutBack,
                            builder: (context, val, child) => Transform.scale(
                              scale: 0.8 + (0.2 * val),
                              child: Opacity(opacity: val, child: child),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(12), // Reduced from 16
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(alpha: 0.08),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Digital Clock
                                  Obx(
                                    () => Text(
                                      controller.currentTime.value,
                                      style: TextStyle(
                                        fontSize: 32, // Reduced from 36
                                        fontWeight: FontWeight.w900,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'current_time'.tr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                                      letterSpacing: 1.5,
                                      textBaseline: TextBaseline.alphabetic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12), // Reduced from 16

                          // In/Out Buttons
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 700),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, val, child) => Opacity(
                              opacity: val,
                              child: Transform.translate(offset: Offset(0, 30 * (1 - val)), child: child),
                            ),
                            child: _buildAttendanceButtons(context, primaryGreen, primaryRed, isDark),
                          ),
                          const SizedBox(height: 12), // Reduced from 16

                          // Current Shift & Coordinates
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 800),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, val, child) => Opacity(
                              opacity: val,
                              child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child),
                            ),
                            child: ShiftLocationBlock(colorScheme: colorScheme, isDark: isDark),
                          ),
                          const SizedBox(height: 32),

                          // Last 5 Punches Section
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 900),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, val, child) => Opacity(
                              opacity: val,
                              child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child),
                            ),
                            child: _buildLastPunchesSection(context, colorScheme, isDark),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: HomeBottomNavigation(
        currentIndex: -1,
        onTap: (index) {
          Get.back();
          if (Get.isRegistered<HomeController>()) {
            Get.find<HomeController>().changeTab(index);
          }
        },
      ),
    );
  }

  Widget _buildCameraPreview(BuildContext context, ColorScheme colorScheme) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final containerAspectRatio = isLandscape ? 4.0 / 3.0 : 3.0 / 4.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.2, // 20% on each side = 60% width
      ),
      child: AspectRatio(
        aspectRatio: containerAspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Obx(() {
              if (!controller.isCameraPermissionGranted.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text('Camera permission required', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14)),
                    ],
                  ),
                );
              }

              if (!controller.isCameraInitialized.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary)),
                      const SizedBox(height: 12),
                      Text('Initializing camera...', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14)),
                    ],
                  ),
                );
              }

              final cameraController = controller.cameraController;
              if (cameraController != null) {
                try {
                  final cameraValue = cameraController.value;

                  if (!cameraValue.isInitialized || cameraValue.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (cameraValue.hasError)
                            Icon(Icons.error_outline, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.5))
                          else
                            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary)),
                          const SizedBox(height: 12),
                          Text(
                            cameraValue.hasError ? 'Camera error occurred' : 'Initializing camera...',
                            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  final previewSize = cameraValue.previewSize;
                  if (previewSize != null) {
                    return FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: isLandscape ? previewSize.width : previewSize.height,
                        height: isLandscape ? previewSize.height : previewSize.width,
                        child: CameraPreview(cameraController),
                      ),
                    );
                  } else {
                    // Prevent internal CameraPreview NPE when previewSize is null
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary)),
                          const SizedBox(height: 12),
                          Text(
                            'Starting camera feed...',
                            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text('Camera preview error', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14)),
                      ],
                    ),
                  );
                }
              }

              return Center(
                child: Text(
                  'Camera not available',
                  style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceButtons(BuildContext context, Color green, Color red, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Obx(
            () => _AnimatedPunchButton(
              title: 'in_uppercase'.tr,
              icon: Icons.login_rounded,
              color: green,
              isLoading: controller.isProcessingIn.value,
              isDisabled: controller.isProcessingIn.value || controller.isProcessingAttendance.value,
              onTap: controller.markAttendanceIn,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Obx(
            () => _AnimatedPunchButton(
              title: 'out_uppercase'.tr,
              icon: Icons.logout_rounded,
              color: red,
              isLoading: controller.isProcessingOut.value,
              isDisabled: controller.isProcessingOut.value || controller.isProcessingAttendance.value,
              onTap: controller.markAttendanceOut,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLastPunchesSection(BuildContext context, ColorScheme colorScheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.history_rounded, size: 18, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Text(
              'last_5_punches'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Get.toNamed(AppRoutes.attendanceHistory),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'see_more'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Obx(() {
            if (controller.isLoadingPunches.value) {
              return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
            }
            if (controller.hasPunchesError.value || controller.lastPunches.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    controller.hasPunchesError.value ? 'Failed to load punches' : 'No punches found',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500]),
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: controller.lastPunches.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outline.withValues(alpha: 0.05)),
              itemBuilder: (context, index) {
                final punch = controller.lastPunches[index];
                return _buildPunchItem(punch, colorScheme, isDark);
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildPunchItem(dynamic punch, ColorScheme colorScheme, bool isDark) {
    final rawType = punch.type.toString().toLowerCase();
    final isIn = rawType == 'in';
    final color = isIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    
    String displayType = punch.type.toString().toUpperCase();
    if (displayType == 'IN') displayType = 'in_uppercase'.tr;
    if (displayType == 'OUT') displayType = 'out_uppercase'.tr;

    String displayStatus = punch.status;
    if (displayStatus.toLowerCase() == 'success') displayStatus = 'success'.tr;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(isIn ? Icons.login_rounded : Icons.logout_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayType, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text('${punch.date} • ${punch.time}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[500])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: punch.status == 'Success' ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(displayStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: punch.status == 'Success' ? const Color(0xFF10B981) : Colors.red)),
          ),
        ],
      ),
    );
  }

}

class _AnimatedPunchButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;

  const _AnimatedPunchButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  State<_AnimatedPunchButton> createState() => _AnimatedPunchButtonState();
}

class _AnimatedPunchButtonState extends State<_AnimatedPunchButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled) _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isDisabled) {
      _controller.reverse();
      widget.onTap();
    }
  }

  void _handleTapCancel() {
    if (!widget.isDisabled) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            color: widget.isDisabled ? Colors.grey.withValues(alpha: 0.1) : widget.color.withValues(alpha: 0.1),
            border: Border.all(
              color: widget.isDisabled ? Colors.grey.withValues(alpha: 0.3) : widget.color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(27),
            boxShadow: widget.isDisabled
                ? []
                : [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: widget.color, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: widget.isDisabled ? Colors.grey : widget.color, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: widget.isDisabled ? Colors.grey : widget.color,
                          letterSpacing: 1.5,
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
