import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/recognition_availability.dart';
import '../models/recognition_mode.dart';
import '../models/recognition_state.dart';
import 'android_speech_recognition_handler.dart';
import 'recognition_availability_service.dart';
import 'recognition_preference_service.dart';
import 'voice_command_matcher.dart';

class SpeechRecognitionService extends ChangeNotifier {
  final RecognitionPreferenceService _prefs;
  final RecognitionAvailabilityService _availabilityService;
  final AndroidSpeechRecognitionHandler _handler;
  final VoiceCommandMatcher _matcher;

  RecognitionState _state = RecognitionState.idle;
  RecognitionMode? _selectedMode;
  String _selectedLocale = RecognitionPreferenceService.defaultLocale;
  RecognitionAvailability _lastAvailability = RecognitionAvailability.unknown();
  String? _errorMessage;

  String _lastRecognizedText = '';
  VoiceCommandMatch? _lastMatch;

  StreamSubscription<Map<dynamic, dynamic>>? _eventSubscription;

  SpeechRecognitionService({
    RecognitionPreferenceService? prefs,
    RecognitionAvailabilityService? availabilityService,
    AndroidSpeechRecognitionHandler? handler,
    VoiceCommandMatcher? matcher,
  })  : _prefs = prefs ?? RecognitionPreferenceService(),
        _availabilityService = availabilityService ?? RecognitionAvailabilityService(),
        _handler = handler ?? MethodChannelSpeechRecognitionHandler(),
        _matcher = matcher ?? VoiceCommandMatcher();

  RecognitionState get state => _state;
  RecognitionMode? get selectedMode => _selectedMode;
  String get selectedLocale => _selectedLocale;
  RecognitionAvailability get lastAvailability => _lastAvailability;
  String? get errorMessage => _errorMessage;
  String get lastRecognizedText => _lastRecognizedText;
  VoiceCommandMatch? get lastMatch => _lastMatch;

  bool get isListening => _state == RecognitionState.listening;

  /// Initializes preferences and checks availability.
  Future<void> initialize() async {
    _setState(RecognitionState.checking);
    _selectedMode = await _prefs.getSelectedMode();
    _selectedLocale = await _prefs.getSelectedLocale();

    _lastAvailability = await _availabilityService.checkAvailability(_selectedLocale);

    if (_selectedMode != null) {
      final isAvail = _lastAvailability.isModeAvailable(_selectedMode!);
      if (isAvail) {
        _setState(RecognitionState.ready);
      } else {
        _setState(RecognitionState.unavailable);
        _errorMessage = '${_selectedMode!.displayName} is currently unavailable for $_selectedLocale.';
      }
    } else {
      _setState(RecognitionState.idle);
    }

    _listenToNativeEvents();
  }

  /// Sets and saves the recognition mode permanently after validating availability.
  Future<bool> setRecognitionMode(RecognitionMode mode) async {
    _setState(RecognitionState.checking);
    _lastAvailability = await _availabilityService.checkAvailability(_selectedLocale);

    final isAvailable = _lastAvailability.isModeAvailable(mode);
    if (!isAvailable) {
      _setState(RecognitionState.unavailable);
      _errorMessage = '${mode.displayName} is not available on this device for $_selectedLocale.';
      notifyListeners();
      return false;
    }

    _selectedMode = mode;
    await _prefs.setSelectedMode(mode);
    _errorMessage = null;
    _setState(RecognitionState.ready);
    notifyListeners();
    return true;
  }

  /// Sets and saves the locale, and updates availability checks.
  Future<void> setLocale(String locale) async {
    _selectedLocale = locale;
    await _prefs.setSelectedLocale(locale);
    await refreshAvailability();
  }

  /// Re-checks the device availability for the current locale.
  Future<RecognitionAvailability> refreshAvailability() async {
    _setState(RecognitionState.checking);
    _lastAvailability = await _availabilityService.checkAvailability(_selectedLocale);

    if (_selectedMode != null) {
      final isAvail = _lastAvailability.isModeAvailable(_selectedMode!);
      if (isAvail) {
        _setState(RecognitionState.ready);
        _errorMessage = null;
      } else {
        _setState(RecognitionState.unavailable);
        _errorMessage = '${_selectedMode!.displayName} is currently not available for $_selectedLocale.';
      }
    } else {
      _setState(RecognitionState.idle);
    }

    notifyListeners();
    return _lastAvailability;
  }

  /// Starts listening using the user's selected mode ONLY.
  Future<bool> startListening() async {
    if (_selectedMode == null) {
      _errorMessage = 'Speech recognition mode has not been configured.';
      _setState(RecognitionState.error);
      return false;
    }

    final hasPerm = await _availabilityService.hasRecordAudioPermission();
    if (!hasPerm) {
      final granted = await _availabilityService.requestRecordAudioPermission();
      if (!granted) {
        _errorMessage = 'Microphone permission is required to listen for commands.';
        _setState(RecognitionState.error);
        return false;
      }
    }

    _lastAvailability = await _availabilityService.checkAvailability(_selectedLocale);
    if (!_lastAvailability.isModeAvailable(_selectedMode!)) {
      _errorMessage = '${_selectedMode!.displayName} is not available on this device.';
      _setState(RecognitionState.unavailable);
      return false;
    }

    _setState(RecognitionState.listening);
    final success = await _handler.startListening(
      mode: _selectedMode!.key,
      locale: _selectedLocale,
    );

    if (!success) {
      _setState(RecognitionState.error);
      _errorMessage = 'Failed to start ${_selectedMode!.displayName}.';
      return false;
    }

    return true;
  }

  /// Stops speech listening.
  Future<void> stopListening() async {
    await _handler.stopListening();
    _setState(RecognitionState.ready);
  }

  /// Cancels speech listening and resets state.
  Future<void> cancelListening() async {
    await _handler.cancelListening();
    _setState(RecognitionState.ready);
  }

  void _listenToNativeEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _handler.eventStream.listen(
      (event) {
        final eventType = event['event'] as String?;
        switch (eventType) {
          case 'ready':
            _setState(RecognitionState.listening);
            break;
          case 'partial':
            _lastRecognizedText = event['text'] as String? ?? '';
            notifyListeners();
            break;
          case 'result':
            final text = event['text'] as String? ?? '';
            final confidence = (event['confidence'] as num?)?.toDouble() ?? 1.0;
            _lastRecognizedText = text;
            _processRecognizedSpeech(text, confidence);
            break;
          case 'error':
            final message = event['message'] as String? ?? 'Recognition error';
            _errorMessage = message;
            _setState(RecognitionState.ready);
            break;
          case 'endOfSpeech':
            _setState(RecognitionState.ready);
            break;
        }
      },
      onError: (e) {
        _errorMessage = e.toString();
        _setState(RecognitionState.error);
      },
    );
  }

  Future<void> _processRecognizedSpeech(String text, double confidence) async {
    if (text.isEmpty) return;

    final match = await _matcher.matchSpeech(speech: text, confidence: confidence);
    if (match != null) {
      _lastMatch = match;
      _matcher.dispatchMatch(match);
      notifyListeners();
    }
  }

  void _setState(RecognitionState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _handler.cancelListening();
    super.dispose();
  }
}
