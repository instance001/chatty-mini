class SandboxFileEntry {
  const SandboxFileEntry({
    required this.relativePath,
    required this.fileType,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String relativePath;
  final String fileType;
  final int sizeBytes;
  final DateTime modifiedAt;
}
