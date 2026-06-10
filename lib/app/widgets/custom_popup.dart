import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum CustomPopupType { error, success, info, warning }

class CustomPopup {
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    CustomPopupType type = CustomPopupType.error,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    // Determine colors & icons based on the type
    Color primaryColor;
    IconData iconData;
    List<Color> gradientColors;

    switch (type) {
      case CustomPopupType.success:
        primaryColor = const Color(0xFF6BC04B); // Green
        iconData = Icons.check_circle_outline_rounded;
        gradientColors = [const Color(0xFF6BC04B), const Color(0xFF8CD86B)];
        break;
      case CustomPopupType.warning:
        primaryColor = const Color(0xFFF7941D); // Orange/Gold
        iconData = Icons.warning_amber_rounded;
        gradientColors = [const Color(0xFFF7941D), const Color(0xFFFAB059)];
        break;
      case CustomPopupType.info:
        primaryColor = const Color(0xFF3B6EA5); // Blue
        iconData = Icons.info_outline_rounded;
        gradientColors = [const Color(0xFF3B6EA5), const Color(0xFF5B8EC5)];
        break;
      case CustomPopupType.error:
      default:
        primaryColor = const Color(0xFFE53935); // Deep Red
        iconData = Icons.error_outline_rounded;
        gradientColors = [const Color(0xFFE53935), const Color(0xFFEF5350)];
        break;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              elevation: 24,
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      // Elegant background accent gradient glow at the top
                      Positioned(
                        top: -50,
                        right: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.08),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Beautiful, Animated Floating Icon Container
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                iconData,
                                size: 48,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Title
                            Text(
                              title.tr,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            // Message
                            Text(
                              message.tr,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 26),
                            // Beautiful Gradient Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: gradientColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    if (onPressed != null) {
                                      onPressed();
                                    }
                                  },
                                  child: Text(
                                    (buttonText ?? 'OK').tr,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
