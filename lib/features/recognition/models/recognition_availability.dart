import 'recognition_mode.dart';

class RecognitionAvailability {
  final bool isRecognitionAvailable;
  final bool isOnDeviceAvailable;
  final bool isOfflineLocaleInstalled;
  final bool isOfflineLocaleSupported;
  final bool isOnlineAvailable;
  final List<String> installedOfflineLanguages;
  final int androidApiVersion;
  final String statusMessage;

  const RecognitionAvailability({
    required this.isRecognitionAvailable,
    required this.isOnDeviceAvailable,
    required this.isOfflineLocaleInstalled,
    required this.isOfflineLocaleSupported,
    required this.isOnlineAvailable,
    required this.installedOfflineLanguages,
    required this.androidApiVersion,
    required this.statusMessage,
  });

  factory RecognitionAvailability.unknown() {
    return const RecognitionAvailability(
      isRecognitionAvailable: false,
      isOnDeviceAvailable: false,
      isOfflineLocaleInstalled: false,
      isOfflineLocaleSupported: false,
      isOnlineAvailable: false,
      installedOfflineLanguages: [],
      androidApiVersion: 0,
      statusMessage: 'Not checked yet',
    );
  }

  factory RecognitionAvailability.fromMap(Map<dynamic, dynamic> map) {
    final installedLangs = (map['installedOfflineLanguages'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return RecognitionAvailability(
      isRecognitionAvailable: map['isRecognitionAvailable'] as bool? ?? false,
      isOnDeviceAvailable: map['isOnDeviceAvailable'] as bool? ?? false,
      isOfflineLocaleInstalled: map['isOfflineLocaleInstalled'] as bool? ?? false,
      isOfflineLocaleSupported: map['isOfflineLocaleSupported'] as bool? ?? false,
      isOnlineAvailable: map['isOnlineAvailable'] as bool? ?? false,
      installedOfflineLanguages: installedLangs,
      androidApiVersion: map['androidApiVersion'] as int? ?? 0,
      statusMessage: map['statusMessage'] as String? ?? '',
    );
  }

  bool isModeAvailable(RecognitionMode mode) {
    switch (mode) {
      case RecognitionMode.offline:
        // Offline is available if on-device recognition is supported AND the locale is installed
        // (or if on Android 12 without fine-grained locale query, isOnDeviceAvailable is true)
        return isRecognitionAvailable &&
            isOnDeviceAvailable &&
            (isOfflineLocaleInstalled || (androidApiVersion < 33 && isOnDeviceAvailable));
      case RecognitionMode.online:
        return isRecognitionAvailable && isOnlineAvailable;
    }
  }

  bool canDownloadOffline() {
    // If on-device engine exists, but the exact locale is not yet downloaded
    return isOnDeviceAvailable && !isOfflineLocaleInstalled;
  }
}
