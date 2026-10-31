import 'reel_action.dart';

class VoiceCommand {
  final String id;
  final String phrase;
  final String normalizedPhrase;
  final ReelAction action;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  VoiceCommand({
    required this.id,
    required this.phrase,
    String? normalizedPhrase,
    required this.action,
    this.isEnabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : normalizedPhrase = normalizedPhrase ?? normalize(phrase),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Normalizes a phrase by trimming whitespace, collapsing multiple spaces, and lowercasing.
  /// Works across English, Hinglish, and Hindi / Unicode scripts.
  static String normalize(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  VoiceCommand copyWith({
    String? id,
    String? phrase,
    String? normalizedPhrase,
    ReelAction? action,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final newPhrase = phrase ?? this.phrase;
    return VoiceCommand(
      id: id ?? this.id,
      phrase: newPhrase,
      normalizedPhrase:
          normalizedPhrase ?? (phrase != null ? normalize(newPhrase) : this.normalizedPhrase),
      action: action ?? this.action,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phrase': phrase,
      'normalized_phrase': normalizedPhrase,
      'action': action.dbValue,
      'is_enabled': isEnabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory VoiceCommand.fromMap(Map<String, dynamic> map) {
    return VoiceCommand(
      id: map['id'] as String,
      phrase: map['phrase'] as String,
      normalizedPhrase: map['normalized_phrase'] as String,
      action: ReelAction.fromDbValue(map['action'] as String),
      isEnabled: (map['is_enabled'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceCommand &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          phrase == other.phrase &&
          normalizedPhrase == other.normalizedPhrase &&
          action == other.action &&
          isEnabled == other.isEnabled;

  @override
  int get hashCode =>
      id.hashCode ^
      phrase.hashCode ^
      normalizedPhrase.hashCode ^
      action.hashCode ^
      isEnabled.hashCode;
}
