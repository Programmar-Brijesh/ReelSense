enum RecognitionState {
  idle,
  checking,
  ready,
  listening,
  unavailable,
  error;

  String get displayName {
    switch (this) {
      case RecognitionState.idle:
        return 'Idle';
      case RecognitionState.checking:
        return 'Verifying Availability...';
      case RecognitionState.ready:
        return 'Ready';
      case RecognitionState.listening:
        return 'Listening...';
      case RecognitionState.unavailable:
        return 'Service Unavailable';
      case RecognitionState.error:
        return 'Recognition Error';
    }
  }

  bool get isProcessing => this == RecognitionState.checking || this == RecognitionState.listening;
}
