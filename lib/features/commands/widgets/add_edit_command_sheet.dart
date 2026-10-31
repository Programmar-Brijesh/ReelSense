import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/reel_action.dart';
import '../models/voice_command.dart';
import '../services/voice_command_service.dart';

class AddEditCommandSheet extends StatefulWidget {
  final VoiceCommand? existingCommand;
  final ReelAction? initialAction;
  final VoiceCommandService service;
  final Future<void> Function(String phrase, ReelAction action, bool isEnabled) onSave;

  const AddEditCommandSheet({
    super.key,
    this.existingCommand,
    this.initialAction,
    required this.service,
    required this.onSave,
  });

  @override
  State<AddEditCommandSheet> createState() => _AddEditCommandSheetState();
}

class _AddEditCommandSheetState extends State<AddEditCommandSheet> {
  late final TextEditingController _phraseController;
  late ReelAction _selectedAction;
  late bool _isEnabled;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phraseController = TextEditingController(
      text: widget.existingCommand?.phrase ?? '',
    );
    _selectedAction = widget.existingCommand?.action ??
        widget.initialAction ??
        ReelAction.nextReel;
    _isEnabled = widget.existingCommand?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final phrase = _phraseController.text;

    setState(() {
      _errorMessage = null;
    });

    final validation = await widget.service.validatePhrase(
      phrase: phrase,
      action: _selectedAction,
      excludeId: widget.existingCommand?.id,
      isEnabled: _isEnabled,
    );

    if (!validation.isValid) {
      setState(() {
        _errorMessage = validation.errorMessage;
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(phrase.trim(), _selectedAction, _isEnabled);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '').replaceFirst('ArgumentError: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCommand != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 12.0,
        bottom: bottomInset + 20.0,
      ),
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Voice Command' : 'New Voice Command',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Spoken Phrase TextField
            const Text(
              'Voice Phrase',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _phraseController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. "next", "aage badho", "अगला"',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.cardSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.accentCyan,
                    width: 1.5,
                  ),
                ),
                suffixIcon: _phraseController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _phraseController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFF5252),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF5252),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Action Selector
            const Text(
              'Assigned Action',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: ReelAction.values.map((action) {
                final isSelected = _selectedAction == action;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAction = action;
                      _errorMessage = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? action.accentColor.withValues(alpha: 0.20)
                          : AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? action.accentColor
                            : AppColors.cardBorder,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          action.icon,
                          size: 16,
                          color: isSelected
                              ? action.accentColor
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          action.displayName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Enabled Switch Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Enable Command Immediately',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: _isEnabled,
                      onChanged: (val) {
                        setState(() {
                          _isEnabled = val;
                        });
                      },
                      activeThumbColor: _selectedAction.accentColor,
                      activeTrackColor:
                          _selectedAction.accentColor.withValues(alpha: 0.35),
                      inactiveThumbColor: AppColors.textSecondary,
                      inactiveTrackColor: AppColors.secondaryBackground,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _isSaving
                    ? const Text(
                        'Saving...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Text(
                        isEditing ? 'Update Command' : 'Save Command',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
