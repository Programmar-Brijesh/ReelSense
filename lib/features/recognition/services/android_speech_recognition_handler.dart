import 'dart:async';
import 'package:flutter/services.dart';

abstract class AndroidSpeechRecognitionHandler {
  Future<bool> hasRecordAudioPermission();
  Future<bool> requestRecordAudioPermission();
  Future<Map<dynamic, dynamic>> checkAvailability(String locale);
  Future<bool> triggerModelDownload(String locale);
  Future<bool> openVoiceSettings();
  Future<bool> startListening({required String mode, required String locale});
  Future<bool> stopListening();
  Future<bool> cancelListening();
  Stream<Map<dynamic, dynamic>> get eventStream;
}

class MethodChannelSpeechRecognitionHandler implements AndroidSpeechRecognitionHandler {
  static const MethodChannel _methodChannel =
      MethodChannel('in.developerbrijesh.reelsense/speech_recognition');
  static const EventChannel _eventChannel =
      EventChannel('in.developerbrijesh.reelsense/speech_events');

  Stream<Map<dynamic, dynamic>>? _events;

  @override
  Future<bool> hasRecordAudioPermission() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('hasRecordAudioPermission');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestRecordAudioPermission() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('requestRecordAudioPermission');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<Map<dynamic, dynamic>> checkAvailability(String locale) async {
    try {
      final res = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'checkAvailability',
        {'locale': locale},
      );
      return res ?? {};
    } on PlatformException catch (_) {
      return {};
    }
  }

  @override
  Future<bool> triggerModelDownload(String locale) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>(
        'triggerModelDownload',
        {'locale': locale},
      );
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openVoiceSettings() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('openVoiceSettings');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> startListening({required String mode, required String locale}) async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('startListening', {
        'mode': mode,
        'locale': locale,
      });
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopListening() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('stopListening');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> cancelListening() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('cancelListening');
      return res ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Stream<Map<dynamic, dynamic>> get eventStream {
    _events ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<dynamic, dynamic>.from(event as Map));
    return _events!;
  }
}
