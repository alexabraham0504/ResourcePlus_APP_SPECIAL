import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/home_controller.dart';
import '../../../routes/app_routes.dart';
import 'widgets/tab_header.dart';
import 'widgets/app_drawer.dart';

class AttendanceHistoryView extends StatefulWidget {
  const AttendanceHistoryView({Key? key}) : super(key: key);

  @override
  State<AttendanceHistoryView> createState() => _AttendanceHistoryViewState();
}

class _AttendanceHistoryViewState extends State<AttendanceHistoryView> {
  // ─── Professional Corporate Palette ──────────────────────────────
  static const _primary    = Color(0xFF0F172A); // Slate 900
  static const _surface    = Colors.white;
  static const _bg         = Color(0xFFF8FAFC); // Slate 50
  
  static const _present    = Color(0xFF059669); // Emerald 600
  static const _absent     = Color(0xFFE11D48); // Rose 600
  static const _late       = Color(0xFFD97706); // Amber 600
  static const _weekend    = Color(0xFF4F46E5); // Indigo 600
  static const _neutral    = Color(0xFF64748B); // Slate 500

  DateTimeRange? _dateRange;
  final HomeController _controller = Get.find<HomeController>();

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

  void _showDatePicker() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? const ColorScheme.dark(primary: Colors.white, onPrimary: _primary, surface: _primary)
                : const ColorScheme.light(primary: _primary, onPrimary: Colors.white, surface: _surface),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() {
        _dateRange = result;
      });
    }
  }

  List<dynamic> _getFilteredRecords() {
    List<dynamic> records = _controller.recentActivities.toList();
    
    if (_dateRange != null) {
      records = records.where((record) {
        final dateStr = (record['AttDate'] ?? record['LogDate'] ?? '').toString();
        if (dateStr.isEmpty) return true; // keep if no date (fallback)
        
        DateTime? parsed;
        try {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            int day = int.parse(parts[0]);
            int month = int.parse(parts[1]);
            int year = int.parse(parts[2]);
            if (day > 12 && month <= 12) {
              parsed = DateTime(year, month, day);
            } else if (month > 12 && day <= 12) {
              parsed = DateTime(year, day, month);
            } else {
              parsed = DateTime(year, month, day);
            }
          } else {
            parsed = DateFormat('yyyy-MM-dd').parse(dateStr);
          }
        } catch (_) {}

        if (parsed != null) {
          // Check if parsed date falls within range (inclusive of boundaries)
          final start = _dateRange!.start.subtract(const Duration(days: 1));
          final end = _dateRange!.end.add(const Duration(days: 1));
          return parsed.isAfter(start) && parsed.isBefore(end);
        }
        return true;
      }).toList();
    }
    
    return records;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final records = _getFilteredRecords();

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: isDark ? const Color(0xFF0F172A) : _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: TabHeader(
                title: '',
                onNotificationTap: () {
                  Get.until((route) => route.settings.name == AppRoutes.home || route.settings.name == '/');
                  Get.find<HomeController>().changeTab(3);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Attendance History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: isDark ? Colors.white : _primary)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _dateRange != null ? Icons.filter_alt_rounded : Icons.filter_alt_outlined, 
                          color: _dateRange != null ? (isDark ? Colors.white : _primary) : (isDark ? Colors.grey[400] : Colors.grey[600])
                        ),
                        onPressed: _showDatePicker,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (_dateRange != null) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(Icons.clear, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          onPressed: () => setState(() => _dateRange = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // "Coming Soon" Filter Chips
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: ['10', '20', '30', '50', 'Next 50'].map((val) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black26,
                          builder: (context) {
                            Future.delayed(const Duration(milliseconds: 1500), () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            });
                            return Center(
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                  margin: const EdgeInsets.symmetric(horizontal: 40),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 40),
                                      const SizedBox(height: 16),
                                      Text('Coming Soon!', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'The "$val" filter will be available\nin the next update.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        alignment: Alignment.center,
                        child: Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: records.isEmpty
                ? _emptyState(context)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _recordCard(context, records[i]),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(vertical: 40),
    alignment: Alignment.center,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.history_rounded, size: 40, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text('No records found for the selected period.', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
    ]),
  );

  Widget _recordCard(BuildContext ctx, dynamic item) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final date = (item['AttDate'] ?? item['LogDate'] ?? '').toString();
    final type = (item['DayType'] ?? '').toString();
    final checkIn = (item['CheckIN'] ?? '').toString();
    final checkOut = (item['CheckOut'] ?? '').toString();

    String nth = '';
    String lsh = '';

    if (checkIn.isNotEmpty && checkOut.isNotEmpty) {
      final worked = _calculateWorkedMinutes(checkIn, checkOut);
      if (worked != null) {
        final nthH = (worked ~/ 60).toString().padLeft(2, '0');
        final nthM = (worked % 60).toString().padLeft(2, '0');
        nth = '$nthH:$nthM';
        
        final expected = 9 * 60; 
        final lshMinutes = expected - worked;
        if (lshMinutes > 0) {
          final lshH = (lshMinutes ~/ 60).toString().padLeft(2, '0');
          final lshM = (lshMinutes % 60).toString().padLeft(2, '0');
          lsh = '$lshH:$lshM';
        }
      }
    }

    final color = _statusColor(type);

    String dayStr = '--';
    String weekdayStr = '---';
    String monthStr = '---';
    String yearStr = '';
    try {
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
              Expanded(
                child: (checkIn.isNotEmpty || checkOut.isNotEmpty)
                  ? Column(
                      children: [
                        Row(
                          children: [
                            if (checkIn.isNotEmpty) Expanded(child: _timeSection(ctx, 'Check In', checkIn)),
                            if (checkIn.isNotEmpty && checkOut.isNotEmpty) Container(width: 1, height: 30, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            if (checkOut.isNotEmpty) Expanded(child: _timeSection(ctx, 'Check Out', checkOut, isRight: checkIn.isNotEmpty)),
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
                                if (nth.isNotEmpty) Expanded(child: Center(child: _hoursChip(ctx, 'NTH', nth, const Color(0xFF059669)))),
                                if (nth.isNotEmpty && lsh.isNotEmpty) Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                if (lsh.isNotEmpty) Expanded(child: Center(child: _hoursChip(ctx, 'LSH', lsh, const Color(0xFFE11D48)))),
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
    return Container(
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500])),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : _primary)),
        ],
      ),
    );
  }

  String _label(String type) {
    if (type.isEmpty) return type;
    switch (type.toLowerCase().trim()) {
      case 'absent':                                        return 'absent'.tr;
      case 'absent *p': case 'absent*p':                    return 'Absent *P';
      case 'present':                                       return 'present'.tr;
      case 'early':                                         return 'early'.tr;
      case 'late':                                          return 'late'.tr;
      case 'less':                                          return 'Less Hrs';
      case 'week end': case 'weekend': case 'week_end':     return 'week_end'.tr;
      default:                                              return type;
    }
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
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : _primary)),
      ],
    );
  }

  int? _calculateWorkedMinutes(String checkInStr, String checkOutStr) {
    try {
      final inTime = _parseTimeString(checkInStr);
      final outTime = _parseTimeString(checkOutStr);
      if (inTime == null || outTime == null) return null;

      int diffMinutes = outTime.difference(inTime).inMinutes;
      if (diffMinutes < 0) diffMinutes += 24 * 60;
      return diffMinutes;
    } catch (e) {
      return null;
    }
  }

  DateTime? _parseTimeString(String time) {
    final trimmed = time.trim();
    if (trimmed.isEmpty) return null;
    final formats = [
      'HH:mm:ss', 'HH:mm', 'hh:mm:ss a', 'hh:mm a', 'h:mm:ss a', 'h:mm a',
    ];
    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parse(trimmed);
      } catch (_) {}
    }
    return null;
  }
}
