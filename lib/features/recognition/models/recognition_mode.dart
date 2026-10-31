import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum RecognitionMode {
  offline,
  online;

  String get key => name;

  static RecognitionMode? fromKey(String? key) {
    if (key == null) return null;
    for (final mode in RecognitionMode.values) {
      if (mode.key == key) return mode;
    }
    return null;
  }

  String get displayName {
    switch (this) {
      case RecognitionMode.offline:
        return 'Offline Recognition';
      case RecognitionMode.online:
        return 'Online Recognition';
    }
  }

  String get badgeLabel {
    switch (this) {
      case RecognitionMode.offline:
        return 'ON-DEVICE';
      case RecognitionMode.online:
        return 'CLOUD-ASSISTED';
    }
  }

  String get description {
    switch (this) {
      case RecognitionMode.offline:
        return 'Private on-device processing. No network latency, works without internet connection.';
      case RecognitionMode.online:
        return 'Cloud-assisted recognition. High accuracy for complex accents and background noise.';
    }
  }

  String get privacyNote {
    switch (this) {
      case RecognitionMode.offline:
        return 'Audio never leaves your phone. Zero bytes transmitted to any server.';
      case RecognitionMode.online:
        return 'Speech is processed through your device\'s speech recognition provider.';
    }
  }

  IconData get icon {
    switch (this) {
      case RecognitionMode.offline:
        return Icons.offline_bolt_rounded;
      case RecognitionMode.online:
        return Icons.cloud_done_rounded;
    }
  }

  Color get accentColor {
    switch (this) {
      case RecognitionMode.offline:
        return AppColors.accentCyan;
      case RecognitionMode.online:
        return AppColors.primaryPurple;
    }
  }
}
