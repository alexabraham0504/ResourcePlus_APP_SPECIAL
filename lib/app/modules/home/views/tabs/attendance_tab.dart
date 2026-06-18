import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/home_controller.dart';
import '../widgets/tab_header.dart';
import '../../../../routes/app_routes.dart';

class AttendanceTab extends GetView<HomeController> {
  const AttendanceTab({Key? key}) : super(key: key);

  // ─── Professional Corporate Palette ──────────────────────────────
  static const _primary    = Color(0xFF0F172A); // Slate 900
  static const _surface    = Colors.white;
  static const _bg         = Color(0xFFF8FAFC); // Slate 50
  
  static const _present    = Color(0xFF059669); // Emerald 600
  static const _absent     = Color(0xFFE11D48); // Rose 600
  static const _late       = Color(0xFFD97706); // Amber 600
  static const _weekend    = Color(0xFF4F46E5); // Indigo 600
  static const _neutral    = Color(0xFF64748B); // Slate 500

  Color _statusColor(String dayType) {
    switch (dayType.toLowerCase().trim()) {
      case 'present':                              return _present;
      case 'absent': case 'absent *p': case 'absent*p': return _absent;
      case 'late':                                 return _late;
      case 'early':                                return _present;
      case 'week end': case 'weekend':             return _weekend;
      case 'half day': case 'halfday':             return _late;
      case 'leave':                                return _weekend;
      default:                                     return _neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add date filter variables to controller if not present
    // We will manage local state for the date range filter
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF0F172A) 
          : _bg,
      body: Obx(() {
        if (controller.isAttendanceLoading.value) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }
        if (controller.hasAttendanceError.value) {
          return _errorState(context);
        }

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: controller.fetchAttendanceData,
            color: _primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabHeader(title: 'attendance_overview'.tr),
                  const SizedBox(height: 24),
                  _rateCards(context),
                  const SizedBox(height: 32),
                  _summaryGrid(context),
                  const SizedBox(height: 32),
                  _punchSection(context),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ERROR
  // ═══════════════════════════════════════════════════════════
  Widget _errorState(BuildContext ctx) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
      const SizedBox(height: 16),
      Text('connection_error'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
      const SizedBox(height: 16),
      TextButton.icon(
        onPressed: controller.refreshAttendanceData, 
        icon: const Icon(Icons.refresh), 
        label: Text('retry'.tr),
        style: TextButton.styleFrom(foregroundColor: _primary),
      ),
    ]),
  );

  // ═══════════════════════════════════════════════════════════
  //  RATE CARDS
  // ═══════════════════════════════════════════════════════════
  Widget _rateCards(BuildContext ctx) {
    if (controller.attendanceRate.isEmpty) return const SizedBox.shrink();
    final d = controller.attendanceRate.first;
    return Row(children: [
      Expanded(child: _statCard(ctx, 'present_rate'.tr, d['PresentPercentage'] ?? '0', _present, Icons.check_circle_outline)),
      const SizedBox(width: 16),
      Expanded(child: _statCard(ctx, 'absent_rate'.tr, d['AbsentPercentage'] ?? '0', _absent, Icons.cancel_outlined)),
    ]);
  }

  Widget _statCard(BuildContext ctx, String label, String pct, Color color, IconData icon) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isDark) BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(pct, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: isDark ? Colors.white : _primary, height: 1)),
          const SizedBox(width: 2),
          Text('%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[500])),
        ]),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SUMMARY GRID
  // ═══════════════════════════════════════════════════════════
  Widget _summaryGrid(BuildContext ctx) {
    if (controller.attendanceCounts.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('attendance_summary'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : _primary)),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (_, box) {
        final cols = box.maxWidth > 500 ? 4 : 3;
        return GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1
          ),
          itemCount: controller.attendanceCounts.length,
          itemBuilder: (_, i) {
            final item = controller.attendanceCounts[i];
            final type = item['CountType'] ?? '';
            final days = item['NoOfDays'] ?? 0;
            final c = _statusColor(type);
            
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$days', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c)),
                const SizedBox(height: 4),
                Text(_label(type), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[400] : Colors.grey[600]), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            );
          },
        );
      }),
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  //  RECENT PUNCHES (WITH FILTERS)
  // ═══════════════════════════════════════════════════════════
  Widget _punchSection(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    // We use a local state variable in GetX for date filter since it's not in controller
    // If we wanted a persistent one we'd add to HomeController.
    final types = <String>{'All'};
    for (final a in controller.recentActivities) {
      final dt = (a['DayType'] ?? '').toString();
      if (dt.isNotEmpty) types.add(dt);
    }

    // Apply type filter
    List filtered = controller.attendanceFilter.value == 'All'
        ? controller.recentActivities.toList()
        : controller.recentActivities.where((a) => (a['DayType'] ?? '').toString() == controller.attendanceFilter.value).toList();

    // The backend provides what it provides. We show up to the selected limit.
    final limit = controller.attendanceDisplayCount.value;
    final showAll = limit >= 999;
    final display = showAll ? filtered : filtered.take(limit).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('recent_records'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : _primary)),
          if (filtered.length > 5)
            GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.attendanceHistory),
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('see_more'.tr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : _primary)),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? Colors.white : _primary),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      
      // Type filters (Clean style)
      SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal, itemCount: types.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final t = types.elementAt(i);
            final active = controller.attendanceFilter.value == t;
            return GestureDetector(
              onTap: () => controller.attendanceFilter.value = t,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: active ? (isDark ? Colors.white : _primary) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? (isDark ? Colors.white : _primary) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                ),
                alignment: Alignment.center,
                child: Text(t == 'All' ? 'All'.tr : _label(t), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? (isDark ? _primary : Colors.white) : (isDark ? Colors.grey[400] : Colors.grey[600]))),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 24),

      // Record List
      if (filtered.isEmpty)
        _emptyState(ctx)
      else ...[
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length > 5 ? 5 : filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _recordCard(ctx, filtered[i]),
        ),
      ]
    ]);
  }

  Widget _limitChip(BuildContext ctx, int n, String text, bool active, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => controller.attendanceDisplayCount.value = n,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: active ? _primary.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? _primary.withOpacity(0.2) : Colors.transparent),
          ),
          alignment: Alignment.center,
          child: Text(text, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? _primary : Colors.grey[500])),
        ),
      ),
    );
  }

  // ─── Professional Record Card ──────────────────────────────
  Widget _recordCard(BuildContext ctx, Map<String, dynamic> a) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final date = a['AttDate'] ?? '';
    final type = (a['DayType'] ?? '').toString();
    final checkIn = a['CheckIN'] ?? '';
    final checkOut = a['CheckOut'] ?? '';
    final color = _statusColor(type);

    // Calculate NTH (Net Hours) and LSH (Less Hours)
    String nth = '';
    String lsh = '';
    if (checkIn.toString().isNotEmpty && checkOut.toString().isNotEmpty) {
      final nthMinutes = _calculateWorkedMinutes(checkIn.toString(), checkOut.toString());
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

    // Parse date for the big left block
    String dayStr = '--';
    String weekdayStr = '---';
    String monthStr = '---';
    String yearStr = '';
    try {
      // First try dd/MM/yyyy
      final parts = date.split('/');
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (day > 12 && month <= 12) {
          final d = DateTime(year, month, day);
          dayStr = DateFormat('dd').format(d);
          weekdayStr = DateFormat('EEE').format(d);
          monthStr = DateFormat('MMMM').format(d);
          yearStr = DateFormat('yyyy').format(d);
        } else if (month > 12 && day <= 12) {
          final d = DateTime(year, day, month);
          dayStr = DateFormat('dd').format(d);
          weekdayStr = DateFormat('EEE').format(d);
          monthStr = DateFormat('MMMM').format(d);
          yearStr = DateFormat('yyyy').format(d);
        } else {
          final d = DateTime(year, month, day);
          dayStr = DateFormat('dd').format(d);
          weekdayStr = DateFormat('EEE').format(d);
          monthStr = DateFormat('MMMM').format(d);
          yearStr = DateFormat('yyyy').format(d);
        }
      } else {
        // try other formats
        final d = DateFormat('yyyy-MM-dd').parse(date);
        dayStr = DateFormat('dd').format(d);
        weekdayStr = DateFormat('EEE').format(d);
        monthStr = DateFormat('MMMM').format(d);
        yearStr = DateFormat('yyyy').format(d);
      }
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 16, color: (isDark ? Colors.white : Colors.grey[600])?.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Text('$monthStr $yearStr', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.grey[600])?.withOpacity(0.7))),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(_label(type), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.grey[600])?.withOpacity(0.8))),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 0.5, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big Date Block (Left)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF3F3F6).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1A1C1E).withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    Text(dayStr, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1C1E), height: 1.0)),
                    const SizedBox(height: 4),
                    Text(weekdayStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: (isDark ? Colors.white : const Color(0xFF3F4A3C)).withOpacity(0.9))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Times and NTH/LSH Block (Right)
              Expanded(
                child: (checkIn.isNotEmpty || checkOut.isNotEmpty)
                  ? Column(
                      children: [
                        Row(
                          children: [
                            if (checkIn.isNotEmpty) Expanded(child: _timeSection(ctx, 'check_in'.tr, checkIn)),
                            if (checkIn.isNotEmpty && checkOut.isNotEmpty) Container(width: 1, height: 30, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            if (checkOut.isNotEmpty) Expanded(child: _timeSection(ctx, 'check_out'.tr, checkOut, isRight: checkIn.isNotEmpty)),
                          ],
                        ),
                        if (nth.isNotEmpty || lsh.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                if (nth.isNotEmpty) Expanded(child: Center(child: _hoursChip(ctx, 'nth'.tr, nth, const Color(0xFF059669)))),
                                if (nth.isNotEmpty && lsh.isNotEmpty) Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                if (lsh.isNotEmpty) Expanded(child: Center(child: _hoursChip(ctx, 'lsh'.tr, lsh, const Color(0xFFE11D48)))),
                              ],
                            ),
                          ),
                        ],
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
    );
  }

  Widget _timeSection(BuildContext ctx, String label, String time, {bool isRight = false}) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    String displayTime = time.replaceAll('AM', 'am'.tr).replaceAll('PM', 'pm'.tr).replaceAll('am', 'am'.tr).replaceAll('pm', 'pm'.tr);
    return Container(
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500])),
          const SizedBox(height: 4),
          Text(displayTime, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : _primary)),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(vertical: 40),
    alignment: Alignment.center,
    child: Column(children: [
      Icon(Icons.history_rounded, size: 40, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text('no_records'.tr, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
    ]),
  );

  // ═══════════════════════════════════════════════════════════
  //  DATE FILTER DIALOG
  // ═══════════════════════════════════════════════════════════
  void _showDateFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('filter_by_date'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The API currently returns predefined recent activities. Advanced server-side date filtering will be implemented in the next backend update.', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Select Date Range'),
                subtitle: const Text('Coming soon'),
                onTap: () {},
                enabled: false,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════
  String _label(String type) {
    if (type.isEmpty) return type;
    switch (type.toLowerCase().trim()) {
      case 'absent':                                        return 'absent'.tr;
      case 'absent *p': case 'absent*p':                    return 'absent_p'.tr;
      case 'present':                                       return 'present'.tr;
      case 'early':                                         return 'early'.tr;
      case 'late':                                          return 'late'.tr;
      case 'less':                                          return 'less_hrs'.tr;
      case 'regular':                                       return 'regular'.tr;
      case 'week end': case 'weekend': case 'week_end':     return 'week_end'.tr;
      default:                                              return type;
    }
  }

  Widget _hoursChip(BuildContext ctx, String label, String value, Color color) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
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
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : _primary)),
        ],
      ),
    );
  }

  /// Parses check-in and check-out time strings and returns the worked duration in minutes.
  /// Handles multiple time formats: "HH:mm", "HH:mm:ss", "hh:mm AM/PM", "hh:mm:ss AM/PM".
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

  /// Attempts to parse a time string in multiple formats and returns a DateTime for comparison.
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
}
