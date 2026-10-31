import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ControlModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;
  final Color accentColor;

  const ControlModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isEnabled,
    required this.onChanged,
    this.accentColor = AppColors.primaryPurple,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEnabled
              ? accentColor.withValues(alpha: 0.45)
              : AppColors.cardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isEnabled
                ? accentColor.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEnabled
                        ? accentColor.withValues(alpha: 0.5)
                        : AppColors.cardBorder,
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? accentColor : AppColors.textSecondary,
                  size: 20,
                ),
              ),

              // Switch toggle
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: isEnabled,
                  onChanged: onChanged,
                  activeThumbColor: accentColor,
                  activeTrackColor: accentColor.withValues(alpha: 0.35),
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.secondaryBackground,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Title & Status Badge
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? accentColor.withValues(alpha: 0.15)
                      : AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isEnabled
                        ? accentColor.withValues(alpha: 0.4)
                        : AppColors.cardBorder,
                  ),
                ),
                child: Text(
                  isEnabled ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isEnabled ? accentColor : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
