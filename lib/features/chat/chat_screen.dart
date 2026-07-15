import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/inference/inference_controller.dart';
import '../../core/inference/inference_models.dart';
import '../../core/inference/inference_presets.dart';
import '../../core/inference/inference_service.dart';
import '../../core/runtime/runtime_controller.dart';
import '../../core/runtime/runtime_models.dart';
import '../../core/runtime/runtime_service.dart';
import '../../core/storage/app_storage.dart';
import '../character/character_controller.dart';
import '../character/character_tray.dart';
import '../help/help_sheet.dart';
import '../memory/memory_controller.dart';
import '../memory/memory_tray.dart';
import '../models/model_controller.dart';
import '../models/model_models.dart';
import '../models/model_sheet.dart';
import '../sandbox/sandbox_controller.dart';
import '../sandbox/sandbox_models.dart';
import '../sandbox/sandbox_tray.dart';
import '../settings/settings_sheet.dart';
import '../settings/settings_controller.dart';
import 'chat_models.dart';

enum SandboxTaskMode { targetFile, newFile }

enum AppSurfaceId { sandbox, models, memory, characters, settings, help }

class _PendingSandboxWrite {
  const _PendingSandboxWrite.newFile({
    required this.relativePath,
    required this.fileType,
  }) : mode = SandboxTaskMode.newFile;

  const _PendingSandboxWrite.targetFile({required this.relativePath})
    : mode = SandboxTaskMode.targetFile,
      fileType = null;

  final SandboxTaskMode mode;
  final String relativePath;
  final String? fileType;
}

class _BookkeeperUpdate {
  const _BookkeeperUpdate({
    this.hotContextMarkdown,
    this.rollingSummaryMarkdown,
    this.coldLogAppendMarkdown,
  });

  final String? hotContextMarkdown;
  final String? rollingSummaryMarkdown;
  final String? coldLogAppendMarkdown;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _composerController = TextEditingController();
  final TextEditingController _sandboxNewFileController =
      TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final AppStorageService _storage = AppStorageService();
  String? _sessionLogPath;

  late final SandboxController _sandboxController = SandboxController(
    storage: _storage,
  );
  late final ModelController _modelController = ModelController(
    storage: _storage,
  );
  late final MemoryController _memoryController = MemoryController(
    storage: _storage,
  );
  late final CharacterController _characterController = CharacterController(
    storage: _storage,
  );
  late final RuntimeController _runtimeController = RuntimeController(
    service: RuntimeService(),
  );
  late final SettingsController _settingsController = SettingsController(
    storage: _storage,
  );
  late final InferenceController _inferenceController = InferenceController(
    service: InferenceService(),
  );

  SidePanel? _expandedPanel;
  bool _storageReady = false;
  bool _sandboxTaskEnabled = false;
  SandboxTaskMode _sandboxTaskMode = SandboxTaskMode.targetFile;
  String? _sandboxTargetPath;
  _PendingSandboxWrite? _pendingSandboxWrite;
  String? _lastUserPromptForBookkeeper;
  bool _didRunStartupBehaviors = false;
  bool _isRefreshingMemoryBumps = false;
  bool _isBookkeeperRunning = false;

  final List<ChatMessage> _messages = [
    const ChatMessage(
      role: 'System',
      body:
          'Local mode is the default. Cloud inference runs only when you explicitly select a cloud model.',
      accent: MessageAccent.info,
    ),
    const ChatMessage(
      role: 'You',
      body: 'Sketch a compact Android-first chat tool for local GGUF work.',
      accent: MessageAccent.user,
    ),
    const ChatMessage(
      role: 'Assistant',
      body:
          'Chat stays dominant, memory lives in side bumps, and the sandbox tray stays scoped to simple text files.',
      accent: MessageAccent.assistant,
    ),
  ];

  List<MemoryEntry> _hotContextEntries = const [
    MemoryEntry(
      title: 'Current Aim',
      body: 'Build a minimal portrait app for local GGUF chat.',
    ),
    MemoryEntry(
      title: 'Constraints',
      body:
          'Small phones first. Minimal chrome. Sandbox limited to text files.',
    ),
    MemoryEntry(
      title: 'Runtime',
      body: 'Bundled native runtime with user-managed GGUF models.',
    ),
  ];

  List<String> _rollingSummaryLines = const [
    'The app direction is intentionally narrower than ChattyCog.',
    'Main screen should feel practical and uncluttered on small Android devices.',
    'Bookkeeper remains separate from the main chat role but lighter by default.',
  ];

  List<String> _coldLogExcerptLines = const [
    'Persistent notes and long-tail recap can live here.',
  ];

  @override
  void initState() {
    super.initState();
    _inferenceController.addListener(_handleInferenceUpdates);
    _sandboxController.addListener(_handleSandboxUpdates);
    _memoryController.addListener(_handleMemoryUpdates);
    _initializeStorage();
  }

  @override
  void dispose() {
    _composerController.dispose();
    _sandboxNewFileController.dispose();
    _chatScrollController.dispose();
    _inferenceController.removeListener(_handleInferenceUpdates);
    _sandboxController.removeListener(_handleSandboxUpdates);
    _memoryController.removeListener(_handleMemoryUpdates);
    _sandboxController.dispose();
    _modelController.dispose();
    _memoryController.dispose();
    _characterController.dispose();
    _runtimeController.dispose();
    _settingsController.dispose();
    _inferenceController.dispose();
    super.dispose();
  }

  Future<void> _initializeStorage() async {
    final snapshot = await _storage.ensureInitialized();
    await _sandboxController.initialize();
    await _modelController.initialize();
    await _memoryController.initialize();
    await _characterController.initialize();
    await _settingsController.initialize();
    await _runtimeController.initialize(
      runtimeDirPath: snapshot.runtimeDir.path,
    );
    await _inferenceController.initialize();
    await _refreshMemoryBumps();
    if (!mounted) {
      return;
    }
    _syncSandboxTargetWithFiles();
    setState(() {
      _storageReady = true;
      _sandboxTaskMode = _sandboxTaskModeFromSetting(
        _settingsController.defaultSandboxTaskMode,
      );
    });
    _runStartupBehaviors();
  }

  void _pushMessage(ChatMessage message, {bool logIfEnabled = true}) {
    setState(() {
      _messages.add(message);
    });
    if (logIfEnabled) {
      _appendSessionLogMessage(message);
    }
  }

  Future<void> _appendSessionLogMessage(ChatMessage message) async {
    if (!_memoryController.sessionLoggingEnabled) {
      return;
    }
    final logPath = await _ensureSessionLogPath();
    if (logPath == null) {
      return;
    }
    final timestamp = DateTime.now().toIso8601String();
    final entry =
        '## ${message.role} [$timestamp]\n\n${message.body.trim()}\n\n';
    await _storage.appendMemoryFile(logPath, entry);
  }

  Future<String?> _ensureSessionLogPath() async {
    if (!_memoryController.sessionLoggingEnabled) {
      return null;
    }
    if (_sessionLogPath != null) {
      final exists = await _storage.memoryFileExists(_sessionLogPath!);
      if (exists) {
        return _sessionLogPath;
      }
      _sessionLogPath = null;
    }

    final selectedModel = _modelController.findById(
      _modelController.settings.mainModelId,
    );
    final selectedCloudModel = _modelController.findCloudBySelectionId(
      _modelController.settings.mainModelId,
    );
    final preset = inferencePresetById(_modelController.settings.mainAiPreset);
    _sessionLogPath = await _storage.createSessionLogFile(
      modelFileName: selectedCloudModel?.label ?? selectedModel?.fileName,
      presetLabel: preset.label,
    );
    await _storage.enforceSessionLogRetention(
      _memoryController.sessionLogRetentionCount,
    );
    await _memoryController.refresh();
    return _sessionLogPath;
  }

  void _handleInferenceUpdates() {
    final completed = _inferenceController.status.completedResponse;
    if (completed != null && completed.isNotEmpty) {
      _handleCompletedAssistantResponse(completed);
      _inferenceController.clearCompletedResponse();
      return;
    }

    final error = _inferenceController.status.error;
    if (error != null && error.isNotEmpty) {
      var appended = false;
      setState(() {
        final hasSameError =
            _messages.isNotEmpty &&
            _messages.last.role == 'System' &&
            _messages.last.body == error;
        if (!hasSameError) {
          appended = true;
          _messages.add(
            ChatMessage(
              role: 'System',
              body: error,
              accent: MessageAccent.info,
            ),
          );
        }
      });
      if (appended) {
        _appendSessionLogMessage(
          ChatMessage(role: 'System', body: error, accent: MessageAccent.info),
        );
      }
    }
  }

  Future<void> _handleCompletedAssistantResponse(String completed) async {
    _pushMessage(
      ChatMessage(
        role: 'Assistant',
        body: completed,
        accent: MessageAccent.assistant,
      ),
    );

    await _applyImmediateMemoryRefresh(
      userPrompt: _lastUserPromptForBookkeeper ?? '',
      assistantResponse: completed,
    );

    final pendingWrite = _pendingSandboxWrite;
    _pendingSandboxWrite = null;
    if (pendingWrite == null) {
      unawaited(
        _runBookkeeperPass(
          userPrompt: _lastUserPromptForBookkeeper ?? '',
          assistantResponse: completed,
        ),
      );
      return;
    }

    await _applySandboxWrite(
      pendingWrite: pendingWrite,
      assistantResponse: completed,
    );
    unawaited(
      _runBookkeeperPass(
        userPrompt: _lastUserPromptForBookkeeper ?? '',
        assistantResponse: completed,
      ),
    );
  }

  void _togglePanel(SidePanel panel) {
    setState(() {
      _expandedPanel = _expandedPanel == panel ? null : panel;
    });
  }

  void _handleSandboxUpdates() {
    if (!mounted) {
      return;
    }
    _syncSandboxTargetWithFiles();
  }

  void _handleMemoryUpdates() {
    if (!mounted || _isRefreshingMemoryBumps) {
      return;
    }
    _refreshMemoryBumps();
  }

  Future<void> _refreshMemoryBumps() async {
    _isRefreshingMemoryBumps = true;
    try {
      final hotContext = await _storage.readMemoryFile('hot_context.md');
      final rollingSummary = await _storage.readMemoryFile(
        'rolling_summary.md',
      );
      final coldLog = await _storage.readMemoryFile('cold_log.md');
      if (!mounted) {
        return;
      }
      setState(() {
        _hotContextEntries = _parseHotContextEntries(hotContext);
        _rollingSummaryLines = _parseRollingSummaryLines(rollingSummary);
        _coldLogExcerptLines = _parseColdLogExcerptLines(coldLog);
      });
    } catch (_) {
      // Keep the existing fallback text if memory files are unavailable.
    } finally {
      _isRefreshingMemoryBumps = false;
    }
  }

  List<MemoryEntry> _parseHotContextEntries(String raw) {
    final entries = <MemoryEntry>[];
    String? currentTitle;
    final currentBody = StringBuffer();

    void flush() {
      final title = currentTitle?.trim();
      final body = currentBody.toString().trim();
      if (title != null && title.isNotEmpty && body.isNotEmpty) {
        entries.add(MemoryEntry(title: title, body: body));
      }
      currentBody.clear();
    }

    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final heading = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(line.trim());
      if (heading != null) {
        flush();
        currentTitle = heading.group(1);
        continue;
      }
      if (currentTitle == null && line.trim().isNotEmpty) {
        currentTitle = 'Working Memory';
      }
      currentBody.writeln(line);
    }
    flush();

    if (entries.isNotEmpty) {
      return entries.take(6).toList();
    }

    final fallback = raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim().replaceFirst(RegExp(r'^[-*]\s+'), ''))
        .where((line) => line.isNotEmpty)
        .take(6)
        .toList();
    return fallback
        .map((line) => MemoryEntry(title: 'Context', body: line))
        .toList();
  }

  List<String> _parseRollingSummaryLines(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim().replaceFirst(RegExp(r'^[-*]\s+'), ''))
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .take(8)
        .toList();
    return lines.isEmpty ? _rollingSummaryLines : lines;
  }

  List<String> _parseColdLogExcerptLines(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim().replaceFirst(RegExp(r'^[-*]\s+'), ''))
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    if (lines.isEmpty) {
      return _coldLogExcerptLines;
    }
    return lines.reversed.take(6).toList().reversed.toList();
  }

  void _syncSandboxTargetWithFiles() {
    final files = _sandboxController.files;
    final currentExists =
        _sandboxTargetPath != null &&
        files.any((file) => file.relativePath == _sandboxTargetPath);
    final nextTarget = currentExists
        ? _sandboxTargetPath
        : (files.isNotEmpty ? files.first.relativePath : null);
    if (nextTarget == _sandboxTargetPath) {
      return;
    }
    setState(() {
      _sandboxTargetPath = nextTarget;
    });
  }

  Future<void> _runStartupBehaviors() async {
    if (_didRunStartupBehaviors || !mounted) {
      return;
    }
    _didRunStartupBehaviors = true;

    final startupCharacterId = _settingsController.startupCharacterProfileId;
    if (startupCharacterId != null &&
        _characterController.findById(startupCharacterId) != null &&
        _characterController.activeProfileId != startupCharacterId) {
      await _characterController.selectProfile(startupCharacterId);
    }

    if (_settingsController.reopenLastSurfaceOnLaunch) {
      final restored = _reopenRememberedSurface(
        _settingsController.lastSurfaceId,
      );
      if (restored) {
        return;
      }
    }

    final shouldAutoOpen =
        _settingsController.autoOpenModelInventoryIfUnassigned &&
        _modelController.settings.mainModelId == null;
    if (shouldAutoOpen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openModelSheet();
        }
      });
    }
  }

  SandboxTaskMode _sandboxTaskModeFromSetting(String value) {
    return value == 'new_file'
        ? SandboxTaskMode.newFile
        : SandboxTaskMode.targetFile;
  }

  String _sandboxTaskModeToSetting(SandboxTaskMode value) {
    return value == SandboxTaskMode.newFile ? 'new_file' : 'target_file';
  }

  void _rememberSurface(AppSurfaceId surface) {
    _settingsController.setLastSurfaceId(_surfaceIdToSetting(surface));
  }

  bool _reopenRememberedSurface(String? surfaceId) {
    final surface = _surfaceIdFromSetting(surfaceId);
    if (surface == null || !mounted) {
      return false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      switch (surface) {
        case AppSurfaceId.sandbox:
          _openSandboxTray(restoreLastEditor: true);
        case AppSurfaceId.models:
          _openModelSheet();
        case AppSurfaceId.memory:
          _openMemoryTray(restoreLastEditor: true);
        case AppSurfaceId.characters:
          _openCharacterTray(restoreLastEditor: true);
        case AppSurfaceId.settings:
          _openSettingsSheet();
        case AppSurfaceId.help:
          _openHelpSheet();
      }
    });
    return true;
  }

  String _surfaceIdToSetting(AppSurfaceId surface) {
    return switch (surface) {
      AppSurfaceId.sandbox => 'sandbox',
      AppSurfaceId.models => 'models',
      AppSurfaceId.memory => 'memory',
      AppSurfaceId.characters => 'characters',
      AppSurfaceId.settings => 'settings',
      AppSurfaceId.help => 'help',
    };
  }

  AppSurfaceId? _surfaceIdFromSetting(String? value) {
    return switch (value) {
      'sandbox' => AppSurfaceId.sandbox,
      'models' => AppSurfaceId.models,
      'memory' => AppSurfaceId.memory,
      'characters' => AppSurfaceId.characters,
      'settings' => AppSurfaceId.settings,
      'help' => AppSurfaceId.help,
      _ => null,
    };
  }

  Future<void> _sendMessage() async {
    final prompt = _composerController.text.trim();
    if (prompt.isEmpty) {
      return;
    }

    final selectedModel = _modelController.findById(
      _modelController.settings.mainModelId,
    );
    final selectedCloudModel = _modelController.findCloudBySelectionId(
      _modelController.settings.mainModelId,
    );
    final selectedPreset = inferencePresetById(
      _modelController.settings.mainAiPreset,
    );
    final characterProfile = _characterController.activeProfile;
    final pendingSandboxWrite = _capturePendingSandboxWrite();
    final sandboxInstruction = await _buildSandboxInstruction();
    if (selectedCloudModel == null && !_runtimeController.status.isReady) {
      _pushMessage(
        const ChatMessage(
          role: 'System',
          body:
              'Bundled native runtime is not available in this build yet. Rebuild the app with the packaged native library before starting local generation.',
          accent: MessageAccent.info,
        ),
      );
      return;
    }
    if (selectedModel == null && selectedCloudModel == null) {
      _pushMessage(
        const ChatMessage(
          role: 'System',
          body:
              'No Main AI model is selected. Open Model Inventory and choose a local GGUF or cloud model.',
          accent: MessageAccent.info,
        ),
      );
      return;
    }
    if (selectedCloudModel != null && !selectedCloudModel.verified) {
      _pushMessage(
        const ChatMessage(
          role: 'System',
          body:
              'This cloud model has not been verified yet. Open Model Inventory and tap Verify before using it.',
          accent: MessageAccent.info,
        ),
      );
      return;
    }

    _pushMessage(
      ChatMessage(role: 'You', body: prompt, accent: MessageAccent.user),
    );
    _composerController.clear();
    _pendingSandboxWrite = pendingSandboxWrite;
    _lastUserPromptForBookkeeper = prompt;

    final generationPrompt = _buildGenerationPrompt(
      characterPrompt: characterProfile.prompt,
      userPrompt: prompt,
      isCloud: selectedCloudModel != null,
      sandboxInstruction: sandboxInstruction,
    );
    if (selectedCloudModel != null) {
      await _inferenceController.startCloudGeneration(
        model: selectedCloudModel,
        prompt: generationPrompt,
        maxTokens: selectedPreset.maxTokens,
        temperature: selectedPreset.temperature,
      );
    } else {
      await _inferenceController.startGeneration(
        request: GenerationRequest(
          prompt: generationPrompt,
          modelPath: selectedModel!.fullPath,
          contextSize: selectedPreset.contextSize,
          maxTokens: selectedPreset.maxTokens,
          temperature: selectedPreset.temperature,
          topP: selectedPreset.topP,
          topK: selectedPreset.topK,
          gpuLayers: selectedPreset.gpuLayers,
        ),
      );
    }
  }

  _PendingSandboxWrite? _capturePendingSandboxWrite() {
    if (!_sandboxTaskEnabled) {
      return null;
    }

    if (_sandboxTaskMode == SandboxTaskMode.newFile) {
      final requestedName = _sandboxNewFileController.text.trim();
      if (requestedName.isEmpty) {
        return null;
      }
      return _PendingSandboxWrite.newFile(
        relativePath: requestedName,
        fileType: _sandboxStorageFileType(requestedName),
      );
    }

    if (_sandboxTargetPath == null || _sandboxTargetPath!.trim().isEmpty) {
      return null;
    }
    return _PendingSandboxWrite.targetFile(relativePath: _sandboxTargetPath!);
  }

  Future<void> _stopGeneration() {
    return _inferenceController.cancelGeneration();
  }

  Future<void> _runBookkeeperPass({
    required String userPrompt,
    required String assistantResponse,
  }) async {
    if (_isBookkeeperRunning) {
      return;
    }
    if (userPrompt.trim().isEmpty || assistantResponse.trim().isEmpty) {
      return;
    }
    final bookkeeperCloudModel =
        _modelController.findCloudBySelectionId(
          _modelController.settings.bookkeeperModelId,
        ) ??
        _modelController.findCloudBySelectionId(
          _modelController.settings.mainModelId,
        );
    if (bookkeeperCloudModel == null || !bookkeeperCloudModel.verified) {
      return;
    }

    _isBookkeeperRunning = true;
    try {
      final preset = inferencePresetById(
        _modelController.settings.bookkeeperPreset,
      );
      final bookkeeperPrompt = _buildBookkeeperPrompt(
        userPrompt: userPrompt,
        assistantResponse: assistantResponse,
        currentHotContext: _hotContextEntries,
        currentRollingSummary: _rollingSummaryLines,
        currentColdLogExcerpt: _coldLogExcerptLines,
      );
      final response = await _inferenceController.cloudService.generateWithRetry(
        model: bookkeeperCloudModel,
        prompt: bookkeeperPrompt,
        maxTokens: preset.maxTokens,
        temperature: preset.temperature,
        onChunk: (_) {},
      );
      if (response.trim().isEmpty) {
        return;
      }

      final update = _parseBookkeeperUpdate(response);
      var wroteMemory = false;
      if (update.hotContextMarkdown != null &&
          update.hotContextMarkdown!.trim().isNotEmpty) {
        await _storage.writeMemoryFile(
          'hot_context.md',
          '${update.hotContextMarkdown!.trim()}\n',
        );
        wroteMemory = true;
      }
      if (update.rollingSummaryMarkdown != null &&
          update.rollingSummaryMarkdown!.trim().isNotEmpty) {
        await _storage.writeMemoryFile(
          'rolling_summary.md',
          '${update.rollingSummaryMarkdown!.trim()}\n',
        );
        wroteMemory = true;
      }
      final coldLogAppend = update.coldLogAppendMarkdown?.trim();
      if (coldLogAppend != null &&
          coldLogAppend.isNotEmpty &&
          coldLogAppend.toLowerCase() != '- no durable update.') {
        final timestamp = DateTime.now().toIso8601String();
        await _storage.appendMemoryFile(
          'cold_log.md',
          '\n## Bookkeeper $timestamp\n\n$coldLogAppend\n',
        );
        wroteMemory = true;
      }

      if (wroteMemory) {
        await _memoryController.refresh();
        await _refreshMemoryBumps();
      }
    } catch (_) {
      // Keep the bookkeeper silent in the prototype build when it fails.
    } finally {
      _isBookkeeperRunning = false;
    }
  }

  Future<void> _applyImmediateMemoryRefresh({
    required String userPrompt,
    required String assistantResponse,
  }) async {
    final cleanPrompt = userPrompt.trim();
    final cleanReply = assistantResponse.trim();
    if (cleanPrompt.isEmpty || cleanReply.isEmpty) {
      return;
    }

    final promptLine = _compactSingleLine(cleanPrompt, maxLength: 140);
    final replyLine = _compactSingleLine(cleanReply, maxLength: 180);
    final timestamp = DateTime.now();
    final stampedDate =
        '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

    final nextHotContext = <MemoryEntry>[
      MemoryEntry(title: 'Current Turn', body: promptLine),
      MemoryEntry(title: 'Latest Reply', body: replyLine),
      if (_hotContextEntries.isNotEmpty) ..._hotContextEntries.take(3),
    ];

    final nextRollingSummary = <String>[
      '$stampedDate: User asked about ${_summarizeSubject(promptLine)}.',
      '$stampedDate: Assistant replied with ${_summarizeSubject(replyLine)}.',
      ..._rollingSummaryLines.take(4),
    ];

    final hotContextMarkdown = nextHotContext
        .take(4)
        .map((entry) => '## ${entry.title}\n\n${entry.body}')
        .join('\n\n');
    final rollingSummaryMarkdown = nextRollingSummary
        .take(5)
        .map((line) => '- $line')
        .join('\n');

    final coldLogLine =
        '- $stampedDate: ${_summarizeSubject(promptLine)} -> ${_summarizeSubject(replyLine)}';

    await _storage.writeMemoryFile('hot_context.md', '$hotContextMarkdown\n');
    await _storage.writeMemoryFile(
      'rolling_summary.md',
      '$rollingSummaryMarkdown\n',
    );
    await _storage.appendMemoryFile('cold_log.md', '\n$coldLogLine\n');
    await _memoryController.refresh();
    await _refreshMemoryBumps();
  }

  String _compactSingleLine(String input, {required int maxLength}) {
    final singleLine = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= maxLength) {
      return singleLine;
    }
    return '${singleLine.substring(0, maxLength - 1).trim()}…';
  }

  String _summarizeSubject(String input) {
    final words = input
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s_-]'), '')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(10)
        .toList();
    if (words.isEmpty) {
      return 'the recent turn';
    }
    return words.join(' ');
  }

  Future<void> _openSandboxTray({bool restoreLastEditor = false}) {
    _rememberSurface(AppSurfaceId.sandbox);
    return showSandboxTray(
      context: context,
      controller: _sandboxController,
      restoreFilePath: restoreLastEditor
          ? _settingsController.lastSandboxFilePath
          : null,
      onFileOpened: (relativePath) {
        _settingsController.setLastSandboxFilePath(relativePath);
      },
    );
  }

  Future<void> _openModelSheet() {
    _rememberSurface(AppSurfaceId.models);
    return showModelSheet(context: context, controller: _modelController);
  }

  Future<void> _openMemoryTray({bool restoreLastEditor = false}) {
    _rememberSurface(AppSurfaceId.memory);
    return showMemoryTray(
      context: context,
      controller: _memoryController,
      restoreFilePath: restoreLastEditor
          ? _settingsController.lastMemoryFilePath
          : null,
      onFileOpened: (relativePath) {
        _settingsController.setLastMemoryFilePath(relativePath);
      },
    );
  }

  Future<void> _openCharacterTray({bool restoreLastEditor = false}) {
    _rememberSurface(AppSurfaceId.characters);
    return showCharacterTray(
      context: context,
      controller: _characterController,
      restoreProfileId: restoreLastEditor
          ? _settingsController.lastCharacterProfileId
          : null,
      onProfileEditorOpened: (profileId) {
        _settingsController.setLastCharacterProfileId(profileId);
      },
    );
  }

  Future<void> _openHelpSheet() {
    _rememberSurface(AppSurfaceId.help);
    return showHelpSheet(
      context: context,
      onOpenSandbox: _openSandboxTray,
      onOpenCharacters: _openCharacterTray,
      onOpenModels: _openModelSheet,
      onOpenMemory: _openMemoryTray,
    );
  }

  Future<void> _openSettingsSheet() async {
    _rememberSurface(AppSurfaceId.settings);
    await _settingsController.refresh();
    if (!mounted) {
      return;
    }
    return showSettingsSheet(
      context: context,
      memoryController: _memoryController,
      settingsController: _settingsController,
      onOpenColdLog: _openMemoryTray,
      onOpenModels: _openModelSheet,
      onOpenHelp: _openHelpSheet,
    );
  }

  String _buildGenerationPrompt({
    required String characterPrompt,
    required String userPrompt,
    required bool isCloud,
    required String? sandboxInstruction,
  }) {
    final buffer = StringBuffer()
      ..write('System:\n')
      ..write(_buildChatProtocol(isCloud: isCloud))
      ..write('\n\nCharacter overlay:\n')
      ..write(characterPrompt.trim());
    if (sandboxInstruction != null && sandboxInstruction.isNotEmpty) {
      buffer
        ..write('\n\n')
        ..write(sandboxInstruction.trim());
    }
    buffer
      ..write('\n\nUser:\n')
      ..write(userPrompt.trim())
      ..write('\n\nAssistant:\n');
    return buffer.toString();
  }

  String _buildChatProtocol({required bool isCloud}) {
    final laneNote = isCloud
        ? 'This reply uses the cloud model explicitly selected by the user.'
        : 'This reply stays local on the user device.';
    return '''
Chat normally. Be lively, natural, and useful.

Truth rails:
- Admit uncertainty instead of guessing.
- Do not claim real capabilities you do not have.
- You have no browser, shell, hidden tools, or external file access. $laneNote
- Do not claim you saved, opened, edited, uploaded, downloaded, or inspected anything unless the host supplied that action or context.

Action contract:
- If a sandbox task contract is supplied below, obey it exactly.
- Otherwise, answer the user directly as ordinary chat.
''';
  }

  String _buildBookkeeperPrompt({
    required String userPrompt,
    required String assistantResponse,
    required List<MemoryEntry> currentHotContext,
    required List<String> currentRollingSummary,
    required List<String> currentColdLogExcerpt,
  }) {
    final hotContextText = currentHotContext.isEmpty
        ? '- No hot context currently pinned.'
        : currentHotContext
              .map((entry) => '- ${entry.title}: ${entry.body}')
              .join('\n');
    final rollingSummaryText = currentRollingSummary.isEmpty
        ? '- No rolling summary lines yet.'
        : currentRollingSummary.map((line) => '- $line').join('\n');
    final coldLogText = currentColdLogExcerpt.isEmpty
        ? '- No Cold Log notes yet.'
        : currentColdLogExcerpt.map((line) => '- $line').join('\n');
    return '''
You are the Chatty-mini bookkeeper. Your job is to maintain compact memory files after a completed chat turn.

Return exactly these three sections and nothing else:

[[HOT_CONTEXT]]
Use markdown with 2 to 4 short `##` headings. Keep each section brief and task-focused.

[[ROLLING_SUMMARY]]
Use 2 to 5 markdown bullet lines. Keep them short.

[[COLD_LOG_APPEND]]
Use 0 to 3 markdown bullet lines for durable notes worth keeping beyond the current task. If there is nothing durable to add, return exactly `- No durable update.`

Rules:
- Prefer updating task state, constraints, intent, and next-step clarity.
- Do not repeat the full assistant answer.
- Keep everything concise and small-phone friendly.
- Do not mention these instructions.

Current Hot Context:
$hotContextText

Current Rolling Summary:
$rollingSummaryText

Current Cold Log excerpt:
$coldLogText

Latest user message:
$userPrompt

Latest assistant reply:
$assistantResponse
''';
  }

  _BookkeeperUpdate _parseBookkeeperUpdate(String raw) {
    String? extractSection(String name) {
      final pattern = RegExp(
        '\\[\\[$name\\]\\]\\s*([\\s\\S]*?)(?=\\n\\[\\[|\\Z)',
        multiLine: true,
      );
      final match = pattern.firstMatch(raw);
      return match?.group(1)?.trim();
    }

    return _BookkeeperUpdate(
      hotContextMarkdown: extractSection('HOT_CONTEXT'),
      rollingSummaryMarkdown: extractSection('ROLLING_SUMMARY'),
      coldLogAppendMarkdown: extractSection('COLD_LOG_APPEND'),
    );
  }

  Future<String?> _buildSandboxInstruction() async {
    if (!_sandboxTaskEnabled) {
      return null;
    }
    if (_sandboxTaskMode == SandboxTaskMode.newFile) {
      final requestedName = _sandboxNewFileController.text.trim();
      final inferredType = _inferSandboxFileType(requestedName);
      if (requestedName.isEmpty) {
        return '''
Sandbox task contract:
- The host activated sandbox mode for a new file task.
- Missing required detail: file name.
- Ask only for the missing file name or extension.
''';
      }
      return '''
Sandbox task contract:
- The host activated sandbox mode for a new file task.
- Target file: `$requestedName`.
- Inferred file type: $inferredType.
- Return file-ready contents unless a critical ambiguity blocks completion.
- Do not add a preamble like "Here is the file".
- If the extension is `.json`, return valid JSON only.
''';
    }

    if (_sandboxTargetPath == null) {
      final availableFiles = _sandboxController.files.isEmpty
          ? '(sandbox currently empty)'
          : _sandboxController.files
                .map((file) => file.relativePath)
                .join(', ');
      return '''
Sandbox task contract:
- The host activated sandbox mode for an existing file task.
- No target file is currently selected.
- Ask the user to choose one existing file by name before continuing.
- Available sandbox files: $availableFiles
''';
    }

    try {
      final contents = await _sandboxController.readFile(_sandboxTargetPath!);
      return '''
Sandbox task contract:
- The host activated sandbox mode for an existing file task.
- Target file: `${_sandboxTargetPath!}`.
- Use the current file contents below as the source material.
- Prefer returning the full revised file contents unless the user clearly asked for a smaller patch, summary, or diagnosis.
- Preserve the file's apparent format and structure.
- If the file is JSON, keep the reply valid JSON.

Current contents of `${_sandboxTargetPath!}`:
```
$contents
```
''';
    } catch (error) {
      return '''
Sandbox task contract:
- The host activated sandbox mode for a file task.
- Target file: `${_sandboxTargetPath!}`.
- Current contents could not be read: $error
- Acknowledge the read failure briefly, then continue as a file-focused assistant.
''';
    }
  }

  String _inferSandboxFileType(String relativePath) {
    final lower = relativePath.toLowerCase();
    if (lower.endsWith('.json')) {
      return 'json';
    }
    if (lower.endsWith('.txt')) {
      return 'plain text';
    }
    return 'markdown';
  }

  String _sandboxStorageFileType(String relativePath) {
    final lower = relativePath.toLowerCase();
    if (lower.endsWith('.json')) {
      return 'json';
    }
    if (lower.endsWith('.txt')) {
      return 'text';
    }
    return 'markdown';
  }

  Future<void> _applySandboxWrite({
    required _PendingSandboxWrite pendingWrite,
    required String assistantResponse,
  }) async {
    final cleanedOutput = _normalizeSandboxFileContents(
      assistantResponse,
      fileType:
          pendingWrite.fileType ??
          _sandboxStorageFileType(pendingWrite.relativePath),
    );
    if (cleanedOutput.trim().isEmpty) {
      _pushMessage(
        const ChatMessage(
          role: 'System',
          body:
              'Sandbox task completed, but the model returned empty file contents so nothing was written.',
          accent: MessageAccent.info,
        ),
      );
      return;
    }

    try {
      if (pendingWrite.mode == SandboxTaskMode.newFile) {
        final existing = _sandboxController.files.any(
          (file) => file.relativePath == pendingWrite.relativePath,
        );
        if (!existing) {
          final created = await _sandboxController.createFile(
            fileName: pendingWrite.relativePath,
            fileType: pendingWrite.fileType ?? 'markdown',
          );
          if (created == null) {
            throw Exception(
              'Could not create sandbox file `${pendingWrite.relativePath}`.',
            );
          }
        }
      }

      await _sandboxController.saveFile(
        pendingWrite.relativePath,
        cleanedOutput,
      );
      _settingsController.setLastSandboxFilePath(pendingWrite.relativePath);
      _syncSandboxTargetWithFiles();
      if (mounted) {
        setState(() {
          _sandboxTargetPath = pendingWrite.relativePath;
        });
      }
      _pushMessage(
        ChatMessage(
          role: 'System',
          body: 'Saved sandbox file `${pendingWrite.relativePath}`.',
          accent: MessageAccent.info,
        ),
      );
    } catch (error) {
      _pushMessage(
        ChatMessage(
          role: 'System',
          body:
              'Sandbox write for `${pendingWrite.relativePath}` failed: $error',
          accent: MessageAccent.info,
        ),
      );
    }
  }

  String _normalizeSandboxFileContents(
    String assistantResponse, {
    required String fileType,
  }) {
    var normalized = assistantResponse.trim();
    final fencedBlock = RegExp(
      r'^```(?:[a-zA-Z0-9_-]+)?\s*([\s\S]*?)\s*```$',
      dotAll: true,
    ).firstMatch(normalized);
    if (fencedBlock != null) {
      normalized = fencedBlock.group(1)?.trim() ?? normalized;
    }

    if (fileType == 'json') {
      return normalized;
    }

    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      final unwrapped = normalized.substring(1, normalized.length - 1).trim();
      if (unwrapped.isNotEmpty) {
        normalized = unwrapped;
      }
    }

    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final compactLandscapeLayout =
        screenWidth > screenHeight && screenHeight < 700;
    final compactKeyboardLayout = keyboardVisible || compactLandscapeLayout;
    final bumpTop = compactLandscapeLayout
        ? (screenHeight * 0.42).clamp(150.0, 220.0)
        : (screenHeight * 0.43).clamp(220.0, 360.0);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                ChatTopBar(
                  compactMode: compactLandscapeLayout,
                  onSandboxPressed: _openSandboxTray,
                  onPromptPressed: _openCharacterTray,
                  onModelPressed: _openModelSheet,
                  onSettingsPressed: _openSettingsSheet,
                  onInfoPressed: _openHelpSheet,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      compactLandscapeLayout ? 10 : 14,
                      compactLandscapeLayout ? 4 : 8,
                      compactLandscapeLayout ? 10 : 14,
                      0,
                    ),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _modelController,
                            _runtimeController,
                            _inferenceController,
                            _characterController,
                          ]),
                          builder: (context, _) => StatusStrip(
                            storageReady: _storageReady,
                            modelController: _modelController,
                            runtimeController: _runtimeController,
                            inferenceController: _inferenceController,
                            characterController: _characterController,
                          ),
                        ),
                        SizedBox(height: compactKeyboardLayout ? 3 : 6),
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _modelController,
                            _runtimeController,
                          ]),
                          builder: (context, _) {
                            final selectedModel = _modelController.findById(
                              _modelController.settings.mainModelId,
                            );
                            final selectedCloudModel = _modelController
                                .findCloudBySelectionId(
                                  _modelController.settings.mainModelId,
                                );
                            final preset =
                                selectedModel == null &&
                                    selectedCloudModel == null
                                ? null
                                : inferencePresetById(
                                    _modelController.settings.mainAiPreset,
                                  );
                            return SystemHealthRow(
                              runtimeStatus: _runtimeController.status,
                              isLoading: _runtimeController.isLoading,
                              error: _runtimeController.error,
                              hasModels: _modelController.models.isNotEmpty,
                              selectedModel: selectedModel,
                              selectedCloudModel: selectedCloudModel,
                              preset: preset,
                              activeCharacterProfile:
                                  _characterController.activeProfile,
                              onRefresh: _runtimeController.refresh,
                              onOpenModels: _openModelSheet,
                            );
                          },
                        ),
                        SizedBox(height: compactKeyboardLayout ? 4 : 8),
                        AnimatedBuilder(
                          animation: _inferenceController,
                          builder: (context, _) {
                            return Expanded(
                              child: ChatCard(
                                scrollController: _chatScrollController,
                                messages: _messages,
                                assistantDraft:
                                    _inferenceController.status.assistantDraft,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: compactLandscapeLayout ? 4 : 8),
                        AnimatedBuilder(
                          animation: _inferenceController,
                          builder: (context, _) {
                            return ComposerBar(
                              controller: _composerController,
                              sandboxFiles: _sandboxController.files,
                              sandboxTaskEnabled: _sandboxTaskEnabled,
                              sandboxTaskMode: _sandboxTaskMode,
                              sandboxTargetPath: _sandboxTargetPath,
                              sandboxNewFileController:
                                  _sandboxNewFileController,
                              isGenerating:
                                  _inferenceController.status.isGenerating,
                              compactMode: compactKeyboardLayout,
                              landscapeMode: compactLandscapeLayout,
                              onSandboxTaskEnabledChanged: (value) {
                                setState(() => _sandboxTaskEnabled = value);
                              },
                              onSandboxTaskModeChanged: (value) {
                                setState(() {
                                  _sandboxTaskMode = value;
                                  if (value == SandboxTaskMode.targetFile &&
                                      _sandboxTargetPath == null &&
                                      _sandboxController.files.isNotEmpty) {
                                    _sandboxTargetPath = _sandboxController
                                        .files
                                        .first
                                        .relativePath;
                                  }
                                });
                                _settingsController.setDefaultSandboxTaskMode(
                                  _sandboxTaskModeToSetting(value),
                                );
                              },
                              onSandboxTargetChanged: (value) {
                                setState(() => _sandboxTargetPath = value);
                              },
                              onSend: _sendMessage,
                              onStop: _stopGeneration,
                            );
                          },
                        ),
                        SizedBox(height: compactKeyboardLayout ? 4 : 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (!keyboardVisible)
              Positioned(
                left: 0,
                top: bumpTop,
                child: SideBump(
                  label: 'Hot Context',
                  icon: Icons.push_pin_outlined,
                  isExpanded: _expandedPanel == SidePanel.hotContext,
                  alignment: PanelAlignment.left,
                  onTap: () => _togglePanel(SidePanel.hotContext),
                ),
              ),
            if (!keyboardVisible)
              Positioned(
                right: 0,
                top: bumpTop,
                child: SideBump(
                  label: 'Summary',
                  icon: Icons.subject_outlined,
                  isExpanded: _expandedPanel == SidePanel.rollingSummary,
                  alignment: PanelAlignment.right,
                  onTap: () => _togglePanel(SidePanel.rollingSummary),
                ),
              ),
            if (_expandedPanel != null)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _expandedPanel = null),
                  child: Container(color: Colors.black.withValues(alpha: 0.08)),
                ),
              ),
            if (_expandedPanel == SidePanel.hotContext)
              SidePanelOverlay(
                alignment: PanelAlignment.left,
                title: 'Hot Context',
                subtitle: 'User-curated working memory for the active task.',
                child: _hotContextEntries.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No hot context is pinned yet. Open Cold Log to add working memory or let the bookkeeper create it after a reply.',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      )
                    : Column(
                        children: _hotContextEntries
                            .map((entry) => MemoryCard(entry: entry))
                            .toList(),
                      ),
              ),
            if (_expandedPanel == SidePanel.rollingSummary)
              SidePanelOverlay(
                alignment: PanelAlignment.right,
                title: 'Rolling Summary',
                subtitle:
                    'Short-running recap maintained by the lighter bookkeeper role.',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _rollingSummaryLines.isEmpty
                        ? Text(
                            'No rolling summary is available yet. Send a reply and let the bookkeeper build one.',
                            style: theme.textTheme.bodyLarge,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: _rollingSummaryLines
                                .map(
                                  (line) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      line,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChatTopBar extends StatelessWidget {
  const ChatTopBar({
    super.key,
    required this.compactMode,
    required this.onSandboxPressed,
    required this.onPromptPressed,
    required this.onModelPressed,
    required this.onSettingsPressed,
    required this.onInfoPressed,
  });

  final bool compactMode;
  final VoidCallback onSandboxPressed;
  final VoidCallback onPromptPressed;
  final VoidCallback onModelPressed;
  final VoidCallback onSettingsPressed;
  final VoidCallback onInfoPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(14, compactMode ? 4 : 10, 14, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chatty-mini', style: theme.textTheme.titleMedium),
                    if (!compactMode) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Local GGUF chat for small phones',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TopBarAction(
                tooltip: 'Sandbox',
                icon: Icons.inventory_2_outlined,
                onPressed: onSandboxPressed,
              ),
              const SizedBox(width: 6),
              TopBarAction(
                tooltip: 'Characters',
                icon: Icons.face_5_outlined,
                onPressed: onPromptPressed,
              ),
              const SizedBox(width: 6),
              TopBarAction(
                tooltip: 'Models',
                icon: Icons.tune_outlined,
                onPressed: onModelPressed,
              ),
              const SizedBox(width: 6),
              TopBarAction(
                tooltip: 'Settings',
                icon: Icons.settings_outlined,
                onPressed: onSettingsPressed,
              ),
              const SizedBox(width: 6),
              TopBarAction(
                tooltip: 'Help',
                icon: Icons.info_outline,
                onPressed: onInfoPressed,
              ),
            ],
          ),
          SizedBox(height: compactMode ? 4 : 10),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

class TopBarAction extends StatelessWidget {
  const TopBarAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
      ),
    );
  }
}

class StatusStrip extends StatelessWidget {
  const StatusStrip({
    super.key,
    required this.storageReady,
    required this.modelController,
    required this.runtimeController,
    required this.inferenceController,
    required this.characterController,
  });

  final bool storageReady;
  final ModelController modelController;
  final RuntimeController runtimeController;
  final InferenceController inferenceController;
  final CharacterController characterController;

  @override
  Widget build(BuildContext context) {
    final settings = modelController.settings;
    final hasMainModel = modelController.findById(settings.mainModelId) != null;
    final cloudModel = modelController.findCloudBySelectionId(
      settings.mainModelId,
    );
    final mainPreset = inferencePresetById(settings.mainAiPreset);
    final chips = <Widget>[
      _MiniStatusChip(
        icon: inferenceController.status.isGenerating
            ? Icons.graphic_eq
            : Icons.offline_bolt_outlined,
        label: inferenceController.status.isGenerating
            ? 'Generating'
            : cloudModel != null
            ? 'Cloud'
            : 'Local',
      ),
      _MiniStatusChip(
        icon: runtimeController.status.isReady
            ? Icons.check_circle_outline
            : Icons.pending_outlined,
        label: runtimeController.status.isReady
            ? 'Ready'
            : runtimeController.status.state,
      ),
      _MiniStatusChip(
        icon: hasMainModel || cloudModel != null
            ? Icons.forum_outlined
            : Icons.file_open_outlined,
        label:
            cloudModel?.label ?? (hasMainModel ? mainPreset.label : 'No model'),
      ),
      _MiniStatusChip(
        icon: Icons.face_5_outlined,
        label: characterController.activeProfile.name,
      ),
      if (!storageReady)
        const _MiniStatusChip(
          icon: Icons.folder_open_outlined,
          label: 'Storage',
        ),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => chips[index],
      ),
    );
  }
}

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurface),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class SystemHealthRow extends StatelessWidget {
  const SystemHealthRow({
    super.key,
    required this.runtimeStatus,
    required this.isLoading,
    required this.error,
    required this.hasModels,
    required this.selectedModel,
    required this.selectedCloudModel,
    required this.preset,
    required this.activeCharacterProfile,
    required this.onRefresh,
    required this.onOpenModels,
  });

  final RuntimeStatus runtimeStatus;
  final bool isLoading;
  final String? error;
  final bool hasModels;
  final ModelRecord? selectedModel;
  final CloudModelRecord? selectedCloudModel;
  final InferenceConfig? preset;
  final CharacterProfile activeCharacterProfile;
  final VoidCallback onRefresh;
  final VoidCallback onOpenModels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assessment = selectedModel == null || preset == null
        ? null
        : _assessModelHealth(
            model: selectedModel!,
            preset: preset!,
            runtimeStatus: runtimeStatus,
          );
    final fitLabel = selectedCloudModel != null
        ? (selectedCloudModel!.verified ? 'Verified' : 'Unverified')
        : assessment?.label ?? (hasModels ? 'Unknown' : 'No model');
    final fitColor = assessment?.color ?? theme.colorScheme.onSurface;
    final parts = <String>[
      selectedCloudModel != null
          ? (selectedCloudModel!.verified ? 'Ready' : 'Check setup')
          : (runtimeStatus.isReady ? 'Ready' : runtimeStatus.state),
      selectedCloudModel != null ? 'Cloud' : 'Local',
      if (selectedCloudModel == null &&
          runtimeStatus.deviceAvailableRamBytes != null)
        '${_formatCompactBytes(runtimeStatus.deviceAvailableRamBytes!)} free',
      'Model fit: $fitLabel',
    ];

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: selectedCloudModel != null
            ? onOpenModels
            : () => showRuntimeDetailsSheet(
                context: context,
                runtimeStatus: runtimeStatus,
                isLoading: isLoading,
                error: error,
                hasModels: hasModels,
                selectedModel: selectedModel,
                preset: preset,
                activeCharacterProfile: activeCharacterProfile,
                onRefresh: onRefresh,
                onOpenModels: onOpenModels,
              ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  parts.join(' | '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 10),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.chevron_right, color: fitColor),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingNotice extends StatelessWidget {
  const OnboardingNotice({
    super.key,
    required this.models,
    required this.runtimeStatus,
    required this.onOpenModels,
  });

  final List<ModelRecord> models;
  final RuntimeStatus runtimeStatus;
  final VoidCallback onOpenModels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsModels = models.isEmpty;
    if (!needsModels) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('First-run setup', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              'The native runtime ships with the app bundle. First-run setup is mainly about importing one or more GGUF models through Android.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Runtime state: ${runtimeStatus.state}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'No GGUF models detected yet. Open Model Inventory, import from Downloads or Recent files, and manage cleanup there as well.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onOpenModels,
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Open Models'),
            ),
          ],
        ),
      ),
    );
  }
}

class StorageNotice extends StatelessWidget {
  const StorageNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App folders created', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              'Runtime metadata, imported models, and sandbox notes are stored in private app storage. Model import and deletion are handled inside the app so users do not need to browse hidden Android folders.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showRuntimeDetailsSheet({
  required BuildContext context,
  required RuntimeStatus runtimeStatus,
  required bool isLoading,
  required String? error,
  required bool hasModels,
  required ModelRecord? selectedModel,
  required InferenceConfig? preset,
  required CharacterProfile activeCharacterProfile,
  required VoidCallback onRefresh,
  required VoidCallback onOpenModels,
}) {
  final assessment = selectedModel == null || preset == null
      ? null
      : _assessModelHealth(
          model: selectedModel,
          preset: preset,
          runtimeStatus: runtimeStatus,
        );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return FractionallySizedBox(
        heightFactor: 0.72,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            Text('Runtime Details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Diagnostics live here so the main screen can stay focused on chat.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('State ${runtimeStatus.state}')),
                        Chip(
                          label: Text(
                            runtimeStatus.isBundled ? 'Bundled' : 'External',
                          ),
                        ),
                        if (runtimeStatus.version != null)
                          Chip(label: Text(runtimeStatus.version!)),
                        if (runtimeStatus.backend != null)
                          Chip(label: Text(runtimeStatus.backend!)),
                        if (runtimeStatus.deviceTotalRamBytes != null)
                          Chip(
                            label: Text(
                              'RAM ${_formatCompactBytes(runtimeStatus.deviceTotalRamBytes!)}',
                            ),
                          ),
                        if (runtimeStatus.deviceAvailableRamBytes != null)
                          Chip(
                            label: Text(
                              'Free ${_formatCompactBytes(runtimeStatus.deviceAvailableRamBytes!)}',
                            ),
                          ),
                        if (assessment != null)
                          Chip(
                            label: Text('Model fit ${assessment.label}'),
                            backgroundColor: assessment.color.withValues(
                              alpha: 0.14,
                            ),
                            side: BorderSide(
                              color: assessment.color.withValues(alpha: 0.35),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      runtimeStatus.message,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (assessment != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        assessment.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Character', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Text(
                      activeCharacterProfile.name,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeCharacterProfile.prompt,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (selectedModel != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected Model', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Text(
                        selectedModel.fileName,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatCompactBytes(selectedModel.sizeBytes)} | ${preset?.label ?? 'No preset'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Text(
                    hasModels
                        ? 'Pick a main model in Model Inventory to start chatting.'
                        : 'No GGUF models imported yet. Use Model Inventory to import from Downloads or Recent files.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: isLoading ? null : onRefresh,
                  icon: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenModels();
                    },
                    icon: const Icon(Icons.tune_outlined),
                    label: Text(hasModels ? 'Open Models' : 'Import Model'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class ChatCard extends StatefulWidget {
  const ChatCard({
    super.key,
    required this.scrollController,
    required this.messages,
    required this.assistantDraft,
  });

  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final String assistantDraft;

  @override
  State<ChatCard> createState() => _ChatCardState();
}

class _ChatCardState extends State<ChatCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(covariant ChatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final messageCountChanged =
        widget.messages.length != oldWidget.messages.length;
    final draftChanged = widget.assistantDraft != oldWidget.assistantDraft;
    if (messageCountChanged || draftChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (!widget.scrollController.hasClients) {
      return;
    }
    final position = widget.scrollController.position.maxScrollExtent;
    widget.scrollController.animateTo(
      position,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleMessages = <ChatMessage>[
      ...widget.messages,
      if (widget.assistantDraft.isNotEmpty)
        ChatMessage(
          role: 'Assistant',
          body: widget.assistantDraft,
          accent: MessageAccent.assistant,
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: ListView.separated(
          controller: widget.scrollController,
          padding: EdgeInsets.zero,
          itemCount: visibleMessages.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final message = visibleMessages[index];
            return MessageBubble(message: message);
          },
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.accent == MessageAccent.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 290),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: messageBubbleColor(message.accent),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.role,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                const SizedBox(height: 6),
                Text(message.body, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ComposerBar extends StatelessWidget {
  const ComposerBar({
    super.key,
    required this.controller,
    required this.sandboxFiles,
    required this.sandboxTaskEnabled,
    required this.sandboxTaskMode,
    required this.sandboxTargetPath,
    required this.sandboxNewFileController,
    required this.isGenerating,
    required this.compactMode,
    required this.landscapeMode,
    required this.onSandboxTaskEnabledChanged,
    required this.onSandboxTaskModeChanged,
    required this.onSandboxTargetChanged,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final List<SandboxFileEntry> sandboxFiles;
  final bool sandboxTaskEnabled;
  final SandboxTaskMode sandboxTaskMode;
  final String? sandboxTargetPath;
  final TextEditingController sandboxNewFileController;
  final bool isGenerating;
  final bool compactMode;
  final bool landscapeMode;
  final ValueChanged<bool> onSandboxTaskEnabledChanged;
  final ValueChanged<SandboxTaskMode> onSandboxTaskModeChanged;
  final ValueChanged<String?> onSandboxTargetChanged;
  final Future<void> Function() onSend;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sandboxStrip = _SandboxTaskStrip(
      files: sandboxFiles,
      enabled: sandboxTaskEnabled,
      mode: sandboxTaskMode,
      targetPath: sandboxTargetPath,
      newFileController: sandboxNewFileController,
      compactMode: compactMode,
      onEnabledChanged: onSandboxTaskEnabledChanged,
      onModeChanged: onSandboxTaskModeChanged,
      onTargetChanged: onSandboxTargetChanged,
    );
    final messageComposer = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: compactMode ? 1 : 2,
            maxLines: compactMode ? (landscapeMode ? 2 : 4) : 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: isGenerating
                  ? 'Streaming reply...'
                  : 'Message the model...',
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: compactMode ? 46 : 50,
          child: FilledButton.tonalIcon(
            onPressed: isGenerating ? () => onStop() : () => onSend(),
            icon: Icon(
              isGenerating ? Icons.stop_circle_outlined : Icons.arrow_upward,
            ),
            label: Text(isGenerating ? 'Stop' : 'Send'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: isGenerating
                  ? const Color(0xFFF3E4D8)
                  : theme.colorScheme.primary,
              foregroundColor: isGenerating
                  ? theme.colorScheme.onSurface
                  : Colors.white,
            ),
          ),
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          compactMode ? 8 : 10,
          12,
          compactMode ? 8 : 10,
        ),
        child: landscapeMode
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 300, child: sandboxStrip),
                  const SizedBox(width: 10),
                  Expanded(child: messageComposer),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sandboxStrip,
                  SizedBox(height: compactMode ? 8 : 10),
                  messageComposer,
                ],
              ),
      ),
    );
  }
}

class _SandboxTaskStrip extends StatelessWidget {
  const _SandboxTaskStrip({
    required this.files,
    required this.enabled,
    required this.mode,
    required this.targetPath,
    required this.newFileController,
    required this.compactMode,
    required this.onEnabledChanged,
    required this.onModeChanged,
    required this.onTargetChanged,
  });

  final List<SandboxFileEntry> files;
  final bool enabled;
  final SandboxTaskMode mode;
  final String? targetPath;
  final TextEditingController newFileController;
  final bool compactMode;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<SandboxTaskMode> onModeChanged;
  final ValueChanged<String?> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        10,
        compactMode ? 6 : 8,
        10,
        compactMode ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: enabled,
                  onChanged: (value) => onEnabledChanged(value ?? false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text('Sandbox task', style: theme.textTheme.labelLarge),
              ),
              SizedBox(
                width: 112,
                child: DropdownButtonHideUnderline(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButton<SandboxTaskMode>(
                        value: mode,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: SandboxTaskMode.targetFile,
                            child: Text('Target'),
                          ),
                          DropdownMenuItem(
                            value: SandboxTaskMode.newFile,
                            child: Text('New file'),
                          ),
                        ],
                        onChanged: enabled
                            ? (value) {
                                if (value != null) {
                                  onModeChanged(value);
                                }
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (enabled) ...[
            SizedBox(height: compactMode ? 6 : 8),
            if (mode == SandboxTaskMode.targetFile)
              files.isEmpty
                  ? Text(
                      'No sandbox files available yet. Create one in the sandbox tray first.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue:
                          files.any((file) => file.relativePath == targetPath)
                          ? targetPath
                          : files.first.relativePath,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Target file',
                      ),
                      items: files
                          .map(
                            (file) => DropdownMenuItem<String>(
                              value: file.relativePath,
                              child: Text(
                                file.relativePath,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: onTargetChanged,
                    )
            else
              TextField(
                controller: newFileController,
                maxLines: 1,
                decoration: InputDecoration(
                  isDense: compactMode,
                  labelText: compactMode ? null : 'New sandbox file name',
                  hintText: compactMode
                      ? 'New sandbox file name'
                      : 'draft_reply.md',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class SideBump extends StatelessWidget {
  const SideBump({
    super.key,
    required this.label,
    required this.icon,
    required this.isExpanded,
    required this.alignment,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isExpanded;
  final PanelAlignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = alignment == PanelAlignment.left
        ? const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: isExpanded
                ? theme.colorScheme.primary
                : theme.colorScheme.surface.withValues(alpha: 0.96),
            borderRadius: radius,
            border: Border.all(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x17000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: RotatedBox(
            quarterTurns: alignment == PanelAlignment.left ? 3 : 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isExpanded
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isExpanded
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SidePanelOverlay extends StatelessWidget {
  const SidePanelOverlay({
    super.key,
    required this.alignment,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final PanelAlignment alignment;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth * 0.78;

    return Positioned(
      top: 126,
      bottom: 22,
      left: alignment == PanelAlignment.left ? 14 : null,
      right: alignment == PanelAlignment.right ? 14 : null,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelWidth.clamp(260.0, 360.0),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 14),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key, required this.entry});

  final MemoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(entry.body, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class ModelHealthCard extends StatelessWidget {
  const ModelHealthCard({
    super.key,
    required this.model,
    required this.preset,
    required this.runtimeStatus,
  });

  final ModelRecord model;
  final InferenceConfig preset;
  final RuntimeStatus runtimeStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assessment = _assessModelHealth(
      model: model,
      preset: preset,
      runtimeStatus: runtimeStatus,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Model Health',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Chip(
                  label: Text(assessment.label),
                  backgroundColor: assessment.color.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: assessment.color.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${model.fileName} with ${preset.label}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              assessment.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('Model: ${_formatCompactBytes(model.sizeBytes)}'),
                ),
                Chip(label: Text('Context: ${preset.contextSize}')),
                Chip(label: Text('Max tokens: ${preset.maxTokens}')),
                if (runtimeStatus.deviceTotalRamBytes != null)
                  Chip(
                    label: Text(
                      'RAM: ${_formatCompactBytes(runtimeStatus.deviceTotalRamBytes!)}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelHealthAssessment {
  const _ModelHealthAssessment({
    required this.label,
    required this.summary,
    required this.color,
  });

  final String label;
  final String summary;
  final Color color;
}

_ModelHealthAssessment _assessModelHealth({
  required ModelRecord model,
  required InferenceConfig preset,
  required RuntimeStatus runtimeStatus,
}) {
  final totalRam = runtimeStatus.deviceTotalRamBytes ?? 0;
  final availableRam = runtimeStatus.deviceAvailableRamBytes ?? 0;

  if (model.isTooLargeForSmallPhones) {
    return const _ModelHealthAssessment(
      label: 'High Risk',
      summary:
          'This GGUF is probably too large for the small-phone target. Expect load failure or aggressive memory pressure.',
      color: Color(0xFFB64C3A),
    );
  }

  if (runtimeStatus.lowRamDevice && model.isLargeForSmallPhones) {
    return const _ModelHealthAssessment(
      label: 'High Risk',
      summary:
          'This device is flagged as low RAM and the selected GGUF is heavy. A smaller model would be safer.',
      color: Color(0xFFB64C3A),
    );
  }

  if (runtimeStatus.memoryTrimSuggested) {
    return const _ModelHealthAssessment(
      label: 'Caution',
      summary:
          'Android is already signaling memory pressure. Avoid roomy presets until memory settles.',
      color: Color(0xFFB67A3A),
    );
  }

  if (totalRam > 0 && model.sizeBytes > totalRam * 0.45) {
    return const _ModelHealthAssessment(
      label: 'Caution',
      summary:
          'This model is large relative to device RAM. It may still run, but it is a more fragile fit for small phones.',
      color: Color(0xFFB67A3A),
    );
  }

  if (availableRam > 0 && model.sizeBytes > availableRam * 0.85) {
    return const _ModelHealthAssessment(
      label: 'Caution',
      summary:
          'Current free memory is tight for this model. Closing background apps or using a tighter preset would help.',
      color: Color(0xFFB67A3A),
    );
  }

  if (preset.contextSize >= 2048 && model.isLargeForSmallPhones) {
    return const _ModelHealthAssessment(
      label: 'Caution',
      summary:
          'This roomy context plus a heavy GGUF leans ambitious for a small portrait phone. Balanced or tight is safer.',
      color: Color(0xFFB67A3A),
    );
  }

  return const _ModelHealthAssessment(
    label: 'Reasonable',
    summary:
        'This model and preset look like a reasonable starting point for the current hardware.',
    color: Color(0xFF587A4A),
  );
}

String _formatCompactBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}
