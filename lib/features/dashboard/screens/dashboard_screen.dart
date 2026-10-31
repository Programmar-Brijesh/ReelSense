import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../autostart/screens/auto_start_settings_screen.dart';
import '../../autostart/services/auto_start_platform_service.dart';
import '../../autostart/services/auto_start_preference_service.dart';
import '../../commands/screens/voice_commands_screen.dart';
import '../../gestures/screens/gesture_settings_screen.dart';
import '../../permissions/screens/permissions_screen.dart';
import '../../privacy/screens/privacy_settings_screen.dart';
import '../../recognition/screens/voice_settings_screen.dart';
import '../../recognition/services/recognition_availability_service.dart';
import '../../recognition/services/recognition_preference_service.dart';
import '../../recognition/widgets/initial_recognition_setup_sheet.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/controller_state.dart';
import '../services/dashboard_preferences_service.dart';
import '../widgets/control_mode_card.dart';
import '../widgets/controller_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/reel_session_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardPreferencesService _prefsService =
      DashboardPreferencesService();
  final RecognitionPreferenceService _recognitionPrefs =
      RecognitionPreferenceService();
  final RecognitionAvailabilityService _availabilityService =
      RecognitionAvailabilityService();

  ControllerState _state = const ControllerState();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final loaded = await _prefsService.loadControllerState();
    if (mounted) {
      setState(() {
        _state = loaded;
        _isLoading = false;
      });
    }

    try {
      final autoStartConfig = await AutoStartPreferenceService().loadConfig();
      if (autoStartConfig.isEnabled) {
        final isRunning = await AutoStartPlatformService().isMonitoringServiceRunning();
        if (!isRunning) {
          await AutoStartPlatformService().startMonitoringService(autoStartConfig);
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleMasterController() async {
    final newMasterState = !_state.isMasterEnabled;
    final newSessionState = newMasterState ? _state.isSessionActive : false;

    setState(() {
      _state = _state.copyWith(
        isMasterEnabled: newMasterState,
        isSessionActive: newSessionState,
      );
    });

    await _prefsService.setMasterControllerEnabled(newMasterState);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.secondaryBackground,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(
            newMasterState
                ? 'Master Controller started. Handlers ready.'
                : 'Master Controller stopped. Active sessions terminated.',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }
  }

  Future<void> _toggleVoiceControl(bool enabled) async {
    if (enabled) {
      final isSetupDone = await _recognitionPrefs.isInitialSetupDone();
      final mode = await _recognitionPrefs.getSelectedMode();

      if (!isSetupDone || mode == null) {
        final locale = await _recognitionPrefs.getSelectedLocale();
        if (!mounted) return;

        // Show Initial Voice Recognition Setup
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => InitialRecognitionSetupSheet(
            locale: locale,
            availabilityService: _availabilityService,
            preferenceService: _recognitionPrefs,
            onModeSelected: (selectedMode) {
              _applyVoiceControlState(true);
            },
          ),
        );
        return;
      }

      // Validate availability before activating
      final locale = await _recognitionPrefs.getSelectedLocale();
      final isAvail = await _availabilityService.isModeAvailable(mode, locale);
      if (!isAvail) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF261919),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            content: Text(
              '${mode.displayName} is currently unavailable for $locale. Open Voice Settings to resolve.',
              style: const TextStyle(color: Color(0xFFFFCDD2)),
            ),
            action: SnackBarAction(
              label: 'Settings',
              textColor: AppColors.accentCyan,
              onPressed: () => _navigateTo(const VoiceSettingsScreen()),
            ),
          ),
        );
        return;
      }
    }

    await _applyVoiceControlState(enabled);
  }

  Future<void> _applyVoiceControlState(bool enabled) async {
    setState(() {
      _state = _state.copyWith(isVoiceEnabled: enabled);
    });

    await _prefsService.setVoiceControlEnabled(enabled);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.secondaryBackground,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          content: Text(
            enabled ? 'Voice Control enabled.' : 'Voice Control disabled.',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }
  }

  Future<void> _toggleGestureControl(bool enabled) async {
    setState(() {
      _state = _state.copyWith(isGestureEnabled: enabled);
    });

    await _prefsService.setGestureControlEnabled(enabled);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.secondaryBackground,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          content: Text(
            enabled ? 'Gesture Control enabled.' : 'Gesture Control disabled.',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }
  }

  Future<void> _toggleReelSession() async {
    if (!_state.isMasterEnabled) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF261D15),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
          content: Text(
            'Cannot start Reel Session while Master Controller is disabled.',
            style: TextStyle(color: Color(0xFFFFB74D), fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }

    final newSessionState = !_state.isSessionActive;

    setState(() {
      _state = _state.copyWith(isSessionActive: newSessionState);
    });

    await _prefsService.setReelSessionActive(newSessionState);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.secondaryBackground,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(
            newSessionState
                ? 'Reel Session Activated. Open Instagram Reels to scroll.'
                : 'Reel Session Stopped.',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryPurple,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    _buildHeader(),

                    const SizedBox(height: 24),

                    // Master Controller Section
                    ControllerCard(
                      isEnabled: _state.isMasterEnabled,
                      onToggle: _toggleMasterController,
                    ),

                    const SizedBox(height: 24),

                    // Control Modes (Voice & Gesture independent cards)
                    const Text(
                      'Control Modes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ControlModeCard(
                            icon: Icons.mic_rounded,
                            title: 'Voice Control',
                            description: 'Scroll via voice commands',
                            isEnabled: _state.isVoiceEnabled,
                            onChanged: _toggleVoiceControl,
                            accentColor: AppColors.accentCyan,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ControlModeCard(
                            icon: Icons.pan_tool_rounded,
                            title: 'Gesture Control',
                            description: 'Scroll via hand gestures',
                            isEnabled: _state.isGestureEnabled,
                            onChanged: _toggleGestureControl,
                            accentColor: AppColors.primaryPurple,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Reel Session Section
                    ReelSessionCard(
                      isSessionActive: _state.isSessionActive,
                      isMasterEnabled: _state.isMasterEnabled,
                      onToggleSession: _toggleReelSession,
                    ),

                    const SizedBox(height: 28),

                    // Quick Actions Section
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    QuickActionCard(
                      icon: Icons.record_voice_over_rounded,
                      title: 'My Voice Commands',
                      subtitle: 'View and customize recognition triggers',
                      accentColor: AppColors.accentCyan,
                      onTap: () => _navigateTo(const VoiceCommandsScreen()),
                    ),
                    const SizedBox(height: 10),
                    QuickActionCard(
                      icon: Icons.flash_on_rounded,
                      title: 'Auto-Start Controller',
                      subtitle: 'Auto-activate hands-free controls on Instagram',
                      accentColor: const Color(0xFF00E5FF),
                      onTap: () => _navigateTo(const AutoStartSettingsScreen()),
                    ),
                    const SizedBox(height: 10),

                    QuickActionCard(
                      icon: Icons.tune_rounded,
                      title: 'Voice Recognition Mode',
                      subtitle: 'Configure Offline / Online speech engine',
                      accentColor: AppColors.accentCyan,
                      onTap: () => _navigateTo(const VoiceSettingsScreen()),
                    ),
                    const SizedBox(height: 10),

                    QuickActionCard(
                      icon: Icons.gesture_rounded,
                      title: 'Gesture Settings',
                      subtitle: 'Calibrate sensitivity and camera input',
                      accentColor: AppColors.primaryPurple,
                      onTap: () => _navigateTo(const GestureSettingsScreen()),
                    ),
                    const SizedBox(height: 10),

                    QuickActionCard(
                      icon: Icons.verified_user_rounded,
                      title: 'Permissions',
                      subtitle: 'On-demand microphone and camera access',
                      accentColor: const Color(0xFF4CAF50),
                      onTap: () => _navigateTo(const PermissionsScreen()),
                    ),
                    const SizedBox(height: 10),

                    QuickActionCard(
                      icon: Icons.security_rounded,
                      title: 'Privacy Settings',
                      subtitle: 'Local data boundary and execution architecture',
                      accentColor: const Color(0xFFFFB74D),
                      onTap: () => _navigateTo(const PrivacySettingsScreen()),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/splashscreenimg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to ReelSense',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Scroll Without Touch.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () => _navigateTo(const SettingsScreen()),
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
