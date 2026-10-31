import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/reel_action.dart';
import '../models/voice_command.dart';
import '../services/voice_command_service.dart';
import '../widgets/action_filter_bar.dart';
import '../widgets/add_edit_command_sheet.dart';
import '../widgets/command_card.dart';
import '../../recognition/screens/voice_settings_screen.dart';

class VoiceCommandsScreen extends StatefulWidget {
  final VoiceCommandService? service;

  const VoiceCommandsScreen({super.key, this.service});

  @override
  State<VoiceCommandsScreen> createState() => _VoiceCommandsScreenState();
}

class _VoiceCommandsScreenState extends State<VoiceCommandsScreen> {
  late final VoiceCommandService _service;
  final TextEditingController _searchController = TextEditingController();

  List<VoiceCommand> _commands = [];
  ReelAction? _selectedActionFilter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? VoiceCommandService();
    _loadCommands();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommands() async {
    try {
      final list = await _service.searchAndFilterCommands(
        query: _searchController.text,
        actionFilter: _selectedActionFilter,
      );
      if (mounted) {
        setState(() {
          _commands = list;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading voice commands: $e\n$stack');
      if (mounted) {
        setState(() {
          _commands = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleCommand(VoiceCommand command, bool isEnabled) async {
    try {
      await _service.toggleCommand(command.id, isEnabled);
      await _loadCommands();
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondaryBackground,
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            content: Text(
              isEnabled
                  ? 'Enabled "${command.phrase}".'
                  : 'Disabled "${command.phrase}".',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD32F2F),
            content: Text(
              e.toString().replaceFirst('Exception: ', '').replaceFirst('ArgumentError: ', ''),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAddEditSheet({VoiceCommand? command, ReelAction? initialAction}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditCommandSheet(
        existingCommand: command,
        initialAction: initialAction,
        service: _service,
        onSave: (phrase, action, isEnabled) async {
          if (command == null) {
            await _service.addCommand(
              phrase: phrase,
              action: action,
              isEnabled: isEnabled,
            );
          } else {
            await _service.updateCommand(
              id: command.id,
              phrase: phrase,
              action: action,
              isEnabled: isEnabled,
            );
          }
          await _loadCommands();
        },
      ),
    );
  }

  Future<void> _confirmDelete(VoiceCommand command) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete Voice Command?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${command.phrase}" for ${command.action.displayName}?',
          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deleteCommand(command.id);
      await _loadCommands();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.secondaryBackground,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Deleted "${command.phrase}".',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmResetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Reset to Defaults?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: const Text(
          'This will restore the standard Hindi, Hinglish, and English voice commands and remove custom modifications.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.resetToDefaults();
      await _loadCommands();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.secondaryBackground,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Voice commands restored to defaults.',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group commands by action
    final Map<ReelAction, List<VoiceCommand>> grouped = {};
    for (final cmd in _commands) {
      grouped.putIfAbsent(cmd.action, () => []).add(cmd);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Voice Commands Manager',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            color: AppColors.secondaryBackground,
            onSelected: (value) {
              if (value == 'reset') {
                _confirmResetDefaults();
              } else if (value == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VoiceSettingsScreen()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18, color: AppColors.accentCyan),
                    SizedBox(width: 8),
                    Text(
                      'Voice Recognition Settings',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, size: 18, color: AppColors.accentCyan),
                    SizedBox(width: 8),
                    Text(
                      'Reset to Defaults',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(initialAction: _selectedActionFilter),
        backgroundColor: AppColors.primaryPurple,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Command',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search commands by phrase or action...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _loadCommands();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.cardSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
                  ),
                ),
                onChanged: (_) => _loadCommands(),
              ),
            ),

            const SizedBox(height: 6),

            // Action Filter Bar
            ActionFilterBar(
              selectedAction: _selectedActionFilter,
              onSelectAction: (action) {
                setState(() {
                  _selectedActionFilter = action;
                });
                _loadCommands();
              },
            ),

            const SizedBox(height: 14),

            // Command list view
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryPurple,
                      ),
                    )
                  : _commands.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            left: 20.0,
                            right: 20.0,
                            bottom: 84.0,
                          ),
                          itemCount: grouped.keys.length,
                          itemBuilder: (context, index) {
                            final action = grouped.keys.elementAt(index);
                            final actionCommands = grouped[action]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Action Group Header
                                Padding(
                                  padding: const EdgeInsets.only(top: 14.0, bottom: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            action.icon,
                                            size: 16,
                                            color: action.accentColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            action.displayName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardSurface,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.cardBorder),
                                        ),
                                        child: Text(
                                          '${actionCommands.length} phrases',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Command Cards
                                ...actionCommands.map((command) {
                                  return CommandCard(
                                    command: command,
                                    onToggle: (enabled) => _toggleCommand(command, enabled),
                                    onEdit: () => _showAddEditSheet(command: command),
                                    onDelete: () => _confirmDelete(command),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryPurple.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.mic_off_rounded,
                color: AppColors.textSecondary,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Voice Commands Found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No phrases match your current search or action filter. Add a custom phrase or restore defaults.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _confirmResetDefaults,
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Reset Defaults'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditSheet(initialAction: _selectedActionFilter),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Phrase'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
