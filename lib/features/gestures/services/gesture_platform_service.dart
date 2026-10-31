import 'dart:async';
import 'package:flutter/services.dart';
import '../models/custom_gesture.dart';

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

  Future<bool> syncCustomGestures(List<CustomGesture> gestures) async {
    try {
      final payload = gestures
          .map((g) => {
                'id': g.id,
                'name': g.name,
                'action': g.action.dbValue,
                'templateJson': g.landmarkTemplateJson,
                'confidenceThreshold': g.confidenceThreshold,
                'isEnabled': g.isEnabled,
              })
          .toList();

      final res = await _channel.invokeMethod<bool>('syncCustomGestures', {
        'gestures': payload,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startGestureRegistration() async {
    try {
      final res = await _channel.invokeMethod<bool>('startGestureRegistration');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopGestureRegistration() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopGestureRegistration');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startGestureTest() async {
    try {
      final res = await _channel.invokeMethod<bool>('startGestureTest');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopGestureTest() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopGestureTest');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> validateGestureConflict(
    String templateJson, {
    String? excludeGestureId,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'validateGestureConflict',
        {
          'templateJson': templateJson,
          'excludeGestureId': ?excludeGestureId,
        },
      );
      return res ?? {'hasConflict': false};
    } catch (e) {
      return {
        'hasConflict': true,
        'reason': 'Validation error: $e',
      };
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

  Stream<Map<String, dynamic>> get registrationProgressEvents {
    return gestureEvents.where((e) => e['type'] == 'registration_progress');
  }

  Stream<Map<String, dynamic>> get testEvents {
    return gestureEvents.where((e) => e['type'] == 'test_event');
  }
}
