import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../autostart/screens/auto_start_settings_screen.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../onboarding/services/onboarding_storage_service.dart';
import '../../recognition/screens/voice_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _replayOnboarding(BuildContext context) async {
    await OnboardingStorageService().resetOnboarding();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            _buildSettingsTile(
              title: 'Auto-Start Controller',
              subtitle: 'Automatic hands-free activation on Instagram',
              icon: Icons.flash_on_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AutoStartSettingsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              title: 'Speech Recognition Mode',
              subtitle: 'Configure Offline / Online voice recognition',
              icon: Icons.mic_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const VoiceSettingsScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              title: 'Replay Onboarding Flow',
              subtitle: 'View the 3-step introduction walkthrough again',
              icon: Icons.replay_rounded,
              onTap: () => _replayOnboarding(context),
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              title: 'Theme Preference',
              subtitle: 'OLED Obsidian Dark (Default)',
              icon: Icons.dark_mode_rounded,
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              title: 'App Version',
              subtitle: 'ReelSense v1.0.0+1',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              title: 'Lead Developer',
              subtitle: 'Brijesh Verma',
              icon: Icons.person_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.accentCyan, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
