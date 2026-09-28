import 'package:flutter/material.dart';
import 'package:resource_plus_ai_workforce/features/dashboard/main_shell.dart';
import '../widgets/tab_header.dart';

class AiWorkforceTab extends StatelessWidget {
  const AiWorkforceTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Do NOT add a Scaffold here — MainShell already has its own Scaffold
    // with a drawer. Adding another Scaffold causes a triple-nested-Scaffold
    // crash when the hamburger menu tries to call Scaffold.of(context).openDrawer().
    return Column(
      children: [
        const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: TabHeader(title: 'AI Workforce'),
          ),
        ),
        Expanded(
          child: MainShell(),
        ),
      ],
    );
  }
}

