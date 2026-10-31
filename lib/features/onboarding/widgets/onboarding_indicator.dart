import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class OnboardingIndicator extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final ValueChanged<int>? onIndicatorTap;

  const OnboardingIndicator({
    super.key,
    required this.totalPages,
    required this.currentPage,
    this.onIndicatorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalPages, (index) {
        final isActive = index == currentPage;
        return GestureDetector(
          onTap: onIndicatorTap != null ? () => onIndicatorTap!(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            width: isActive ? 28.0 : 8.0,
            height: 8.0,
            decoration: BoxDecoration(
              gradient: isActive ? AppColors.primaryGradient : null,
              color: isActive ? null : AppColors.inactiveIndicator,
              borderRadius: BorderRadius.circular(4.0),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primaryPurple.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
