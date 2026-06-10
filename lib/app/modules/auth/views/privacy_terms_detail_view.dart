import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/privacy_policy_text.dart';

class PrivacyTermsDetailView extends StatelessWidget {
  const PrivacyTermsDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    // Get parameters: type can be 'privacy' or 'terms'
    final String type = Get.arguments as String? ?? 'privacy';
    final bool isPrivacy = type == 'privacy';
    
    final bool isArabic = Get.locale?.languageCode == 'ar' || Localizations.localeOf(context).languageCode == 'ar';
    
    final String title = isPrivacy 
        ? 'privacy_policy'.tr 
        : 'terms_conditions'.tr;
        
    final String textContent = isPrivacy 
        ? (isArabic ? PrivacyPolicyText.privacyPolicyAr : PrivacyPolicyText.privacyPolicy) 
        : (isArabic ? PrivacyPolicyText.termsAndConditionsAr : PrivacyPolicyText.termsAndConditions);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).colorScheme.onBackground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document icon and header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPrivacy ? Icons.privacy_tip_outlined : Icons.description_outlined,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'last_updated'.tr,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Document Body Text
              SelectableText(
                textContent,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.85),
                  fontFamily: 'Roboto', // Clean default sans-serif font
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
