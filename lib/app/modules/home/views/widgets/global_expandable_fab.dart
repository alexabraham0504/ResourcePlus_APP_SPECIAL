import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resourceplus_app/main.dart';
import 'package:resourceplus_app/services/settings_service.dart';
import '../../../../routes/app_routes.dart';
import '../../../home/controllers/home_controller.dart';

// ─── Data model for each speed-dial action ─────────────────────────
class _FabAction {
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const _FabAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });
}

List<_FabAction> get _actions => <_FabAction>[
  _FabAction(
    label: 'AI Workforce',
    icon: Icons.dashboard_customize_rounded,
    color: const Color(0xFF8B5CF6), // Purple color
    route: 'ai_workforce',
  ),
  _FabAction(
    label: 'ai_chat'.tr,
    icon: Icons.chat_bubble_outline_rounded,
    color: const Color(0xFF6366F1), // AI Chat color
    route: 'ai_chat',
  ),
  _FabAction(
    label: 'face_punch'.tr,
    icon: Icons.face_retouching_natural_rounded,
    color: const Color(0xFF3B82F6),
    route: AppRoutes.faceDetectionPunch,
  ),
  _FabAction(
    label: 'Fingerprint Punch',
    icon: Icons.fingerprint_rounded,
    color: const Color(0xFF10B981),
    route: AppRoutes.fingerprintPunch,
  ),
  _FabAction(
    label: 'Bluetooth Punch',
    icon: Icons.bluetooth_rounded,
    color: const Color(0xFFF59E0B),
    route: AppRoutes.bluetoothPunch,
  ),
  _FabAction(
    label: 'QR Scan Punch',
    icon: Icons.qr_code_scanner_rounded,
    color: const Color(0xFF8B5CF6),
    route: AppRoutes.QR_ATTENDANCE,
  ),
  _FabAction(
    label: 'Selfie Punch',
    icon: Icons.touch_app_rounded,
    color: const Color(0xFFEC4899), // Pink color
    route: AppRoutes.hrPortal,
  ),
];

// ─── Main Widget ──────────────────────────────────────────────────
class GlobalExpandableFab extends StatefulWidget {
  final Widget child;
  final bool isVisible;
  const GlobalExpandableFab({Key? key, required this.child, this.isVisible = true}) : super(key: key);

  @override
  State<GlobalExpandableFab> createState() => _GlobalExpandableFabState();
}

class _GlobalExpandableFabState extends State<GlobalExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _open = !_open;
      _open ? _ctrl.forward() : _ctrl.reverse();
    });
  }

  void _closeAndNavigate(String route) {
    HapticFeedback.mediumImpact();
    setState(() {
      _open = false;
      _ctrl.reverse();
    });
    Future.delayed(const Duration(milliseconds: 180), () async {
      if (route == 'ai_chat') {
        Get.find<HomeController>().changeTab(6);
      } else if (route == 'ai_workforce') {
        Get.find<HomeController>().changeTab(7);
      } else {
        Get.toNamed(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // The main app content
        widget.child,

        // The blur overlay that blocks touches and closes the FAB
        if (_open && widget.isVisible)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggle, // Close when tapping background
              behavior: HitTestBehavior.opaque,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                child: Container(
                  color: isDark ? Colors.black54 : Colors.black12,
                ),
              ),
            ),
          ),

        // The FAB and its speed-dial actions
        if (widget.isVisible)
          Positioned.directional(
          textDirection: Directionality.of(context),
          end: 18,
          bottom: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Action buttons
              for (int i = 0; i < _actions.length; i++)
                _SpeedDialItem(
                  action: _actions[i],
                  index: i,
                  totalCount: _actions.length,
                  controller: _ctrl,
                  isDark: isDark,
                  onTap: () => _closeAndNavigate(_actions[i].route),
                ),
              const SizedBox(height: 10),
              // Main toggle button
              _MainFab(open: _open, controller: _ctrl, onToggle: _toggle),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Each speed-dial item with size + fade + slide ────────────────
class _SpeedDialItem extends StatelessWidget {
  final _FabAction action;
  final int index;
  final int totalCount;
  final AnimationController controller;
  final bool isDark;
  final VoidCallback onTap;

  const _SpeedDialItem({
    required this.action,
    required this.index,
    required this.totalCount,
    required this.controller,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Top item animates first → bottom last
    final double delay = index * 0.07;
    final double end = (delay + 0.5).clamp(0.0, 1.0);

    final sizeFactor = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, end, curve: Curves.easeOutCubic),
    );
    final opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, end, curve: Curves.easeOut),
      ),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Interval(delay, end, curve: Curves.easeOutBack),
    ));

    return SizeTransition(
      sizeFactor: sizeFactor,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: opacity,
        child: SlideTransition(
          position: slide,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SpeedDialRow(
              action: action,
              isDark: isDark,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Row: glass label pill + coloured icon button ────────────────
class _SpeedDialRow extends StatefulWidget {
  final _FabAction action;
  final bool isDark;
  final VoidCallback onTap;

  const _SpeedDialRow({
    required this.action,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SpeedDialRow> createState() => _SpeedDialRowState();
}

class _SpeedDialRowState extends State<_SpeedDialRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Label pill — glassmorphism style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.grey.shade800.withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : widget.action.color.withValues(alpha: 0.18),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.action.color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Coloured dot indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.action.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.action.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: widget.isDark
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Icon circle button
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: widget.action.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.action.color.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                widget.action.icon,
                color: Colors.white,
                size: 23,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Main FAB button ─────────────────────────────────────────────
class _MainFab extends StatefulWidget {
  final bool open;
  final AnimationController controller;
  final VoidCallback onToggle;

  const _MainFab({
    required this.open,
    required this.controller,
    required this.onToggle,
  });

  @override
  State<_MainFab> createState() => _MainFabState();
}

class _MainFabState extends State<_MainFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (ctx, _) => GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onToggle();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.open ? const Color(0xFFEF4444) : const Color(0xFF004A77),
              boxShadow: [
                BoxShadow(
                  color: (widget.open ? const Color(0xFFEF4444) : const Color(0xFF004A77))
                      .withValues(alpha: 0.5),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: RotationTransition(
              turns: Tween<double>(begin: 0.0, end: 0.5).animate(
                CurvedAnimation(parent: widget.controller, curve: Curves.easeOutBack),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  widget.open ? Icons.close_rounded : Icons.touch_app_rounded,
                  key: ValueKey<bool>(widget.open),
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
