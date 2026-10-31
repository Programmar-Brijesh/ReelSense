import 'dart:async';
import 'package:flutter/services.dart';

class GesturePlatformService {
  static const MethodChannel _methodChannel =
      MethodChannel('in.developerbrijesh.reelsense/gestures');
  static const EventChannel _eventChannel =
      EventChannel('in.developerbrijesh.reelsense/gesture_events');

  final MethodChannel? _overrideChannel;
  final EventChannel? _overrideEventChannel;

  GesturePlatformService({MethodChannel? channel, EventChannel? eventChannel})
      : _overrideChannel = channel,
        _overrideEventChannel = eventChannel;

  MethodChannel get _channel => _overrideChannel ?? _methodChannel;
  EventChannel get _events => _overrideEventChannel ?? _eventChannel;

  Future<bool> hasCameraPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasCameraPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestCameraPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestCameraPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isFrontCameraAvailable() async {
    try {
      final res = await _channel.invokeMethod<bool>('isFrontCameraAvailable');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<List<Map<String, dynamic>>> getGestureMappings() async {
    try {
      final res = await _channel.invokeListMethod<Map>('getGestureMappings');
      if (res == null) return [];
      return res.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<Map<String, dynamic>>? _cachedBroadcastStream;

  Stream<Map<String, dynamic>> get gestureEvents {
    return _cachedBroadcastStream ??= _events
        .receiveBroadcastStream()
        .map((event) {
          if (event is Map) {
            return Map<String, dynamic>.from(event);
          }
          return <String, dynamic>{};
        })
        .asBroadcastStream();
  }
}
