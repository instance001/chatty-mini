import 'package:flutter/material.dart';

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.body,
    required this.accent,
  });

  final String role;
  final String body;
  final MessageAccent accent;
}

enum MessageAccent { info, user, assistant }

class MemoryEntry {
  const MemoryEntry({required this.title, required this.body});

  final String title;
  final String body;
}

enum SidePanel { hotContext, rollingSummary }

enum PanelAlignment { left, right }

Color messageBubbleColor(ColorScheme scheme, MessageAccent accent) {
  return switch (accent) {
    MessageAccent.user => scheme.primaryContainer.withValues(alpha: 0.68),
    MessageAccent.assistant => scheme.surface,
    MessageAccent.info => scheme.secondaryContainer.withValues(alpha: 0.58),
  };
}
