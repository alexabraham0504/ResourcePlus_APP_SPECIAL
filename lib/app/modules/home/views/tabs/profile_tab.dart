import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/home_controller.dart';
import '../widgets/tab_header.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  // ─── Professional Corporate Palette ──────────────────────────────
  static const _primary = Color(0xFF0F172A); // Slate 900
  static const _surface = Colors.white;
  static const _bg = Color(0xFFF8FAFC); // Slate 50
  static const _accent = Color(0xFF004A77); // Corporate Blue
  static const _accentLight = Color(0xFFE0F2FE); // Sky 100

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : _bg;

    return Scaffold(
      backgroundColor: bgColor,
      body: Obx(() {
        if (controller.isProfileLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        if (controller.hasProfileError.value) {
          return _buildErrorState(context, controller);
        }

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => controller.refreshProfileData(),
            color: _primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TabHeader(title: 'profile'.tr),
                  const SizedBox(height: 24),
                  
                  // Keep the requested Profile Card but style it cleanly
                  _buildProfileHeader(context, controller),
                  
                  const SizedBox(height: 32),
                  _buildContactSection(context, controller),
                  const SizedBox(height: 24),
                  _buildWorkSection(context, controller),
                  const SizedBox(height: 24),
                  
                  // Row for Skills & Certs if they are small, or just column
                  _buildSkillsSection(context, controller),
                  const SizedBox(height: 24),
                  _buildCertificationsSection(context, controller),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildErrorState(BuildContext context, HomeController controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('error'.tr,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: controller.refreshProfileData,
            icon: const Icon(Icons.refresh),
            label: Text('retry'.tr),
            style: TextButton.styleFrom(foregroundColor: _primary),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PROFILE HEADER (Matches Home Tab Request)
  // ═══════════════════════════════════════════════════════════
  Widget _buildProfileHeader(BuildContext context, HomeController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : _surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    const primaryGreen = Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: ClipOval(
                  child: controller.profilePictureUrl.value.isNotEmpty
                      ? Image.network(
                          controller.profilePictureUrl.value,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.person,
                              color: isDark ? Colors.white54 : Colors.grey, size: 32),
                        )
                      : Icon(Icons.person,
                          color: isDark ? Colors.white54 : Colors.grey, size: 32),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.profileEmployeeName.value.isNotEmpty
                      ? controller.profileEmployeeName.value
                      : 'employee_name'.tr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : _primary,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  controller.positionName.value.isNotEmpty
                      ? controller.positionName.value
                      : 'position'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    'ID: ${controller.profileEmpNumber.value.isNotEmpty ? controller.profileEmpNumber.value : "N/A"}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.grey[300] : _primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Verified badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, color: primaryGreen, size: 24),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CONTACT INFO
  // ═══════════════════════════════════════════════════════════
  Widget _buildContactSection(BuildContext context, HomeController controller) {
    final title = 'contact_information'.tr;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, Icons.contact_mail_outlined, context),
        const SizedBox(height: 12),
        _buildCard(
          context,
          child: Column(
            children: [
              _infoRow(
                context,
                icon: Icons.alternate_email_rounded,
                label: controller.profileStaticContents['Emailext'] ?? 'Email Address',
                value: controller.profileEmpEmail.value.isNotEmpty 
                    ? controller.profileEmpEmail.value 
                    : 'not_provided'.tr,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, thickness: 0.5, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              _infoRow(
                context,
                icon: Icons.phone_outlined,
                label: controller.profileStaticContents['PhoneText'] ?? 'Phone Number',
                value: controller.profileEmpMobile.value.isNotEmpty 
                    ? controller.profileEmpMobile.value 
                    : 'not_provided'.tr,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  WORK INFO
  // ═══════════════════════════════════════════════════════════
  Widget _buildWorkSection(BuildContext context, HomeController controller) {
    final title = 'work_information'.tr;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, Icons.work_outline_rounded, context),
        const SizedBox(height: 12),
        _buildCard(
          context,
          child: controller.workInformation.isNotEmpty
              ? Column(
                  children: controller.workInformation.map((work) {
                    return Column(
                      children: [
                        _infoRow(
                          context,
                          icon: Icons.business_rounded,
                          label: controller.profileStaticContents['Companytext'] ?? 'Company',
                          value: work['Company']?.toString() ?? 'not_provided'.tr,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 1, thickness: 0.5, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        _infoRow(
                          context,
                          icon: Icons.account_tree_outlined,
                          label: controller.profileStaticContents['DepartmentText'] ?? 'Department',
                          value: work['Organization']?.toString() ?? 'not_provided'.tr,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 1, thickness: 0.5, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        _infoRow(
                          context,
                          icon: Icons.event_available_outlined,
                          label: controller.profileStaticContents['JoinText'] ?? 'Join Date',
                          value: work['DateOfJoin']?.toString() ?? 'not_provided'.tr,
                        ),
                      ],
                    );
                  }).toList(),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'no_work_info'.tr,
                      style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SKILLS
  // ═══════════════════════════════════════════════════════════
  Widget _buildSkillsSection(BuildContext context, HomeController controller) {
    final title = 'skills'.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, Icons.psychology_outlined, context),
        const SizedBox(height: 12),
        if (controller.skills.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: controller.skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  skill['Skill']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : _primary,
                  ),
                ),
              );
            }).toList(),
          )
        else
          Text('no_skills'.tr, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CERTIFICATIONS
  // ═══════════════════════════════════════════════════════════
  Widget _buildCertificationsSection(BuildContext context, HomeController controller) {
    final title = 'certifications'.tr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, Icons.workspace_premium_outlined, context),
        const SizedBox(height: 12),
        if (controller.certifications.isNotEmpty)
          Column(
            children: controller.certifications.map((cert) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.workspace_premium, color: _accent, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        cert['Certification']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : _primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          Text('no_certifications'.tr, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════
  
  Widget _sectionHeader(String title, IconData icon, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : _primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: child,
    );
  }

  Widget _infoRow(BuildContext context, {required IconData icon, required String label, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : _primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
