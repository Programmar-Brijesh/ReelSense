import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum ReelAction {
  nextReel('NEXT_REEL'),
  previousReel('PREVIOUS_REEL'),
  likeReel('LIKE_REEL'),
  pausePlay('PAUSE_PLAY'),
  replayReel('REPLAY_REEL');

  final String dbValue;
  const ReelAction(this.dbValue);

  static ReelAction fromDbValue(String value) {
    return ReelAction.values.firstWhere(
      (a) => a.dbValue == value || a.name == value,
      orElse: () => ReelAction.nextReel,
    );
  }

  String get displayName {
    switch (this) {
      case ReelAction.nextReel:
        return 'Next Reel';
      case ReelAction.previousReel:
        return 'Previous Reel';
      case ReelAction.likeReel:
        return 'Like Reel';
      case ReelAction.pausePlay:
        return 'Pause / Play';
      case ReelAction.replayReel:
        return 'Replay Reel';
    }
  }

  String get description {
    switch (this) {
      case ReelAction.nextReel:
        return 'Scroll down to the next short video';
      case ReelAction.previousReel:
        return 'Scroll up to the previous short video';
      case ReelAction.likeReel:
        return 'Double-tap heart to like current video';
      case ReelAction.pausePlay:
        return 'Toggle playback pause and resume';
      case ReelAction.replayReel:
        return 'Restart current video from beginning';
    }
  }

  IconData get icon {
    switch (this) {
      case ReelAction.nextReel:
        return Icons.keyboard_double_arrow_down_rounded;
      case ReelAction.previousReel:
        return Icons.keyboard_double_arrow_up_rounded;
      case ReelAction.likeReel:
        return Icons.favorite_rounded;
      case ReelAction.pausePlay:
        return Icons.pause_circle_filled_rounded;
      case ReelAction.replayReel:
        return Icons.replay_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case ReelAction.nextReel:
        return AppColors.accentCyan;
      case ReelAction.previousReel:
        return AppColors.primaryPurple;
      case ReelAction.likeReel:
        return const Color(0xFFFF3366);
      case ReelAction.pausePlay:
        return const Color(0xFFFFB74D);
      case ReelAction.replayReel:
        return const Color(0xFF00E5FF);
    }
  }
}
