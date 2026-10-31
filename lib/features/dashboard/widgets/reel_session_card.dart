import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ReelSessionCard extends StatelessWidget {
  final bool isSessionActive;
  final bool isMasterEnabled;
  final VoidCallback onToggleSession;

  const ReelSessionCard({
    super.key,
    required this.isSessionActive,
    required this.isMasterEnabled,
    required this.onToggleSession,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSessionActive
              ? AppColors.accentCyan.withValues(alpha: 0.7)
              : AppColors.cardBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSessionActive
                ? AppColors.accentCyan.withValues(alpha: 0.20)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: isSessionActive ? 20 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Target App Badge & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Target App Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE1306C).withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.video_collection_rounded,
                      color: Color(0xFFE1306C),
                      size: 15,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Target: Instagram Reels',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Active / Idle status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSessionActive
                      ? AppColors.accentCyan.withValues(alpha: 0.15)
                      : AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSessionActive
                        ? AppColors.accentCyan
                        : AppColors.cardBorder,
                  ),
                ),
                child: Text(
                  isSessionActive ? 'ACTIVE' : 'STANDBY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isSessionActive
                        ? AppColors.accentCyan
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Reel Session Control',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Instagram must be opened and Reels must be selected before starting a session for hands-free scrolling.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),

          if (!isMasterEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF261D15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFFB74D).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFFB74D),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Turn ON Master Controller above to enable Reel Sessions.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFB74D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Start / Stop Session Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onToggleSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSessionActive
                    ? const Color(0xFFD32F2F)
                    : (isMasterEnabled
                        ? AppColors.accentCyan
                        : AppColors.chipBackground),
                foregroundColor: isSessionActive
                    ? Colors.white
                    : (isMasterEnabled
                        ? Colors.black87
                        : AppColors.textSecondary),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSessionActive
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSessionActive
                        ? 'Stop Reel Session'
                        : 'Start Reel Session',
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
