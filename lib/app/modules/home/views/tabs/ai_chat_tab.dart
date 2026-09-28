import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importing from the local Resourceplus_AICHAT package
import 'package:resourceplus_app/bloc/chat_bloc.dart';
import 'package:resourceplus_app/services/ai_service.dart';
import 'package:resourceplus_app/services/settings_service.dart';
import '../orbit_chat_screen.dart';
import '../widgets/chat_details_sheet.dart';

import '../../controllers/home_controller.dart';

class AIChatTab extends StatelessWidget {
  const AIChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF004A77)),
            ),
          );
        }

        final settingsService = SettingsService(snapshot.data!);

        return Scaffold(
          backgroundColor: Colors.white,
          body: BlocProvider<ChatBloc>(
            create: (_) =>
                ChatBloc(aiService: AIService(settings: settingsService)),
            child: OrbitChatScreen(
              settingsService: settingsService,
              onQuickAccess: (shortcut) => showChatDetails(context, shortcut),
              appHeader: ResourcePlusChatHeader(
                onNotifications: () =>
                    showChatDetails(context, ChatShortcut.notifications),
              ),
              onBackPressed: () {
                // Navigate back to Home Tab when back button is pressed inside the AI Chat Tab
                Get.find<HomeController>().changeTab(0);
              },
            ),
          ),
        );
      },
    );
  }
}
