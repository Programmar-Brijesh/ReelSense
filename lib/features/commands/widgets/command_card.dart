import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/voice_command.dart';

class CommandCard extends StatelessWidget {
  final VoiceCommand command;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CommandCard({
    super.key,
    required this.command,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final action = command.action;
    final isEnabled = command.isEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? action.accentColor.withValues(alpha: 0.35)
              : AppColors.cardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Action Icon Badge
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: action.accentColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  action.icon,
                  size: 18,
                  color: isEnabled ? action.accentColor : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),

              // Phrase Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${command.phrase}"',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isEnabled ? Colors.white : AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isEnabled
                            ? action.accentColor
                            : AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Enable/Disable Switch
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: isEnabled,
                  onChanged: onToggle,
                  activeThumbColor: action.accentColor,
                  activeTrackColor: action.accentColor.withValues(alpha: 0.35),
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.secondaryBackground,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 4),

          // Bottom Action Buttons (Edit / Delete)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Edit command',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFFF5252),
                ),
                tooltip: 'Delete command',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
