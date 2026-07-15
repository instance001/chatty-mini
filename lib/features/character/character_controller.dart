import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/storage/app_storage.dart';
import '../sandbox/sandbox_models.dart';
import '../models/model_models.dart';

class CharacterController extends ChangeNotifier {
  CharacterController({required this.storage});

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
  List<CharacterProfile> get profiles => _settings.characterProfiles;
  String get activeProfileId => _settings.activeCharacterProfileId;
  CharacterProfile get activeProfile =>
      findById(activeProfileId) ?? profiles.first;
  List<SandboxFileEntry> get importableSandboxFiles => _importableSandboxFiles;

  List<SandboxFileEntry> _importableSandboxFiles = const [];

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    _statusMessage = null;
    notifyListeners();

    try {
      await storage.ensureInitialized();
      _settings = await storage.readSettings();
      _reconcileProfiles();
      _importableSandboxFiles = await _loadImportableSandboxFiles();
      await storage.writeSettings(_settings);
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
      _reconcileProfiles();
      _importableSandboxFiles = await _loadImportableSandboxFiles();
      _error = null;
    } catch (error) {
      _error = error.toString();
    }
    notifyListeners();
  }

  CharacterProfile? findById(String id) {
    for (final profile in profiles) {
      if (profile.id == id) {
        return profile;
      }
    }
    return null;
  }

  Future<void> selectProfile(String id) async {
    if (id == activeProfileId || findById(id) == null) {
      return;
    }
    _settings = _settings.copyWith(activeCharacterProfileId: id);
    await _persist('Selected ${findById(id)!.name}.');
  }

  Future<void> saveProfile({
    String? existingProfileId,
    required String name,
    required String prompt,
    bool makeActive = true,
  }) async {
    final trimmedName = name.trim();
    final trimmedPrompt = prompt.trim();
    if (trimmedName.isEmpty) {
      _error = 'Profile name cannot be empty.';
      notifyListeners();
      return;
    }
    if (trimmedPrompt.isEmpty) {
      _error = 'Character prompt cannot be empty.';
      notifyListeners();
      return;
    }

    final normalizedName = _dedupeName(trimmedName, existingProfileId);
    final existing = existingProfileId == null
        ? null
        : findById(existingProfileId);
    final profile = CharacterProfile(
      id: existing?.id ?? _slugify(trimmedName),
      name: normalizedName,
      prompt: trimmedPrompt,
    );

    final nextProfiles = [...profiles];
    final index = existing == null
        ? -1
        : nextProfiles.indexWhere((item) => item.id == existing.id);
    if (index >= 0) {
      nextProfiles[index] = profile;
    } else {
      nextProfiles.add(profile);
    }

    _settings = _settings.copyWith(
      characterProfiles: nextProfiles,
      activeCharacterProfileId: makeActive ? profile.id : activeProfileId,
    );
    await _persist(
      existing == null ? 'Saved $normalizedName.' : 'Updated $normalizedName.',
    );
  }

  Future<void> deleteProfile(String id) async {
    if (profiles.length == 1) {
      _error = 'Keep at least one character profile available.';
      notifyListeners();
      return;
    }
    final target = findById(id);
    if (target == null) {
      return;
    }

    final nextProfiles = profiles.where((profile) => profile.id != id).toList();
    final nextActiveId = activeProfileId == id
        ? nextProfiles.first.id
        : activeProfileId;
    _settings = _settings.copyWith(
      characterProfiles: nextProfiles,
      activeCharacterProfileId: nextActiveId,
    );
    await _persist('Deleted ${target.name}.');
  }

  Future<void> duplicateProfile(String id) async {
    final target = findById(id);
    if (target == null) {
      return;
    }
    final duplicateName = _dedupeName('${target.name} Copy', null);
    final duplicate = CharacterProfile(
      id: _slugify(duplicateName),
      name: duplicateName,
      prompt: target.prompt,
    );
    _settings = _settings.copyWith(
      characterProfiles: [...profiles, duplicate],
      activeCharacterProfileId: duplicate.id,
    );
    await _persist('Duplicated ${target.name}.');
  }

  Future<void> exportProfilesToSandbox({String? profileId}) async {
    _isSaving = true;
    _statusMessage = null;
    _error = null;
    notifyListeners();
    try {
      final selectedProfiles = profileId == null
          ? profiles
          : [if (findById(profileId) != null) findById(profileId)!];
      if (selectedProfiles.isEmpty) {
        _error = 'No character profiles available to export.';
      } else {
        final stamp = _timestampSlug();
        final suffix = profileId == null ? 'all' : 'single';
        final relativePath = 'exports/character_profiles_${suffix}_$stamp.json';
        final payload = {
          'format': 'chatty_mini_character_profiles_v1',
          'exported_at': DateTime.now().toIso8601String(),
          'active_character_profile_id': activeProfileId,
          'profiles': selectedProfiles
              .map((profile) => profile.toJson())
              .toList(),
        };
        await storage.writeSandboxFile(
          relativePath,
          const JsonEncoder.withIndent('  ').convert(payload),
        );
        _importableSandboxFiles = await _loadImportableSandboxFiles();
        _statusMessage = profileId == null
            ? 'Exported ${selectedProfiles.length} profiles to sandbox/$relativePath.'
            : 'Exported ${selectedProfiles.first.name} to sandbox/$relativePath.';
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> importProfilesFromSandbox(
    String relativePath, {
    bool replaceExisting = false,
  }) async {
    _isSaving = true;
    _statusMessage = null;
    _error = null;
    notifyListeners();
    try {
      final raw = await storage.readSandboxFile(relativePath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException(
          'Profile import file must be a JSON object.',
        );
      }
      final map = Map<String, dynamic>.from(decoded);
      final imported = _profilesFromImportPayload(map);
      if (imported.isEmpty) {
        throw const FormatException(
          'No character profiles found in import file.',
        );
      }

      final nextProfiles = replaceExisting
          ? <CharacterProfile>[]
          : [...profiles];
      for (final profile in imported) {
        final uniqueName = _dedupeName(profile.name, null);
        final uniqueId = _slugify(uniqueName);
        nextProfiles.add(
          CharacterProfile(
            id: uniqueId,
            name: uniqueName,
            prompt: profile.prompt,
          ),
        );
      }

      _settings = _settings.copyWith(
        characterProfiles: nextProfiles,
        activeCharacterProfileId: nextProfiles.first.id,
      );
      await _persist(
        replaceExisting
            ? 'Imported ${imported.length} profiles and replaced existing set.'
            : 'Imported ${imported.length} profiles from $relativePath.',
      );
    } catch (error) {
      _error = error.toString();
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearStatus() {
    if (_statusMessage == null && _error == null) {
      return;
    }
    _statusMessage = null;
    _error = null;
    notifyListeners();
  }

  Future<void> _persist(String statusMessage) async {
    _isSaving = true;
    _statusMessage = null;
    _error = null;
    notifyListeners();
    try {
      _reconcileProfiles();
      await storage.writeSettings(_settings);
      _importableSandboxFiles = await _loadImportableSandboxFiles();
      _statusMessage = statusMessage;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _reconcileProfiles() {
    final profiles = _settings.characterProfiles.isEmpty
        ? [CharacterProfile.defaultAssistant]
        : _settings.characterProfiles;
    final hasActive = profiles.any(
      (profile) => profile.id == _settings.activeCharacterProfileId,
    );
    _settings = _settings.copyWith(
      characterProfiles: profiles,
      activeCharacterProfileId: hasActive
          ? _settings.activeCharacterProfileId
          : profiles.first.id,
    );
  }

  String _dedupeName(String baseName, String? currentProfileId) {
    final lowerNames = profiles
        .where((profile) => profile.id != currentProfileId)
        .map((profile) => profile.name.toLowerCase())
        .toSet();
    if (!lowerNames.contains(baseName.toLowerCase())) {
      return baseName;
    }
    var suffix = 2;
    var candidate = '$baseName $suffix';
    while (lowerNames.contains(candidate.toLowerCase())) {
      suffix += 1;
      candidate = '$baseName $suffix';
    }
    return candidate;
  }

  String _slugify(String input) {
    final base = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (base.isEmpty) {
      return 'character_${DateTime.now().millisecondsSinceEpoch}';
    }
    var candidate = base;
    var suffix = 2;
    final ids = profiles.map((profile) => profile.id).toSet();
    while (ids.contains(candidate)) {
      candidate = '${base}_$suffix';
      suffix += 1;
    }
    return candidate;
  }

  Future<List<SandboxFileEntry>> _loadImportableSandboxFiles() async {
    final files = await storage.listSandboxFiles();
    return files
        .where((file) => file.relativePath.toLowerCase().endsWith('.json'))
        .toList();
  }

  List<CharacterProfile> _profilesFromImportPayload(Map<String, dynamic> json) {
    final rawProfiles = json['profiles'];
    if (rawProfiles is! List) {
      return const [];
    }
    return rawProfiles
        .whereType<Map>()
        .map(
          (item) => CharacterProfile.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  String _timestampSlug() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }
}
