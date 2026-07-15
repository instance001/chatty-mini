import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../features/memory/memory_models.dart';
import '../../features/models/model_models.dart';
import '../../features/sandbox/sandbox_models.dart';

class AppStorageSnapshot {
  const AppStorageSnapshot({
    required this.rootDir,
    required this.runtimeDir,
    required this.modelsDir,
    required this.sandboxDir,
    required this.memoryDir,
    required this.configDir,
  });

  final Directory rootDir;
  final Directory runtimeDir;
  final Directory modelsDir;
  final Directory sandboxDir;
  final Directory memoryDir;
  final Directory configDir;
}

class AppStorageService {
  AppStorageSnapshot? _snapshot;

  Future<AppStorageSnapshot> ensureInitialized() async {
    if (_snapshot != null) {
      return _snapshot!;
    }

    final appSupportDir = await getApplicationSupportDirectory();
    final rootDir = Directory('${appSupportDir.path}/chatty_mini');
    final runtimeDir = Directory('${rootDir.path}/runtime');
    final modelsDir = Directory('${rootDir.path}/models');
    final sandboxDir = Directory('${rootDir.path}/sandbox');
    final memoryDir = Directory('${rootDir.path}/memory');
    final configDir = Directory('${rootDir.path}/config');

    for (final dir in [
      rootDir,
      runtimeDir,
      modelsDir,
      sandboxDir,
      memoryDir,
      configDir,
    ]) {
      await dir.create(recursive: true);
    }

    await _seedDefaults(
      sandboxDir: sandboxDir,
      memoryDir: memoryDir,
      configDir: configDir,
    );

    _snapshot = AppStorageSnapshot(
      rootDir: rootDir,
      runtimeDir: runtimeDir,
      modelsDir: modelsDir,
      sandboxDir: sandboxDir,
      memoryDir: memoryDir,
      configDir: configDir,
    );
    return _snapshot!;
  }

  Future<List<SandboxFileEntry>> listSandboxFiles() async {
    final snapshot = await ensureInitialized();
    final entities = await snapshot.sandboxDir.list().toList();
    final files = <SandboxFileEntry>[];

    for (final entity in entities.whereType<File>()) {
      final stat = await entity.stat();
      final relativePath = entity.path.substring(
        snapshot.sandboxDir.path.length + 1,
      );
      final extension = entity.path.split('.').last.toLowerCase();
      if (!_supportedExtensions.contains(extension)) {
        continue;
      }
      files.add(
        SandboxFileEntry(
          relativePath: relativePath.replaceAll('\\', '/'),
          fileType: _typeForExtension(extension),
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }

    files.sort(
      (a, b) =>
          a.relativePath.toLowerCase().compareTo(b.relativePath.toLowerCase()),
    );
    return files;
  }

  Future<String> readSandboxFile(String relativePath) async {
    final file = await _resolveSandboxFile(relativePath);
    return file.readAsString();
  }

  Future<void> writeSandboxFile(String relativePath, String contents) async {
    final file = await _resolveSandboxFile(relativePath);
    await file.writeAsString(contents);
  }

  Future<SandboxFileEntry> createSandboxFile({
    required String fileName,
    required String fileType,
  }) async {
    final cleanName = _sanitizeFileName(fileName, fileType);
    final file = await _resolveSandboxFile(cleanName);
    if (await file.exists()) {
      throw SandboxFileException(
        'A sandbox file named `$cleanName` already exists.',
      );
    }

    await file.writeAsString(_starterContentForType(fileType));
    final stat = await file.stat();
    return SandboxFileEntry(
      relativePath: cleanName,
      fileType: fileType,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }

  Future<SandboxFileEntry> importSandboxFile({
    required String fileName,
    required String contents,
  }) async {
    final fileType = _typeForExtension(fileName.split('.').last.toLowerCase());
    final cleanName = _sanitizeFileName(fileName, fileType);
    final snapshot = await ensureInitialized();
    final file = await _resolveUniqueSandboxFile(snapshot.sandboxDir, cleanName);
    await file.writeAsString(contents);
    final stat = await file.stat();
    return SandboxFileEntry(
      relativePath: file.path
          .substring(snapshot.sandboxDir.path.length + 1)
          .replaceAll('\\', '/'),
      fileType: fileType,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }

  Future<void> deleteSandboxFiles(Iterable<String> relativePaths) async {
    for (final relativePath in relativePaths) {
      final file = await _resolveSandboxFile(relativePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<AppSettings> readSettings() async {
    final snapshot = await ensureInitialized();
    final file = File('${snapshot.configDir.path}/settings.json');
    if (!await file.exists()) {
      return AppSettings.defaults;
    }
    final raw = await file.readAsString();
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      return AppSettings.defaults;
    }
    return AppSettings.fromJson(data);
  }

  Future<void> writeSettings(AppSettings settings) async {
    final snapshot = await ensureInitialized();
    final file = File('${snapshot.configDir.path}/settings.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    );
  }

  Future<List<MemoryFileEntry>> listMemoryFiles() async {
    final snapshot = await ensureInitialized();
    final entities = await snapshot.memoryDir.list(recursive: true).toList();
    final files = <MemoryFileEntry>[];

    for (final entity in entities.whereType<File>()) {
      final stat = await entity.stat();
      final relativePath = entity.path.substring(
        snapshot.memoryDir.path.length + 1,
      );
      files.add(
        MemoryFileEntry(
          relativePath: relativePath.replaceAll('\\', '/'),
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }

    files.sort(
      (a, b) =>
          a.relativePath.toLowerCase().compareTo(b.relativePath.toLowerCase()),
    );
    return files;
  }

  Future<String> readMemoryFile(String relativePath) async {
    final file = await _resolveMemoryFile(relativePath);
    return file.readAsString();
  }

  Future<void> writeMemoryFile(String relativePath, String contents) async {
    final file = await _resolveMemoryFile(relativePath);
    await file.writeAsString(contents);
  }

  Future<void> appendMemoryFile(String relativePath, String contents) async {
    final file = await _resolveMemoryFile(relativePath);
    await file.writeAsString(contents, mode: FileMode.append);
  }

  Future<bool> memoryFileExists(String relativePath) async {
    final file = await _resolveMemoryFile(relativePath);
    return file.exists();
  }

  Future<void> deleteMemoryFiles(Iterable<String> relativePaths) async {
    for (final relativePath in relativePaths) {
      final file = await _resolveMemoryFile(relativePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<String> createSessionLogFile({
    required String? modelFileName,
    required String presetLabel,
  }) async {
    final timestamp = DateTime.now();
    final fileName =
        '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}_'
        '${timestamp.hour.toString().padLeft(2, '0')}-${timestamp.minute.toString().padLeft(2, '0')}-${timestamp.second.toString().padLeft(2, '0')}.md';
    final relativePath = 'session_logs/$fileName';
    final header =
        '# Session Log\n\n'
        '- Started: ${timestamp.toIso8601String()}\n'
        '- Main model: ${modelFileName ?? 'unassigned'}\n'
        '- Preset: $presetLabel\n\n';
    await writeMemoryFile(relativePath, header);
    return relativePath;
  }

  Future<void> enforceSessionLogRetention(int maxFiles) async {
    if (maxFiles <= 0) {
      return;
    }
    final files = await listMemoryFiles();
    final sessionLogs = files.where((file) => file.isSessionLog).toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    if (sessionLogs.length <= maxFiles) {
      return;
    }
    final toDelete = sessionLogs
        .skip(maxFiles)
        .map((file) => file.relativePath);
    await deleteMemoryFiles(toDelete);
  }

  Future<void> clearSessionLogFiles() async {
    final files = await listMemoryFiles();
    final sessionLogPaths = files
        .where((file) => file.isSessionLog)
        .map((file) => file.relativePath);
    await deleteMemoryFiles(sessionLogPaths);
  }

  Future<List<ModelRecord>> scanModels() async {
    final snapshot = await ensureInitialized();
    final entities = await snapshot.modelsDir.list().toList();
    final models = <ModelRecord>[];

    for (final entity in entities.whereType<File>()) {
      if (!entity.path.toLowerCase().endsWith('.gguf')) {
        continue;
      }
      final stat = await entity.stat();
      final fileName = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : entity.path.split(Platform.pathSeparator).last;
      models.add(
        ModelRecord(
          id: fileName,
          fileName: fileName,
          fullPath: entity.path,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }

    models.sort(
      (a, b) => a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
    );
    return models;
  }

  Future<ModelRecord> importModelFromStream({
    required String fileName,
    required Stream<List<int>> stream,
  }) async {
    final snapshot = await ensureInitialized();
    final sanitizedName = _sanitizeModelFileName(fileName);
    final destination = await _resolveUniqueModelFile(
      snapshot.modelsDir,
      sanitizedName,
    );
    final sink = destination.openWrite();
    try {
      await sink.addStream(stream);
    } finally {
      await sink.close();
    }

    final stat = await destination.stat();
    final finalName = destination.uri.pathSegments.isNotEmpty
        ? destination.uri.pathSegments.last
        : destination.path.split(Platform.pathSeparator).last;

    return ModelRecord(
      id: finalName,
      fileName: finalName,
      fullPath: destination.path,
      sizeBytes: stat.size,
      modifiedAt: stat.modified,
    );
  }

  Future<void> deleteModelFiles(Iterable<String> modelIds) async {
    final snapshot = await ensureInitialized();
    for (final modelId in modelIds) {
      final cleanId = _sanitizeModelFileName(modelId);
      final file = File('${snapshot.modelsDir.path}/$cleanId');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<File> _resolveSandboxFile(String relativePath) async {
    final snapshot = await ensureInitialized();
    final normalized = relativePath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) {
      throw SandboxFileException('Sandbox path cannot be empty.');
    }
    if (normalized.contains('..')) {
      throw SandboxFileException(
        'Sandbox path cannot escape the sandbox folder.',
      );
    }
    final file = File('${snapshot.sandboxDir.path}/$normalized');
    final parent = file.parent;
    await parent.create(recursive: true);
    return file;
  }

  Future<File> _resolveMemoryFile(String relativePath) async {
    final snapshot = await ensureInitialized();
    final normalized = relativePath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) {
      throw SandboxFileException('Memory path cannot be empty.');
    }
    if (normalized.contains('..')) {
      throw SandboxFileException(
        'Memory path cannot escape the memory folder.',
      );
    }
    final file = File('${snapshot.memoryDir.path}/$normalized');
    final parent = file.parent;
    await parent.create(recursive: true);
    return file;
  }

  Future<void> _seedDefaults({
    required Directory sandboxDir,
    required Directory memoryDir,
    required Directory configDir,
  }) async {
    final starterMd = File('${sandboxDir.path}/welcome.md');
    if (!await starterMd.exists()) {
      await starterMd.writeAsString(
        '# Chatty-mini Sandbox\n\n'
        '- Keep lightweight notes here.\n'
        '- Sandbox v1 is limited to local text formats.\n',
      );
    }

    final starterJson = File('${sandboxDir.path}/task_state.json');
    if (!await starterJson.exists()) {
      await starterJson.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'status': 'draft',
          'current_task': 'Define Android-first local chat shell',
          'next_step': 'Wire storage and sandbox tray',
        }),
      );
    }

    final rollingSummary = File('${memoryDir.path}/rolling_summary.md');
    if (!await rollingSummary.exists()) {
      await rollingSummary.writeAsString(
        '- Chatty-mini is focused on compact local GGUF chat.\n'
        '- The app is tuned for small portrait Android devices.\n',
      );
    }

    final hotContext = File('${memoryDir.path}/hot_context.md');
    if (!await hotContext.exists()) {
      await hotContext.writeAsString(
        '## Current Aim\n\n'
        'Build a minimal portrait app for local GGUF chat.\n\n'
        '## Constraints\n\n'
        'Small phones first. Minimal chrome. Sandbox limited to text files.\n\n'
        '## Runtime\n\n'
        'Bundled native runtime with user-managed GGUF models.\n',
      );
    }

    final coldLog = File('${memoryDir.path}/cold_log.md');
    if (!await coldLog.exists()) {
      await coldLog.writeAsString(
        '# Cold Log\n\n'
        '- Persistent notes and long-tail recap can live here.\n'
        '- Users manage this file from the in-app Cold Log tray.\n',
      );
    }

    final settings = File('${configDir.path}/settings.json');
    if (!await settings.exists()) {
      await settings.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'runtime_install_mode': 'bundled',
          'main_ai_preset': 'balanced_mobile',
          'bookkeeper_preset': 'tiny_summary',
          'main_model_id': null,
          'bookkeeper_model_id': null,
          'session_logging_enabled': false,
          'session_log_retention_count': 25,
          'has_completed_onboarding': false,
          'active_character_profile_id': 'default_assistant',
          'character_profiles': [
            {
              'id': 'default_assistant',
              'name': 'Default Assistant',
              'prompt':
                  'Be concise, practical, and calm. Focus on helping with the current task on a small local-device chat app.',
            },
          ],
          'user_display_name': '',
          'default_sandbox_task_mode': 'target_file',
          'startup_character_profile_id': null,
          'auto_open_model_inventory_if_unassigned': true,
          'reopen_last_surface_on_launch': true,
          'last_surface_id': null,
          'last_sandbox_file_path': null,
          'last_memory_file_path': null,
          'last_character_profile_id': null,
        }),
      );
    }
  }
}

class SandboxFileException implements Exception {
  SandboxFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _supportedExtensions = {'md', 'txt', 'json'};

String _typeForExtension(String extension) {
  switch (extension) {
    case 'md':
      return 'markdown';
    case 'json':
      return 'json';
    default:
      return 'text';
  }
}

String _sanitizeFileName(String input, String fileType) {
  final base = input
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9_\-./ ]'), '')
      .replaceAll(' ', '_');
  if (base.isEmpty) {
    throw SandboxFileException('File name cannot be empty.');
  }
  if (base.contains('..')) {
    throw SandboxFileException('File name cannot contain `..`.');
  }
  final extension = switch (fileType) {
    'markdown' => '.md',
    'json' => '.json',
    _ => '.txt',
  };
  return base.endsWith(extension) ? base : '$base$extension';
}

String _starterContentForType(String fileType) {
  switch (fileType) {
    case 'markdown':
      return '# New Note\n\n';
    case 'json':
      return '{\n  \n}\n';
    default:
      return '';
  }
}

String _sanitizeModelFileName(String input) {
  final base = input
      .trim()
      .replaceAll(RegExp(r'[^a-zA-Z0-9_\-./ ]'), '')
      .replaceAll(' ', '_');
  if (base.isEmpty) {
    throw SandboxFileException('Model file name cannot be empty.');
  }
  if (base.contains('..')) {
    throw SandboxFileException('Model file name cannot contain `..`.');
  }
  final normalized = base.toLowerCase().endsWith('.gguf') ? base : '$base.gguf';
  return normalized;
}

Future<File> _resolveUniqueModelFile(
  Directory modelsDir,
  String fileName,
) async {
  final dotIndex = fileName.toLowerCase().lastIndexOf('.gguf');
  final stem = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  var candidate = File('${modelsDir.path}/$fileName');
  var suffix = 2;
  while (await candidate.exists()) {
    candidate = File('${modelsDir.path}/${stem}_$suffix.gguf');
    suffix += 1;
  }
  return candidate;
}

Future<File> _resolveUniqueSandboxFile(
  Directory sandboxDir,
  String fileName,
) async {
  final dotIndex = fileName.lastIndexOf('.');
  final stem = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  final extension = dotIndex > 0 ? fileName.substring(dotIndex) : '';
  var candidate = File('${sandboxDir.path}/$fileName');
  var suffix = 2;
  while (await candidate.exists()) {
    candidate = File('${sandboxDir.path}/${stem}_$suffix$extension');
    suffix += 1;
  }
  return candidate;
}
