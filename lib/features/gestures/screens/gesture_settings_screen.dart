import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/gesture_mapping.dart';
import '../services/gesture_platform_service.dart';

class GestureSettingsScreen extends StatefulWidget {
  final GesturePlatformService? platformService;

  const GestureSettingsScreen({
    super.key,
    this.platformService,
  });

  @override
  State<GestureSettingsScreen> createState() => _GestureSettingsScreenState();
}

class _GestureSettingsScreenState extends State<GestureSettingsScreen> {
  late final GesturePlatformService _gestureService;

  bool _hasCameraPermission = false;
  bool _isFrontCameraAvailable = true;
  bool _isLoading = true;

  StreamSubscription<Map<String, dynamic>>? _gestureSub;
  String? _lastDetectedGesture;
  String? _lastExecutedAction;

  @override
  void initState() {
    super.initState();
    _gestureService = widget.platformService ?? GesturePlatformService();
    _checkPermissions();
    _listenToGestureEvents();
  }

  @override
  void dispose() {
    _gestureSub?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final hasCam = await _gestureService.hasCameraPermission();
    final hasFrontCam = await _gestureService.isFrontCameraAvailable();

    if (mounted) {
      setState(() {
        _hasCameraPermission = hasCam;
        _isFrontCameraAvailable = hasFrontCam;
        _isLoading = false;
      });
    }
  }

  void _listenToGestureEvents() {
    _gestureSub = _gestureService.gestureEvents.listen((event) {
      if (mounted) {
        setState(() {
          _lastDetectedGesture = event['displayName'] as String?;
          _lastExecutedAction = event['actionExecuted'] as String?;
        });
      }
    });
  }

  Future<void> _requestCameraPermission() async {
    final granted = await _gestureService.requestCameraPermission();
    if (mounted) {
      setState(() => _hasCameraPermission = granted);
      if (granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.secondaryBackground,
            content: Text(
              'Camera permission granted for hand tracking.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Hand Gesture Control',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                children: [
                  // Camera Status Card
                  _buildCameraStatusCard(),
                  const SizedBox(height: 20),

                  // Section Title: Default Gestures
                  const Text(
                    'Configured Gestures',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Show your hand clearly to the front camera while watching Reels.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4 Defined Gestures
                  ...ReelGesture.values.map((gesture) => _buildGestureCard(gesture)),

                  const SizedBox(height: 24),

                  // Safety and Cooldown Notice Card
                  _buildSafetyCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCameraStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasCameraPermission
              ? AppColors.accentCyan.withValues(alpha: 0.35)
              : const Color(0xFFFF5252).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hasCameraPermission
                      ? AppColors.accentCyan.withValues(alpha: 0.15)
                      : const Color(0xFFFF5252).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _hasCameraPermission ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                  color: _hasCameraPermission ? AppColors.accentCyan : const Color(0xFFFF5252),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasCameraPermission
                          ? (_isFrontCameraAvailable ? 'Front Camera Tracking Ready' : 'Front Camera Unavailable')
                          : 'Camera Permission Required',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _hasCameraPermission
                          ? 'MediaPipe on-device hand landmarker active in memory only.'
                          : 'Camera access is required for real-time hand gesture recognition.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_hasCameraPermission) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _requestCameraPermission,
                icon: const Icon(Icons.security_rounded, size: 18),
                label: const Text('Grant Camera Permission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          if (_lastDetectedGesture != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded, color: AppColors.accentCyan, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Live: $_lastDetectedGesture',
                    style: const TextStyle(fontSize: 12, color: AppColors.accentCyan, fontWeight: FontWeight.w600),
                  ),
                  if (_lastExecutedAction != null) ...[
                    const Spacer(),
                    Text(
                      'Action: $_lastExecutedAction ✓',
                      style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGestureCard(ReelGesture gesture) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryPurple.withValues(alpha: 0.3)),
            ),
            child: Icon(
              gesture.icon,
              color: AppColors.primaryPurple,
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
                      gesture.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        gesture.action,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  gesture.actionLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  gesture.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard() {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.accentCyan, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Camera frames are processed in-memory only on your device using MediaPipe and immediately discarded. Frames are never saved or sent to any server.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
