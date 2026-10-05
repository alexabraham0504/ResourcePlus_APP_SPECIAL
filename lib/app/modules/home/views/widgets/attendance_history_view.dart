import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../controllers/home_controller.dart';
import 'tab_header.dart';
import '../tabs/attendance_tab.dart';

class AttendanceHistoryView extends StatefulWidget {
  const AttendanceHistoryView({super.key});

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
      backgroundColor: isDark ? const Color(0xFF0F172A) : _bg,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: 1, // Attendance tab is visually selected
          onTap: (index) {
            Get.back(); // Pop the history view to return to main tabs
            if (index != 1) {
              _controller.changeTab(index); // Navigate to new tab if not attendance
            }
          },
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          selectedItemColor: const Color(0xFF006E1C), // primaryGreen from HomeView
          unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[400],
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10.0,
          unselectedFontSize: 10.0,
          elevation: 0,
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.home_rounded), label: 'home'.tr),
            BottomNavigationBarItem(icon: const Icon(Icons.calendar_month_rounded), label: 'attendance'.tr),
            BottomNavigationBarItem(icon: const Icon(Icons.widgets_rounded), label: 'self_service'.tr),
            BottomNavigationBarItem(icon: const Icon(Icons.person_rounded), label: 'profile'.tr),
            BottomNavigationBarItem(icon: const Icon(Icons.settings_rounded), label: 'settings'.tr),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Standard header - same as all other pages
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: TabHeader(title: ''),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('attendance_history'.tr, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: isDark ? Colors.white : _primary)),
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
                children: ['day', 'week', 'month'].map((val) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        final now = DateTime.now();
                        setState(() {
                          if (val == 'day') {
                            _dateRange = DateTimeRange(
                                start: DateTime(now.year, now.month, now.day),
                                end: DateTime(now.year, now.month, now.day));
                          } else if (val == 'week') {
                            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                            final endOfWeek = startOfWeek.add(const Duration(days: 6));
                            _dateRange = DateTimeRange(
                                start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
                                end: DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day));
                          } else if (val == 'month') {
                            final endOfMonth = DateTime(now.year, now.month + 1, 0);
                            _dateRange = DateTimeRange(
                                start: DateTime(now.year, now.month, 1),
                                end: DateTime(endOfMonth.year, endOfMonth.month, endOfMonth.day));
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        alignment: Alignment.center,
                        child: Text(val.tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
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

    // Helper to find value across multiple possible keys
    String _find(List<String> keys) {
      for (final k in item.keys) {
        if (keys.any((pk) => pk.toLowerCase().trim() == k.toString().toLowerCase().trim())) {
          final val = item[k];
          if (val != null && val.toString().trim().isNotEmpty && val.toString() != 'null') {
            return val.toString().trim();
          }
        }
      }
      return '00:00';
    }

    // Read hour fields directly from the API response
    String gsh = _find(['GrossHrs', 'GrossHr', 'GrossHours', 'GSH']);
    String nth = _find(['NetHrs', 'NetHr', 'NetHours', 'NTH']);
    String dih = _find(['DelayHrs', 'DelayHr', 'DelayHours', 'DIH']);
    String eoh = _find(['EarlyOutHrs', 'EarlyOutHr', 'EarlyOutHours', 'EOH']);
    String lsh = _find(['LessHrs', 'LessHr', 'LessHours', 'LSH']);
    String esh = _find(['ExcessHrs', 'ExcessHr', 'ExcessHours', 'ESH']);

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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (c) => const Center(child: CircularProgressIndicator()),
          );

          final homeController = Get.find<HomeController>();
          final actualDateStr = (item['AttDate'] ?? '').toString(); 
          
          String formattedApiDate = actualDateStr;
          try {
            if (actualDateStr.contains('/')) {
              final parts = actualDateStr.split('/');
              if (parts.length == 3) {
                 formattedApiDate = '${parts[2]}-${parts[1]}-${parts[0]}';
              }
            } else if (actualDateStr.contains('-')) {
              final parts = actualDateStr.split('-');
              if (parts.length == 3 && parts[0].length == 2) {
                 formattedApiDate = '${parts[2]}-${parts[1]}-${parts[0]}';
              }
            }
          } catch (_) {}
          
          final rawPunches = await homeController.fetchPunchesForDate(formattedApiDate);
          
          if (rawPunches.isNotEmpty) {
            final inAddr = item['CheckINAddr']?.toString() ?? '';
            final outAddr = item['CheckoutAddr']?.toString() ?? '';
            final fallbackLoc = item['Location']?.toString() ?? item['locationinfo']?.toString() ?? '';
            
            for (var punch in rawPunches) {
              // If punch has its own location data, preserve it — don't overwrite with summary-level data
              final hasPunchLocation = (punch['locationinfo']?.toString() ?? '').isNotEmpty ||
                  (punch['LocationInfo']?.toString() ?? '').isNotEmpty ||
                  (punch['Location']?.toString() ?? '').isNotEmpty;
              if (hasPunchLocation) continue;
              
              final t = punch['Type']?.toString().toUpperCase() ?? '';
              if (t == 'IN' && inAddr.isNotEmpty) punch['CheckINAddr'] = inAddr;
              else if (t == 'OUT' && outAddr.isNotEmpty) punch['CheckoutAddr'] = outAddr;
              if (fallbackLoc.isNotEmpty) punch['Location'] = fallbackLoc;
            }
          }
          
          Navigator.pop(ctx);
          AttendanceTab.showPunchesBottomSheet(ctx, [item], rawPunches.isNotEmpty ? rawPunches : [item]);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                      Icon(Icons.calendar_month_outlined, size: 16, color: (isDark ? Colors.white : Colors.grey[600])?.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Text('$monthStr $yearStr', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.grey[600])?.withValues(alpha: 0.7))),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(_label(type), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.grey[600])?.withValues(alpha: 0.8))),
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
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F3F6).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1A1C1E).withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        Text(dayStr, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1C1E), height: 1.0)),
                        const SizedBox(height: 4),
                        Text(weekdayStr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: (isDark ? Colors.white : const Color(0xFF3F4A3C)).withValues(alpha: 0.9))),
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
                                Expanded(child: _timeSection(ctx, 'check_in'.tr, checkIn.isNotEmpty ? checkIn : '--:--')),
                                Container(width: 1, height: 30, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                Expanded(child: _timeSection(ctx, 'check_out'.tr, checkOut.isNotEmpty ? checkOut : '--:--', isRight: true)),
                              ],
                            ),
                            if (gsh != '00:00' || nth != '00:00' || dih != '00:00' || eoh != '00:00' || lsh != '00:00' || esh != '00:00') ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    if (gsh != '00:00') _hoursChip(ctx, 'gsh'.tr, gsh, Colors.blue[600]!),
                                    if (nth != '00:00' || (gsh == '00:00' && lsh == '00:00' && dih == '00:00')) _hoursChip(ctx, 'nth'.tr, nth, const Color(0xFF059669)),
                                    if (dih != '00:00') _hoursChip(ctx, 'dih'.tr, dih, Colors.orange),
                                    if (eoh != '00:00') _hoursChip(ctx, 'eoh'.tr, eoh, Colors.deepOrange),
                                    if (lsh != '00:00') _hoursChip(ctx, 'lsh'.tr, lsh, const Color(0xFFE11D48)),
                                    if (esh != '00:00') _hoursChip(ctx, 'esh'.tr, esh, Colors.green),
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
        ),
      ),
    );
  }

  void _showPunchDetailsDialog(BuildContext context, dynamic item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String parsedDate = (item['AttDate'] ?? item['LogDate'] ?? '').toString();
    if (parsedDate.contains('T')) parsedDate = parsedDate.split('T')[0];
    
    String date = parsedDate;
    try {
      if (date.isNotEmpty) {
        if (date.contains('/')) {
          final parts = date.split('/');
          if (parts.length == 3) {
            int p1 = int.parse(parts[0]);
            int p2 = int.parse(parts[1]);
            int p3 = int.parse(parts[2]);
            if (p1 > 12) date = DateFormat('dd MMM yyyy').format(DateTime(p3, p2, p1));
            else if (p2 > 12) date = DateFormat('dd MMM yyyy').format(DateTime(p3, p1, p2));
            else date = DateFormat('dd MMM yyyy').format(DateTime(p3, p2, p1));
          }
        } else {
          date = DateFormat('dd MMM yyyy').format(DateTime.parse(date));
        }
      }
    } catch (_) {}
    final checkIn = (item['CheckIN'] ?? '--:--').toString();
    final checkOut = (item['CheckOut'] ?? '--:--').toString();
    final type = (item['DayType'] ?? '').toString();
    
    // Extract location intelligently from multiple possible fields
    String location = 'Location data unavailable';
    final checkInAddr = (item['CheckINAddr'] ?? '').toString().trim();
    final checkOutAddr = (item['CheckoutAddr'] ?? '').toString().trim();
    
    if (checkInAddr.isNotEmpty && checkInAddr != '0.000000,0.000000') {
      location = checkInAddr.replaceAll('Address :', '').trim();
    } else if (checkOutAddr.isNotEmpty && checkOutAddr != '0.000000,0.000000') {
      location = checkOutAddr.replaceAll('Address :', '').trim();
    } else {
      location = (item['Location'] ?? item['locationinfo'] ?? 'Location data unavailable').toString();
    }

    final deviceId = (item['DeviceID'] ?? item['deviceinfo'] ?? 'Device info unavailable').toString();
    
    // Clean up backend location duplication bugs based on device type
    final dLow = deviceId.toLowerCase();
    if (dLow.contains('external') || dLow.contains('adms')) {
      location = 'Location data unavailable';
    } else if (!dLow.contains('bluetooth') && !dLow.contains('ble') && location.toLowerCase().contains('ble beacon')) {
      location = 'Location data unavailable';
    }

    final selfieUrl = (item['SelfieUrl'] ?? item['PunchImage'] ?? '').toString();

    // Extract raw GPS coordinates from CheckINAddr or CheckoutAddr
    String? mapLat, mapLng;
    final coordRegex = RegExp(r'(-?\d+\.\d+)[,/](-?\d+\.\d+)');
    for (final addr in [checkInAddr, checkOutAddr]) {
      final match = coordRegex.firstMatch(addr);
      if (match != null) {
        final lat = double.tryParse(match.group(1)!);
        final lng = double.tryParse(match.group(2)!);
        if (lat != null && lng != null && (lat != 0 || lng != 0)) {
          mapLat = match.group(1);
          mapLng = match.group(2);
          break;
        }
      }
    }
    final hasCoords = mapLat != null && mapLng != null;
    final googleMapsUrl = hasCoords ? 'https://maps.google.com/?q=$mapLat,$mapLng' : null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Punch Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              const SizedBox(height: 20),
              
              if (selfieUrl.isNotEmpty) 
                Center(
                  child: Container(
                    height: 120, width: 90, 
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(image: NetworkImage(selfieUrl), fit: BoxFit.cover),
                    ),
                  ),
                )
              else 
                Center(
                  child: Container(
                    height: 100, width: 100,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey[100], 
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(Icons.person_outline, size: 48, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  ),
                ),
              const SizedBox(height: 24),
              
              _detailRow('Date', date, isDark),
              _detailRow('Status', _label(type), isDark),
              const SizedBox(height: 16),
              
              // Grouped Check In/Out Times
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _detailRow('Check In', checkIn.isEmpty ? '--:--' : checkIn, isDark),
                    _detailRow('Check Out', checkOut.isEmpty ? '--:--' : checkOut, isDark),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              _detailRow('Device', deviceId, isDark),

              // Google Maps preview (using InAppWebView to render iframe like web without APIs)
              if (hasCoords) ...[  
                const SizedBox(height: 12),
                const Text('Location Map', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 150, 
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.grey[200],
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(googleMapsUrl!);
                        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      child: AbsorbPointer(
                        child: InAppWebView(
                          initialSettings: InAppWebViewSettings(
                            transparentBackground: true,
                            disableHorizontalScroll: true,
                            disableVerticalScroll: true,
                            supportZoom: false,
                            builtInZoomControls: false,
                            displayZoomControls: false,
                          ),
                          onWebViewCreated: (controller) {
                            final String htmlContent = '''
                              <!DOCTYPE html>
                              <html>
                                <head>
                                  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                                  <style>body { margin: 0; padding: 0; overflow: hidden; background-color: transparent; }</style>
                                </head>
                                <body>
                                  <iframe src="https://maps.google.com/maps?width=100%25&amp;hl=en&amp;q=$mapLat,$mapLng&amp;t=&amp;z=14&amp;ie=UTF8&amp;iwloc=B&amp;output=embed" width="100%" height="150" frameborder="0" scrolling="no" marginheight="0" marginwidth="0"></iframe>
                                </body>
                              </html>
                            ''';
                            controller.loadData(data: htmlContent);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90, 
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[500]))
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)))
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
          Text(displayTime, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

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
      case 'holiday':                                       return 'holiday'.tr;
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
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
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
