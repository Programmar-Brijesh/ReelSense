import '../models/reel_action.dart';
import '../models/voice_command.dart';

class DefaultCommands {
  DefaultCommands._();

  static List<VoiceCommand> getDefaultCommands() {
    final now = DateTime.now();

    final defaults = <(String, ReelAction)>[
      // Next Reel
      ('next', ReelAction.nextReel),
      ('scroll down', ReelAction.nextReel),
      ('aage badho', ReelAction.nextReel),
      ('अगला रील', ReelAction.nextReel),

      // Previous Reel
      ('previous', ReelAction.previousReel),
      ('scroll up', ReelAction.previousReel),
      ('peeche karo', ReelAction.previousReel),
      ('पिछला रील', ReelAction.previousReel),

      // Like Reel
      ('like', ReelAction.likeReel),
      ('heart', ReelAction.likeReel),
      ('pasand', ReelAction.likeReel),
      ('पसंद है', ReelAction.likeReel),

      // Pause / Play
      ('pause', ReelAction.pausePlay),
      ('play', ReelAction.pausePlay),
      ('ruk jao', ReelAction.pausePlay),
      ('रुको', ReelAction.pausePlay),

      // Replay Reel
      ('replay', ReelAction.replayReel),
      ('dobara chalao', ReelAction.replayReel),
      ('फिर से चलाओ', ReelAction.replayReel),
    ];

    return defaults.asMap().entries.map((entry) {
      final index = entry.key;
      final pair = entry.value;
      return VoiceCommand(
        id: 'default_${index + 1}',
        phrase: pair.$1,
        action: pair.$2,
        isEnabled: true,
        createdAt: now.add(Duration(seconds: index)),
        updatedAt: now.add(Duration(seconds: index)),
      );
    }).toList();
  }
}
