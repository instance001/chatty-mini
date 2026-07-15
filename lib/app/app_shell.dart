import 'package:flutter/material.dart';

import '../features/chat/chat_screen.dart';
import '../features/startup/startup_splash_screen.dart';
import 'theme.dart';

class ChattyMiniApp extends StatefulWidget {
  const ChattyMiniApp({super.key});

  @override
  State<ChattyMiniApp> createState() => _ChattyMiniAppState();
}

class _ChattyMiniAppState extends State<ChattyMiniApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatty-mini',
      debugShowCheckedModeBanner: false,
      theme: buildChattyMiniTheme(),
      home: _showSplash
          ? StartupSplashScreen(
              onContinue: () {
                setState(() => _showSplash = false);
              },
            )
          : const ChatScreen(),
    );
  }
}
