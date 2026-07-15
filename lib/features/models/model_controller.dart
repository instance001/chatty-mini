import 'package:flutter/foundation.dart';

import '../../core/storage/app_storage.dart';
import '../../core/storage/model_import_service.dart';
import '../../core/inference/cloud_inference_service.dart';
import '../../core/inference/cloud_key_service.dart';
import 'model_models.dart';

class ModelController extends ChangeNotifier {
  ModelController({
    required this.storage,
    ModelImportService? modelImportService,
    CloudKeyService? cloudKeyService,
    CloudInferenceService? cloudInferenceService,
  }) : modelImportService = modelImportService ?? ModelImportService(),
       cloudKeyServiceOverride = cloudKeyService,
       cloudInferenceServiceOverride = cloudInferenceService;

  final AppStorageService storage;
  final ModelImportService modelImportService;
  late final CloudKeyService cloudKeyService =
      cloudKeyServiceOverride ?? CloudKeyService();
  late final CloudInferenceService cloudInferenceService =
      cloudInferenceServiceOverride ??
      CloudInferenceService(keyService: cloudKeyService);
  final CloudKeyService? cloudKeyServiceOverride;
  final CloudInferenceService? cloudInferenceServiceOverride;

  bool _isLoading = false;
  String? _error;
  String? _statusMessage;
  AppSettings _settings = AppSettings.defaults;
  List<ModelRecord> _models = const [];
  final Set<String> _selectedModelIds = <String>{};

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get statusMessage => _statusMessage;
  AppSettings get settings => _settings;
  List<ModelRecord> get models => _models;
  List<CloudModelRecord> get cloudModels => _settings.cloudModels;
  Set<String> get selectedModelIds => Set.unmodifiable(_selectedModelIds);
  int get selectedCount => _selectedModelIds.length;
  int get totalModelBytes =>
      _models.fold(0, (sum, model) => sum + model.sizeBytes);

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await storage.ensureInitialized();
      _settings = await storage.readSettings();
      _models = await storage.scanModels();
      _settings = _reconcileSelections(_settings, _models);
      _reconcileSelectionState();
      await storage.writeSettings(_settings);
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshModels() async {
    _isLoading = true;
    _statusMessage = null;
    notifyListeners();
    try {
      _models = await storage.scanModels();
      _settings = _reconcileSelections(_settings, _models);
      _reconcileSelectionState();
      await storage.writeSettings(_settings);
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectMainModel(String? modelId) async {
    _settings = _settings.copyWith(
      mainModelId: modelId,
      clearMainModel: modelId == null,
      hasCompletedOnboarding: true,
    );
    await _persist();
  }

  Future<void> selectBookkeeperModel(String? modelId) async {
    _settings = _settings.copyWith(
      bookkeeperModelId: modelId,
      clearBookkeeperModel: modelId == null,
      hasCompletedOnboarding: true,
    );
    await _persist();
  }

  Future<void> selectMainPreset(String presetId) async {
    _settings = _settings.copyWith(
      mainAiPreset: presetId,
      hasCompletedOnboarding: true,
    );
    await _persist();
  }

  Future<void> selectBookkeeperPreset(String presetId) async {
    _settings = _settings.copyWith(
      bookkeeperPreset: presetId,
      hasCompletedOnboarding: true,
    );
    await _persist();
  }

  ModelRecord? findById(String? id) {
    if (id == null) {
      return null;
    }
    for (final model in _models) {
      if (model.id == id) {
        return model;
      }
    }
    return null;
  }

  CloudModelRecord? findCloudBySelectionId(String? selectionId) {
    if (selectionId == null || !selectionId.startsWith('cloud:')) return null;
    final id = selectionId.substring('cloud:'.length);
    for (final model in _settings.cloudModels) {
      if (model.id == id) return model;
    }
    return null;
  }

  Future<void> saveCloudModel({
    String? existingId,
    required String label,
    required String baseUrl,
    required String model,
    required String apiKey,
    required String provider,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final id = existingId ?? DateTime.now().microsecondsSinceEpoch.toString();
      if (apiKey.trim().isNotEmpty) {
        await cloudKeyService.save(id, apiKey.trim());
      }
      if (!await cloudKeyService.has(id)) {
        throw StateError('Enter an API key before saving this cloud model.');
      }
      final entry = CloudModelRecord(
        id: id,
        label: label.trim(),
        baseUrl: baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
        model: model.trim(),
        provider: provider,
      );
      final entries = [..._settings.cloudModels];
      final index = entries.indexWhere((item) => item.id == id);
      if (index == -1) {
        entries.add(entry);
      } else {
        entries[index] = entry;
      }
      _settings = _settings.copyWith(cloudModels: entries);
      await storage.writeSettings(_settings);
      _statusMessage =
          'Saved cloud model ${entry.label}. Verify it before use.';
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyCloudModel(String id) async {
    final entry = _settings.cloudModels
        .where((item) => item.id == id)
        .firstOrNull;
    if (entry == null) return;
    _isLoading = true;
    _error = null;
    _statusMessage = 'Verifying ${entry.label}…';
    notifyListeners();
    try {
      await cloudInferenceService.verify(entry);
      _settings = _settings.copyWith(
        cloudModels: _settings.cloudModels
            .map((item) => item.id == id ? item.copyWith(verified: true) : item)
            .toList(),
      );
      await storage.writeSettings(_settings);
      _statusMessage = '${entry.label} verified.';
    } catch (error) {
      _error = error is CloudRequestException
          ? error.friendlyMessage(entry.label)
          : error.toString();
      _statusMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteCloudModel(String id) async {
    await cloudKeyService.delete(id);
    final selectionId = 'cloud:$id';
    _settings = _settings.copyWith(
      cloudModels: _settings.cloudModels
          .where((item) => item.id != id)
          .toList(),
      clearMainModel: _settings.mainModelId == selectionId,
      clearBookkeeperModel: _settings.bookkeeperModelId == selectionId,
    );
    await _persist();
  }

  bool isSelected(String modelId) => _selectedModelIds.contains(modelId);

  void toggleModelSelection(String modelId, bool selected) {
    if (selected) {
      _selectedModelIds.add(modelId);
    } else {
      _selectedModelIds.remove(modelId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedModelIds.clear();
    notifyListeners();
  }

  Future<void> importModelFromPicker() async {
    _isLoading = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      final snapshot = await storage.ensureInitialized();
      final importedNames = await modelImportService.importModels(
        modelsDirPath: snapshot.modelsDir.path,
      );
      if (importedNames.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _models = await storage.scanModels();
      _settings = _reconcileSelections(_settings, _models);
      _reconcileSelectionState();
      await storage.writeSettings(_settings);
      _error = null;
      _statusMessage = importedNames.length == 1
          ? 'Imported ${importedNames.first} into private model storage.'
          : 'Imported ${importedNames.length} GGUF files into private model storage.';
    } catch (error) {
      _error = error.toString();
      _statusMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSelectedModels() async {
    if (_selectedModelIds.isEmpty) {
      return;
    }

    _isLoading = true;
    _statusMessage = null;
    notifyListeners();
    try {
      final deletedCount = _selectedModelIds.length;
      await storage.deleteModelFiles(_selectedModelIds);
      _selectedModelIds.clear();
      _models = await storage.scanModels();
      _settings = _reconcileSelections(_settings, _models);
      _reconcileSelectionState();
      await storage.writeSettings(_settings);
      _error = null;
      _statusMessage = deletedCount == 1
          ? 'Deleted 1 model from private storage.'
          : 'Deleted $deletedCount models from private storage.';
    } catch (error) {
      _error = error.toString();
      _statusMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteModel(String modelId) async {
    _selectedModelIds
      ..clear()
      ..add(modelId);
    await deleteSelectedModels();
  }

  Future<void> _persist() async {
    try {
      await storage.writeSettings(_settings);
      _error = null;
    } catch (error) {
      _error = error.toString();
    }
    notifyListeners();
  }

  AppSettings _reconcileSelections(
    AppSettings settings,
    List<ModelRecord> models,
  ) {
    final availableIds = {
      ...models.map((model) => model.id),
      ...settings.cloudModels.map((model) => model.selectionId),
    };
    final hasMain =
        settings.mainModelId != null &&
        availableIds.contains(settings.mainModelId);
    final hasBookkeeper =
        settings.bookkeeperModelId != null &&
        availableIds.contains(settings.bookkeeperModelId);
    final fallbackId = models.isNotEmpty
        ? models.first.id
        : (settings.cloudModels.isNotEmpty
              ? settings.cloudModels.first.selectionId
              : null);

    return settings.copyWith(
      mainModelId: hasMain ? settings.mainModelId : fallbackId,
      bookkeeperModelId: hasBookkeeper
          ? settings.bookkeeperModelId
          : (hasMain ? settings.mainModelId : fallbackId),
      clearMainModel: fallbackId == null && !hasMain,
      clearBookkeeperModel: fallbackId == null && !hasBookkeeper,
    );
  }

  void _reconcileSelectionState() {
    final availableIds = _models.map((model) => model.id).toSet();
    _selectedModelIds.removeWhere((id) => !availableIds.contains(id));
  }
}
