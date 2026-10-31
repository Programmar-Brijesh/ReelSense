class ControllerState {
  final bool isMasterEnabled;
  final bool isVoiceEnabled;
  final bool isGestureEnabled;
  final bool isSessionActive;

  const ControllerState({
    this.isMasterEnabled = false,
    this.isVoiceEnabled = true,
    this.isGestureEnabled = true,
    this.isSessionActive = false,
  });

  ControllerState copyWith({
    bool? isMasterEnabled,
    bool? isVoiceEnabled,
    bool? isGestureEnabled,
    bool? isSessionActive,
  }) {
    return ControllerState(
      isMasterEnabled: isMasterEnabled ?? this.isMasterEnabled,
      isVoiceEnabled: isVoiceEnabled ?? this.isVoiceEnabled,
      isGestureEnabled: isGestureEnabled ?? this.isGestureEnabled,
      isSessionActive: isSessionActive ?? this.isSessionActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ControllerState &&
          runtimeType == other.runtimeType &&
          isMasterEnabled == other.isMasterEnabled &&
          isVoiceEnabled == other.isVoiceEnabled &&
          isGestureEnabled == other.isGestureEnabled &&
          isSessionActive == other.isSessionActive;

  @override
  int get hashCode =>
      isMasterEnabled.hashCode ^
      isVoiceEnabled.hashCode ^
      isGestureEnabled.hashCode ^
      isSessionActive.hashCode;
}
