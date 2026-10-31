import '../../recognition/models/recognition_mode.dart';

enum AutoStartControllerMode {
  voice('voice', 'Voice Control', 'Uses hands-free speech triggers like "next reel", "like", "pause"'),
  gesture('gesture', 'Gesture Control', 'Uses front camera to detect hand gestures like wave up / down');

  final String key;
  final String displayName;
  final String description;

  const AutoStartControllerMode(this.key, this.displayName, this.description);

  static AutoStartControllerMode fromKey(String? key) {
    if (key == 'gesture') return AutoStartControllerMode.gesture;
    return AutoStartControllerMode.voice;
  }
}

class AutoStartConfig {
  final bool isEnabled;
  final AutoStartControllerMode controllerMode;
  final RecognitionMode recognitionMode;
  final String locale;
  final bool hasCompletedSetup;
  final int updatedAt;

  const AutoStartConfig({
    required this.isEnabled,
    required this.controllerMode,
    required this.recognitionMode,
    required this.locale,
    required this.hasCompletedSetup,
    required this.updatedAt,
  });

  factory AutoStartConfig.defaults() {
    return AutoStartConfig(
      isEnabled: false,
      controllerMode: AutoStartControllerMode.voice,
      recognitionMode: RecognitionMode.offline,
      locale: 'en-US',
      hasCompletedSetup: false,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  AutoStartConfig copyWith({
    bool? isEnabled,
    AutoStartControllerMode? controllerMode,
    RecognitionMode? recognitionMode,
    String? locale,
    bool? hasCompletedSetup,
    int? updatedAt,
  }) {
    return AutoStartConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      controllerMode: controllerMode ?? this.controllerMode,
      recognitionMode: recognitionMode ?? this.recognitionMode,
      locale: locale ?? this.locale,
      hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': isEnabled,
      'controllerMode': controllerMode.key,
      'recognitionMode': recognitionMode.key,
      'locale': locale,
      'hasCompletedSetup': hasCompletedSetup,
      'updatedAt': updatedAt,
    };
  }
}
