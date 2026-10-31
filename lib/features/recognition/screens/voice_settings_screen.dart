import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/recognition_availability.dart';
import '../models/recognition_mode.dart';
import '../services/recognition_availability_service.dart';
import '../services/recognition_preference_service.dart';

class VoiceSettingsScreen extends StatefulWidget {
  final RecognitionPreferenceService? preferenceService;
  final RecognitionAvailabilityService? availabilityService;

  const VoiceSettingsScreen({
    super.key,
    this.preferenceService,
    this.availabilityService,
  });

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen>
    with WidgetsBindingObserver {
  late final RecognitionPreferenceService _prefs;
  late final RecognitionAvailabilityService _availabilityService;

  RecognitionMode? _selectedMode;
  String _selectedLocale = RecognitionPreferenceService.defaultLocale;
  RecognitionAvailability _availability = RecognitionAvailability.unknown();
  bool _isLoading = true;
  bool _isChecking = false;
  bool _isDownloading = false;

  final List<Map<String, String>> _availableLocales = [
    {'code': 'en-US', 'name': 'English (United States)'},
    {'code': 'en-IN', 'name': 'English (India)'},
    {'code': 'hi-IN', 'name': 'Hindi (India - हिंदी)'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prefs = widget.preferenceService ?? RecognitionPreferenceService();
    _availabilityService =
        widget.availabilityService ?? RecognitionAvailabilityService();
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isDownloading) {
      _checkAvailability(silent: false);
    }
  }

  Future<void> _loadSettings() async {
    final mode = await _prefs.getSelectedMode();
    final locale = await _prefs.getSelectedLocale();
    final avail = await _availabilityService.checkAvailability(locale);

    if (mounted) {
      setState(() {
        _selectedMode = mode;
        _selectedLocale = locale;
        _availability = avail;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAvailability({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isChecking = true;
      });
    }

    final avail = await _availabilityService.checkAvailability(_selectedLocale);

    if (mounted) {
      setState(() {
        _availability = avail;
        _isChecking = false;
      });
    }
  }

  Future<void> _changeLocale(String newLocale) async {
    setState(() {
      _selectedLocale = newLocale;
      _isChecking = true;
    });

    await _prefs.setSelectedLocale(newLocale);
    final avail = await _availabilityService.checkAvailability(newLocale);

    if (mounted) {
      setState(() {
        _availability = avail;
        _isChecking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.secondaryBackground,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Language set to ${_getLocaleDisplayName(newLocale)}.',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
    }
  }

  String _getLocaleDisplayName(String code) {
    return _availableLocales.firstWhere(
      (l) => l['code'] == code,
      orElse: () => {'name': code},
    )['name']!;
  }

  Future<void> _handleModeSelection(RecognitionMode targetMode) async {
    if (_selectedMode == targetMode) return;

    if (targetMode == RecognitionMode.offline) {
      // Online -> Offline: Verify offline availability first
      await _switchToOffline();
    } else {
      // Offline -> Online: Save Online and verify
      await _switchToOnline();
    }
  }

  Future<void> _switchToOffline() async {
    setState(() {
      _isChecking = true;
    });

    final avail = await _availabilityService.checkAvailability(_selectedLocale);
    final isOfflineReady = avail.isModeAvailable(RecognitionMode.offline);

    if (!mounted) return;

    setState(() {
      _availability = avail;
      _isChecking = false;
    });

    if (isOfflineReady) {
      // Verified! Save Offline
      await _prefs.setSelectedMode(RecognitionMode.offline);
      setState(() {
        _selectedMode = RecognitionMode.offline;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF132A22),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Offline Recognition enabled. On-device engine active.',
              style: TextStyle(color: Color(0xFFE8F5E9)),
            ),
          ),
        );
      }
    } else {
      // Missing offline language pack! Show download prompt. Do NOT change preference.
      _showMissingOfflineDialog();
    }
  }

  Future<void> _switchToOnline() async {
    setState(() {
      _isChecking = true;
    });

    final avail = await _availabilityService.checkAvailability(_selectedLocale);
    final isOnlineReady = avail.isModeAvailable(RecognitionMode.online);

    if (!mounted) return;

    setState(() {
      _availability = avail;
      _isChecking = false;
    });

    if (isOnlineReady) {
      await _prefs.setSelectedMode(RecognitionMode.online);
      setState(() {
        _selectedMode = RecognitionMode.online;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.secondaryBackground,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Online Recognition enabled. Cloud speech processing active.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    } else {
      // Online service unavailable on device
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.secondaryBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Online Service Unavailable',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'The Android speech recognition service is not responding or network is unavailable. Your recognition mode remains unchanged.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(color: AppColors.accentCyan)),
            ),
          ],
        ),
      );
    }
  }

  void _showMissingOfflineDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: Color(0xFFFF5252), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Offline Pack Not Available',
                style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Download the language pack for ${_getLocaleDisplayName(_selectedLocale)} to use offline voice recognition, or continue with online recognition.\n\nYour preference remains unchanged until the download is verified.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() {
                _isDownloading = true;
              });
              final ok = await _availabilityService.triggerModelDownload(_selectedLocale);
              if (!ok && mounted) {
                await _availabilityService.openVoiceSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Download Language Pack', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
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
          'Voice Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Mode Banner
                    _buildActiveModeBanner(),

                    const SizedBox(height: 24),

                    // Section: Speech Recognition Mode
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Speech Recognition Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (_isChecking)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accentCyan,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select on-device offline processing or cloud-assisted recognition. Your choice is permanently saved and never changed automatically.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Offline Mode Option Card
                    _buildModeCard(
                      mode: RecognitionMode.offline,
                      isAvailable: _availability.isModeAvailable(RecognitionMode.offline),
                    ),

                    const SizedBox(height: 12),

                    // Online Mode Option Card
                    _buildModeCard(
                      mode: RecognitionMode.online,
                      isAvailable: _availability.isModeAvailable(RecognitionMode.online),
                    ),

                    // Offline Language Pack Missing Callout (if offline selected or inspected without pack)
                    if (!_availability.isModeAvailable(RecognitionMode.offline)) ...[
                      const SizedBox(height: 14),
                      _buildMissingLanguagePackCallout(),
                    ],

                    const SizedBox(height: 26),

                    // Section: Language Selection
                    const Text(
                      'Recognition Language',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'SpeechRecognizer matches voice commands in this locale.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildLanguageSelector(),

                    const SizedBox(height: 26),

                    // Section: Availability & System Diagnostics
                    _buildDiagnosticsCard(),

                    const SizedBox(height: 26),

                    // Section: Privacy & Data Protection
                    _buildPrivacyCard(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildActiveModeBanner() {
    final mode = _selectedMode;
    final isConfigured = mode != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConfigured
              ? mode.accentColor.withValues(alpha: 0.4)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isConfigured
                  ? mode.accentColor.withValues(alpha: 0.16)
                  : AppColors.chipBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isConfigured ? mode.icon : Icons.mic_off_rounded,
              color: isConfigured ? mode.accentColor : AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isConfigured ? mode.displayName : 'Not Configured',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (isConfigured) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: mode.accentColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          mode.badgeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: mode.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isConfigured
                      ? 'Active for ${_getLocaleDisplayName(_selectedLocale)}'
                      : 'Voice Control initial setup not completed',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required RecognitionMode mode,
    required bool isAvailable,
  }) {
    final isSelected = _selectedMode == mode;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? mode.accentColor : AppColors.cardBorder,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: mode.accentColor.withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleModeSelection(mode),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? mode.accentColor : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      mode.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? const Color(0xFF132A22)
                            : const Color(0xFF261919),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isAvailable
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF5252),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 32.0),
                  child: Text(
                    mode.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissingLanguagePackCallout() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF261919),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Color(0xFFFF5252), size: 18),
              SizedBox(width: 8),
              Text(
                'Offline language pack not available',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Download the language pack to use offline voice recognition, or continue with online recognition.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFFFCDD2),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() {
                    _isDownloading = true;
                  });
                  final ok = await _availabilityService.triggerModelDownload(_selectedLocale);
                  if (!ok && mounted) {
                    await _availabilityService.openVoiceSettings();
                  }
                },
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download Language Pack'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _checkAvailability(silent: false),
                child: const Text('Re-check', style: TextStyle(color: AppColors.accentCyan)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLocale,
          dropdownColor: AppColors.secondaryBackground,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accentCyan),
          isExpanded: true,
          items: _availableLocales.map((locale) {
            return DropdownMenuItem<String>(
              value: locale['code'],
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Text(
                    locale['name']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              _changeLocale(val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildDiagnosticsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Engine & Hardware Diagnostics',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.accentCyan),
                tooltip: 'Re-check engine availability',
                onPressed: () => _checkAvailability(silent: false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDiagRow(
            'SpeechRecognizer Service',
            _availability.isRecognitionAvailable ? 'Available' : 'Unavailable',
            _availability.isRecognitionAvailable,
          ),
          _buildDiagRow(
            'On-Device Engine Support',
            _availability.isOnDeviceAvailable ? 'Supported' : 'Not Supported',
            _availability.isOnDeviceAvailable,
          ),
          _buildDiagRow(
            'Offline Language Pack ($_selectedLocale)',
            _availability.isOfflineLocaleInstalled ? 'Installed & Ready' : 'Not Installed',
            _availability.isOfflineLocaleInstalled,
          ),
          _buildDiagRow(
            'Android Platform API',
            'API ${_availability.androidApiVersion}',
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildDiagRow(String label, String value, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isOk ? const Color(0xFF81C784) : const Color(0xFFFF8A80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.shield_outlined, color: AppColors.accentCyan, size: 18),
              SizedBox(width: 8),
              Text(
                'Audio Privacy Architecture',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Offline Mode: Microphone input is transcribed strictly on-device using local weights. No audio or text leaves your phone.\n\n• Online Mode: High-accuracy recognition processed by your device\'s speech provider. Audio is never recorded or stored to disk by ReelSense.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
