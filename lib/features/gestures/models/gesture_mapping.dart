import 'package:flutter/material.dart';

enum ReelGesture {
  openPalm(
    id: 'OPEN_PALM',
    displayName: 'Open Palm',
    action: 'PAUSE_PLAY',
    actionLabel: 'Pause / Resume Video',
    description: 'Extend all five fingers facing front camera',
    icon: Icons.pan_tool_rounded,
  ),
  thumbsUp(
    id: 'THUMBS_UP',
    displayName: 'Thumbs Up',
    action: 'LIKE_REEL',
    actionLabel: 'Double Tap / Like Reel',
    description: 'Thumb pointing upwards with other four fingers folded',
    icon: Icons.thumb_up_rounded,
  ),
  indexFinger(
    id: 'INDEX_FINGER',
    displayName: 'Only Index Finger',
    action: 'NEXT_REEL',
    actionLabel: 'Swipe to Next Reel',
    description: 'Extend index finger upward with other fingers folded',
    icon: Icons.touch_app_rounded,
  ),
  indexAndMiddle(
    id: 'INDEX_AND_MIDDLE',
    displayName: 'Index + Middle',
    action: 'PREVIOUS_REEL',
    actionLabel: 'Swipe to Previous Reel',
    description: 'Extend index and middle fingers together',
    icon: Icons.content_cut_rounded,
  );

  const ReelGesture({
    required this.id,
    required this.displayName,
    required this.action,
    required this.actionLabel,
    required this.description,
    required this.icon,
  });

  final String id;
  final String displayName;
  final String action;
  final String actionLabel;
  final String description;
  final IconData icon;

  static ReelGesture? fromId(String id) {
    for (final g in values) {
      if (g.id.toUpperCase() == id.toUpperCase()) return g;
    }
    return null;
  }
}
