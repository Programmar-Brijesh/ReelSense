import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/recognition_availability.dart';
import '../models/recognition_mode.dart';
import '../services/recognition_availability_service.dart';
import '../services/recognition_preference_service.dart';

class InitialRecognitionSetupSheet extends StatefulWidget {
  final String locale;
  final RecognitionAvailabilityService availabilityService;
  final RecognitionPreferenceService preferenceService;
  final ValueChanged<RecognitionMode> onModeSelected;

  const InitialRecognitionSetupSheet({
    super.key,
    required this.locale,
    required this.availabilityService,
    required this.preferenceService,
    required this.onModeSelected,
  });

  @override
  State<InitialRecognitionSetupSheet> createState() =>
      _InitialRecognitionSetupSheetState();
}

class _InitialRecognitionSetupSheetState
    extends State<InitialRecognitionSetupSheet> with WidgetsBindingObserver {
  bool _isLoading = true;
  RecognitionAvailability? _availability;
  bool _isCheckingAgain = false;
  bool _isDownloading = false;
  String? _infoNotice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDeviceAvailability();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isDownloading) {
      _checkDeviceAvailability(isReturningFromSettings: true);
    }
  }

  Future<void> _checkDeviceAvailability({bool isReturningFromSettings = false}) async {
    setState(() {
      _isCheckingAgain = true;
      if (!isReturningFromSettings) _isLoading = true;
    });

    final avail = await widget.availabilityService.checkAvailability(widget.locale);

    if (mounted) {
      setState(() {
        _availability = avail;
        _isLoading = false;
        _isCheckingAgain = false;

        if (isReturningFromSettings) {
          final isOfflineNow = avail.isModeAvailable(RecognitionMode.offline);
          if (isOfflineNow) {
            _infoNotice = 'Offline language pack detected and ready!';
          } else {
            _infoNotice =
                'Language pack is still not installed. You can retry downloading or proceed with Online Recognition.';
          }
        }
      });
    }
  }

  Future<void> _handleDownloadLanguagePack() async {
    setState(() {
      _isDownloading = true;
      _infoNotice = 'Opening language download service...';
    });

    final triggered =
        await widget.availabilityService.triggerModelDownload(widget.locale);

    if (!triggered && mounted) {
      await widget.availabilityService.openVoiceSettings();
    }
  }

  Future<void> _selectMode(RecognitionMode mode) async {
    await widget.preferenceService.setSelectedMode(mode);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onModeSelected(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 14.0,
        bottom: bottomInset + 24.0,
      ),
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice Recognition Setup',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Choose how ReelSense listens to your commands',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 36.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.accentCyan,
                        strokeWidth: 2.5,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Checking on-device recognition support...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              if (_infoNotice != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.accentCyan,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _infoNotice!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Check if offline mode is available for this locale
              if (_availability != null &&
                  _availability!.isModeAvailable(RecognitionMode.offline))
                _buildCaseAOfflineAvailable()
              else
                _buildCaseBOfflineUnavailable(),
            ],
          ],
        ),
      ),
    );
  }

  /// Case A: Offline is available on the device
  Widget _buildCaseAOfflineAvailable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF132A22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF4CAF50),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'On-device speech pack is installed for ${widget.locale}.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFE8F5E9),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Choice 1: Use Offline Recognition
        _buildOptionCard(
          mode: RecognitionMode.offline,
          badge: 'RECOMMENDED • PRIVATE',
          onTap: () => _selectMode(RecognitionMode.offline),
        ),

        const SizedBox(height: 12),

        // Choice 2: Use Online Recognition
        _buildOptionCard(
          mode: RecognitionMode.online,
          badge: 'CLOUD-ASSISTED',
          onTap: () => _selectMode(RecognitionMode.online),
        ),
      ],
    );
  }

  /// Case B: Offline is NOT available on the device
  Widget _buildCaseBOfflineUnavailable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Missing offline pack banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF261919),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF5252).withValues(alpha: 0.4),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFFF5252),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Offline Language Pack Not Available',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Download the language pack to use offline voice recognition, or continue with online recognition.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFFFCDD2),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),

        // Choice 1: Download Language Pack
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _handleDownloadLanguagePack,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        color: AppColors.accentCyan,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Download Language Pack',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Install on-device model via Android system settings',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (_isDownloading) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: _isCheckingAgain
                  ? null
                  : () => _checkDeviceAvailability(isReturningFromSettings: true),
              icon: _isCheckingAgain
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentCyan,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Re-check Language Pack Status'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentCyan,
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Choice 2: Use Online Recognition
        _buildOptionCard(
          mode: RecognitionMode.online,
          badge: 'READY TO USE',
          onTap: () => _selectMode(RecognitionMode.online),
        ),
      ],
    );
  }

  Widget _buildOptionCard({
    required RecognitionMode mode,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mode.accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(mode.icon, color: mode.accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            mode.displayName,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: mode.accentColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: mode.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        mode.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
