import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/custom_gesture.dart';
import '../services/gesture_platform_service.dart';

class GestureTestSheet extends StatefulWidget {
  final CustomGesture? targetGesture;
  final GesturePlatformService? platformService;

  const GestureTestSheet({
    super.key,
    this.targetGesture,
    this.platformService,
  });

  static Future<void> show(
    BuildContext context, {
    CustomGesture? targetGesture,
    GesturePlatformService? platformService,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureTestSheet(
        targetGesture: targetGesture,
        platformService: platformService,
      ),
    );
  }

  @override
  State<GestureTestSheet> createState() => _GestureTestSheetState();
}

class _GestureTestSheetState extends State<GestureTestSheet> {
  late final GesturePlatformService _platformService;
  StreamSubscription? _testSub;

  bool _isHandPresent = false;
  String? _detectedGestureName;
  double _similarity = 0.0;
  String? _detectedAction;

  @override
  void initState() {
    super.initState();
    _platformService = widget.platformService ?? GesturePlatformService();
    _startTesting();
  }

  @override
  void dispose() {
    _testSub?.cancel();
    _platformService.stopGestureTest();
    super.dispose();
  }

  Future<void> _startTesting() async {
    _testSub = _platformService.testEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        _isHandPresent = event['isHandPresent'] as bool? ?? false;
        _detectedGestureName = event['gestureName'] as String?;
        _similarity = (event['similarity'] as num?)?.toDouble() ?? 0.0;
        _detectedAction = event['action'] as String?;
      });
    });

    await _platformService.startGestureTest();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.targetGesture;
    final isTargetMatch = target != null &&
        _detectedGestureName != null &&
        _detectedGestureName == target.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.videocam_rounded, color: AppColors.accentCyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target != null ? 'Testing "${target.name}"' : 'Live Gesture Test',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'No Instagram actions are executed in test mode',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Live Feedback Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isTargetMatch
                    ? AppColors.accentCyan
                    : _isHandPresent
                        ? AppColors.primaryPurple
                        : AppColors.cardBorder,
                width: 2.0,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isTargetMatch
                      ? Icons.check_circle_rounded
                      : _isHandPresent
                          ? Icons.pan_tool_rounded
                          : Icons.front_hand_outlined,
                  size: 42,
                  color: isTargetMatch
                      ? AppColors.accentCyan
                      : _isHandPresent
                          ? AppColors.primaryPurple
                          : AppColors.textSecondary,
                ),
                const SizedBox(height: 14),
                Text(
                  _isHandPresent
                      ? (_detectedGestureName ?? 'Evaluating pose...')
                      : 'Position your hand in camera view',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isTargetMatch ? AppColors.accentCyan : Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isHandPresent
                      ? 'Confidence: ${(_similarity * 100).toInt()}% • Action: ${_detectedAction ?? "None"}'
                      : 'Front camera active. Show hand clearly to test detection.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Close Test', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
