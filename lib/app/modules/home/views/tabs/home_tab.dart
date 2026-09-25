import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/home_controller.dart';
import '../../../../routes/app_routes.dart';
import '../../../../controllers/language_controller.dart';
import '../../../auth/controllers/auth_controller.dart' as resource_plus_auth;
import '../../../../controllers/global_beacon_controller.dart';
import '../../../face_attendance/repositories/face_template_repository.dart';
class HomeTab extends GetView<HomeController> {
  const HomeTab({super.key});

  static const Color corporateBlue  = Color(0xFF004A77);
  static const Color primaryGreen   = Color(0xFF006E1C);
  static const Color onSurface      = Color(0xFF1A1C1E);
  static const Color onSurfaceVariant = Color(0xFF3F4A3C);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4F8),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(corporateBlue),
                  ),
                ),
                const SizedBox(height: 14),
                Text('loading_dashboard'.tr,
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey[500])),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.fetchHomeData,
          color: const Color(0xFF004A77),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // ── Hero Header (intrinsic height — wraps content) ──
                _buildHeroHeader(context, isDark),
                // ── Body ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    children: [
                      _buildAttendanceCard(context, isDark),
                      const SizedBox(height: 16),
                      // Quick Actions Heading
                      Row(
                        children: [
                          Icon(Icons.flash_on_rounded, size: 16, color: corporateBlue),
                          const SizedBox(width: 6),
                          Text(
                            'Quick Actions',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : corporateBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildQuickActions(context, isDark),
                      const SizedBox(height: 12),
                      _buildStatsRow(context, isDark),
                      const SizedBox(height: 12),
                      _buildPunchReminderBanner(isDark),
                      // Removed large spacing to prevent scrolling
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      }),
    );
  }

  // ── HERO HEADER ─────────────────────────────────────────────────────
  Widget _buildHeroHeader(BuildContext context, bool isDark) {
    return Obx(() {
      final firstName = controller.employeeName.value.split(' ').first;
      final position  = controller.positionName.value;
      final empId     = controller.empNumber.value;
      final now       = DateTime.now();
      final h         = now.hour;
      final greeting  = h < 12 ? 'good_morning'.tr : (h < 17 ? 'good_afternoon'.tr : 'good_evening'.tr);

      final btController = Get.find<GlobalBeaconController>();
      final btColor = btController.activeBeaconColor.value;

      return Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 18,
          right: 18,
          bottom: 14,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0D1B2A), const Color(0xFF003554)]
                : [const Color(0xFF004A77), const Color(0xFF0096C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: corporateBlue.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar: Logo + actions ──────────────────────────
            Row(
              children: [
                // ─ Real logo on white frosted container ─
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/app_logo.png',
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(text: 'Resource', style: TextStyle(color: Color(0xFF004A77), fontSize: 16, fontWeight: FontWeight.w900)),
                          TextSpan(text: 'Plus',     style: TextStyle(color: Color(0xFFFF6B00), fontSize: 16, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Bluetooth active indicator
                if (btColor != null) ...[
                  _HeaderIconBtn(
                    onTap: () => btController.showBeaconDetails(),
                    child: Icon(Icons.bluetooth_connected, color: btColor, size: 20),
                  ),
                  const SizedBox(width: 6),
                ],
                // Notification bell
                _HeaderIconBtn(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                      Positioned(
                        right: -3, top: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: controller.unreadNotificationsCount > 0 ? Colors.red : Colors.grey, 
                            shape: BoxShape.circle
                          ),
                          child: Text('${controller.unreadNotificationsCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => controller.changeTab(5),
                ),
                const SizedBox(width: 6),
                // Language toggle
                Obx(() {
                  final lc = Get.find<LanguageController>();
                  final label = lc.currentLanguage.value == 'en' ? 'AR' : 'EN';
                  return _HeaderIconBtn(
                    child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                    onTap: () => lc.toggleLanguage(),
                  );
                }),
                const SizedBox(width: 6),
                // Logout
                _HeaderIconBtn(
                  child: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFFF6B6B), size: 19),
                  onTap: () {
                    final lc = Get.find<LanguageController>();
                    final isAr = lc.currentLanguage.value == 'ar';
                    Get.defaultDialog(
                      title: isAr ? 'تسجيل خروج' : 'Logout',
                      middleText: isAr ? 'هل أنت متأكد؟' : 'Are you sure you want to log out?',
                      textConfirm: isAr ? 'نعم' : 'Yes',
                      textCancel: isAr ? 'إلغاء' : 'Cancel',
                      confirmTextColor: Colors.white,
                      buttonColor: Colors.red,
                      onConfirm: () {
                        try { Get.find<resource_plus_auth.AuthController>().logout(); } catch (_) {}
                        Get.offAllNamed(AppRoutes.login);
                      },
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Greeting + profile ───────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        firstName.isNotEmpty ? firstName : 'employee'.tr,
                        style: GoogleFonts.outfit(
                          fontSize: 26, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.5, height: 1.1,
                        ),
                      ),
                      if (position.isNotEmpty)
                        Text(
                          position,
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      // ID chip + last login in one row
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (empId.isNotEmpty)
                            _WhiteChip(
                              icon: Icons.badge_rounded,
                              label: '${'id_prefix'.tr} $empId',
                            ),
                          Builder(builder: (ctx) {
                            final raw = GetStorage().read('lastLoginTime');
                            if (raw == null) return const SizedBox.shrink();
                            try {
                              final date = DateTime.parse(raw.toString());
                              final fmt  = DateFormat('dd MMM, hh:mm a').format(date);
                              return _WhiteChip(icon: Icons.history_rounded, label: fmt);
                            } catch (_) { return const SizedBox.shrink(); }
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Avatar
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2.5),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 1),
                    ],
                  ),
                  child: ClipOval(
                    child: controller.profilePictureUrl.value.isNotEmpty
                        ? Image.network(controller.profilePictureUrl.value, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white, size: 32))
                        : const Icon(Icons.person_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ── ATTENDANCE CARD ─────────────────────────────────────────────────
  Widget _buildAttendanceCard(BuildContext context, bool isDark) {
    return Obx(() {
      String checkIn = '--:--', checkOut = '--:--', status = 'No Data';
      Map<String, dynamic>? rec;

      if (controller.recentActivities.isNotEmpty) {
        final today = DateTime.now();
        final s1 = DateFormat('dd/MM/yyyy').format(today);
        final s2 = DateFormat('d/MM/yyyy').format(today);
        final s3 = DateFormat('MM/dd/yyyy').format(today);
        for (final a in controller.recentActivities) {
          final d = (a['AttDate'] ?? '').toString().trim();
          if (d == s1 || d == s2 || d == s3) { rec = a as Map<String, dynamic>; break; }
        }
        rec ??= controller.recentActivities.first as Map<String, dynamic>;

        checkIn  = rec['CheckIN']?.toString()  ?? '--:--';
        checkOut = rec['CheckOut']?.toString() ?? '--:--';
        if (checkIn.isEmpty  || checkIn  == 'null') checkIn  = '--:--';
        if (checkOut.isEmpty || checkOut == 'null') checkOut = '--:--';
        final dt = (rec['DayType'] ?? '').toString().trim();
        if (dt.isNotEmpty) status = dt;
        else if (checkIn != '--:--') status = 'Present';
      }

      String nth = '', lsh = '';
      if (rec != null) {
        nth = _findVal(['NetHrs', 'NetHr', 'NetHours'], rec!);
        lsh = _findVal(['LessHrs', 'LessHr', 'LessHours'], rec!);
      }

      final now     = DateTime.now();
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayStr  = now.day.toString().padLeft(2, '0');
      final wdStr   = weekdays[now.weekday - 1];
      final monthStr = DateFormat('MMM yyyy').format(now);
      final sc      = _statusColor(status);
      final checkedIn  = checkIn  != '--:--';
      final checkedOut = checkOut != '--:--';

      return GestureDetector(
        onTap: () => controller.openTodayPunches(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark ? const Color(0xFF1A2235) : Colors.white,
            boxShadow: [BoxShadow(color: corporateBlue.withValues(alpha: 0.1), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF004A77), Color(0xFF0096C7)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('todays_attendance'.tr, style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
                        Text(monthStr, style: GoogleFonts.outfit(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sc.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(_label(status), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Date block
                    Container(
                      width: 62, padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : corporateBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: corporateBlue.withValues(alpha: 0.12)),
                      ),
                      child: Column(
                        children: [
                          Text(dayStr, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : corporateBlue, height: 1.0)),
                          Text(wdStr,  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : corporateBlue.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _TimeBlock(label: 'check_in'.tr, time: checkedIn ? checkIn.split(' ').first : '--:--', icon: Icons.login_rounded, color: const Color(0xFF10B981), isDark: isDark, active: checkedIn)),
                              const SizedBox(width: 8),
                              Expanded(child: _TimeBlock(label: 'check_out'.tr, time: checkedOut ? checkOut.split(' ').first : '--:--', icon: Icons.logout_rounded, color: const Color(0xFF3B82F6), isDark: isDark, active: checkedOut)),
                            ],
                          ),
                          if (nth.isNotEmpty || lsh.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  if (nth.isNotEmpty) _ChipHour(label: 'NTH', value: nth, color: const Color(0xFF059669), isDark: isDark),
                                  if (nth.isNotEmpty && lsh.isNotEmpty)
                                    Container(width: 1, height: 18, color: isDark ? Colors.white12 : Colors.black12),
                                  if (lsh.isNotEmpty) _ChipHour(label: 'LSH', value: lsh, color: const Color(0xFFE11D48), isDark: isDark),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Footer tap hint
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : corporateBlue.withValues(alpha: 0.04),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                  border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.06) : corporateBlue.withValues(alpha: 0.08))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 13, color: isDark ? Colors.white38 : corporateBlue.withValues(alpha: 0.5)),
                    const SizedBox(width: 5),
                    Text('view_full_history'.tr, style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.white38 : corporateBlue.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                    const SizedBox(width: 3),
                    Icon(Icons.arrow_forward_ios_rounded, size: 9, color: isDark ? Colors.white38 : corporateBlue.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ── QUICK ACTIONS ────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.how_to_reg_rounded,
            label: 'Selfie Punch',
            gradient: const [Color(0xFFFFB74D), Color(0xFFFFA726)], // Softer Orange
            onTap: () => Get.toNamed(AppRoutes.hrPortal),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Face Punch', // Changed label to reflect the smart action
            gradient: const [Color(0xFF81C784), Color(0xFF66BB6A)], // Softer Green
            onTap: () async {
              bool isEnrolled = false;
              try {
                Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
                isEnrolled = await ApiFaceTemplateRepository().hasTemplate().timeout(const Duration(seconds: 8));
                Get.back(); // close loading dialog
              } catch (_) {
                // Network error or timeout — safely close dialog and fall through
                if (Get.isDialogOpen == true) Get.back();
              }
              if (isEnrolled) {
                Get.toNamed(AppRoutes.faceDetectionPunch);
              } else {
                Get.toNamed(AppRoutes.faceEnrollment);
              }
            },
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ── STATS ROW ────────────────────────────────────────────────────────
  Widget _buildStatsRow(BuildContext context, bool isDark) {
    return Obx(() {
      final activities = controller.recentActivities;
      int present = 0, late = 0, absent = 0;
      for (final a in activities) {
        final dt = (a['DayType'] ?? '').toString().toLowerCase();
        if (dt.contains('regular') || dt.contains('present')) present++;
        else if (dt.contains('late')) late++;
        else if (dt.contains('absent')) absent++;
      }
      return Row(
        children: [
          Expanded(child: _StatCard(label: 'present_status'.tr, value: '$present', icon: Icons.check_circle_rounded, color: const Color(0xFF66BB6A), isDark: isDark)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'late_status'.tr,    value: '$late',    icon: Icons.schedule_rounded,     color: const Color(0xFFFFB74D), isDark: isDark)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'absent_status'.tr,  value: '$absent',  icon: Icons.cancel_rounded,       color: const Color(0xFFEF5350), isDark: isDark)),
        ],
      );
    });
  }

  // ── PUNCH REMINDER BANNER (fills bottom space near FAB) ────────────
  Widget _buildPunchReminderBanner(bool isDark) {
    final now = DateTime.now();
    final h = now.hour;
    final isCheckInTime  = h >= 7  && h < 10;
    final isCheckOutTime = h >= 17 && h < 21;

    String message;
    IconData icon;
    List<Color> colors;

    if (isCheckInTime) {
      message = 'time_to_punch_in'.tr;
      icon    = Icons.login_rounded;
      colors  = [const Color(0xFF81C784), const Color(0xFF66BB6A)];
    } else if (isCheckOutTime) {
      message = 'dont_forget_punch_out'.tr;
      icon    = Icons.logout_rounded;
      colors  = [const Color(0xFF64B5F6), const Color(0xFF42A5F5)];
    } else {
      message = 'use_button_to_punch'.tr;
      icon    = Icons.touch_app_rounded;
      colors  = [const Color(0xFF4FC3F7), const Color(0xFF29B6F6)];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────
  String _findVal(List<String> keys, Map<String, dynamic> rec) {
    for (final k in rec.keys) {
      if (keys.any((pk) => pk.toLowerCase() == k.toString().toLowerCase())) {
        final v = rec[k];
        if (v != null && v.toString().trim().isNotEmpty && v.toString() != 'null') return v.toString().trim();
      }
    }
    return '';
  }

  Color _statusColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('absent*p'))                              return const Color(0xFF6366F1);
    if (t.contains('absent') || t.contains('missing'))      return const Color(0xFFEF4444);
    if (t.contains('regular') || t.contains('present'))     return const Color(0xFF10B981);
    if (t.contains('late'))                                  return const Color(0xFFF59E0B);
    if (t.contains('week end'))                              return const Color(0xFF8B5CF6);
    if (t.contains('holiday'))                               return const Color(0xFFEC4899);
    if (t.contains('leave'))                                 return const Color(0xFF3B82F6);
    return Colors.grey;
  }

  String _label(String type) {
    switch (type.toLowerCase().trim()) {
      case 'absent':                                        return 'absent'.tr;
      case 'absent *p': case 'absent*p':                   return 'absent_p'.tr;
      case 'present':                                       return 'present'.tr;
      case 'early':                                         return 'early'.tr;
      case 'late':                                          return 'late'.tr;
      case 'less':                                          return 'less_hrs'.tr;
      case 'regular':                                       return 'regular'.tr;
      case 'week end': case 'weekend': case 'week_end':    return 'week_end'.tr;
      default:                                              return type.isEmpty ? 'No Data' : type;
    }
  }
}

// ─── Header Icon Button ──────────────────────────────────────────────
class _HeaderIconBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HeaderIconBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: child,
      ),
    );
  }
}

// ─── White Chip ──────────────────────────────────────────────────────
class _WhiteChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _WhiteChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

// ─── Quick Action Card ───────────────────────────────────────────────
class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool isDark;
  const _QuickActionCard({required this.icon, required this.label, required this.gradient, required this.onTap, required this.isDark});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: widget.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [BoxShadow(color: widget.gradient.last.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(11)),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3)),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2235) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : HomeTab.onSurface)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

// ─── Time Block ──────────────────────────────────────────────────────
class _TimeBlock extends StatelessWidget {
  final String label, time;
  final IconData icon;
  final Color color;
  final bool isDark, active;
  const _TimeBlock({required this.label, required this.time, required this.icon, required this.color, required this.isDark, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: isDark ? 0.15 : 0.08) : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: active ? color.withValues(alpha: 0.3) : Colors.transparent),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: active ? color : Colors.grey),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(time, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: active ? color : (isDark ? Colors.white38 : Colors.grey[400]!))),
        ],
      ),
    );
  }
}

// ─── Hours Chip ──────────────────────────────────────────────────────
class _ChipHour extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  const _ChipHour({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5)),
          child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.4)),
        ),
        const SizedBox(width: 5),
        Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : HomeTab.onSurface)),
      ],
    );
  }
}
