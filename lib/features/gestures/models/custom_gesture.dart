import 'dart:convert';
import '../../commands/models/reel_action.dart';

class CustomGesture {
  final String id;
  final String name;
  final ReelAction action;
  final String landmarkTemplateJson;
  final int sampleCount;
  final double confidenceThreshold;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomGesture({
    required this.id,
    required this.name,
    required this.action,
    required this.landmarkTemplateJson,
    this.sampleCount = 25,
    this.confidenceThreshold = 0.82,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  CustomGesture copyWith({
    String? id,
    String? name,
    ReelAction? action,
    String? landmarkTemplateJson,
    int? sampleCount,
    double? confidenceThreshold,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomGesture(
      id: id ?? this.id,
      name: name ?? this.name,
      action: action ?? this.action,
      landmarkTemplateJson: landmarkTemplateJson ?? this.landmarkTemplateJson,
      sampleCount: sampleCount ?? this.sampleCount,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'action': action.dbValue,
      'landmark_template_json': landmarkTemplateJson,
      'sample_count': sampleCount,
      'confidence_threshold': confidenceThreshold,
      'is_enabled': isEnabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CustomGesture.fromMap(Map<String, dynamic> map) {
    return CustomGesture(
      id: map['id'] as String,
      name: map['name'] as String,
      action: ReelAction.fromDbValue(map['action'] as String),
      landmarkTemplateJson: map['landmark_template_json'] as String,
      sampleCount: (map['sample_count'] as num?)?.toInt() ?? 25,
      confidenceThreshold: (map['confidence_threshold'] as num?)?.toDouble() ?? 0.82,
      isEnabled: (map['is_enabled'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  List<Map<String, double>> get parsedLandmarks {
    try {
      final decoded = jsonDecode(landmarkTemplateJson) as List<dynamic>;
      return decoded.map((p) {
        final map = p as Map<String, dynamic>;
        return {
          'x': (map['x'] as num).toDouble(),
          'y': (map['y'] as num).toDouble(),
          'z': (map['z'] as num).toDouble(),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomGesture &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
