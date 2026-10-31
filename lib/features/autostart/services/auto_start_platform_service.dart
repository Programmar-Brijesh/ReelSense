import 'package:flutter/services.dart';
import '../models/auto_start_config.dart';

class AutoStartServiceStatus {
  final bool isMonitoringRunning;
  final bool isAccessibilityEnabled;
  final bool isOverlayGranted;
  final bool hasAccessibilityInstance;

  const AutoStartServiceStatus({
    required this.isMonitoringRunning,
    required this.isAccessibilityEnabled,
    required this.isOverlayGranted,
    required this.hasAccessibilityInstance,
  });

  factory AutoStartServiceStatus.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const AutoStartServiceStatus(
        isMonitoringRunning: false,
        isAccessibilityEnabled: false,
        isOverlayGranted: false,
        hasAccessibilityInstance: false,
      );
    }
    return AutoStartServiceStatus(
      isMonitoringRunning: map['isMonitoringRunning'] as bool? ?? false,
      isAccessibilityEnabled: map['isAccessibilityEnabled'] as bool? ?? false,
      isOverlayGranted: map['isOverlayGranted'] as bool? ?? false,
      hasAccessibilityInstance: map['hasAccessibilityInstance'] as bool? ?? false,
    );
  }
}

class AutoStartPlatformService {
  static const MethodChannel _channel =
      MethodChannel('in.developerbrijesh.reelsense/auto_start');

  final MethodChannel? customChannel;

  AutoStartPlatformService({this.customChannel});

  MethodChannel get _effectiveChannel => customChannel ?? _channel;

  /// Checks if ReelSenseAccessibilityService is enabled in Android Accessibility settings.
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android Accessibility Settings page.
  Future<bool> openAccessibilitySettings() async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>('openAccessibilitySettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if SYSTEM_ALERT_WINDOW (display over other apps) is granted.
  Future<bool> isOverlayPermissionGranted() async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>('isOverlayPermissionGranted');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Launches Android settings to grant SYSTEM_ALERT_WINDOW permission.
  Future<bool> requestOverlayPermission() async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>('requestOverlayPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if ReelSenseMonitoringService is running as a foreground service.
  Future<bool> isMonitoringServiceRunning() async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>('isMonitoringServiceRunning');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts the Foreground Monitoring Service while ReelSense is in the foreground.
  Future<bool> startMonitoringService(AutoStartConfig config) async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>(
        'startMonitoringService',
        {
          'controllerMode': config.controllerMode.key,
          'recognitionMode': config.recognitionMode.key,
          'locale': config.locale,
        },
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stops the Foreground Monitoring Service.
  Future<bool> stopMonitoringService() async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>('stopMonitoringService');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Updates active configuration in running monitoring service.
  Future<bool> updateConfig(AutoStartConfig config) async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>(
        'updateConfig',
        {
          'controllerMode': config.controllerMode.key,
          'recognitionMode': config.recognitionMode.key,
          'locale': config.locale,
        },
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Manually pauses active controller.
  Future<bool> pauseController() async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>('pauseController');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Resumes paused controller.
  Future<bool> resumeController() async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>('resumeController');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Manually stops controller session.
  Future<bool> stopController() async {
    try {
      final res = await _effectiveChannel.invokeMethod<bool>('stopController');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Gets full status of native services and permissions.
  Future<AutoStartServiceStatus> getServiceStatus() async {
    try {
      final map = await _effectiveChannel.invokeMethod<Map<dynamic, dynamic>>('getServiceStatus');
      return AutoStartServiceStatus.fromMap(map);
    } catch (_) {
      return const AutoStartServiceStatus(
        isMonitoringRunning: false,
        isAccessibilityEnabled: false,
        isOverlayGranted: false,
        hasAccessibilityInstance: false,
      );
    }
  }
}
