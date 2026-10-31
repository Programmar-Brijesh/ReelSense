import '../models/recognition_availability.dart';
import '../models/recognition_mode.dart';
import 'android_speech_recognition_handler.dart';

class RecognitionAvailabilityService {
  final AndroidSpeechRecognitionHandler _handler;

  RecognitionAvailabilityService({AndroidSpeechRecognitionHandler? handler})
      : _handler = handler ?? MethodChannelSpeechRecognitionHandler();

  /// Queries the Android SpeechRecognizer engine for on-device and online support.
  Future<RecognitionAvailability> checkAvailability(String locale) async {
    final map = await _handler.checkAvailability(locale);
    return RecognitionAvailability.fromMap(map);
  }

  /// Triggers on-device language pack download (API 33+) or falls back to system settings.
  Future<bool> triggerModelDownload(String locale) async {
    return await _handler.triggerModelDownload(locale);
  }

  /// Opens the system speech / voice search settings.
  Future<bool> openVoiceSettings() async {
    return await _handler.openVoiceSettings();
  }

  /// Convenient helper to check if a specific mode is supported.
  Future<bool> isModeAvailable(RecognitionMode mode, String locale) async {
    final availability = await checkAvailability(locale);
    return availability.isModeAvailable(mode);
  }

  /// Checks if microphone permission is granted.
  Future<bool> hasRecordAudioPermission() async {
    return await _handler.hasRecordAudioPermission();
  }

  /// Requests microphone permission.
  Future<bool> requestRecordAudioPermission() async {
    return await _handler.requestRecordAudioPermission();
  }
}
