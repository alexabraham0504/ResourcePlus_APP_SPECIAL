// CalendarView — DISABLED for production build.
// Google Calendar integration is not included in the production release.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/calendar_controller.dart';

class CalendarView extends GetView<CalendarController> {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Calendar module is not available in this build.'),
      ),
    );
  }
}
