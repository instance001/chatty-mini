import 'package:flutter/foundation.dart';

import '../../core/storage/app_storage.dart';
import '../models/model_models.dart';
import 'memory_models.dart';

class MemoryController extends ChangeNotifier {
  MemoryController({required this.storage});

  final AppStorageService storage;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _statusMessage;
  List<MemoryFileEntry> _files = const [];
  final Set<String> _selectedPaths = <String>{};
  AppSettings _settings = AppSettings.defaults;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get statusMessage => _statusMessage;
  List<MemoryFileEntry> get files => _files;
  List<MemoryFileEntry> get curatedFiles => _files
      .where((file) => !file.isSessionLog && !file.isSideRailMemory)
      .toList();
  List<MemoryFileEntry> get sideRailFiles =>
      _files.where((file) => file.isSideRailMemory).toList();
  List<MemoryFileEntry> get sessionLogFiles =>
      _files.where((file) => file.isSessionLog).toList();
  Set<String> get selectedPaths => Set.unmodifiable(_selectedPaths);
  bool get sessionLoggingEnabled => _settings.sessionLoggingEnabled;
  int get sessionLogRetentionCount => _settings.sessionLogRetentionCount;
  int get totalBytes => _files.fold(0, (sum, file) => sum + file.sizeBytes);
  int get sessionLogCount => _files.where((file) => file.isSessionLog).length;
  int get curatedFileCount => curatedFiles.length;

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await storage.ensureInitialized();
      _settings = await storage.readSettings();
      await refresh();
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      _settings = await storage.readSettings();
      _files = await storage.listMemoryFiles();
      _selectedPaths.removeWhere(
        (selected) => !_files.any((file) => file.relativePath == selected),
      );
      _error = null;
    } catch (error) {
      _error = error.toString();
    }
    notifyListeners();
  }

  Future<void> setSessionLoggingEnabled(bool enabled) async {
    _isSaving = true;
    _statusMessage = null;
    notifyListeners();
    try {
      _settings = _settings.copyWith(sessionLoggingEnabled: enabled);
      await storage.writeSettings(_settings);
      _error = null;
      _statusMessage = enabled
          ? 'Session logging enabled. New chats will be archived locally.'
          : 'Session logging disabled.';
    } catch (error) {
      _error = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> setSessionLogRetentionCount(int count) async {
    _isSaving = true;
    _statusMessage = null;
    notifyListeners();
    try {
      _settings = _settings.copyWith(sessionLogRetentionCount: count);
      await storage.writeSettings(_settings);
      await storage.enforceSessionLogRetention(count);
      await refresh();
      _error = null;
      _statusMessage = 'Session log retention set to last $count logs.';
    } catch (error) {
      _error = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void toggleSelected(String relativePath) {
    if (_selectedPaths.contains(relativePath)) {
      _selectedPaths.remove(relativePath);
    } else {
      _selectedPaths.add(relativePath);
    }
    notifyListeners();
  }

  Future<String> readFile(String relativePath) {
    return storage.readMemoryFile(relativePath);
  }

  Future<void> saveFile(String relativePath, String contents) async {
    _isSaving = true;
    _statusMessage = null;
    notifyListeners();
    try {
      await storage.writeMemoryFile(relativePath, contents);
      await refresh();
      _statusMessage = 'Saved $relativePath.';
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> clearFile(String relativePath) async {
    _isSaving = true;
    _statusMessage = null;
    notifyListeners();
    try {
      await storage.writeMemoryFile(relativePath, '');
      await refresh();
      _error = null;
      _statusMessage = 'Cleared $relativePath.';
    } catch (error) {
      _error = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> deleteSelected() async {
    if (_selectedPaths.isEmpty) {
      return;
    }

    _isSaving = true;
    _statusMessage = null;
    notifyListeners();
    try {
      final deletedCount = _selectedPaths.length;
      await storage.deleteMemoryFiles(_selectedPaths);
      _selectedPaths.clear();
      await refresh();
      _error = null;
      _statusMessage = deletedCount == 1
          ? 'Deleted 1 Cold Log file.'
          : 'Deleted $deletedCount Cold Log files.';
    } catch (error) {
      _error = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> clearSessionLogs() async {
    _isSaving = true;
    _statusMessage = null;
    notifyListeners();
    try {
      final deletedCount = sessionLogCount;
      await storage.clearSessionLogFiles();
      _selectedPaths.removeWhere((path) => path.startsWith('session_logs/'));
      await refresh();
      _error = null;
      _statusMessage = deletedCount == 1
          ? 'Deleted 1 session log.'
          : 'Deleted $deletedCount session logs.';
    } catch (error) {
      _error = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
