class RuntimeStatus {
  const RuntimeStatus({
    required this.state,
    required this.installMode,
    required this.message,
    this.version,
    this.backend,
    this.deviceTotalRamBytes,
    this.deviceAvailableRamBytes,
    this.lowRamDevice = false,
    this.memoryTrimSuggested = false,
  });

  final String state;
  final String installMode;
  final String message;
  final String? version;
  final String? backend;
  final int? deviceTotalRamBytes;
  final int? deviceAvailableRamBytes;
  final bool lowRamDevice;
  final bool memoryTrimSuggested;

  bool get isReady => state == 'ready';
  bool get isBundled => installMode == 'bundled';

  factory RuntimeStatus.fromMap(Map<Object?, Object?> map) {
    return RuntimeStatus(
      state: (map['state'] as String?) ?? 'missing',
      installMode: (map['installMode'] as String?) ?? 'bundled',
      message: (map['message'] as String?) ?? 'Runtime status unavailable.',
      version: map['version'] as String?,
      backend: map['backend'] as String?,
      deviceTotalRamBytes: (map['deviceTotalRamBytes'] as num?)?.toInt(),
      deviceAvailableRamBytes: (map['deviceAvailableRamBytes'] as num?)
          ?.toInt(),
      lowRamDevice: (map['lowRamDevice'] as bool?) ?? false,
      memoryTrimSuggested: (map['memoryTrimSuggested'] as bool?) ?? false,
    );
  }

  static const initial = RuntimeStatus(
    state: 'missing',
    installMode: 'bundled',
    message: 'Runtime status unavailable.',
  );
}
