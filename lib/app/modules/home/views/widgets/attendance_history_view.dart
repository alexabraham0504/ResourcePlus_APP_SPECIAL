import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:get_storage/get_storage.dart';

import '../../../../config/api_endpoints.dart';
import '../../../../controllers/language_controller.dart';
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

  final HomeController _controller = Get.find<HomeController>();

  String _selectedPeriod = 'This Week';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isLoading = false;
  Map<String, dynamic>? _summaryData;

  final List<String> _periods = [
    'Today',
    'This Week',
    'Last Week',
    'This Month',
    'Last Month',
    'This Year',
    'Last Year',
    'Select Date',
    'All'
  ];

  @override
  void initState() {
    super.initState();
    _updateDatesFromPeriod();
    _fetchSummaryData();
  }

  void _updateDatesFromPeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_selectedPeriod) {
      case 'Today':
        _fromDate = today;
        _toDate = today;
        break;
      case 'This Week':
        _fromDate = today.subtract(Duration(days: today.weekday - 1));
        _toDate = _fromDate!.add(const Duration(days: 6));
        if (_toDate!.isAfter(today)) _toDate = today; // Cap to today
        break;
      case 'Last Week':
        final lastWeekStart = today.subtract(Duration(days: today.weekday - 1 + 7));
        _fromDate = lastWeekStart;
        _toDate = _fromDate!.add(const Duration(days: 6));
        break;
      case 'This Month':
        _fromDate = DateTime(today.year, today.month, 1);
        _toDate = DateTime(today.year, today.month + 1, 0);
        if (_toDate!.isAfter(today)) _toDate = today; // Cap to today
        break;
      case 'Last Month':
        _fromDate = DateTime(today.year, today.month - 1, 1);
        _toDate = DateTime(today.year, today.month, 0);
        break;
      case 'This Year':
        _fromDate = DateTime(today.year, 1, 1);
        _toDate = DateTime(today.year, 12, 31);
        if (_toDate!.isAfter(today)) _toDate = today; // Cap to today
        break;
      case 'Last Year':
        _fromDate = DateTime(today.year - 1, 1, 1);
        _toDate = DateTime(today.year - 1, 12, 31);
        break;
      case 'Select Date':
        _fromDate ??= today;
        _toDate ??= today;
        break;
      case 'All':
        _fromDate = null;
        _toDate = null;
        break;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    // Automatically switch to 'Select Date' if they tap the date field
    if (_selectedPeriod != 'Select Date') {
      setState(() {
        _selectedPeriod = 'Select Date';
      });
    }
    
    final initialDate = isFrom ? (_fromDate ?? DateTime.now()) : (_toDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
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

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_toDate != null && picked.isAfter(_toDate!)) {
            _toDate = picked;
          }
        } else {
          _toDate = picked;
          if (_fromDate != null && picked.isBefore(_fromDate!)) {
            _fromDate = picked;
          }
        }
      });
    }
  }

  Future<void> _fetchSummaryData() async {
    setState(() => _isLoading = true);
    try {
      final email = GetStorage().read('username') ?? '';
      final instance = GetStorage().read('instanceName') ?? '';
      final langId = Get.find<LanguageController>().currentLanguage.value == 'ar' ? '2' : '1';
      
      String fromStr = '';
      String toStr = '';
      if (_fromDate != null) fromStr = DateFormat('yyyy-MM-dd').format(_fromDate!);
      if (_toDate != null) toStr = DateFormat('yyyy-MM-dd').format(_toDate!);

      final uri = Uri.parse('${ApiEndpoints.getAttendanceSummary}?usrEmail=$email&fromDate=$fromStr&toDate=$toStr&instanceName=$instance&lang=$langId');
      
      final ioClient = HttpClient()..badCertificateCallback = ((_, __, ___) => true);
      final client = io_client.IOClient(ioClient);
      
      var response = await client.get(uri);
      
      // Fallback for missing /Mobile prefix
      if (response.statusCode == 404) {
        final fallbackUri = Uri.parse('${ApiEndpoints.baseUrl}/Mobile/api/AI/AttendanceSummary?usrEmail=$email&fromDate=$fromStr&toDate=$toStr&instanceName=$instance&lang=$langId');
        response = await client.get(fallbackUri);
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _summaryData = data;
        });
      } else {
         debugPrint('API Error: ${response.statusCode} - ${response.body}');
         // Try to parse the error message if any
         String errorMsg = 'server_error'.tr;
         try {
           final errData = json.decode(response.body);
           if (errData['Message'] != null) errorMsg = errData['Message'];
         } catch (_) {}
         Get.snackbar('error'.tr, errorMsg, backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint('Error fetching summary: $e');
      Get.snackbar('error'.tr, 'network_error'.tr, backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTranslationForPeriod(String period) {
    switch (period) {
      case 'Today': return 'today'.tr;
      case 'This Week': return 'this_week'.tr;
      case 'Last Week': return 'last_week'.tr;
      case 'This Month': return 'this_month'.tr;
      case 'Last Month': return 'last_month'.tr;
      case 'This Year': return 'this_year'.tr;
      case 'Last Year': return 'last_year'.tr;
      case 'Select Date': return 'select_date'.tr;
      case 'All': return 'all_period'.tr;
      default: return period;
    }
  }

  Widget _buildSearchCriteria(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: isDark ? Colors.white : _primary),
              const SizedBox(width: 8),
              Text('search_criteria'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : _primary)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Period Dropdown
          Text('period'.tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedPeriod,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[600]),
                items: _periods.map((String period) {
                  return DropdownMenuItem<String>(
                    value: period,
                    child: Text(_getTranslationForPeriod(period), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : _primary)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedPeriod = newValue;
                      _updateDatesFromPeriod();
                    });
                  }
                },
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Dates Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('from_date'.tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _selectDate(context, true),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedPeriod == 'Select Date' ? (isDark ? const Color(0xFF0F172A) : Colors.white) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fromDate != null ? DateFormat('dd/MM/yyyy').format(_fromDate!) : '',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _selectedPeriod == 'Select Date' ? (isDark ? Colors.white : _primary) : Colors.grey[500]),
                            ),
                            Icon(Icons.calendar_month_rounded, size: 18, color: Colors.grey[500]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('to_date'.tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _selectDate(context, false),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _selectedPeriod == 'Select Date' ? (isDark ? const Color(0xFF0F172A) : Colors.white) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _toDate != null ? DateFormat('dd/MM/yyyy').format(_toDate!) : '',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _selectedPeriod == 'Select Date' ? (isDark ? Colors.white : _primary) : Colors.grey[500]),
                            ),
                            Icon(Icons.calendar_month_rounded, size: 18, color: Colors.grey[500]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // View Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006E1C), // Corporate Green
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _fetchSummaryData,
              child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.analytics_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text('view'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    if (_summaryData == null) return const SizedBox.shrink();
    
    final counts = _summaryData!['Attendance Counts'] as List<dynamic>? ?? [];
    int present = 0, less = 0, absent = 0;
    
    for (var c in counts) {
      if (c['CountType'] == 'Present') present = c['NoOfDays'] ?? 0;
      if (c['CountType'] == 'Less') less = c['NoOfDays'] ?? 0;
      if (c['CountType'] == 'Absent') absent = c['NoOfDays'] ?? 0;
    }

    final rates = _summaryData!['Attendance Rate'] as List<dynamic>? ?? [];
    String presentPerc = '0.00', absentPerc = '0.00';
    if (rates.isNotEmpty) {
      presentPerc = rates[0]['PresentPercentage']?.toString() ?? '0.00';
      absentPerc = rates[0]['AbsentPercentage']?.toString() ?? '0.00';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _statCard('present_percentage'.tr, '$presentPerc%', Colors.green, isDark),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('absent_percentage'.tr, '$absentPerc%', Colors.red, isDark),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('less'.tr, less.toString(), Colors.orange, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]), textAlign: TextAlign.center, maxLines: 2),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _onDayTapped(Map<String, dynamic> day) async {
    final dateStr = day['AttDate']?.toString() ?? '';
    if (dateStr.isEmpty) return;
    
    // Parse DD/MM/YYYY into YYYY-MM-DD
    String apiDate = dateStr;
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        apiDate = '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    } catch (_) {}
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final rawPunches = await _controller.fetchPunchesForDate(apiDate);
      if (mounted) Navigator.pop(context); // Close loading
      
      if (rawPunches.isEmpty) {
        Get.snackbar('notice'.tr, 'no_punches_found'.tr, snackPosition: SnackPosition.BOTTOM);
        return;
      }

      // Try to find the detailed record from cached GetAttData to get the location fallback
      final storage = GetStorage();
      final cachedData = storage.read('cachedAttendanceData');
      String inAddr = day['CheckINAddr']?.toString() ?? '';
      String outAddr = day['CheckoutAddr']?.toString() ?? '';
      String fallbackLoc = day['Location']?.toString() ?? day['locationinfo']?.toString() ?? '';

      if (cachedData != null && cachedData is Map && cachedData.containsKey('Recent Activites')) {
        try {
          final activitiesList = cachedData['Recent Activites'] as List;
          for (var item in activitiesList) {
            if (item is Map) {
              final itemDate = item['AttDate']?.toString() ?? '';
              // Match by date string (e.g. "05/10/2026")
              if (itemDate.isNotEmpty && dateStr.isNotEmpty && itemDate.split(' ').first == dateStr.split(' ').first) {
                if (inAddr.isEmpty) inAddr = item['CheckINAddr']?.toString() ?? '';
                if (outAddr.isEmpty) outAddr = item['CheckoutAddr']?.toString() ?? '';
                if (fallbackLoc.isEmpty) fallbackLoc = item['Location']?.toString() ?? item['locationinfo']?.toString() ?? item['LocationInfo']?.toString() ?? '';
                break;
              }
            }
          }
        } catch (_) {}
      }

      for (var punch in rawPunches) {
        final hasPunchLocation = (punch['locationinfo']?.toString() ?? '').isNotEmpty ||
            (punch['LocationInfo']?.toString() ?? '').isNotEmpty ||
            (punch['Location']?.toString() ?? '').isNotEmpty ||
            (punch['CheckINAddr']?.toString() ?? '').isNotEmpty ||
            (punch['CheckoutAddr']?.toString() ?? '').isNotEmpty ||
            (punch['Latitude']?.toString() ?? '').isNotEmpty ||
            (punch['PunchLat']?.toString() ?? '').isNotEmpty ||
            (punch['Lat']?.toString() ?? '').isNotEmpty;
            
        if (hasPunchLocation) continue;
        
        final type = (punch['PunchType'] ?? punch['Type'] ?? '').toString().toUpperCase();
        if (type == 'IN' && inAddr.isNotEmpty) punch['CheckINAddr'] = inAddr;
        else if (type == 'OUT' && outAddr.isNotEmpty) punch['CheckoutAddr'] = outAddr;
        
        if (fallbackLoc.isNotEmpty) {
          punch['Location'] = fallbackLoc;
        }
      }
      
      AttendanceTab.showPunchesBottomSheet(
        context,
        [day], // Passing the day data as summary list
        rawPunches,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      Get.snackbar('error'.tr, 'failed_fetch_punches'.tr, backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Widget _buildCards(bool isDark) {
    if (_summaryData == null) return const SizedBox.shrink();
    
    final days = _summaryData!['Days'] as List<dynamic>? ?? [];
    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('no_punch_records'.tr, style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600])),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final day = days[index];
        final dayType = day['DayType']?.toString().toLowerCase().trim() ?? '';
        final actualDateStr = day['AttDate']?.toString() ?? '';
        
        Color statusColor = _neutral;
        if (dayType.contains('present') || dayType.contains('regular')) statusColor = _present;
        else if (dayType.contains('absent')) statusColor = _absent;
        else if (dayType.contains('late') || dayType.contains('half')) statusColor = _late;
        else if (dayType.contains('week end') || dayType.contains('leave')) statusColor = _weekend;

        String monthStr = '';
        String yearStr = '';
        String dayStr = '';
        String weekdayStr = '';

        try {
          if (actualDateStr.contains('/')) {
            final parts = actualDateStr.split('/');
            if (parts.length >= 3) {
              int d = int.parse(parts[0]);
              int m = int.parse(parts[1]);
              int y = int.parse(parts[2]);
              DateTime dt = (d > 12 && m <= 12) ? DateTime(y, m, d) : ((m > 12 && d <= 12) ? DateTime(y, d, m) : DateTime(y, m, d));
              monthStr = DateFormat('MMMM').format(dt).tr;
              yearStr = DateFormat('yyyy').format(dt);
              dayStr = DateFormat('dd').format(dt);
              weekdayStr = DateFormat('EEE').format(dt).tr;
            }
          }
        } catch (_) {}
        
        if (dayStr.isEmpty && actualDateStr.isNotEmpty) {
           dayStr = actualDateStr.split('/').first;
        }

        String overallCheckIn = (day['CheckIN'] ?? '').toString().trim();
        String overallCheckOut = (day['CheckOut'] ?? '').toString().trim();
        overallCheckIn = overallCheckIn.replaceAll('AM', 'am'.tr).replaceAll('PM', 'pm'.tr).replaceAll('am', 'am'.tr).replaceAll('pm', 'pm'.tr);
        overallCheckOut = overallCheckOut.replaceAll('AM', 'am'.tr).replaceAll('PM', 'pm'.tr).replaceAll('am', 'am'.tr).replaceAll('pm', 'pm'.tr);
        final nth = (day['NetHrs'] ?? '').toString().trim();
        final lsh = (day['LessHrs'] ?? '').toString().trim();

        return InkWell(
          onTap: () => _onDayTapped(day),
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
                        Text('$monthStr $yearStr'.trim(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.grey[600])?.withValues(alpha: 0.7))),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text((day['DayType']?.toString() ?? '').tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: (isDark ? Colors.white : Colors.grey[600])?.withValues(alpha: 0.8))),
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
                      child: Column(
                        children: [
                          if (overallCheckIn.isEmpty && overallCheckOut.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('no_punch_data'.tr, style: TextStyle(fontSize: 13, color: Colors.grey[400], fontStyle: FontStyle.italic)),
                              ),
                            )
                          else ...[
                            Row(
                              children: [
                                Expanded(child: _timeSection(context, 'check_in'.tr, overallCheckIn.isNotEmpty ? overallCheckIn : '--:--', isDark)),
                                Container(width: 1, height: 30, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                Expanded(child: _timeSection(context, 'check_out'.tr, overallCheckOut.isNotEmpty ? overallCheckOut : '--:--', isDark, isRight: true)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Center(child: _hoursChip(context, 'nth'.tr, nth.isNotEmpty ? nth : '00:00', const Color(0xFF059669), isDark))),
                                  Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  Expanded(child: Center(child: _hoursChip(context, 'lsh'.tr, lsh.isNotEmpty ? lsh : '00:00', const Color(0xFFE11D48), isDark))),
                                ],
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _timeSection(BuildContext context, String label, String time, bool isDark, {bool isRight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isRight) Icon(Icons.login_rounded, size: 14, color: Colors.grey[400]),
            if (!isRight) const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[500], fontWeight: FontWeight.w500)),
            if (isRight) const SizedBox(width: 4),
            if (isRight) Icon(Icons.logout_rounded, size: 14, color: Colors.grey[400]),
          ],
        ),
        const SizedBox(height: 4),
        Text(time, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.grey[200] : const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _hoursChip(BuildContext context, String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: (isDark ? Colors.white : Colors.grey[600])?.withValues(alpha: 0.7))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : _bg,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
          selectedItemColor: const Color(0xFF006E1C),
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
            // Standard header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: TabHeader(title: ''),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text('attendance_history'.tr, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: isDark ? Colors.white : _primary)),
                ],
              ),
            ),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchSummaryData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildSearchCriteria(isDark),
                    const SizedBox(height: 8),
                    _buildSummaryCards(isDark),
                    _buildCards(isDark),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
