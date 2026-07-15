import 'package:flutter/foundation.dart';

import '../../core/storage/app_storage.dart';
import '../models/model_models.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({required this.storage});

  final AppStorageService storage;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _statusMessage;
  AppSettings _settings = AppSettings.defaults;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get statusMessage => _statusMessage;
  String get defaultSandboxTaskMode => _settings.defaultSandboxTaskMode;
  String? get startupCharacterProfileId => _settings.startupCharacterProfileId;
  bool get autoOpenModelInventoryIfUnassigned =>
      _settings.autoOpenModelInventoryIfUnassigned;
  bool get reopenLastSurfaceOnLaunch => _settings.reopenLastSurfaceOnLaunch;
  String? get lastSurfaceId => _settings.lastSurfaceId;
  String? get lastSandboxFilePath => _settings.lastSandboxFilePath;
  String? get lastMemoryFilePath => _settings.lastMemoryFilePath;
  String? get lastCharacterProfileId => _settings.lastCharacterProfileId;
  String get userDisplayName => _settings.userDisplayName;
  List<CharacterProfile> get characterProfiles => _settings.characterProfiles;

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();
    try {
      await storage.ensureInitialized();
      _settings = await storage.readSettings();
      _error = null;
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
      _error = null;
    } catch (error) {
      _error = error.toString();
    }
    notifyListeners();
  }

  Future<void> setDefaultSandboxTaskMode(String mode) async {
    _settings = _settings.copyWith(defaultSandboxTaskMode: mode);
    await _persist('Default sandbox mode updated.');
  }

  Future<void> setUserDisplayName(String name) async {
    _settings = _settings.copyWith(userDisplayName: name.trim());
    await _persist(
      name.trim().isEmpty
          ? 'User name cleared.'
          : 'Chatty will use that name.',
    );
  }

  Future<void> setStartupCharacterProfileId(String? profileId) async {
    _settings = _settings.copyWith(
      startupCharacterProfileId: profileId,
      clearStartupCharacterProfile: profileId == null,
    );
    await _persist(
      profileId == null
          ? 'Startup character cleared.'
          : 'Startup character updated.',
    );
  }

  Future<void> setAutoOpenModelInventoryIfUnassigned(bool enabled) async {
    _settings = _settings.copyWith(autoOpenModelInventoryIfUnassigned: enabled);
    await _persist(
      enabled
          ? 'Auto-open Model Inventory enabled.'
          : 'Auto-open Model Inventory disabled.',
    );
  }

  Future<void> setReopenLastSurfaceOnLaunch(bool enabled) async {
    _settings = _settings.copyWith(reopenLastSurfaceOnLaunch: enabled);
    await _persist(
      enabled
          ? 'Reopen last surface on launch enabled.'
          : 'Reopen last surface on launch disabled.',
    );
  }

  Future<void> setLastSurfaceId(String? surfaceId) async {
    _settings = _settings.copyWith(
      lastSurfaceId: surfaceId,
      clearLastSurface: surfaceId == null,
    );
    await _persist('Last surface updated.', silentStatus: true);
  }

  Future<void> setLastSandboxFilePath(String? relativePath) async {
    _settings = _settings.copyWith(
      lastSandboxFilePath: relativePath,
      clearLastSandboxFilePath: relativePath == null,
    );
    await _persist('Last sandbox file updated.', silentStatus: true);
  }

  Future<void> setLastMemoryFilePath(String? relativePath) async {
    _settings = _settings.copyWith(
      lastMemoryFilePath: relativePath,
      clearLastMemoryFilePath: relativePath == null,
    );
    await _persist('Last memory file updated.', silentStatus: true);
  }

  Future<void> setLastCharacterProfileId(String? profileId) async {
    _settings = _settings.copyWith(
      lastCharacterProfileId: profileId,
      clearLastCharacterProfileId: profileId == null,
    );
    await _persist('Last character profile updated.', silentStatus: true);
  }

  Future<void> _persist(
    String statusMessage, {
    bool silentStatus = false,
  }) async {
    _isSaving = true;
    if (!silentStatus) {
      _statusMessage = null;
    }
    _error = null;
    notifyListeners();
    try {
      await storage.writeSettings(_settings);
      if (!silentStatus) {
        _statusMessage = statusMessage;
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
