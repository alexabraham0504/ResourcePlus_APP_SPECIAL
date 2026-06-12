import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/home_controller.dart';
import '../../../../routes/app_routes.dart';
import '../../../../controllers/language_controller.dart';
import '../widgets/tab_header.dart';

class HomeTab extends GetView<HomeController> {
  const HomeTab({Key? key}) : super(key: key);

  // Design system colors matching HTML
  static const Color corporateBlue = Color(0xFF004A77);
  static const Color primaryGreen = Color(0xFF006E1C);
  static const Color primaryContainer = Color(0xFF4BAE4F);
  static const Color secondaryOrange = Color(0xFF934B00);
  static const Color secondaryContainer = Color(0xFFFC943B);
  static const Color tertiary = Color(0xFF3C6184);
  static const Color surfaceBg = Color(0xFFF9F9FC);
  static const Color surfaceContainerLow = Color(0xFFF3F3F6);
  static const Color onSurface = Color(0xFF1A1C1E);
  static const Color onSurfaceVariant = Color(0xFF3F4A3C);
  static const Color outlineVariant = Color(0xFFBECAB9);
  static const Color errorColor = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : surfaceBg,
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
            ),
          );
        }

        if (controller.hasError.value) {
          return _buildErrorState(context);
        }

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.fetchHomeData,
            color: primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Hamburger + Logo + Notifications
                    const TabHeader(title: 'ResourcePlus'),
                    const SizedBox(height: 24),

                    // Welcome Section
                    _buildWelcomeSection(isDark),
                    const SizedBox(height: 20),
                    
                    _buildActionGrid(context, isDark),
                    const SizedBox(height: 20),

                    // Attendance Card
                    _buildAttendanceCard(context, isDark),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text('failed_to_load_home_data'.tr,
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[700])),
          const SizedBox(height: 8),
          Text(controller.errorMessage.value, textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: controller.refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('retry'.tr, style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }



  Widget _buildWelcomeSection(bool isDark) {
    return Obx(() {
      final firstName = controller.employeeName.value.split(' ').first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${'hello_there'.tr}${firstName.isNotEmpty ? firstName : ""}',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : onSurface,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'dashboard_up_to_date'.tr,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: (isDark ? Colors.white : onSurfaceVariant).withOpacity(0.6),
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildProfileCard(BuildContext context, bool isDark) {
    return Obx(() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: onSurface.withOpacity(0.1)),
                ),
                child: ClipOval(
                  child: controller.profilePictureUrl.value.isNotEmpty
                      ? Image.network(controller.profilePictureUrl.value,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.person,
                              color: isDark ? Colors.white54 : Colors.grey, size: 32))
                      : Icon(Icons.person,
                          color: isDark ? Colors.white54 : Colors.grey, size: 32),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.employeeName.value.isNotEmpty
                      ? controller.employeeName.value : 'Employee',
                  style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : onSurface,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                Text(
                  controller.positionName.value.isNotEmpty
                      ? controller.positionName.value : 'Position',
                  style: GoogleFonts.outfit(fontSize: 14,
                      color: (isDark ? Colors.white : onSurfaceVariant).withOpacity(0.7)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ID: ${controller.empNumber.value.isNotEmpty ? controller.empNumber.value : "N/A"}',
                    style: GoogleFonts.outfit(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.verified_user,
              color: primaryGreen.withOpacity(0.2), size: 28),
        ],
      ),
    ));
  }

  Widget _buildActionGrid(BuildContext context, bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.1,
      children: [
        // Face Punch
        _buildGlassActionCard(
          isDark: isDark,
          icon: Icons.face,
          label: 'FACE PUNCH',
          iconColor: corporateBlue,
          labelColor: isDark ? Colors.white : onSurface,
          hasIconBg: true,
          onTap: () => Get.toNamed(AppRoutes.hrPortal),
        ),
        // Self Service → HR Portal WebView
        _buildGlassActionCard(
          isDark: isDark,
          icon: Icons.widgets,
          label: 'SELF SERVICE',
          iconColor: primaryGreen,
          labelColor: isDark ? Colors.white : onSurface,
          hasIconBg: true,
          onTap: controller.launchHrPortal,
        ),
        // Profile
        _buildGlassActionCard(
          isDark: isDark,
          icon: Icons.account_circle,
          label: 'PROFILE',
          iconColor: const Color(0xFFFC943B),
          labelColor: isDark ? Colors.white : onSurface,
          hasIconBg: true,
          onTap: () => controller.changeTab(2),
        ),
        // Settings
        _buildGlassActionCard(
          isDark: isDark,
          icon: Icons.settings_suggest,
          label: 'SETTINGS',
          iconColor: const Color(0xFF6F7A6B),
          labelColor: isDark ? Colors.white : onSurface,
          hasIconBg: true,
          onTap: () => controller.changeTab(4),
        ),
      ],
    );
  }

  Widget _buildGlassActionCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color labelColor,
    bool hasIconBg = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : outlineVariant.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 16, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52, height: 52,
              decoration: hasIconBg
                  ? BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Icon(icon, size: 30, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksCard(bool isDark) {
    return Obx(() {
      final taskCount = controller.dashboardData.isNotEmpty
          ? controller.dashboardData.fold<int>(0, (sum, item) => sum + ((item['QInfoCount'] ?? 0) as int))
          : 0;

      return GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : outlineVariant.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 16, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$taskCount',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: secondaryOrange,
                  shadows: [
                    Shadow(color: secondaryContainer.withOpacity(0.4), blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text('TASKS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: isDark ? Colors.white70 : onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Color _statusColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('absent*p')) return const Color(0xFF6366F1);
    if (t.contains('absent') || t.contains('missing')) return const Color(0xFFEF4444);
    if (t.contains('regular') || t.contains('present')) return const Color(0xFF10B981);
    if (t.contains('late')) return const Color(0xFFF59E0B);
    if (t.contains('week end')) return const Color(0xFF8B5CF6);
    if (t.contains('holiday')) return const Color(0xFFEC4899);
    if (t.contains('leave')) return const Color(0xFF3B82F6);
    return Colors.grey;
  }

  String _label(String type) {
    if (type.isEmpty) return 'Present';
    if (type.toLowerCase().contains('absent*p')) return 'Absent*P';
    if (type.toLowerCase().contains('week end')) return 'Week End';
    return type;
  }

  Widget _timeSection(BuildContext ctx, String label, String time, {bool isRight = false}) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500])),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF004A77))),
        ],
      ),
    );
  }

  Widget _hoursChip(BuildContext ctx, String label, String value, Color color) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
        ),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF004A77))),
      ],
    );
  }

  Widget _buildAttendanceCard(BuildContext context, bool isDark) {
    return Obx(() {
      // Get today's attendance from recent activities
      String checkIn = '--:--';
      String checkOut = '--:--';
      String status = 'No Data';

      if (controller.recentActivities.isNotEmpty) {
        // Find today's record by matching AttDate to today's date
        final today = DateTime.now();
        final todayStr1 = DateFormat('dd/MM/yyyy').format(today); // e.g. 04/06/2026
        final todayStr2 = DateFormat('d/MM/yyyy').format(today);  // e.g. 4/06/2026
        final todayStr3 = DateFormat('MM/dd/yyyy').format(today);  // e.g. 06/04/2026

        Map<String, dynamic>? todayRecord;
        for (final activity in controller.recentActivities) {
          final attDate = (activity['AttDate'] ?? '').toString().trim();
          if (attDate == todayStr1 || attDate == todayStr2 || attDate == todayStr3) {
            todayRecord = activity as Map<String, dynamic>;
            break;
          }
        }

        // Fallback to first record if no exact today match found
        if (todayRecord == null) {
          todayRecord = controller.recentActivities.first as Map<String, dynamic>;
        }

        checkIn = todayRecord['CheckIN']?.toString() ?? '--:--';
        checkOut = todayRecord['CheckOut']?.toString() ?? '--:--';
        // Handle empty strings for both check-in and check-out
        if (checkIn.isEmpty || checkIn == 'null') checkIn = '--:--';
        if (checkOut.isEmpty || checkOut == 'null') checkOut = '--:--';
        // Determine status from DayType
        final dayType = (todayRecord['DayType'] ?? '').toString().trim();
        if (dayType.isNotEmpty) {
          status = dayType;
        } else if (checkIn != '--:--') {
          status = 'Present';
        }
      }

      // Calculate NTH and LSH for the home tab
      String nth = '';
      String lsh = '';
      if (checkIn != '--:--' && checkOut != '--:--') {
        final nthMinutes = _calculateWorkedMinutes(checkIn, checkOut);
        if (nthMinutes != null && nthMinutes >= 0) {
          final nthH = (nthMinutes ~/ 60).toString().padLeft(2, '0');
          final nthM = (nthMinutes % 60).toString().padLeft(2, '0');
          nth = '$nthH:$nthM';
          // LSH = expected 9 hours (540 minutes) minus actual worked
          final lshMinutes = (540 - nthMinutes).clamp(0, 540);
          final lshH = (lshMinutes ~/ 60).toString().padLeft(2, '0');
          final lshM = (lshMinutes % 60).toString().padLeft(2, '0');
          lsh = '$lshH:$lshM';
        }
      }

      final now = DateTime.now();
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final dateStr = '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
      
      final dayStr = now.day.toString().padLeft(2, '0');
      final weekdayStr = weekdays[now.weekday - 1];
      final monthStr = DateFormat('MMMM').format(now);
      final yearStr = now.year.toString();

      return GestureDetector(
        onTap: () {
          // Switch to Attendance tab (index 1)
          final homeController = Get.find<HomeController>();
          homeController.changeTab(1);
        },
        child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 20, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 16, color: (isDark ? Colors.white : onSurfaceVariant).withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Text('$monthStr $yearStr', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : onSurfaceVariant).withOpacity(0.7))),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(_label(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : onSurfaceVariant).withOpacity(0.8))),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 0.5, color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Big Date Block (Left)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : surfaceContainerLow.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: onSurface.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Text(dayStr, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: isDark ? Colors.white : onSurface, height: 1.0)),
                      const SizedBox(height: 4),
                      Text(weekdayStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: (isDark ? Colors.white : onSurfaceVariant).withOpacity(0.9))),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: (checkIn != '--:--' || checkOut != '--:--')
                    ? Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _timeSection(context, 'Check In', checkIn == '--:--' ? '--:--' : checkIn.split(' ').first)),
                              Container(width: 1, height: 30, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              Expanded(child: _timeSection(context, 'Check Out', checkOut == '--:--' ? '--:--' : checkOut.split(' ').first, isRight: true)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (nth.isNotEmpty) Expanded(child: Center(child: _hoursChip(context, 'NTH', nth, const Color(0xFF059669)))),
                                if (nth.isNotEmpty && lsh.isNotEmpty) Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                if (lsh.isNotEmpty) Expanded(child: Center(child: _hoursChip(context, 'LSH', lsh, const Color(0xFFE11D48)))),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('no_punch_data'.tr, style: TextStyle(fontSize: 13, color: Colors.grey[400], fontStyle: FontStyle.italic)),
                        ),
                      ),
                ),
              ],
            ),
          ],
        ),
      ));
    });
  }

  Color _statusBadgeColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'present':
        return primaryGreen;
      case 'absent':
      case 'absent *p':
      case 'absent*p':
        return errorColor;
      case 'late':
      case 'half day':
      case 'halfday':
        return secondaryOrange;
      case 'week end':
      case 'weekend':
      case 'leave':
        return const Color(0xFF4F46E5); // Indigo
      case 'early':
        return primaryGreen;
      case 'no data':
        return const Color(0xFF64748B); // Neutral slate
      default:
        return primaryGreen;
    }
  }



  int? _calculateWorkedMinutes(String checkInStr, String checkOutStr) {
    try {
      final inTime = _parseTimeString(checkInStr);
      final outTime = _parseTimeString(checkOutStr);
      if (inTime == null || outTime == null) return null;

      int diffMinutes = outTime.difference(inTime).inMinutes;
      if (diffMinutes < 0) diffMinutes += 24 * 60; // Handle overnight
      return diffMinutes;
    } catch (e) {
      return null;
    }
  }

  DateTime? _parseTimeString(String time) {
    final trimmed = time.trim();
    if (trimmed.isEmpty) return null;

    final formats = [
      'HH:mm:ss',
      'HH:mm',
      'hh:mm:ss a',
      'hh:mm a',
      'h:mm:ss a',
      'h:mm a',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parse(trimmed);
      } catch (_) {}
    }
    return null;
  }


  // Leave Balance Card - matches HTML design
  Widget _buildLeaveBalanceCard(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        // Find the matching dashboard item to show details
        Map<String, dynamic>? leaveItem;
        for (final item in controller.dashboardData) {
          final title = (item['QInfoTitle'] ?? '').toString().toLowerCase();
          if (title.contains('leave') || title.contains('annual') || title.contains('vacation')) {
            leaveItem = item;
            break;
          }
        }
        
        if (leaveItem != null) {
          final title = leaveItem['QInfoTitle'] ?? 'Leave Balances';
          final count = leaveItem['QInfoCount'] ?? 0;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(title.toString()),
              content: Text('Count: $count\n${leaveItem!['QInfoDescription'] ?? ''}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('close'.tr),
                )
              ],
            ),
          );
        } else {
          // Fallback if not found
          controller.launchHrPortal(title: 'Leave Balances');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 20, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Blue accent bar
            Container(
              width: 4, height: 60,
              decoration: BoxDecoration(
                color: corporateBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            // Icon
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: corporateBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: corporateBlue.withOpacity(0.1)),
              ),
              child: Icon(Icons.event_available, color: corporateBlue, size: 32),
            ),
            const SizedBox(width: 16),
            // Balance info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(() {
                    // Try to get leave balance from dashboard data
                    String balance = '—';
                    for (final item in controller.dashboardData) {
                      final title = (item['QInfoTitle'] ?? '').toString().toLowerCase();
                      if (title.contains('leave') || title.contains('annual') || title.contains('vacation')) {
                        balance = item['QInfoCount']?.toString() ?? '—';
                        break;
                      }
                    }
                    return Text(balance,
                      style: TextStyle(
                        fontSize: 34, fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1C1E),
                        letterSpacing: -0.5,
                      ),
                    );
                  }),
                  Text('annual_leave_balances'.tr,
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: (isDark ? Colors.white : onSurfaceVariant).withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right,
                color: isDark ? Colors.white70 : onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconFromFontAwesome(String fontAwesomeIcon) {
    switch (fontAwesomeIcon) {
      case 'fa fa-list-alt': return Icons.list_alt;
      case 'fa fa-calendar-check-o': return Icons.calendar_today;
      case 'fa fa-envelope-open-o': return Icons.mail_outline;
      case 'fa fa-book': return Icons.book;
      case 'fa fa-briefcase': return Icons.work;
      case 'fa fa-bank': return Icons.account_balance;
      case 'fa fa-money': return Icons.attach_money;
      case 'fa fa-id-card':
      case 'fa fa-id-card-o': return Icons.badge;
      case 'fa fa-tasks': return Icons.assignment_outlined;
      case 'fa fa-refresh':
      case 'fa fa-history': return Icons.history;
      case 'fa fa-file-text':
      case 'fa fa-file-text-o': return Icons.description_outlined;
      case 'fa fa-send':
      case 'fa fa-paper-plane': return Icons.send_outlined;
      case 'fa fa-clock-o': return Icons.access_time;
      case 'fa fa-user': return Icons.person_outline;
      case 'fa fa-users': return Icons.people_outline;
      case 'fa fa-check-square-o': return Icons.check_box_outlined;
      case 'fa fa-question-circle': return Icons.help_outline;
      case 'fa fa-cog':
      case 'fa fa-gear': return Icons.settings_outlined;
      default: return Icons.info;
    }
  }
}
