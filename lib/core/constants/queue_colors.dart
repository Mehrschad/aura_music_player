import 'package:flutter/material.dart';

/// The twelve named accent colours a queue can be tinted with.
///
/// These are the *only* place raw queue-colour hex lives — widgets reference a
/// queue by its [NamedQueue.colorIndex] and resolve it through [queueColorAt],
/// keeping call sites token-based.
abstract final class QueueColors {
  const QueueColors._();

  /// Muted, desaturated hues chosen to sit calmly on Aura's dark surfaces while
  /// still being distinguishable at a glance in the queue drawer.
  static const List<Color> palette = <Color>[
    Color(0xFF8E8E93), // graphite (default)
    Color(0xFFE05A5A), // coral
    Color(0xFFE0863C), // amber
    Color(0xFFE0C04A), // gold
    Color(0xFF7BB661), // sage
    Color(0xFF4FB6A0), // teal
    Color(0xFF4F9DE0), // azure
    Color(0xFF5A6FE0), // indigo
    Color(0xFF9A6FE0), // violet
    Color(0xFFD06FC0), // orchid
    Color(0xFFB0857A), // clay
    Color(0xFF8A8A90), // slate
  ];

  static const int count = 12;

  /// Resolves a colour index to its palette colour, clamped into range.
  static Color at(int index) => palette[index.clamp(0, count - 1)];
}
