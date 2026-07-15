import 'package:flutter/foundation.dart';

import '../../core/storage/app_storage.dart';
import 'sandbox_models.dart';

class SandboxController extends ChangeNotifier {
  SandboxController({required this.storage});

  final AppStorageService storage;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  List<SandboxFileEntry> _files = const [];
  final Set<String> _selectedPaths = <String>{};

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<SandboxFileEntry> get files => _files;
  Set<String> get selectedPaths => _selectedPaths;

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await storage.ensureInitialized();
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
      _files = await storage.listSandboxFiles();
      _selectedPaths.removeWhere(
        (selected) => !_files.any((file) => file.relativePath == selected),
      );
      _error = null;
    } catch (error) {
      _error = error.toString();
    }
    notifyListeners();
  }

  void toggleSelected(String relativePath) {
    if (_selectedPaths.contains(relativePath)) {
      _selectedPaths.remove(relativePath);
    } else {
      _selectedPaths.add(relativePath);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedPaths.isEmpty) {
      return;
    }
    _selectedPaths.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (_selectedPaths.isEmpty) {
      return;
    }
    _isSaving = true;
    notifyListeners();

    try {
      await storage.deleteSandboxFiles(_selectedPaths);
      _selectedPaths.clear();
      await refresh();
    } catch (error) {
      _error = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<String> readFile(String relativePath) {
    return storage.readSandboxFile(relativePath);
  }

  Future<void> saveFile(String relativePath, String contents) async {
    _isSaving = true;
    notifyListeners();
    try {
      await storage.writeSandboxFile(relativePath, contents);
      await refresh();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<SandboxFileEntry?> createFile({
    required String fileName,
    required String fileType,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final entry = await storage.createSandboxFile(
        fileName: fileName,
        fileType: fileType,
      );
      await refresh();
      return entry;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
