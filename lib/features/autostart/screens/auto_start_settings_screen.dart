import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../recognition/screens/voice_settings_screen.dart';
import '../../recognition/services/recognition_availability_service.dart';
import '../../recognition/services/recognition_preference_service.dart';
import '../models/auto_start_config.dart';
import '../services/auto_start_platform_service.dart';
import '../services/auto_start_preference_service.dart';
import '../widgets/auto_start_setup_sheet.dart';

class AutoStartSettingsScreen extends StatefulWidget {
  final AutoStartPlatformService? platformService;
  final AutoStartPreferenceService? preferenceService;
  final RecognitionAvailabilityService? availabilityService;
  final RecognitionPreferenceService? recognitionPreferenceService;

  const AutoStartSettingsScreen({
    super.key,
    this.platformService,
    this.preferenceService,
    this.availabilityService,
    this.recognitionPreferenceService,
  });

  @override
  State<AutoStartSettingsScreen> createState() => _AutoStartSettingsScreenState();
}

class _AutoStartSettingsScreenState extends State<AutoStartSettingsScreen>
    with WidgetsBindingObserver {
  late final AutoStartPlatformService _platform;
  late final AutoStartPreferenceService _prefs;
  late final RecognitionAvailabilityService _availabilityService;
  late final RecognitionPreferenceService _recognitionPrefs;

  AutoStartConfig _config = AutoStartConfig.defaults();
  AutoStartServiceStatus _status = const AutoStartServiceStatus(
    isMonitoringRunning: false,
    isAccessibilityEnabled: false,
    isOverlayGranted: false,
    hasAccessibilityInstance: false,
  );

  bool _isLoading = true;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platform = widget.platformService ?? AutoStartPlatformService();
    _prefs = widget.preferenceService ?? AutoStartPreferenceService();
    _availabilityService =
        widget.availabilityService ?? RecognitionAvailabilityService();
    _recognitionPrefs =
        widget.recognitionPreferenceService ?? RecognitionPreferenceService();

    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _loadData() async {
    final cfg = await _prefs.loadConfig();
    final st = await _platform.getServiceStatus();

    if (mounted) {
      setState(() {
        _config = cfg;
        _status = st;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    final st = await _platform.getServiceStatus();
    if (mounted) {
      setState(() {
        _status = st;
      });
    }
  }

  Future<void> _handleToggleAutoStart(bool enable) async {
    if (_isToggling) return;

    if (enable) {
      // Check if setup was previously completed and all permissions are present
      final hasCompleted = _config.hasCompletedSetup;
      final isA11y = await _platform.isAccessibilityServiceEnabled();
      final isOverlay = await _platform.isOverlayPermissionGranted();

      if (!hasCompleted || !isA11y || !isOverlay) {
        // Launch One-Time Setup Sheet
        if (!mounted) return;
        final res = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => AutoStartSetupSheet(
            platformService: _platform,
            preferenceService: _prefs,
            availabilityService: _availabilityService,
            recognitionPreferenceService: _recognitionPrefs,
            onSetupCompleted: (ok) {
              _loadData();
            },
          ),
        );

        if (res == true) {
          await _loadData();
        }
        return;
      }

      // If setup already valid, start monitoring service directly
      setState(() => _isToggling = true);
      final ok = await _platform.startMonitoringService(_config.copyWith(isEnabled: true));
      if (ok) {
        await _prefs.setEnabled(true);
        final updated = await _prefs.loadConfig();
        final st = await _platform.getServiceStatus();
        if (mounted) {
          setState(() {
            _config = updated;
            _status = st;
            _isToggling = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isToggling = false);
          _showErrorSnackBar('Failed to start monitoring service.');
        }
      }
    } else {
      // Disabling Auto-Start: stops monitoring and removes overlay
      setState(() => _isToggling = true);
      await _platform.stopMonitoringService();
      await _prefs.setEnabled(false);
      final updated = await _prefs.loadConfig();
      final st = await _platform.getServiceStatus();

      if (mounted) {
        setState(() {
          _config = updated;
          _status = st;
          _isToggling = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.secondaryBackground,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Auto-Start disabled. Background monitoring stopped.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleModeChange(AutoStartControllerMode mode) async {
    final updated = _config.copyWith(controllerMode: mode);
    setState(() {
      _config = updated;
    });
    await _prefs.saveConfig(updated);

    if (_config.isEnabled && _status.isMonitoringRunning) {
      await _platform.updateConfig(updated);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF261919),
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFFFCDD2)),
        ),
      ),
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
          'Auto-Start Controller',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                children: [
                  // Master Switch Card
                  _buildMasterSwitchCard(),

                  const SizedBox(height: 20),

                  // Controller Mode Selection
                  const Text(
                    'Controller Mode on Instagram',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose which hands-free controller activates when Instagram opens.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildModeSelectionRow(),

                  const SizedBox(height: 24),

                  // Diagnostics & Live Status
                  _buildLiveStatusCard(),

                  const SizedBox(height: 24),

                  // Permission & Setup Checklist
                  _buildPermissionsSection(),

                  const SizedBox(height: 24),

                  // Voice Recognition Settings Link (if Voice Mode)
                  if (_config.controllerMode == AutoStartControllerMode.voice) ...[
                    _buildVoiceSettingsTile(),
                    const SizedBox(height: 24),
                  ],

                  // Android Lifecycle & Policy Notices
                  _buildLifecycleNoticeCard(),

                  const SizedBox(height: 20),

                  _buildPolicyNoticeCard(),

                  const SizedBox(height: 28),
                ],
              ),
      ),
    );
  }

  Widget _buildMasterSwitchCard() {
    final isEnabled = _config.isEnabled;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEnabled
              ? AppColors.accentCyan.withValues(alpha: 0.5)
              : AppColors.cardBorder,
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppColors.accentCyan.withValues(alpha: 0.16)
                  : AppColors.chipBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.flash_on_rounded,
              color: isEnabled ? AppColors.accentCyan : AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto-Start Controller',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isEnabled
                      ? 'Activating automatically when Instagram is open'
                      : 'Disabled (requires manual session launch)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isEnabled ? AppColors.accentCyan : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            activeTrackColor: AppColors.accentCyan,
            activeThumbColor: Colors.black,
            inactiveTrackColor: AppColors.chipBackground,
            inactiveThumbColor: AppColors.textSecondary,
            onChanged: _isToggling ? null : _handleToggleAutoStart,
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectionRow() {
    return Row(
      children: [
        Expanded(
          child: _buildModeCard(
            mode: AutoStartControllerMode.voice,
            icon: Icons.mic_rounded,
            color: AppColors.accentCyan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildModeCard(
            mode: AutoStartControllerMode.gesture,
            icon: Icons.pan_tool_rounded,
            color: AppColors.primaryPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required AutoStartControllerMode mode,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _config.controllerMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _handleModeChange(mode),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.14) : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? color : AppColors.textSecondary, size: 22),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              mode.displayName,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mode.key == 'voice' ? 'Speech commands' : 'Hand tracking',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatusCard() {
    final isRunning = _status.isMonitoringRunning;
    final isA11y = _status.isAccessibilityEnabled;
    final isOverlay = _status.isOverlayGranted;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Diagnostic Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.accentCyan, size: 18),
                onPressed: _refreshStatus,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
            label: 'Monitoring Service',
            value: isRunning ? 'Running (Foreground)' : 'Stopped',
            isOk: isRunning,
          ),
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildStatusRow(
            label: 'Accessibility Service',
            value: isA11y ? 'Connected' : 'Disabled in Settings',
            isOk: isA11y,
          ),
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildStatusRow(
            label: 'Floating Overlay Window',
            value: isOverlay ? 'Granted' : 'Permission Required',
            isOk: isOverlay,
          ),
          const Divider(color: AppColors.cardBorder, height: 16),
          _buildStatusRow(
            label: 'Target Package',
            value: 'com.instagram.android',
            isOk: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow({
    required String label,
    required String value,
    required bool isOk,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOk ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isOk ? const Color(0xFFE8F5E9) : const Color(0xFFFFCDD2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPermissionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permissions & Services Checklist',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          title: 'Accessibility Service',
          subtitle: 'Required to detect Instagram foreground window and perform reel gestures.',
          isGranted: _status.isAccessibilityEnabled,
          actionText: 'Settings',
          onTap: () async {
            await _platform.openAccessibilitySettings();
          },
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          title: 'Display Over Other Apps',
          subtitle: 'Required to show the hands-free floating status card over Instagram.',
          isGranted: _status.isOverlayGranted,
          actionText: 'Grant',
          onTap: () async {
            await _platform.requestOverlayPermission();
          },
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required bool isGranted,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: isGranted ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentCyan,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionText,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceSettingsTile() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.settings_voice_rounded, color: AppColors.accentCyan, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Recognition Mode',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Configure Offline / Online mode and language',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 14),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const VoiceSettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.battery_charging_full_rounded, color: AppColors.primaryPurple, size: 18),
              SizedBox(width: 8),
              Text(
                'Android Lifecycle & Restrictions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Android 14+ requires foreground services to be started while the app is visible.\n'
            '• A persistent user-visible notification remains in your shade while monitoring is active.\n'
            '• If you Force-Stop ReelSense via Android App Info, the OS halts all background services until ReelSense is opened again.\n'
            '• Microphone and camera resources are freed immediately whenever Instagram is minimized or left.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.policy_outlined, color: AppColors.accentCyan, size: 18),
              SizedBox(width: 8),
              Text(
                'Google Play Accessibility Policy Compliance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'ReelSense uses the Android AccessibilityService API strictly to detect when Instagram is the active foreground app and perform user-directed navigation gestures (scroll up/down, like, pause). '
            'ReelSense does not monitor, collect, or transmit personal data, keystrokes, messages, or audio to any server.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
