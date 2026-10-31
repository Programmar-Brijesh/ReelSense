import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../recognition/models/recognition_mode.dart';
import '../../recognition/services/recognition_availability_service.dart';
import '../../recognition/services/recognition_preference_service.dart';
import '../models/auto_start_config.dart';
import '../services/auto_start_platform_service.dart';
import '../services/auto_start_preference_service.dart';

class AutoStartSetupSheet extends StatefulWidget {
  final AutoStartPlatformService? platformService;
  final AutoStartPreferenceService? preferenceService;
  final RecognitionAvailabilityService? availabilityService;
  final RecognitionPreferenceService? recognitionPreferenceService;
  final ValueChanged<bool>? onSetupCompleted;

  const AutoStartSetupSheet({
    super.key,
    this.platformService,
    this.preferenceService,
    this.availabilityService,
    this.recognitionPreferenceService,
    this.onSetupCompleted,
  });

  @override
  State<AutoStartSetupSheet> createState() => _AutoStartSetupSheetState();
}

class _AutoStartSetupSheetState extends State<AutoStartSetupSheet>
    with WidgetsBindingObserver {
  late final AutoStartPlatformService _platform;
  late final AutoStartPreferenceService _prefs;
  late final RecognitionAvailabilityService _availabilityService;
  late final RecognitionPreferenceService _recognitionPrefs;

  AutoStartControllerMode _selectedMode = AutoStartControllerMode.voice;
  RecognitionMode _recognitionMode = RecognitionMode.offline;
  String _locale = 'en-US';

  bool _isLoading = true;
  bool _isAccessibilityGranted = false;
  bool _isOverlayGranted = false;
  bool _isAudioGranted = false;
  bool _isCameraGranted = false;
  bool _isVoiceEngineReady = false;

  bool _isStartingService = false;
  String? _errorMessage;

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

    _loadInitialState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndStatus();
    }
  }

  Future<void> _loadInitialState() async {
    final config = await _prefs.loadConfig();
    final recMode = await _recognitionPrefs.getSelectedMode() ?? RecognitionMode.offline;
    final locale = await _recognitionPrefs.getSelectedLocale();

    setState(() {
      _selectedMode = config.controllerMode;
      _recognitionMode = recMode;
      _locale = locale;
    });

    await _checkPermissionsAndStatus();
  }

  Future<void> _checkPermissionsAndStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isA11y = await _platform.isAccessibilityServiceEnabled();
      final isOverlay = await _platform.isOverlayPermissionGranted();
      final isAudio = await _availabilityService.hasRecordAudioPermission();

      // Check voice engine readiness
      bool voiceReady = false;
      if (_selectedMode == AutoStartControllerMode.voice) {
        final avail = await _availabilityService.checkAvailability(_locale);
        voiceReady = avail.isModeAvailable(_recognitionMode);
      }

      if (mounted) {
        setState(() {
          _isAccessibilityGranted = isA11y;
          _isOverlayGranted = isOverlay;
          _isAudioGranted = isAudio;
          _isCameraGranted = true; // Placeholder for gesture camera check
          _isVoiceEngineReady = voiceReady;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to verify system status: $e';
        });
      }
    }
  }

  bool get _areAllPrerequisitesMet {
    if (!_isAccessibilityGranted) return false;
    if (!_isOverlayGranted) return false;

    if (_selectedMode == AutoStartControllerMode.voice) {
      if (!_isAudioGranted) return false;
      if (!_isVoiceEngineReady) return false;
    } else {
      if (!_isCameraGranted) return false;
    }

    return true;
  }

  Future<void> _handleStartAndEnable() async {
    if (!_areAllPrerequisitesMet) {
      setState(() {
        _errorMessage = 'Please complete all required permissions above before enabling Auto-Start.';
      });
      return;
    }

    setState(() {
      _isStartingService = true;
      _errorMessage = null;
    });

    final newConfig = AutoStartConfig(
      isEnabled: true,
      controllerMode: _selectedMode,
      recognitionMode: _recognitionMode,
      locale: _locale,
      hasCompletedSetup: true,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    // 8. Start foreground monitoring service while ReelSense is in foreground
    final startSuccess = await _platform.startMonitoringService(newConfig);

    // 9. Confirm that service is actually running
    final isRunning = await _platform.isMonitoringServiceRunning();

    if (startSuccess && isRunning) {
      // 10. Save Auto-Start as enabled only after successful setup
      await _prefs.saveConfig(newConfig);

      if (mounted) {
        setState(() {
          _isStartingService = false;
        });
        widget.onSetupCompleted?.call(true);
        Navigator.of(context).pop(true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF132A22),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
            content: Text(
              'Auto-Start Active! Open Instagram to test hands-free controls.',
              style: TextStyle(color: Color(0xFFE8F5E9), fontWeight: FontWeight.w700),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isStartingService = false;
          _errorMessage = 'Could not verify background service launch. Please ensure notification permissions are allowed and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Start Setup',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Configure automatic hands-free activation for Instagram',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (_isLoading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 36.0),
                    child: CircularProgressIndicator(color: AppColors.accentCyan),
                  ),
                ),
              ] else ...[
                // Mode Selection
                const Text(
                  '1. Select Controller Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                _buildModeSelector(),

                const SizedBox(height: 20),

                // Checklist Section
                const Text(
                  '2. Verify Required Capabilities',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                // Step A: Accessibility Service
                _buildChecklistItem(
                  title: 'Accessibility Service',
                  subtitle: 'Detects when Instagram is in foreground and injects reel swipes.',
                  icon: Icons.accessibility_new_rounded,
                  isGranted: _isAccessibilityGranted,
                  actionLabel: 'Enable Service',
                  onAction: () async {
                    await _platform.openAccessibilitySettings();
                  },
                ),

                const SizedBox(height: 10),

                // Step B: Draw Over Apps / Overlay
                _buildChecklistItem(
                  title: 'Display Over Other Apps',
                  subtitle: 'Displays floating status card showing speech feedback and controls.',
                  icon: Icons.layers_rounded,
                  isGranted: _isOverlayGranted,
                  actionLabel: 'Allow Overlay',
                  onAction: () async {
                    await _platform.requestOverlayPermission();
                  },
                ),

                const SizedBox(height: 10),

                // Step C: Mode-specific permissions
                if (_selectedMode == AutoStartControllerMode.voice) ...[
                  _buildChecklistItem(
                    title: 'Microphone Permission',
                    subtitle: 'Active ONLY while Instagram is on-screen. Never records audio.',
                    icon: Icons.mic_rounded,
                    isGranted: _isAudioGranted,
                    actionLabel: 'Grant Mic Access',
                    onAction: () async {
                      await _availabilityService.requestRecordAudioPermission();
                      await _checkPermissionsAndStatus();
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildChecklistItem(
                    title: 'Voice Recognition Readiness',
                    subtitle: 'Engine readiness for $_recognitionMode mode ($_locale).',
                    icon: Icons.settings_voice_rounded,
                    isGranted: _isVoiceEngineReady,
                    actionLabel: 'Fix in Voice Settings',
                    onAction: () {
                      _checkPermissionsAndStatus();
                    },
                  ),
                ] else ...[
                  _buildChecklistItem(
                    title: 'Camera Permission',
                    subtitle: 'Required for front-camera hand gesture tracking.',
                    icon: Icons.camera_alt_rounded,
                    isGranted: _isCameraGranted,
                    actionLabel: 'Grant Camera',
                    onAction: () {
                      _checkPermissionsAndStatus();
                    },
                  ),
                ],

                const SizedBox(height: 20),

                // Privacy and Background Monitoring Notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.accentCyan, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Privacy & Background Monitoring',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• A persistent user-visible notification will be displayed while monitoring is active.\n'
                        '• Microphone and camera are captured ONLY when Instagram is in the foreground.\n'
                        '• Audio and camera frames are processed entirely in memory and NEVER stored or recorded.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF261919),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFFCDD2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Start and Enable Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isStartingService ? null : _handleStartAndEnable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _areAllPrerequisitesMet
                          ? AppColors.accentCyan
                          : AppColors.chipBackground,
                      foregroundColor: _areAllPrerequisitesMet
                          ? Colors.black
                          : AppColors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: _areAllPrerequisitesMet ? 4 : 0,
                    ),
                    child: _isStartingService
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            _areAllPrerequisitesMet
                                ? 'Start & Enable Auto-Start'
                                : 'Complete Requirements Above',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModeChoiceChip(
            mode: AutoStartControllerMode.voice,
            icon: Icons.mic_rounded,
            color: AppColors.accentCyan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildModeChoiceChip(
            mode: AutoStartControllerMode.gesture,
            icon: Icons.pan_tool_rounded,
            color: AppColors.primaryPurple,
          ),
        ),
      ],
    );
  }

  Widget _buildModeChoiceChip({
    required AutoStartControllerMode mode,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _selectedMode = mode;
        });
        _checkPermissionsAndStatus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.16) : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mode.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isGranted,
    required String actionLabel,
    required VoidCallback onAction,
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isGranted
                  ? const Color(0xFF132A22)
                  : AppColors.chipBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? const Color(0xFF4CAF50) : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isGranted ? '✓ READY' : '• REQUIRED',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isGranted
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF9800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (!isGranted) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentCyan,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
