import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../commands/models/reel_action.dart';
import '../data/custom_gesture_repository.dart';
import '../models/custom_gesture.dart';
import '../services/gesture_platform_service.dart';

class CustomGestureRegistrationScreen extends StatefulWidget {
  final CustomGestureRepository? repository;
  final GesturePlatformService? platformService;

  const CustomGestureRegistrationScreen({
    super.key,
    this.repository,
    this.platformService,
  });

  @override
  State<CustomGestureRegistrationScreen> createState() =>
      _CustomGestureRegistrationScreenState();
}

class _CustomGestureRegistrationScreenState
    extends State<CustomGestureRegistrationScreen> {
  late final CustomGestureRepository _repository;
  late final GesturePlatformService _platformService;

  // Step 0: Select Action
  // Step 1: Camera & Hand Positioning
  // Step 2: Sampling & Validation
  // Step 3: Name & Confirmation
  // Step 4: Test Saved Gesture
  int _currentStep = 0;

  ReelAction _selectedAction = ReelAction.nextReel;
  final TextEditingController _nameController = TextEditingController();

  bool _isCapturing = false;
  int _sampleCount = 0;
  final int _targetSamples = 25;
  bool _isHandPresent = false;
  String? _capturedTemplateJson;
  String? _captureStatusMessage;
  String? _conflictError;
  bool _isValidating = false;

  // Testing mode state
  bool _isTesting = false;
  String? _testDetectedGesture;
  double _testSimilarity = 0.0;
  String? _testDetectedAction;
  bool _testHandPresent = false;

  StreamSubscription? _progressSub;
  StreamSubscription? _testSub;

  CustomGesture? _savedGesture;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SqliteCustomGestureRepository();
    _platformService = widget.platformService ?? GesturePlatformService();
    _listenToStreams();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _testSub?.cancel();
    _platformService.stopGestureRegistration();
    _platformService.stopGestureTest();
    _nameController.dispose();
    super.dispose();
  }

  void _listenToStreams() {
    _progressSub = _platformService.registrationProgressEvents.listen((event) {
      if (!mounted) return;
      final samples = (event['sampleCount'] as num?)?.toInt() ?? 0;
      final hand = event['isHandPresent'] as bool? ?? false;
      final complete = event['isComplete'] as bool? ?? false;
      final template = event['templateJson'] as String?;
      final err = event['error'] as String?;

      setState(() {
        _sampleCount = samples;
        _isHandPresent = hand;
        if (err != null && err.isNotEmpty) {
          _captureStatusMessage = err;
        } else if (hand) {
          _captureStatusMessage = 'Hand Detected! Recording stable samples ($samples/$_targetSamples)...';
        } else {
          _captureStatusMessage = 'Searching for hand... Position your hand in front of the front camera';
        }
      });

      if (complete && template != null && _capturedTemplateJson == null) {
        _capturedTemplateJson = template;
        _onCaptureComplete(template);
      }
    });

    _testSub = _platformService.testEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        _testHandPresent = event['isHandPresent'] as bool? ?? false;
        _testDetectedGesture = event['gestureName'] as String?;
        _testSimilarity = (event['similarity'] as num?)?.toDouble() ?? 0.0;
        _testDetectedAction = event['action'] as String?;
      });
    });
  }

  Future<void> _startSampling() async {
    final hasCam = await _platformService.hasCameraPermission();
    if (!hasCam) {
      final granted = await _platformService.requestCameraPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required to capture hand gestures.')),
          );
        }
        return;
      }
    }

    setState(() {
      _isCapturing = true;
      _sampleCount = 0;
      _capturedTemplateJson = null;
      _conflictError = null;
      _captureStatusMessage = 'Position your hand clearly in front of the camera';
    });

    await _platformService.startGestureRegistration();
  }

  Future<void> _stopSampling() async {
    await _platformService.stopGestureRegistration();
    if (mounted) {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _onCaptureComplete(String templateJson) async {
    await _stopSampling();

    setState(() => _isValidating = true);

    // Conflict Validation: check against defaults and registered custom gestures
    final conflict = await _platformService.validateGestureConflict(templateJson);

    if (!mounted) return;

    if (conflict['hasConflict'] == true) {
      setState(() {
        _isValidating = false;
        _capturedTemplateJson = null;
        _conflictError = conflict['reason'] as String? ??
            'This gesture conflicts with "${conflict['conflictingGestureName']}".';
      });
    } else {
      setState(() {
        _isValidating = false;
        _currentStep = 2; // Proceed to naming & preview
      });
    }
  }

  Future<void> _saveGesture() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for your custom gesture.')),
      );
      return;
    }

    if (_capturedTemplateJson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No landmark template captured. Please re-sample.')),
      );
      return;
    }

    final now = DateTime.now();
    final newGesture = CustomGesture(
      id: 'gesture_${now.millisecondsSinceEpoch}',
      name: name,
      action: _selectedAction,
      landmarkTemplateJson: _capturedTemplateJson!,
      sampleCount: _targetSamples,
      confidenceThreshold: 0.82,
      isEnabled: true,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.createGesture(newGesture);
    final allGestures = await _repository.getAllGestures();
    await _platformService.syncCustomGestures(allGestures);

    setState(() {
      _savedGesture = newGesture;
      _currentStep = 3; // Step: Interactive test
    });

    _startTesting();
  }

  Future<void> _startTesting() async {
    setState(() => _isTesting = true);
    await _platformService.startGestureTest();
  }

  Future<void> _stopTesting() async {
    await _platformService.stopGestureTest();
    if (mounted) {
      setState(() => _isTesting = false);
    }
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
          onPressed: () {
            _stopSampling();
            _stopTesting();
            Navigator.of(context).pop(_savedGesture != null);
          },
        ),
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepperHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: _buildStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentStep) {
      case 0:
        return 'Step 1: Select Action';
      case 1:
        return 'Step 2: Capture Hand Pose';
      case 2:
        return 'Step 3: Name & Save';
      case 3:
        return 'Step 4: Test Gesture';
      default:
        return 'Register Gesture';
    }
  }

  Widget _buildStepperHeader() {
    final steps = ['Action', 'Capture', 'Save', 'Test'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (index) {
          final isDone = _currentStep > index;
          final isCurrent = _currentStep == index;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AppColors.accentCyan
                        : isCurrent
                            ? AppColors.primaryPurple
                            : AppColors.secondaryBackground,
                    border: Border.all(
                      color: isCurrent ? AppColors.accentCyan : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.black)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: isDone ? AppColors.accentCyan : AppColors.cardBorder,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildActionSelectionStep();
      case 1:
        return _buildCaptureStep();
      case 2:
        return _buildSaveStep();
      case 3:
        return _buildTestStep();
      default:
        return const SizedBox();
    }
  }

  // --- Step 1: Action Selection ---

  Widget _buildActionSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose Instagram Action',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select the Reel navigation action you want to trigger with your new hand gesture.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        ...ReelAction.values.map((action) {
          final isSelected = _selectedAction == action;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: () => setState(() => _selectedAction = action),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryPurple.withValues(alpha: 0.15)
                      : AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.accentCyan : AppColors.cardBorder,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryPurple
                            : AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getActionIcon(action),
                        color: isSelected ? Colors.white : AppColors.accentCyan,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            action.description,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, color: AppColors.accentCyan, size: 22),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() => _currentStep = 1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Continue to Camera Capture', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Step 2: Camera Capture ---

  Widget _buildCaptureStep() {
    final progress = _sampleCount / _targetSamples;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Target Action & Live Camera Badges
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Target Action: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  Text(
                    _selectedAction.displayName,
                    style: const TextStyle(color: AppColors.accentCyan, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (_isCapturing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (_isHandPresent ? AppColors.accentCyan : const Color(0xFFFFB300)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (_isHandPresent ? AppColors.accentCyan : const Color(0xFFFFB300)).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isHandPresent ? AppColors.accentCyan : const Color(0xFFFFB300),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isHandPresent ? 'Hand Tracking' : 'Camera Scanning',
                      style: TextStyle(
                        color: _isHandPresent ? AppColors.accentCyan : const Color(0xFFFFB300),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),

        // Live Hand Status Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isCapturing
                  ? (_isHandPresent ? AppColors.accentCyan : const Color(0xFFFFB300).withValues(alpha: 0.6))
                  : AppColors.cardBorder,
              width: 1.8,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCapturing
                      ? (_isHandPresent
                          ? AppColors.accentCyan.withValues(alpha: 0.2)
                          : const Color(0xFFFFB300).withValues(alpha: 0.15))
                      : AppColors.cardSurface,
                ),
                child: Icon(
                  _isHandPresent
                      ? Icons.pan_tool_rounded
                      : (_isCapturing ? Icons.camera_front_rounded : Icons.front_hand_outlined),
                  size: 42,
                  color: _isCapturing
                      ? (_isHandPresent ? AppColors.accentCyan : const Color(0xFFFFB300))
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isHandPresent
                    ? 'Hand Detected!'
                    : (_isCapturing ? 'Searching for Hand...' : 'Show Hand to Camera'),
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: _isHandPresent
                      ? AppColors.accentCyan
                      : (_isCapturing ? const Color(0xFFFFD54F) : Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _captureStatusMessage ??
                    (_isHandPresent
                        ? 'Hold steady! Capturing 25 landmark frames...'
                        : (_isCapturing
                            ? 'Position your hand clearly in front of the front camera (20–40 cm)'
                            : 'Hold your static hand pose clearly in front of the front camera.')),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _isHandPresent ? Colors.white70 : AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: AppColors.cardSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _sampleCount >= _targetSamples
                        ? const Color(0xFF00E676)
                        : AppColors.accentCyan,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isCapturing
                        ? (_isHandPresent ? 'Recording samples...' : 'Waiting for hand...')
                        : 'Not capturing',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    '$_sampleCount / $_targetSamples Samples (${(progress * 100).toInt()}%)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _sampleCount > 0 ? AppColors.accentCyan : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (_conflictError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _conflictError!,
                    style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Controls
        if (!_isCapturing)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startSampling,
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(_conflictError != null ? 'Try Again' : 'Start Hand Capture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _stopSampling,
              icon: const Icon(Icons.stop_circle_rounded, color: Color(0xFFFF5252)),
              label: const Text('Cancel Capture', style: TextStyle(color: Color(0xFFFF5252))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF5252)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

        if (_isValidating) ...[
          const SizedBox(height: 16),
          const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan)),
                SizedBox(width: 10),
                Text('Validating conflicts against default and custom gestures...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Step 3: Name & Save ---

  Widget _buildSaveStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Name Your Custom Gesture',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a descriptive name to easily identify your static hand pose.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),

        // Gesture Name Input
        TextField(
          controller: _nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'e.g. Three Fingers, Peace, Fist',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.secondaryBackground,
            prefixIcon: const Icon(Icons.label_rounded, color: AppColors.accentCyan),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Preview Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.accentCyan, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Gesture Validated',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accentCyan),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Assigned Action', _selectedAction.displayName),
              _buildDetailRow('Sampled Frames', '25 stable landmarks'),
              _buildDetailRow('Conflict Check', 'Passed (No overlaps with default or custom gestures)'),
              _buildDetailRow('Status', 'Enabled on save'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _capturedTemplateJson = null;
                    _currentStep = 1;
                  });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Re-capture', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _saveGesture,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Gesture', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Step 4: Interactive Live Test ---

  Widget _buildTestStep() {
    final gesture = _savedGesture;
    final isMatching = _testDetectedGesture != null &&
        gesture != null &&
        _testDetectedGesture == gesture.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.accentCyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.accentCyan, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${gesture?.name ?? "Custom gesture"} saved successfully!',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Test Live Feedback Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.secondaryBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isMatching
                  ? AppColors.accentCyan
                  : _testHandPresent
                      ? AppColors.primaryPurple
                      : AppColors.cardBorder,
              width: 2.0,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMatching
                      ? AppColors.accentCyan.withValues(alpha: 0.2)
                      : AppColors.cardSurface,
                ),
                child: Icon(
                  isMatching ? Icons.thumb_up_alt_rounded : Icons.pan_tool_rounded,
                  size: 36,
                  color: isMatching ? AppColors.accentCyan : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isMatching
                    ? 'Gesture Matched!'
                    : _testHandPresent
                        ? 'Pose: ${_testDetectedGesture ?? "Evaluating..."}'
                        : 'Show your registered pose to the camera',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isMatching ? AppColors.accentCyan : Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isMatching
                    ? 'Matches "${gesture.name}" with ${(_testSimilarity * 100).toInt()}% confidence!'
                    : 'Perform your static pose now to verify detection before using in Instagram.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              if (_testHandPresent) ...[
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Confidence: ${(_testSimilarity * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isMatching ? AppColors.accentCyan : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Action: ${_testDetectedAction ?? gesture?.action.displayName ?? ""}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
              if (_isTesting) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accentCyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Live Camera Active',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              _stopTesting();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Done & Return to Gestures', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(ReelAction action) {
    switch (action) {
      case ReelAction.nextReel:
        return Icons.arrow_downward_rounded;
      case ReelAction.previousReel:
        return Icons.arrow_upward_rounded;
      case ReelAction.likeReel:
        return Icons.favorite_rounded;
      case ReelAction.pausePlay:
        return Icons.play_circle_fill_rounded;
      case ReelAction.replayReel:
        return Icons.replay_rounded;
    }
  }
}
