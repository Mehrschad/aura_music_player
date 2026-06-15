import 'package:flutter/foundation.dart';

/// A user-saved equalizer preset: a named 10-band gain curve plus the bass
/// boost and stereo width captured when it was saved.
@immutable
class NamedEqPreset {
  const NamedEqPreset({
    required this.id,
    required this.name,
    required this.gains,
    this.bassBoost = 0,
    this.stereoWidth = 0,
  });

  final String id;
  final String name;
  final List<double> gains;
  final int bassBoost;
  final double stereoWidth;

  NamedEqPreset copyWith({String? name}) => NamedEqPreset(
        id: id,
        name: name ?? this.name,
        gains: gains,
        bassBoost: bassBoost,
        stereoWidth: stereoWidth,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gains': gains,
        'bassBoost': bassBoost,
        'stereoWidth': stereoWidth,
      };

  static NamedEqPreset fromJson(Map<String, dynamic> json) => NamedEqPreset(
        id: json['id'] as String,
        name: json['name'] as String,
        gains:
            (json['gains'] as List).map((e) => (e as num).toDouble()).toList(),
        bassBoost: (json['bassBoost'] as num?)?.toInt() ?? 0,
        stereoWidth: (json['stereoWidth'] as num?)?.toDouble() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is NamedEqPreset &&
      other.id == id &&
      other.name == name &&
      other.bassBoost == bassBoost &&
      other.stereoWidth == stereoWidth &&
      listEquals(other.gains, gains);

  @override
  int get hashCode =>
      Object.hash(id, name, bassBoost, stereoWidth, Object.hashAll(gains));
}
