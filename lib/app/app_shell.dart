import 'package:flutter/material.dart';

import '../core/storage/app_storage.dart';
import '../features/chat/chat_screen.dart';
import '../features/models/model_models.dart';
import '../features/settings/settings_controller.dart';
import '../features/startup/startup_splash_screen.dart';
import 'theme.dart';

class ChattyMiniApp extends StatefulWidget {
  const ChattyMiniApp({super.key});

  @override
  State<ChattyMiniApp> createState() => _ChattyMiniAppState();
}

class _ChattyMiniAppState extends State<ChattyMiniApp> {
  final AppStorageService _storage = AppStorageService();
  bool _showSplash = true;
  String _themeMode = AppSettings.defaults.themeMode;

  @override
  void initState() {
    super.initState();
    SettingsController.themeModeNotifier.addListener(_handleThemeModeChanged);
    _loadThemeMode();
  }

  @override
  void dispose() {
    SettingsController.themeModeNotifier.removeListener(
      _handleThemeModeChanged,
    );
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    try {
      final settings = await _storage.readSettings();
      SettingsController.themeModeNotifier.value = settings.themeMode;
    } catch (_) {
      SettingsController.themeModeNotifier.value =
          AppSettings.defaults.themeMode;
    }
  }

  void _handleThemeModeChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = SettingsController.themeModeNotifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatty-mini',
      debugShowCheckedModeBanner: false,
      theme: buildChattyMiniTheme(Brightness.light),
      darkTheme: buildChattyMiniTheme(Brightness.dark),
      themeMode: _materialThemeMode(_themeMode),
      home: _showSplash
          ? StartupSplashScreen(
              onContinue: () {
                setState(() => _showSplash = false);
              },
            )
          : const ChatScreen(),
    );
  }

  ThemeMode _materialThemeMode(String value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
