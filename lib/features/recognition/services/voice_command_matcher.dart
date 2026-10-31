import 'package:flutter/foundation.dart';
import '../../commands/models/reel_action.dart';
import '../../commands/models/voice_command.dart';
import '../../commands/services/voice_command_service.dart';

class VoiceCommandMatch {
  final VoiceCommand command;
  final ReelAction action;
  final String speechText;
  final double confidence;

  const VoiceCommandMatch({
    required this.command,
    required this.action,
    required this.speechText,
    required this.confidence,
  });
}

abstract class ActionDispatchHandler {
  void dispatchAction(ReelAction action, VoiceCommand command);
}

class LoggingActionDispatchHandler implements ActionDispatchHandler {
  @override
  void dispatchAction(ReelAction action, VoiceCommand command) {
    debugPrint('[ActionDispatchHandler] Dispatched ${action.displayName} for command "${command.phrase}"');
  }
}

class VoiceCommandMatcher {
  final VoiceCommandService _commandService;
  final ActionDispatchHandler _dispatchHandler;

  VoiceCommandMatcher({
    VoiceCommandService? commandService,
    ActionDispatchHandler? dispatchHandler,
  })  : _commandService = commandService ?? VoiceCommandService(),
        _dispatchHandler = dispatchHandler ?? LoggingActionDispatchHandler();

  /// Matches recognized speech text against currently enabled commands from SQLite.
  Future<VoiceCommandMatch?> matchSpeech({
    required String speech,
    double confidence = 1.0,
  }) async {
    final normalized = VoiceCommand.normalize(speech);
    if (normalized.isEmpty) return null;

    final allCommands = await _commandService.getAllCommands();
    final enabledCommands = allCommands.where((c) => c.isEnabled).toList();

    // 1. Exact match on normalized phrase
    for (final cmd in enabledCommands) {
      if (cmd.normalizedPhrase == normalized) {
        return VoiceCommandMatch(
          command: cmd,
          action: cmd.action,
          speechText: speech,
          confidence: confidence,
        );
      }
    }

    // 2. Substring match (e.g. if recognition captures "please next reel" or "next")
    for (final cmd in enabledCommands) {
      if (normalized.contains(cmd.normalizedPhrase) ||
          cmd.normalizedPhrase.contains(normalized)) {
        return VoiceCommandMatch(
          command: cmd,
          action: cmd.action,
          speechText: speech,
          confidence: confidence,
        );
      }
    }

    return null;
  }

  /// Dispatches the matched action.
  void dispatchMatch(VoiceCommandMatch match) {
    _dispatchHandler.dispatchAction(match.action, match.command);
  }
}
