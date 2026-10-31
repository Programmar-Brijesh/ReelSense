import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/reel_action.dart';

class ActionFilterBar extends StatelessWidget {
  final ReelAction? selectedAction;
  final ValueChanged<ReelAction?> onSelectAction;

  const ActionFilterBar({
    super.key,
    required this.selectedAction,
    required this.onSelectAction,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          // "All" filter chip
          _buildChip(
            label: 'All Actions',
            icon: Icons.apps_rounded,
            isSelected: selectedAction == null,
            accentColor: AppColors.primaryPurple,
            onTap: () => onSelectAction(null),
          ),
          const SizedBox(width: 8),

          // Each ReelAction chip
          ...ReelAction.values.map((action) {
            final isSelected = selectedAction == action;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildChip(
                label: action.displayName,
                icon: action.icon,
                isSelected: isSelected,
                accentColor: action.accentColor,
                onTap: () => onSelectAction(isSelected ? null : action),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.18)
              : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? accentColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
