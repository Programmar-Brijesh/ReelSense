import '../data/voice_command_repository.dart';
import '../models/reel_action.dart';
import '../models/voice_command.dart';

class CommandValidationResult {
  final bool isValid;
  final String? errorMessage;
  final VoiceCommand? conflictingCommand;

  const CommandValidationResult({
    required this.isValid,
    this.errorMessage,
    this.conflictingCommand,
  });

  factory CommandValidationResult.valid() =>
      const CommandValidationResult(isValid: true);

  factory CommandValidationResult.error(String message,
          [VoiceCommand? conflict]) =>
      CommandValidationResult(
        isValid: false,
        errorMessage: message,
        conflictingCommand: conflict,
      );
}

class VoiceCommandService {
  final VoiceCommandRepository _repository;

  VoiceCommandService({VoiceCommandRepository? repository})
      : _repository = repository ?? SqliteVoiceCommandRepository();

  /// Validates phrase input based on trimming, empty rejection, duplicate checking,
  /// and conflicting action detection.
  Future<CommandValidationResult> validatePhrase({
    required String phrase,
    required ReelAction action,
    String? excludeId,
    bool isEnabled = true,
  }) async {
    final normalized = VoiceCommand.normalize(phrase);

    if (normalized.isEmpty) {
      return CommandValidationResult.error(
        'Voice command phrase cannot be empty.',
      );
    }

    final existing = await _repository.getCommandByNormalizedPhrase(normalized);

    if (existing != null && existing.id != excludeId) {
      // If it exists and maps to the exact same action:
      if (existing.action == action) {
        return CommandValidationResult.error(
          'Phrase "$phrase" is already registered for ${action.displayName}.',
          existing,
        );
      }

      // If it maps to a different action, check for conflict:
      if (isEnabled && existing.isEnabled) {
        return CommandValidationResult.error(
          'Phrase "$phrase" conflicts with active action "${existing.action.displayName}".',
          existing,
        );
      }
    }

    return CommandValidationResult.valid();
  }

  Future<List<VoiceCommand>> getAllCommands() async {
    return await _repository.getAllCommands();
  }

  /// Searches and filters commands by text query and optional action filter.
  Future<List<VoiceCommand>> searchAndFilterCommands({
    String query = '',
    ReelAction? actionFilter,
  }) async {
    final all = await _repository.getAllCommands();
    final normalizedQuery = VoiceCommand.normalize(query);

    return all.where((cmd) {
      final matchesQuery = normalizedQuery.isEmpty ||
          cmd.normalizedPhrase.contains(normalizedQuery) ||
          cmd.phrase.toLowerCase().contains(normalizedQuery);

      final matchesAction = actionFilter == null || cmd.action == actionFilter;

      return matchesQuery && matchesAction;
    }).toList();
  }

  /// Adds a new command with validation.
  Future<VoiceCommand> addCommand({
    required String phrase,
    required ReelAction action,
    bool isEnabled = true,
  }) async {
    final validation = await validatePhrase(
      phrase: phrase,
      action: action,
      isEnabled: isEnabled,
    );

    if (!validation.isValid) {
      throw ArgumentError(validation.errorMessage);
    }

    final now = DateTime.now();
    final newCommand = VoiceCommand(
      id: 'cmd_${now.millisecondsSinceEpoch}_${phrase.hashCode.abs()}',
      phrase: phrase.trim(),
      action: action,
      isEnabled: isEnabled,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.insertCommand(newCommand);
    return newCommand;
  }

  /// Updates an existing command with validation.
  Future<VoiceCommand> updateCommand({
    required String id,
    required String phrase,
    required ReelAction action,
    required bool isEnabled,
  }) async {
    final validation = await validatePhrase(
      phrase: phrase,
      action: action,
      excludeId: id,
      isEnabled: isEnabled,
    );

    if (!validation.isValid) {
      throw ArgumentError(validation.errorMessage);
    }

    final existing = await _repository.getCommandById(id);
    if (existing == null) {
      throw StateError('Voice command with ID $id not found.');
    }

    final updated = existing.copyWith(
      phrase: phrase.trim(),
      action: action,
      isEnabled: isEnabled,
      updatedAt: DateTime.now(),
    );

    await _repository.updateCommand(updated);
    return updated;
  }

  /// Toggles enabled state of a command.
  Future<void> toggleCommand(String id, bool isEnabled) async {
    final existing = await _repository.getCommandById(id);
    if (existing == null) return;

    if (isEnabled) {
      // Validate that enabling does not conflict with another enabled command
      final validation = await validatePhrase(
        phrase: existing.phrase,
        action: existing.action,
        excludeId: existing.id,
        isEnabled: true,
      );
      if (!validation.isValid) {
        throw ArgumentError(validation.errorMessage);
      }
    }

    final updated = existing.copyWith(isEnabled: isEnabled);
    await _repository.updateCommand(updated);
  }

  /// Deletes a command by ID.
  Future<void> deleteCommand(String id) async {
    await _repository.deleteCommand(id);
  }

  /// Resets all commands to initial default set.
  Future<void> resetToDefaults() async {
    await _repository.resetToDefaults();
  }
}
