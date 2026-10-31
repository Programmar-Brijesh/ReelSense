import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../commands/models/reel_action.dart';
import '../models/custom_gesture.dart';

class GestureEditDialog extends StatefulWidget {
  final CustomGesture gesture;
  final Future<void> Function(String newName, ReelAction newAction) onSave;

  const GestureEditDialog({
    super.key,
    required this.gesture,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required CustomGesture gesture,
    required Future<void> Function(String newName, ReelAction newAction) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => GestureEditDialog(
        gesture: gesture,
        onSave: onSave,
      ),
    );
  }

  @override
  State<GestureEditDialog> createState() => _GestureEditDialogState();
}

class _GestureEditDialogState extends State<GestureEditDialog> {
  late final TextEditingController _nameController;
  late ReelAction _selectedAction;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.gesture.name);
    _selectedAction = widget.gesture.action;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gesture name cannot be empty.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(name, _selectedAction);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Edit Custom Gesture',
        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gesture Name',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.secondaryBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accentCyan),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Assigned Action',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ReelAction>(
                  value: _selectedAction,
                  isExpanded: true,
                  dropdownColor: AppColors.secondaryBackground,
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.accentCyan),
                  items: ReelAction.values.map((action) {
                    return DropdownMenuItem(
                      value: action,
                      child: Text(
                        action.displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedAction = val);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}
