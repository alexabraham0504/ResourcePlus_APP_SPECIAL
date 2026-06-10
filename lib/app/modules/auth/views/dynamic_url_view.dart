import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DynamicUrlView extends StatelessWidget {
  const DynamicUrlView({super.key});

  @override
  Widget build(BuildContext context) {
    final String url = Get.arguments ?? '';
    final theme = Theme.of(context);
    const blue = Color(0xFF3B6EA5);
    const orange = Color(0xFFF7941D);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Image.asset(
                  'assets/app_logo.png',
                  height: 80,
                  width: 280,
                ),
              ),
              Card(
                elevation: 8,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Dynamic URL',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: blue,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'You can now access the website using the link below:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      SelectableText(
                        url,
                        style: const TextStyle(fontSize: 16, color: orange),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          // Optionally, implement URL launch
                        },
                        child: const Text('Open Website'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 