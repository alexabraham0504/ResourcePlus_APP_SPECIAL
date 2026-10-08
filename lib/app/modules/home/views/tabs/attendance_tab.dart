import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../controllers/home_controller.dart';
import '../widgets/tab_header.dart';
import '../../../../routes/app_routes.dart';
import '../../../../controllers/language_controller.dart';

Uint8List? decodeBase64Background(String base64Str) {
  try {
    return base64Decode(base64Str.replaceAll('\n', '').replaceAll('\r', ''));
  } catch (e) {
    return null;
  }
}

class AttendanceTab extends GetView<HomeController> {
  const AttendanceTab({super.key});

  // ═══════════════════════════════════════════════════════════
  //  REUSABLE ACRONYM DIALOG
  // ═══════════════════════════════════════════════════════════
  static void showHourAcronymsDialog(BuildContext context, bool isDark) {
    Widget acronymItem(String acr, String full, Color c, bool dark) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withValues(alpha: 0.5))),
              child: Text(acr, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(full, style: TextStyle(color: dark ? Colors.grey[200] : Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 14))),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (bCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('hour_acronyms'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 16),
              acronymItem('GSH', 'gsh_desc'.tr, Colors.blue, isDark),
              acronymItem('NTH', 'nth_desc'.tr, Colors.lightBlue, isDark),
              acronymItem('DIH', 'dih_desc'.tr, Colors.orange, isDark),
              acronymItem('EOH', 'eoh_desc'.tr, Colors.deepOrange, isDark),
              acronymItem('LSH', 'lsh_desc'.tr, Colors.red, isDark),
              acronymItem('ESH', 'esh_desc'.tr, Colors.green, isDark),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(bCtx),
                  child: Text('close'.tr, style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

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
    final t = dayType.toLowerCase().trim();
    if (t == 'present' || t == 'حاضر') return _present;
    if (t.contains('absent') || t.contains('غائب')) return _absent;
    if (t.contains('late') || t.contains('متأخر') || t.contains('تأخير') || t.contains('half')) return _late;
    if (t.contains('early') || t.contains('مبكر')) return _present;
    if (t.contains('week end') || t.contains('weekend') || t.contains('نهاية') || t.contains('leave') || t.contains('إجازة')) return _weekend;
    return _neutral;
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabHeader(title: 'attendance_overview'.tr),
                  const SizedBox(height: 16),
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
          if (!isDark) BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
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
            var type = (item['CountType'] ?? item['Type'] ?? item['status'] ?? '').toString().trim();
            
            // Fallback for Arabic API translation issues where CountType might return empty string
            if (type.isEmpty) {
              if (i == 0) type = 'present';
              else if (i == 1) type = 'absent';
              else if (i == 2) type = 'late';
            }
            
            final days = item['NoOfDays'] ?? item['days'] ?? item['count'] ?? 0;
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

    final types = <String>{'All'};
    for (final a in controller.recentActivities) {
      final dt = (a['DayType'] ?? '').toString();
      if (dt.isNotEmpty) types.add(dt);
    }

    List filtered = controller.attendanceFilter.value == 'All'
        ? controller.recentActivities.toList()
        : controller.recentActivities.where((a) => (a['DayType'] ?? '').toString() == controller.attendanceFilter.value).toList();

    final limit = controller.attendanceDisplayCount.value;
    final showAll = limit >= 999;
    final display = showAll ? filtered : filtered.take(limit).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('recent_records'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : _primary)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showHourAcronymsDialog(ctx, isDark),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.info_outline, size: 18, color: Colors.blue[600]),
                ),
              ),
            ],
          ),
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

      if (filtered.isEmpty)
        _emptyState(ctx)
      else ...[
        Builder(
          builder: (context) {
            final Map<String, List<Map<String, dynamic>>> grouped = {};
            for (final a in filtered) {
              final d = (a['AttDate'] ?? '').toString();
              grouped.putIfAbsent(d, () => []).add(a);
            }
            
            final limit = controller.attendanceDisplayCount.value;
            final showAll = limit >= 999;
            final entries = grouped.entries.toList();
            final displayEntries = showAll ? entries : entries.take(limit > 5 ? 5 : limit).toList();

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayEntries.length > 5 ? 5 : displayEntries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _groupedRecordCard(ctx, displayEntries[i].key, displayEntries[i].value),
            );
          },
        ),
      ]
    ]);
  }

  // ─── Professional Record Card (Grouped) ──────────────────────────────
  Widget _groupedRecordCard(BuildContext ctx, String dateStrOriginal, List<Map<String, dynamic>> records) {
    if (records.isEmpty) return const SizedBox.shrink();
    
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final firstRecord = records.first;
    final date = firstRecord['AttDate'] ?? '';
    final type = (firstRecord['DayType'] ?? '').toString();
    final color = _statusColor(type);

    String find(List<String> keys) {
      for (final k in firstRecord.keys) {
        if (keys.any((pk) => pk.toLowerCase().trim() == k.toString().toLowerCase().trim())) {
          final val = firstRecord[k];
          if (val != null && val.toString().trim().isNotEmpty && val.toString() != 'null') {
            return val.toString().trim();
          }
        }
      }
      return '';
    }

    String nth = find(['NetHrs', 'NetHr', 'NetHours']);
    String lsh = find(['LessHrs', 'LessHr', 'LessHours']);
    if (nth.isEmpty) nth = '00:00';
    if (lsh.isEmpty) lsh = '00:00';

    String dayStr = '--';
    String weekdayStr = '---';
    String monthStr = '---';
    String yearStr = '';
    try {
      final isAr = Get.find<LanguageController>().currentLanguage.value == 'ar';
      final weekdaysAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
      final monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

      void formatDates(DateTime d) {
         dayStr = DateFormat('dd').format(d);
         yearStr = DateFormat('yyyy').format(d);
         if (isAr) {
           weekdayStr = weekdaysAr[d.weekday - 1];
           monthStr = monthsAr[d.month - 1];
         } else {
           weekdayStr = DateFormat('EEE').format(d);
           monthStr = DateFormat('MMMM').format(d);
         }
      }

      final parts = date.split('/');
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (day > 12 && month <= 12) {
          formatDates(DateTime(year, month, day));
        } else if (month > 12 && day <= 12) {
          formatDates(DateTime(year, day, month));
        } else {
          formatDates(DateTime(year, month, day));
        }
      } else {
        formatDates(DateFormat('yyyy-MM-dd').parse(date));
      }
    } catch (_) {}

    String overallCheckIn = '';
    String overallCheckOut = '';
    
    for (var r in records) {
      final cin = (r['CheckIN'] ?? '').toString();
      if (overallCheckIn.isEmpty && cin.isNotEmpty) overallCheckIn = cin;
    }
    for (var r in records.reversed) {
      final cout = (r['CheckOut'] ?? '').toString();
      if (overallCheckOut.isEmpty && cout.isNotEmpty) overallCheckOut = cout;
    }

    overallCheckIn = overallCheckIn.replaceAll('AM', 'am'.tr).replaceAll('PM', 'pm'.tr).replaceAll('am', 'am'.tr).replaceAll('pm', 'pm'.tr);
    overallCheckOut = overallCheckOut.replaceAll('AM', 'am'.tr).replaceAll('PM', 'pm'.tr).replaceAll('am', 'am'.tr).replaceAll('pm', 'pm'.tr);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (records.isEmpty) return;
          
          showDialog(
            context: ctx,
            barrierDismissible: false,
            builder: (c) => const Center(child: CircularProgressIndicator()),
          );

          final homeController = Get.find<HomeController>();
          final actualDateStr = (records.first['AttDate'] ?? '').toString(); 
          
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
          
          if (rawPunches.isNotEmpty && records.isNotEmpty) {
            final summary = records.first;
            final inAddr = summary['CheckINAddr']?.toString() ?? '';
            final outAddr = summary['CheckoutAddr']?.toString() ?? '';
            final fallbackLoc = summary['Location']?.toString() ?? summary['locationinfo']?.toString() ?? '';
            
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
          }
          
          Navigator.pop(ctx);
          showPunchesBottomSheet(ctx, records, rawPunches.isNotEmpty ? rawPunches : records);
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
                              Expanded(child: _timeSection(ctx, 'check_in'.tr, overallCheckIn.isNotEmpty ? overallCheckIn : '--:--')),
                              Container(width: 1, height: 30, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              Expanded(child: _timeSection(ctx, 'check_out'.tr, overallCheckOut.isNotEmpty ? overallCheckOut : '--:--', isRight: true)),
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
                                Expanded(child: Center(child: _hoursChip(ctx, 'nth'.tr, nth, const Color(0xFF059669)))),
                                Container(width: 1, height: 24, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                Expanded(child: Center(child: _hoursChip(ctx, 'lsh'.tr, lsh, const Color(0xFFE11D48)))),
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PUNCHES BOTTOM SHEET & GRID & DETAILS (Public Static)
  // ═══════════════════════════════════════════════════════════

  static Widget buildPunchGrid(BuildContext context, List<dynamic> punches, bool isDark) {
    if (punches.isEmpty) return const SizedBox.shrink();
    
    // Sort punches latest to oldest
    final sortedPunches = List<dynamic>.from(punches);
    sortedPunches.sort((a, b) {
      final tA = (a['time'] ?? a['PunchTime'] ?? '').toString();
      final tB = (b['time'] ?? b['PunchTime'] ?? '').toString();
      try {
        final df = DateFormat('hh:mm a');
        final dA = df.parse(tA);
        final dB = df.parse(tB);
        final cmp = dB.compareTo(dA); // latest to oldest
        
        // If times are exactly the same (e.g. 02:46 PM), OUT happens after IN.
        // Therefore, OUT is newer and should come first in the list.
        if (cmp == 0) {
          final typeA = ((a['type'] ?? a['PunchType'] ?? '') as String).toUpperCase();
          final typeB = ((b['type'] ?? b['PunchType'] ?? '') as String).toUpperCase();
          final isOutA = typeA.contains('OUT') || typeA.contains('خروج') || typeA.contains('انصراف');
          final isInA = typeA.contains('IN') || typeA.contains('دخول') || typeA.contains('حضور');
          final isOutB = typeB.contains('OUT') || typeB.contains('خروج') || typeB.contains('انصراف');
          final isInB = typeB.contains('IN') || typeB.contains('دخول') || typeB.contains('حضور');
          
          if (isOutA && isInB) return -1;
          if (isOutB && isInA) return 1;
        }
        
        return cmp;
      } catch (_) {
        return tB.compareTo(tA); // fallback string compare
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('punch_details'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : _primary)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(sortedPunches.length, (index) {
            final punch = sortedPunches[index];
            String timeVal = (punch['time'] ?? punch['PunchTime'] ?? '').toString();
            timeVal = timeVal.replaceAll('AM', 'am'.tr).replaceAll('PM', 'pm'.tr).replaceAll('am', 'am'.tr).replaceAll('pm', 'pm'.tr);
            final punchType = ((punch['type'] ?? punch['PunchType'] ?? 'IN') as String).toUpperCase();
            String device = (punch['device'] ?? punch['DeviceName'] ?? '').toString();
            
            // Only mark as Selfie if backend sent actual image URL/bytes.
            // Fingerprint/BLE punches also have PunchImage keys — must NOT mark those as Selfie.
            if (!device.toLowerCase().contains('face') &&
                !device.toLowerCase().contains('selfie') &&
                !device.toLowerCase().contains('finger') &&
                !device.toLowerCase().contains('bluetooth') &&
                !device.toLowerCase().contains('ble') &&
                !device.toLowerCase().contains('qr')) {
              bool hasRealImage = false;
              final recordObj = punch['record'] ?? punch;
              if (recordObj is Map) {
                for (final k in recordObj.keys) {
                  final lowerK = k.toString().toLowerCase();
                  // Only SelfieUrl and PunchImageByte are exclusive to selfie punches
                  if (lowerK == 'selfieurl' || lowerK == 'punchimagebyte' || lowerK == 'punch_image_byte') {
                    final v = recordObj[k]?.toString().trim();
                    if (v != null && v.isNotEmpty && v != 'null' && v.length > 10) {
                      hasRealImage = true;
                      break;
                    }
                  }
                }
              }
              if (hasRealImage) device = 'Selfie ($device)';
            }
            
            final record = punch['record'] ?? punch;
            final pType = punchType.trim().toUpperCase();
            final isOut = pType.contains('OUT') || pType.contains('خروج') || pType.contains('انصراف');
            return InkWell(
              onTap: () {
                showPunchDetailsDialog(context, record);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 100,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155).withValues(alpha: 0.3) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF475569) : Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: isOut ? Colors.red : Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(punchType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isOut ? Colors.red : Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDeviceIconStatic(device, isDark),
                    const SizedBox(height: 4),
                    Text(timeVal, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[200] : Colors.grey[800])),
                    if (device.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(_translateDevice(device), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    ]
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  static String _translateDevice(String deviceName) {
    final dLow = deviceName.toLowerCase();
    if (dLow.contains('android')) return 'android_mobile'.tr;
    if (dLow.contains('ios') || dLow.contains('iphone') || dLow.contains('ipad')) return 'ios_mobile'.tr;
    if (dLow.contains('finger')) return 'fingerprint'.tr;
    if (dLow.contains('face')) return 'face_punch'.tr;
    if (dLow.contains('selfie')) return 'selfie_punch'.tr;
    if (dLow.contains('blue') || dLow.contains('ble')) return 'bluetooth'.tr;
    if (dLow.contains('qr')) return 'qr_scan'.tr;
    return deviceName; // return as is if no match
  }

  static Widget _buildDeviceIconStatic(String deviceName, bool isDarkMode) {
    IconData deviceIcon = Icons.person_outline;
    final dLow = deviceName.toLowerCase();
    if (dLow.contains('finger')) deviceIcon = Icons.fingerprint;
    else if (dLow.contains('face')) deviceIcon = Icons.face;
    else if (dLow.contains('selfie')) deviceIcon = Icons.camera_alt_rounded;
    else if (dLow.contains('blue') || dLow.contains('ble')) deviceIcon = Icons.bluetooth;
    else if (dLow.contains('mobile')) deviceIcon = Icons.phone_android;
    else if (dLow.contains('web')) deviceIcon = Icons.language;
    else if (dLow.contains('external')) deviceIcon = Icons.devices;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      height: 36, width: 36,
      decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E293B) : Colors.grey[200], shape: BoxShape.circle),
      child: Icon(deviceIcon, size: 20, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
    );
  }

  static void showPunchesBottomSheet(BuildContext context, List<Map<String, dynamic>> summaryRecords, List<Map<String, dynamic>> rawPunches) {
    if (summaryRecords.isEmpty) return;
    
    final homeController = Get.find<HomeController>();
    final firstRecord = summaryRecords.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String find(List<String> keys) {
      for (final k in firstRecord.keys) {
        final cleanApiKey = k.toString().replaceAll(' ', '').replaceAll('_', '').toLowerCase().trim();
        if (keys.any((pk) => pk.replaceAll(' ', '').replaceAll('_', '').toLowerCase().trim() == cleanApiKey)) {
          final val = firstRecord[k];
          if (val != null && val.toString().trim().isNotEmpty && val.toString() != 'null') {
            return val.toString().trim();
          }
        }
      }
      return '';
    }

    final empName = homeController.profileEmployeeName.value;
    final empNo = homeController.profileEmpNumber.value;
    final type = (firstRecord['DayType'] ?? 'Regular').toString();
    final dateRawFull = (firstRecord['AttDate'] ?? '').toString();
    final dateRaw = dateRawFull.split(' ').first.split('T').first; // Strip time
    String date = dateRawFull;
    try {
      if (dateRaw.contains('/')) {
        final parts = dateRaw.split('/');
        if (parts.length >= 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          DateTime d = (day > 12 && month <= 12) ? DateTime(year, month, day) : ((month > 12 && day <= 12) ? DateTime(year, day, month) : DateTime(year, month, day));
          date = DateFormat('dd-MM-yyyy EEE').format(d);
        }
      } else if (dateRaw.contains('-')) {
        final parts = dateRaw.split('-');
        if (parts.length >= 3) {
          int p0 = int.parse(parts[0]);
          int p1 = int.parse(parts[1]);
          int p2 = int.parse(parts[2]);
          DateTime d;
          if (p0 > 1000) {
            d = DateTime(p0, p1, p2); // yyyy-MM-dd
          } else {
            d = (p0 > 12 && p1 <= 12) ? DateTime(p2, p1, p0) : ((p1 > 12 && p0 <= 12) ? DateTime(p2, p0, p1) : DateTime(p2, p1, p0)); // dd-MM-yyyy
          }
          date = DateFormat('dd-MM-yyyy EEE').format(d);
        }
      }
    } catch (_) {}

    String shift = find(['Shift', 'ShiftName', 'Shift_Name']);
    if (shift.isEmpty) shift = 'general_shift'.tr;
    
    final shiftIn = find(['ShiftInTime', 'ShiftIn', 'StartTime', 'ExpectedIn', 'ShiftStartTime', 'InTime', 'Shift_In', 'Shift_In_Time', 'expected_in', 'expected_in_time', 'expectedin', 'Start_Time', 'SInTime', 'SIn', 'Shift_Start', 'Expected_Start', 'shift_in', 'exp_in', 'ExpectedCheckIn', 'ScheduledIn', 'ShiftInHr', 'TimeIn', 'ShiftStart']);
    final shiftOut = find(['ShiftOutTime', 'ShiftOut', 'EndTime', 'ExpectedOut', 'ShiftEndTime', 'OutTime', 'Shift_Out', 'Shift_Out_Time', 'expected_out', 'expected_out_time', 'expectedout', 'End_Time', 'SOutTime', 'SOut', 'Shift_End', 'Expected_End', 'shift_out', 'exp_out', 'ExpectedCheckOut', 'ScheduledOut', 'ShiftOutHr', 'TimeOut', 'ShiftEnd']);
    
    // Sometimes backend sends something like 08:00 AM - 05:00 PM directly in 'ShiftTime' or 'Shift_Time'
    final combinedShiftTime = find(['ShiftTime', 'Shift_Time', 'Shift_Times', 'ExpectedShiftTime', 'shifttime', 'shift_times']);
    final expectedHrs = find(['ExpectedHours', 'ExpectedHrs', 'ExpectedHr', 'Expected_Hours']);
    
    final expected = expectedHrs.isNotEmpty ? expectedHrs : '08:00';
    
    if (shiftIn.isNotEmpty && shiftOut.isNotEmpty) {
      shift = '$shift ($shiftIn - $shiftOut)'.trim();
    } else if (combinedShiftTime.isNotEmpty) {
      shift = '$shift ($combinedShiftTime)'.trim();
    } else {
      // Fallback: match web dashboard for General Shift if no explicit times are given
      if ((shift == 'General Shift' || shift == 'general_shift'.tr) && expected == '08:00') {
        shift = '$shift (08:00 - 17:00)'.trim();
      } else {
        shift = '$shift ($expected)'.trim();
      }
    }
    
    String firstIn = '';
    String lastOut = '';
    for (var r in summaryRecords) {
      final cin = (r['CheckIN'] ?? '').toString();
      if (firstIn.isEmpty && cin.isNotEmpty) firstIn = cin;
    }
    for (var r in summaryRecords.reversed) {
      final cout = (r['CheckOut'] ?? '').toString();
      if (lastOut.isEmpty && cout.isNotEmpty) lastOut = cout;
    }

    final List<Map<String, dynamic>> parsedPunches = [];
    for (var p in rawPunches) {
      if (p.containsKey('PunchTime') || p.containsKey('AttTime') || p.containsKey('PunchType') || p.containsKey('DeviceName')) {
        String time = (p['PunchTime'] ?? p['AttTime'] ?? p['Time'] ?? '').toString();
        if (time.contains('T')) {
          try {
            final dt = DateTime.parse(time);
            final h = dt.hour;
            final m = dt.minute.toString().padLeft(2, '0');
            final ampm = h >= 12 ? 'PM' : 'AM';
            final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
            time = '${h12.toString().padLeft(2, '0')}:$m $ampm';
          } catch (_) {
            time = time.split('T').last;
          }
        }
        
        String type = (p['PunchType'] ?? p['InOutMode'] ?? p['Type'] ?? '').toString();
        String device = (p['DeviceName'] ?? p['Device'] ?? '').toString();
        
        if (type.isEmpty) {
          if (time.toLowerCase().contains('in')) type = 'IN';
          else if (time.toLowerCase().contains('out')) type = 'OUT';
        }
        
        if (time.isNotEmpty) {
          parsedPunches.add({
            'time': time,
            'type': type,
            'device': device,
            'record': p,
          });
        }
      } else {
        final cin = (p['CheckIN'] ?? '').toString();
        final cout = (p['CheckOut'] ?? '').toString();
        if (cin.isNotEmpty) parsedPunches.add({'time': cin, 'type': 'IN', 'device': '', 'record': p});
        if (cout.isNotEmpty) parsedPunches.add({'time': cout, 'type': 'OUT', 'device': '', 'record': p});
      }
    }
    final gsh = find(['GrossHrs', 'GrossHr', 'GrossHours', 'GSH']).isNotEmpty ? find(['GrossHrs', 'GrossHr', 'GrossHours', 'GSH']) : '00:00';
    String nth = find(['NetHrs', 'NetHr', 'NetHours', 'NTH']);
    if (nth.isEmpty) nth = '00:00';
    final dih = find(['DelayHrs', 'DelayHr', 'DelayHours', 'LateHrs', 'LateHours', 'LateIn', 'DelayIn', 'DIH']).isNotEmpty ? find(['DelayHrs', 'DelayHr', 'DelayHours', 'LateHrs', 'LateHours', 'LateIn', 'DelayIn', 'DIH']) : '00:00';
    final eoh = find(['EarlyOutHrs', 'EarlyOutHr', 'EarlyOutHours', 'EarlyHrs', 'EarlyHours', 'EarlyOut', 'EOH']).isNotEmpty ? find(['EarlyOutHrs', 'EarlyOutHr', 'EarlyOutHours', 'EarlyHrs', 'EarlyHours', 'EarlyOut', 'EOH']) : '00:00';
    String lsh = find(['LessHrs', 'LessHr', 'LessHours', 'LSH']);
    if (lsh.isEmpty) lsh = '00:00';
    final esh = find(['ExcessHrs', 'ExcessHr', 'ExcessHours', 'ExtraHrs', 'ExtraHours', 'Overtime', 'ESH']).isNotEmpty ? find(['ExcessHrs', 'ExcessHr', 'ExcessHours', 'ExtraHrs', 'ExtraHours', 'Overtime', 'ESH']) : '00:00';

    Widget tableRowSingle(String label, Widget val) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ),
            Expanded(child: val),
          ],
        ),
      );
    }

    Widget tableRowDouble(String label1, Widget val1, String label2, Widget val2) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ),
            Expanded(child: val1),
            SizedBox(
              width: 100,
              child: Text(label2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ),
            Expanded(child: val2),
          ],
        ),
      );
    }

    Widget valText(String t, Color c) => Text(t.isEmpty || t == '00:00' ? '-' : t, style: TextStyle(fontSize: 13, color: c));

    Widget acronymItem(String acr, String full, Color c, bool dark) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withValues(alpha: 0.5))),
              child: Text(acr, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(full, style: TextStyle(color: dark ? Colors.grey[200] : Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 14))),
          ],
        ),
      );
    }

    Widget hoursCol(String label, String val, Color bgColor, Color textColor) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
            child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(val.isEmpty ? '00:00' : val, style: TextStyle(fontSize: 11, color: textColor)),
        ],
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('employee_attendance_details'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          children: [
                            tableRowSingle('${'employee'.tr}:', Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Icon(Icons.info, size: 16, color: Colors.blue[600]),
                                ),
                                const SizedBox(width: 6),
                                Expanded(child: Text('$empNo : $empName', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]))),
                              ],
                            )),
                            tableRowSingle('${'shift'.tr}:', valText(shift.isNotEmpty ? shift : 'general_shift'.tr, Colors.blue[600]!)),
                            tableRowSingle('${'date'.tr}:', valText(date, Colors.blue[600]!)),
                            tableRowSingle('${'expected_hours'.tr}:', valText(expectedHrs.isNotEmpty ? expectedHrs : '08:00', Colors.blue[600]!)),
                            tableRowSingle('${'type'.tr}:', valText(_label(type), Colors.blue[600]!)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Hourly Badges Container (Clickable for Acronyms)
                      GestureDetector(
                        onTap: () => showHourAcronymsDialog(context, isDark),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: [
                              hoursCol('gsh'.tr, gsh, Colors.blue[600]!, isDark ? Colors.grey[300]! : Colors.grey[600]!),
                              hoursCol('nth'.tr, nth, Colors.lightBlue[400]!, isDark ? Colors.grey[300]! : Colors.grey[800]!),
                              hoursCol('dih'.tr, dih, Colors.orange, isDark ? Colors.grey[300]! : Colors.grey[600]!),
                              hoursCol('eoh'.tr, eoh, Colors.deepOrange, isDark ? Colors.grey[300]! : Colors.grey[600]!),
                              hoursCol('lsh'.tr, lsh, Colors.red[600]!, isDark ? Colors.grey[300]! : Colors.grey[800]!),
                              hoursCol('esh'.tr, esh, Colors.green, isDark ? Colors.grey[300]! : Colors.grey[600]!),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      buildPunchGrid(context, parsedPunches, isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  static void showPunchDetailsDialog(BuildContext context, dynamic item) {
    final homeController = Get.find<HomeController>();
    final map = item as Map<String, dynamic>;
    
    // Debug print so we can see exactly what the backend sends
    print('Punch Details Item: $map');

    String findValue(List<String> keys) {
      for (final k in map.keys) {
        if (keys.any((pk) => pk.toLowerCase() == k.toLowerCase())) {
          final val = map[k];
          if (val != null && val.toString().trim().isNotEmpty) return val.toString();
        }
      }
      return '';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    String parsedDate = findValue(['AttDate', 'LogDate', 'PunchTime', 'PDateTime']);
    if (parsedDate.contains('T')) parsedDate = parsedDate.split('T')[0];
    
    String date = parsedDate;
    try {
      if (date.isNotEmpty) {
        DateTime? dt;
        if (date.contains('/')) {
          final parts = date.split('/');
          if (parts.length == 3) {
            int p1 = int.parse(parts[0]);
            int p2 = int.parse(parts[1]);
            int p3 = int.parse(parts[2]);
            if (p1 > 12) dt = DateTime(p3, p2, p1);
            else if (p2 > 12) dt = DateTime(p3, p1, p2);
            else dt = DateTime(p3, p2, p1);
          }
        } else {
          dt = DateTime.parse(date);
        }
        
        if (dt != null) {
          final lc = Get.find<LanguageController>();
          final isAr = lc.currentLanguage.value == 'ar';
          if (isAr) {
            final monthsAr = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
            date = '${dt.day.toString().padLeft(2, '0')} ${monthsAr[dt.month - 1]} ${dt.year}';
          } else {
            date = DateFormat('dd MMM yyyy').format(dt);
          }
        }
      }
    } catch (_) {}
    final checkIn = findValue(['CheckIN', 'checkin_time']);
    final checkOut = findValue(['CheckOut', 'checkout_time']);
    final rawTime = findValue(['Time']);
    
    final type = findValue(['DayType', 'Type']);
    
    // ── Device ID ────────────────────────────────────────────────────
    String deviceId = findValue(['ExtnlAttDvce', 'DeviceID', 'deviceinfo', 'device', 'device_id', 'macaddress', 'mac_address', 'DeviceName']);
    if (deviceId.isEmpty) deviceId = 'Device info unavailable';

    // ── Location extraction ──────────────────────────────────────────
    // The app sends location to backend as: "lat|lng| Address : <text>,"
    // The backend returns it in multiple possible fields.
    // We must parse ALL formats and show location for EVERY punch type.
    
    String location = '';
    String? mapLat, mapLng;

    // Helper: parse "lat|lng|..." or "lat,lng,..." or "lat/lng..." format
    // Returns [lat, lng] or null
    List<String>? _parseCoords(String raw) {
      // Try pipe separator first (our app format)
      final pipeMatch = RegExp(r'(-?\d+\.?\d*)\s*\|\s*(-?\d+\.?\d*)').firstMatch(raw);
      if (pipeMatch != null) {
        final lat = double.tryParse(pipeMatch.group(1)!);
        final lng = double.tryParse(pipeMatch.group(2)!);
        if (lat != null && lng != null && (lat.abs() > 0.001 || lng.abs() > 0.001)) {
          return [pipeMatch.group(1)!, pipeMatch.group(2)!];
        }
      }
      // Try comma/slash separator
      final commaMatch = RegExp(r'(-?\d+\.?\d*)\s*[,/]\s*(-?\d+\.?\d*)').firstMatch(raw);
      if (commaMatch != null) {
        final lat = double.tryParse(commaMatch.group(1)!);
        final lng = double.tryParse(commaMatch.group(2)!);
        if (lat != null && lng != null && (lat.abs() > 0.001 || lng.abs() > 0.001)) {
          return [commaMatch.group(1)!, commaMatch.group(2)!];
        }
      }
      return null;
    }

    // Helper: extract human-readable address from locationinfo string
    String _extractAddress(String raw) {
      if (raw.isEmpty || raw == '0.000000,0.000000' || raw == '0|0' || raw == 'null' || raw == '0/0') return '';
      
      // Format 1: "lat|lng| Address : BLE Beacon DEMO-001," or "lat|lng| Address : GPS (lat, lng),"
      final addrIdx = raw.toLowerCase().indexOf('address');
      if (addrIdx >= 0) {
        String extracted = raw.substring(addrIdx);
        // Remove the "Address :" or "address:" prefix
        extracted = extracted.replaceFirst(RegExp(r'^[Aa]ddress\s*:\s*'), '').trim();
        extracted = extracted.replaceAll(RegExp(r',\s*$'), '').trim();
        
        // Check if what remains is just raw lat/lng numbers (e.g., "24.730000/46.766000")
        // If so, prefer to show them as "GPS (lat, lng)"
        final isJustCoords = RegExp(r'^-?\d+\.\d+\s*[/|,]\s*-?\d+\.\d+$').hasMatch(extracted);
        if (isJustCoords) {
          // Format it as proper GPS coordinates
          final coordParts = extracted.split(RegExp(r'[/|,]'));
          if (coordParts.length >= 2) {
            final lat = coordParts[0].trim();
            final lng = coordParts[1].trim();
            return 'GPS ($lat, $lng)';
          }
        }
        
        if (extracted.isNotEmpty && extracted != '0/0' && extracted.toLowerCase() != 'no location') {
          return extracted;
        }
      }
      
      // Format 2: Pure GPS string like "24.713552|46.675297" — parse and format
      final coords = _parseCoords(raw);
      if (coords != null) {
        return 'GPS (${coords[0]}, ${coords[1]})';
      }
      
      // Format 3: Plain location text like "Dubai Office" or "Riyadh"
      if (raw.isNotEmpty && raw != '0/0' && raw.toLowerCase() != 'no location' && !raw.contains('|')) {
        return raw;
      }
      
      return '';
    }

    // Search ALL possible location fields from both daily summary AND per-punch API
    final locationFields = [
      'locationinfo', 'LocationInfo', 'location_info',
      'PunchLocationInfo', 'AttLocationInfo', 'punch_locationinfo',
      'CheckINAddr', 'checkin_location', 'CheckoutAddr', 'checkout_location',
      'Location', 'Addr', 'Address', 'GpsLocation', 'AttAddr', 'PunchAddr',
      'GPS', 'GpsAddr', 'GpsAddress',
    ];
    
    for (final fieldKey in locationFields) {
      final raw = findValue([fieldKey]);
      if (raw.isEmpty || raw == '0.000000,0.000000' || raw == '0|0' || raw == 'null' || raw == '0/0') continue;
      
      // Try to extract GPS coordinates
      if (mapLat == null) {
        final coords = _parseCoords(raw);
        if (coords != null) {
          mapLat = coords[0];
          mapLng = coords[1];
        }
      }
      
      // Extract human-readable address
      if (location.isEmpty) {
        final addr = _extractAddress(raw);
        if (addr.isNotEmpty) {
          location = addr;
        }
      }
      
      if (mapLat != null && location.isNotEmpty) break;
    }
    
    // Also try explicit lat/lng fields
    if (mapLat == null) {
      final rawLat = findValue(['Latitude', 'lat', 'Lat', 'PunchLat', 'GpsLat']);
      final rawLng = findValue(['Longitude', 'lng', 'long', 'Lng', 'PunchLng', 'GpsLng']);
      if (rawLat.isNotEmpty && rawLng.isNotEmpty) {
        final lat = double.tryParse(rawLat);
        final lng = double.tryParse(rawLng);
        if (lat != null && lng != null && (lat.abs() > 0.001 || lng.abs() > 0.001)) {
          mapLat = rawLat;
          mapLng = rawLng;
        }
      }
    }

    // If we have coords but no readable address, OR if it's a misplaced beacon text, show coords
    if (mapLat != null && mapLng != null) {
      if (location.isEmpty || location.contains('BLE Beacon') || location.contains('Address :')) {
        location = '$mapLat, $mapLng';
      }
    }
    
    String connection = findValue(['ConnectionName']);
    if (connection.isNotEmpty) {
      if (deviceId == 'Device info unavailable') deviceId = connection;
      else deviceId = '$deviceId ($connection)';
    }

    // Simple proven image extraction — same approach that works in attendance_history_view.dart
    // Find keys case-insensitively to protect against backend casing changes
    String directSelfieUrl = '';
    String punchImageByteStr = '';
    String pFolder = '';
    String pImageFilename = '';
    String pBase64Data = '';
    
    for (final key in map.keys) {
      final lowerKey = key.toLowerCase();
      final val = (map[key] ?? '').toString().trim();
      
      if (lowerKey == 'selfieurl' || lowerKey == 'punchimage' || lowerKey == 'punch_image') {
        if (directSelfieUrl.isEmpty) directSelfieUrl = val;
      }
      if (lowerKey == 'punchimagebyte' || lowerKey == 'punch_image_byte') {
        punchImageByteStr = val;
      }
      if (lowerKey == 'punch_folder' || lowerKey == 'punchfolder') {
        pFolder = val;
      }
      
      // Only look for base64 data (very long strings) or filenames — NOT http URLs (those are SelfieUrl)
      if (lowerKey == 'punchimage' || lowerKey == 'punch_image') {
        if (val.isNotEmpty && !val.startsWith('http')) {
          if ((val.endsWith('.jpg') || val.endsWith('.png') || val.endsWith('.jpeg')) && pImageFilename.isEmpty) {
            pImageFilename = val;
          } else if (val.length > 200) {
            // Likely a real base64 string (filenames are never this long)
            pBase64Data = val;
          }
        }
      }
    }

    String? dialogBase64ToDecode;
    String? dialogImgUrl;
    
    String base = 'https://app.resourceplus.app';
    try {
      if (Get.isRegistered<HomeController>()) {
        final dynBase = Get.find<HomeController>().commonContents['BaseUrl'];
        if (dynBase != null && dynBase.toString().isNotEmpty) {
           base = dynBase.toString().trim();
           if (base.endsWith('/')) base = base.substring(0, base.length - 1);
        }
      }
    } catch (e) {}

    if (punchImageByteStr.isNotEmpty && punchImageByteStr.length > 100) {
      int idx = punchImageByteStr.indexOf(',');
      dialogBase64ToDecode = idx != -1 ? punchImageByteStr.substring(idx + 1) : punchImageByteStr;
    } else if (pBase64Data.isNotEmpty && pBase64Data.length > 100) {
      int idx = pBase64Data.indexOf(',');
      dialogBase64ToDecode = idx != -1 ? pBase64Data.substring(idx + 1) : pBase64Data;
    } else if (directSelfieUrl.isNotEmpty && directSelfieUrl.startsWith('http')) {
      // Replace hardcoded domains with the dynamic base URL from API if needed
      dialogImgUrl = directSelfieUrl.replaceFirst(RegExp(r'https?://[a-zA-Z0-9.-]+'), base);
    }

    List<String> possibleUrls = [];
    if (dialogBase64ToDecode == null && dialogImgUrl == null && pImageFilename.isNotEmpty) {
      final folder = pFolder.isNotEmpty && !pFolder.endsWith('/') ? '$pFolder/' : pFolder;
      possibleUrls = [
        '$base/Mobile/Uploads/Client/PunchImage/$folder$pImageFilename',
        '$base/Mobile/Uploads/Client/$folder$pImageFilename',
        '$base/Mobile/Uploads/Client/PunchImage/$pImageFilename',
        '$base/Mobile/Uploads/Client/$pImageFilename',
        '$base/Uploads/Client/PunchImage/$folder$pImageFilename',
        '$base/Uploads/Client/$folder$pImageFilename',
        '$base/Uploads/Client/PunchImage/$pImageFilename',
        '$base/Uploads/Client/$pImageFilename',
      ];
    }
    
    // Only label as Selfie if backend actually sent a selfie image URL or bytes.
    // Do NOT use possibleUrls (filename guessing) as that fires for Fingerprint/BLE too.
    final hasRealSelfieImage = (dialogBase64ToDecode != null && dialogBase64ToDecode!.length > 100) ||
        (dialogImgUrl != null && dialogImgUrl!.isNotEmpty);
    if (!deviceId.toLowerCase().contains('face') &&
        !deviceId.toLowerCase().contains('selfie') &&
        !deviceId.toLowerCase().contains('finger') &&
        !deviceId.toLowerCase().contains('bluetooth') &&
        !deviceId.toLowerCase().contains('ble') &&
        !deviceId.toLowerCase().contains('qr') &&
        hasRealSelfieImage) {
      deviceId = 'Selfie ($deviceId)';
    }

    final hasCoords = mapLat != null && mapLng != null && mapLat != '0.000000' && mapLng != '0.000000';
    final googleMapsUrl = hasCoords ? 'https://maps.google.com/?q=$mapLat,$mapLng' : null;

    Widget _buildClickableImage(Widget imageWidget) {
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.black87,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4,
                    child: imageWidget,
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: imageWidget,
      );
    }

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
              Text('punch_details'.tr, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              const SizedBox(height: 20),
              
              if (dialogBase64ToDecode != null)
                Center(
                  child: Container(
                    height: 100, width: 100,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 2),
                    ),
                    child: FutureBuilder<Uint8List?>(
                      future: compute(decodeBase64Background, dialogBase64ToDecode!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasData && snapshot.data != null) {
                          return _buildClickableImage(Image.memory(snapshot.data!, cacheWidth: 800, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.person_outline, size: 48, color: isDark ? Colors.grey[500] : Colors.grey[400])));
                        }
                        return Icon(Icons.person_outline, size: 48, color: isDark ? Colors.grey[500] : Colors.grey[400]);
                      }
                    ),
                  ),
                )
              else if (dialogImgUrl != null) 
                Center(
                  child: Container(
                    height: 100, width: 100,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 2),
                    ),
                    child: _buildClickableImage(Image.network(dialogImgUrl!, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.person_outline, size: 48, color: isDark ? Colors.grey[500] : Colors.grey[400]))),
                  ),
                )
              else if (possibleUrls.isNotEmpty)
                Center(
                  child: Container(
                    height: 100, width: 100,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 2),
                    ),
                    child: _buildClickableImage(Image.network(
                      possibleUrls[0],
                      fit: BoxFit.cover,
                      errorBuilder: (c1, e1, s1) => Image.network(
                        possibleUrls[1],
                        fit: BoxFit.cover,
                        errorBuilder: (c2, e2, s2) => Image.network(
                          possibleUrls[2],
                          fit: BoxFit.cover,
                          errorBuilder: (c3, e3, s3) => Image.network(
                            possibleUrls[3],
                            fit: BoxFit.cover,
                            errorBuilder: (c4, e4, s4) => Image.network(
                              possibleUrls[4],
                              fit: BoxFit.cover,
                              errorBuilder: (c5, e5, s5) => Image.network(
                                possibleUrls[5],
                                fit: BoxFit.cover,
                                errorBuilder: (c6, e6, s6) => Image.network(
                                  possibleUrls[6],
                                  fit: BoxFit.cover,
                                  errorBuilder: (c7, e7, s7) => Image.network(
                                    possibleUrls[7],
                                    fit: BoxFit.cover,
                                    errorBuilder: (c8, e8, s8) {
                                      print('All 8 fallback URLs failed.');
                                      return Icon(Icons.person_outline, size: 48, color: isDark ? Colors.grey[500] : Colors.grey[400]);
                                    }
                                  )
                                )
                              )
                            )
                          )
                        )
                      )
                    )),
                  )
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
              
              _detailRow('date'.tr, date, isDark),
              _detailRow('status'.tr, _label(type), isDark),
              _punchMethodBadge(deviceId, isDark),
              const SizedBox(height: 16),
              
              // Grouped Check In/Out Times OR Single Punch Time
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    if (rawTime.isNotEmpty && checkIn.isEmpty && checkOut.isEmpty)
                      _detailRow('punch_time'.tr, rawTime, isDark)
                    else ...[
                      _detailRow('check_in'.tr, checkIn.isEmpty ? '--:--' : checkIn, isDark),
                      _detailRow('check_out'.tr, checkOut.isEmpty ? '--:--' : checkOut, isDark),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              _detailRow('device'.tr, () {
                String d = deviceId;
                final dLow = d.toLowerCase();
                
                if (dLow.contains('android')) return 'android_mobile'.tr;
                if (dLow.contains('ios') || dLow.contains('iphone') || dLow.contains('ipad')) return 'ios_mobile'.tr;
                
                if (dLow.contains('bluetooth')) return 'bluetooth'.tr;
                if (dLow.contains('face detection') || dLow.contains('face punch') || dLow.contains('face')) return 'face_punch'.tr;
                if (dLow.contains('fingerprint')) return 'fingerprint'.tr;
                if (dLow.contains('qr') || dLow.contains('scan')) return 'qr_scan'.tr;
                if (dLow.contains('selfie')) return 'selfie_punch'.tr;
                
                // Strip unnecessary parentheses if they exist
                d = d.replaceAll(RegExp(r'^\s*Selfie\s*\(\s*(.*?)\s*\)\s*$', caseSensitive: false), r'$1');
                return d;
              }(), isDark),
              

              // Always show location - show whatever the backend sent but translated if BLE
              _detailRow('location'.tr, () {
                String loc = location.isNotEmpty ? location : 'location_not_available'.tr;
                if (loc.toLowerCase().contains('ble beacon')) {
                  loc = loc.replaceAll(RegExp(r'ble beacon', caseSensitive: false), 'ble_beacon'.tr);
                }
                return loc;
              }(), isDark),
              
              // Google Maps preview (using InAppWebView to render iframe like web without APIs)
              if (hasCoords) ...[  
                const SizedBox(height: 12),
                Text('location_map'.tr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    if (googleMapsUrl != null) {
                      final uri = Uri.parse(googleMapsUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.map_outlined, color: Color(0xFF0EA5E9), size: 20),
                        const SizedBox(width: 8),
                        Text('open_in_google_maps'.tr, style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)
                        )),
                      ],
                    ),
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('close'.tr, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _detailRow(String label, String value, bool isDark) {
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

  /// Displays a colored icon chip identifying how the punch was made.
  /// Reads the Devicename sent to MarkAttendancev2 — returned by the backend.
  static Widget _punchMethodBadge(String deviceId, bool isDark) {
    IconData icon;
    Color color;
    String label;

    final d = deviceId.toLowerCase();
    if (d.contains('fingerprint')) {
      icon = Icons.fingerprint_rounded; color = const Color(0xFF10B981); label = 'fingerprint'.tr;
    } else if (d.contains('face detection') || d.contains('face punch') || d.contains('face')) {
      icon = Icons.face_retouching_natural_rounded; color = const Color(0xFF3B82F6); label = 'face_punch'.tr;
    } else if (d.contains('bluetooth')) {
      icon = Icons.bluetooth_rounded; color = const Color(0xFFF59E0B); label = 'bluetooth'.tr;
    } else if (d.contains('qr') || d.contains('scan')) {
      icon = Icons.qr_code_scanner_rounded; color = const Color(0xFF8B5CF6); label = 'qr_scan'.tr;
    } else if (d.contains('selfie')) {
      icon = Icons.camera_alt_rounded; color = const Color(0xFF004A77); label = 'selfie_punch'.tr;
    } else {
      icon = Icons.devices_other_rounded; color = const Color(0xFF64748B); label = deviceId.isNotEmpty ? deviceId : 'unknown'.tr;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text('method'.tr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[500])),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 5),
                    Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.visible)),
                  ],
                ),
              ),
            ),
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
              Text('filter_api_notice'.tr, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text('select_date_range'.tr),
                subtitle: Text('coming_soon'.tr),
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
  static String _label(String type) {
    if (type.isEmpty) return type;
    final t = type.toLowerCase().trim();
    if (t == 'absent' || t == 'غائب') return 'absent'.tr;
    if (t == 'absent *p' || t == 'absent*p') return 'absent_p'.tr;
    if (t == 'present' || t == 'حاضر') return 'present'.tr;
    if (t == 'early' || t == 'مبكر') return 'early'.tr;
    if (t == 'late' || t == 'متأخر' || t == 'تأخير') return 'late'.tr;
    if (t == 'less' || t == 'ساعات ناقصة') return 'less_hrs'.tr;
    if (t == 'regular' || t == 'منتظم') return 'regular'.tr;
    if (t == 'week end' || t == 'weekend' || t == 'نهاية الأسبوع') return 'week_end'.tr;
    if (t == 'holiday' || t == 'عطلة') return 'holiday'.tr;
    return type.trim();
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
