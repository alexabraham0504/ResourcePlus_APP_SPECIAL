import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importing from the local Resourceplus_AICHAT package
import 'package:resourceplus_app/bloc/chat_bloc.dart';
import 'package:resourceplus_app/services/ai_service.dart';
import 'package:resourceplus_app/services/settings_service.dart';
import 'package:resourceplus_app/screens/chatbot_screen.dart';

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
            backgroundColor: Color(0xFFF0F2F5),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          );
        }

        final settingsService = SettingsService(snapshot.data!);

        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          body: BlocProvider<ChatBloc>(
            create: (_) => ChatBloc(
              aiService: AIService(settings: settingsService),
            ),
            child: ChatbotScreen(
              settingsService: settingsService,
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
