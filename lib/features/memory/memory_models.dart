class MemoryFileEntry {
  const MemoryFileEntry({
    required this.relativePath,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String relativePath;
  final int sizeBytes;
  final DateTime modifiedAt;

  bool get isSessionLog => relativePath.startsWith('session_logs/');
  bool get isSideRailMemory =>
      relativePath == 'hot_context.md' || relativePath == 'rolling_summary.md';
}
