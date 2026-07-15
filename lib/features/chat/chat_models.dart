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

Color messageBubbleColor(MessageAccent accent) {
  return switch (accent) {
    MessageAccent.user => const Color(0xFFDDE9E2),
    MessageAccent.assistant => const Color(0xFFFFFCF6),
    MessageAccent.info => const Color(0xFFF3E4D8),
  };
}
