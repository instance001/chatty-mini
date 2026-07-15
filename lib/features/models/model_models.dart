class ModelRecord {
  const ModelRecord({
    required this.id,
    required this.fileName,
    required this.fullPath,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String id;
  final String fileName;
  final String fullPath;
  final int sizeBytes;
  final DateTime modifiedAt;

  bool get isLargeForSmallPhones => sizeBytes >= 1200 * 1024 * 1024;
  bool get isTooLargeForSmallPhones => sizeBytes >= 2200 * 1024 * 1024;
}

class CloudModelRecord {
  const CloudModelRecord({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.model,
    this.provider = 'openai_compatible',
    this.verified = false,
  });

  final String id;
  final String label;
  final String baseUrl;
  final String model;
  final String provider;
  final bool verified;

  String get selectionId => 'cloud:$id';

  CloudModelRecord copyWith({
    String? label,
    String? baseUrl,
    String? model,
    String? provider,
    bool? verified,
  }) => CloudModelRecord(
    id: id,
    label: label ?? this.label,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    provider: provider ?? this.provider,
    verified: verified ?? this.verified,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'base_url': baseUrl,
    'model': model,
    'provider': provider,
    'verified': verified,
  };

  static CloudModelRecord fromJson(Map<String, dynamic> json) =>
      CloudModelRecord(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? 'Cloud model',
        baseUrl: json['base_url'] as String? ?? 'https://api.openai.com/v1',
        model: json['model'] as String? ?? '',
        provider: json['provider'] as String? ?? 'openai_compatible',
        verified: json['verified'] as bool? ?? false,
      );
}

class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.name,
    required this.prompt,
  });

  final String id;
  final String name;
  final String prompt;

  CharacterProfile copyWith({String? id, String? name, String? prompt}) {
    return CharacterProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      prompt: prompt ?? this.prompt,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'prompt': prompt};
  }

  static CharacterProfile fromJson(Map<String, dynamic> json) {
    return CharacterProfile(
      id: (json['id'] as String?) ?? 'default_assistant',
      name: (json['name'] as String?) ?? 'Default Assistant',
      prompt:
          (json['prompt'] as String?) ??
          'Be concise, practical, and calm. Focus on helping with the current task on a small local-device chat app.',
    );
  }

  static const defaultAssistant = CharacterProfile(
    id: 'default_assistant',
    name: 'Default Assistant',
    prompt:
        'Be concise, practical, and calm. Focus on helping with the current task on a small local-device chat app.',
  );
}

class AppSettings {
  const AppSettings({
    required this.runtimeInstallMode,
    required this.mainAiPreset,
    required this.bookkeeperPreset,
    required this.mainModelId,
    required this.bookkeeperModelId,
    required this.cloudModels,
    required this.sessionLoggingEnabled,
    required this.sessionLogRetentionCount,
    required this.hasCompletedOnboarding,
    required this.activeCharacterProfileId,
    required this.characterProfiles,
    required this.defaultSandboxTaskMode,
    required this.startupCharacterProfileId,
    required this.autoOpenModelInventoryIfUnassigned,
    required this.reopenLastSurfaceOnLaunch,
    required this.lastSurfaceId,
    required this.lastSandboxFilePath,
    required this.lastMemoryFilePath,
    required this.lastCharacterProfileId,
  });

  final String runtimeInstallMode;
  final String mainAiPreset;
  final String bookkeeperPreset;
  final String? mainModelId;
  final String? bookkeeperModelId;
  final List<CloudModelRecord> cloudModels;
  final bool sessionLoggingEnabled;
  final int sessionLogRetentionCount;
  final bool hasCompletedOnboarding;
  final String activeCharacterProfileId;
  final List<CharacterProfile> characterProfiles;
  final String defaultSandboxTaskMode;
  final String? startupCharacterProfileId;
  final bool autoOpenModelInventoryIfUnassigned;
  final bool reopenLastSurfaceOnLaunch;
  final String? lastSurfaceId;
  final String? lastSandboxFilePath;
  final String? lastMemoryFilePath;
  final String? lastCharacterProfileId;

  bool get usesBundledRuntime => runtimeInstallMode == 'bundled';

  AppSettings copyWith({
    String? runtimeInstallMode,
    String? mainAiPreset,
    String? bookkeeperPreset,
    String? mainModelId,
    String? bookkeeperModelId,
    List<CloudModelRecord>? cloudModels,
    bool? sessionLoggingEnabled,
    int? sessionLogRetentionCount,
    bool clearMainModel = false,
    bool clearBookkeeperModel = false,
    bool? hasCompletedOnboarding,
    String? activeCharacterProfileId,
    List<CharacterProfile>? characterProfiles,
    String? defaultSandboxTaskMode,
    String? startupCharacterProfileId,
    bool clearStartupCharacterProfile = false,
    bool? autoOpenModelInventoryIfUnassigned,
    bool? reopenLastSurfaceOnLaunch,
    String? lastSurfaceId,
    bool clearLastSurface = false,
    String? lastSandboxFilePath,
    bool clearLastSandboxFilePath = false,
    String? lastMemoryFilePath,
    bool clearLastMemoryFilePath = false,
    String? lastCharacterProfileId,
    bool clearLastCharacterProfileId = false,
  }) {
    return AppSettings(
      runtimeInstallMode: runtimeInstallMode ?? this.runtimeInstallMode,
      mainAiPreset: mainAiPreset ?? this.mainAiPreset,
      bookkeeperPreset: bookkeeperPreset ?? this.bookkeeperPreset,
      mainModelId: clearMainModel ? null : (mainModelId ?? this.mainModelId),
      bookkeeperModelId: clearBookkeeperModel
          ? null
          : (bookkeeperModelId ?? this.bookkeeperModelId),
      cloudModels: cloudModels ?? this.cloudModels,
      sessionLoggingEnabled:
          sessionLoggingEnabled ?? this.sessionLoggingEnabled,
      sessionLogRetentionCount:
          sessionLogRetentionCount ?? this.sessionLogRetentionCount,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      activeCharacterProfileId:
          activeCharacterProfileId ?? this.activeCharacterProfileId,
      characterProfiles: characterProfiles ?? this.characterProfiles,
      defaultSandboxTaskMode:
          defaultSandboxTaskMode ?? this.defaultSandboxTaskMode,
      startupCharacterProfileId: clearStartupCharacterProfile
          ? null
          : (startupCharacterProfileId ?? this.startupCharacterProfileId),
      autoOpenModelInventoryIfUnassigned:
          autoOpenModelInventoryIfUnassigned ??
          this.autoOpenModelInventoryIfUnassigned,
      reopenLastSurfaceOnLaunch:
          reopenLastSurfaceOnLaunch ?? this.reopenLastSurfaceOnLaunch,
      lastSurfaceId: clearLastSurface
          ? null
          : (lastSurfaceId ?? this.lastSurfaceId),
      lastSandboxFilePath: clearLastSandboxFilePath
          ? null
          : (lastSandboxFilePath ?? this.lastSandboxFilePath),
      lastMemoryFilePath: clearLastMemoryFilePath
          ? null
          : (lastMemoryFilePath ?? this.lastMemoryFilePath),
      lastCharacterProfileId: clearLastCharacterProfileId
          ? null
          : (lastCharacterProfileId ?? this.lastCharacterProfileId),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'runtime_install_mode': runtimeInstallMode,
      'main_ai_preset': mainAiPreset,
      'bookkeeper_preset': bookkeeperPreset,
      'main_model_id': mainModelId,
      'bookkeeper_model_id': bookkeeperModelId,
      'cloud_models': cloudModels.map((entry) => entry.toJson()).toList(),
      'session_logging_enabled': sessionLoggingEnabled,
      'session_log_retention_count': sessionLogRetentionCount,
      'has_completed_onboarding': hasCompletedOnboarding,
      'active_character_profile_id': activeCharacterProfileId,
      'character_profiles': characterProfiles
          .map((profile) => profile.toJson())
          .toList(),
      'default_sandbox_task_mode': defaultSandboxTaskMode,
      'startup_character_profile_id': startupCharacterProfileId,
      'auto_open_model_inventory_if_unassigned':
          autoOpenModelInventoryIfUnassigned,
      'reopen_last_surface_on_launch': reopenLastSurfaceOnLaunch,
      'last_surface_id': lastSurfaceId,
      'last_sandbox_file_path': lastSandboxFilePath,
      'last_memory_file_path': lastMemoryFilePath,
      'last_character_profile_id': lastCharacterProfileId,
    };
  }

  static AppSettings fromJson(Map<String, dynamic> json) {
    final rawProfiles = json['character_profiles'];
    final parsedProfiles = rawProfiles is List
        ? rawProfiles
              .whereType<Map>()
              .map(
                (item) =>
                    CharacterProfile.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <CharacterProfile>[CharacterProfile.defaultAssistant];
    final profiles = parsedProfiles.isEmpty
        ? <CharacterProfile>[CharacterProfile.defaultAssistant]
        : parsedProfiles;
    final activeId =
        (json['active_character_profile_id'] as String?) ?? profiles.first.id;
    final rawCloudModels = json['cloud_models'];
    final cloudModels = rawCloudModels is List
        ? rawCloudModels
              .whereType<Map>()
              .map(
                (item) =>
                    CloudModelRecord.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id.isNotEmpty && item.model.isNotEmpty)
              .toList()
        : <CloudModelRecord>[];
    return AppSettings(
      runtimeInstallMode:
          (json['runtime_install_mode'] as String?) ?? 'bundled',
      mainAiPreset: (json['main_ai_preset'] as String?) ?? 'balanced_mobile',
      bookkeeperPreset:
          (json['bookkeeper_preset'] as String?) ?? 'tiny_summary',
      mainModelId: json['main_model_id'] as String?,
      bookkeeperModelId: json['bookkeeper_model_id'] as String?,
      cloudModels: cloudModels,
      sessionLoggingEnabled:
          (json['session_logging_enabled'] as bool?) ?? false,
      sessionLogRetentionCount:
          (json['session_log_retention_count'] as int?) ?? 25,
      hasCompletedOnboarding:
          (json['has_completed_onboarding'] as bool?) ?? false,
      activeCharacterProfileId:
          profiles.any((profile) => profile.id == activeId)
          ? activeId
          : profiles.first.id,
      characterProfiles: profiles,
      defaultSandboxTaskMode:
          (json['default_sandbox_task_mode'] as String?) ?? 'target_file',
      startupCharacterProfileId:
          json['startup_character_profile_id'] as String?,
      autoOpenModelInventoryIfUnassigned:
          (json['auto_open_model_inventory_if_unassigned'] as bool?) ?? true,
      reopenLastSurfaceOnLaunch:
          (json['reopen_last_surface_on_launch'] as bool?) ?? true,
      lastSurfaceId: json['last_surface_id'] as String?,
      lastSandboxFilePath: json['last_sandbox_file_path'] as String?,
      lastMemoryFilePath: json['last_memory_file_path'] as String?,
      lastCharacterProfileId: json['last_character_profile_id'] as String?,
    );
  }

  static const defaults = AppSettings(
    runtimeInstallMode: 'bundled',
    mainAiPreset: 'balanced_mobile',
    bookkeeperPreset: 'tiny_summary',
    mainModelId: null,
    bookkeeperModelId: null,
    cloudModels: [],
    sessionLoggingEnabled: false,
    sessionLogRetentionCount: 25,
    hasCompletedOnboarding: false,
    activeCharacterProfileId: 'default_assistant',
    characterProfiles: [CharacterProfile.defaultAssistant],
    defaultSandboxTaskMode: 'target_file',
    startupCharacterProfileId: null,
    autoOpenModelInventoryIfUnassigned: true,
    reopenLastSurfaceOnLaunch: true,
    lastSurfaceId: null,
    lastSandboxFilePath: null,
    lastMemoryFilePath: null,
    lastCharacterProfileId: null,
  );
}
