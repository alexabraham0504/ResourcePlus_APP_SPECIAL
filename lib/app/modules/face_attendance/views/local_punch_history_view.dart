// lib/app/modules/face_attendance/views/local_punch_history_view.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../repositories/mock_local_punch_repository.dart';

class LocalPunchHistoryView extends StatefulWidget {
  const LocalPunchHistoryView({super.key});

  @override
  State<LocalPunchHistoryView> createState() => _LocalPunchHistoryViewState();
}

class _LocalPunchHistoryViewState extends State<LocalPunchHistoryView> {
  final MockLocalPunchRepository _repository = MockLocalPunchRepository();
  List<LocalPunchRecord> _punches = [];
  bool _isLoading = true;

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Face', 'Bluetooth', 'Fingerprint'];

  @override
  void initState() {
    super.initState();
    // Pre-select filter based on arguments if passed (e.g. Get.arguments['filter'] == 'Bluetooth')
    if (Get.arguments != null && Get.arguments is Map && Get.arguments['filter'] != null) {
      _selectedFilter = Get.arguments['filter'];
    }
    _loadPunches();
  }

  Future<void> _loadPunches() async {
    final punches = await _repository.getPunches();
    setState(() {
      _punches = punches;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF004A77);
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final filteredPunches = _punches.where((p) {
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Bluetooth') return p.punchMethod.toLowerCase().contains('bluetooth');
      if (_selectedFilter == 'Face') return p.punchMethod.toLowerCase().contains('face');
      if (_selectedFilter == 'Fingerprint') return p.punchMethod.toLowerCase().contains('fingerprint');
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Punch History', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : Column(
              children: [
                // Filter Chips Row
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter, style: TextStyle(
                            color: isSelected ? Colors.white : textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          )),
                          selected: isSelected,
                          selectedColor: primaryBlue,
                          backgroundColor: cardBg,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: filteredPunches.isEmpty
                      ? _buildEmptyState(textColor)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredPunches.length,
                          itemBuilder: (context, index) {
                            final punch = filteredPunches[index];
                            return _buildPunchCard(punch, cardBg, textColor, index);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No punches recorded yet.',
            style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchCard(LocalPunchRecord punch, Color cardBg, Color textColor, int index) {
    final isPunchIn = punch.checkType == 'I';
    final typeColor = isPunchIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final typeText = isPunchIn ? 'PUNCH IN' : 'PUNCH OUT';
    final timeStr = DateFormat('hh:mm a').format(punch.timestamp);
    final dateStr = DateFormat('MMM dd, yyyy').format(punch.timestamp);

    return TweenAnimationBuilder<double>(
      key: ValueKey(punch.id),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 500)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cardBg,
              cardBg.withValues(alpha: 0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: typeColor.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: typeColor.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    typeText,
                    style: TextStyle(
                      color: typeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (punch.employeeName != null && punch.employeeName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.person_rounded, size: 16, color: typeColor.withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Text(
                      punch.employeeName!,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Icon(Icons.access_time_filled_rounded, color: typeColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (punch.punchMethod != 'Unknown')
                  Row(
                    children: [
                      Icon(
                        punch.punchMethod == 'Face' 
                            ? Icons.face_retouching_natural_rounded 
                            : (punch.punchMethod == 'Fingerprint'
                                ? Icons.fingerprint_rounded
                                : Icons.bluetooth_rounded),
                        color: textColor.withValues(alpha: 0.5),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        punch.punchMethod,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 16, color: textColor.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    punch.address.isNotEmpty ? punch.address : punch.location,
                    style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.work_rounded, size: 16, color: textColor.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    punch.shiftDetails,
                    style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.perm_device_info_rounded, size: 16, color: textColor.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Device: ${punch.deviceId}',
                    style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }
}
