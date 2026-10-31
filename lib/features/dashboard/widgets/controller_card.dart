import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ControllerCard extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onToggle;

  const ControllerCard({
    super.key,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEnabled
              ? [const Color(0xFF1B1838), const Color(0xFF101124)]
              : [const Color(0xFF141525), const Color(0xFF0D0E18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isEnabled
              ? AppColors.primaryPurple.withValues(alpha: 0.75)
              : AppColors.cardBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isEnabled
                ? AppColors.primaryPurple.withValues(alpha: 0.30)
                : Colors.black.withValues(alpha: 0.20),
            blurRadius: isEnabled ? 22 : 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? AppColors.primaryPurple.withValues(alpha: 0.2)
                      : AppColors.cardBorder.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isEnabled
                        ? AppColors.primaryPurple
                        : AppColors.textSecondary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEnabled
                            ? AppColors.accentCyan
                            : AppColors.textSecondary,
                        boxShadow: isEnabled
                            ? [
                                const BoxShadow(
                                  color: AppColors.accentCyan,
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEnabled ? 'CONTROLLER RUNNING' : 'CONTROLLER OFF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: isEnabled
                            ? AppColors.accentCyan
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                isEnabled
                    ? Icons.power_settings_new_rounded
                    : Icons.power_off_rounded,
                color: isEnabled
                    ? AppColors.primaryPurple
                    : AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Title & Description
          const Text(
            'Master Controller',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isEnabled
                ? 'Master engine active. Hand gestures and voice triggers are primed for Reel sessions.'
                : 'Master controller is stopped. Enable the controller to start controlling reels and trigger sessions.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 20),

          // Toggle Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onToggle,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnabled
                    ? const Color(0xFF261D3B)
                    : AppColors.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: isEnabled
                      ? BorderSide(
                          color: AppColors.primaryPurple.withValues(alpha: 0.6),
                        )
                      : BorderSide.none,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEnabled
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEnabled ? 'Stop Controller' : 'Start Controller',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
