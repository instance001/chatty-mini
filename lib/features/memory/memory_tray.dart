import 'package:flutter/material.dart';

import 'memory_controller.dart';
import 'memory_models.dart';

const _retentionOptions = [10, 25, 50, 100];

Future<void> showMemoryTray({
  required BuildContext context,
  required MemoryController controller,
  String? restoreFilePath,
  ValueChanged<String>? onFileOpened,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MemoryTray(
      controller: controller,
      restoreFilePath: restoreFilePath,
      onFileOpened: onFileOpened,
    ),
  );
}

class MemoryTray extends StatefulWidget {
  const MemoryTray({
    super.key,
    required this.controller,
    this.restoreFilePath,
    this.onFileOpened,
  });

  final MemoryController controller;
  final String? restoreFilePath;
  final ValueChanged<String>? onFileOpened;

  @override
  State<MemoryTray> createState() => _MemoryTrayState();
}

class _MemoryTrayState extends State<MemoryTray> {
  bool _didAttemptRestore = false;

  @override
  Widget build(BuildContext context) {
    _scheduleRestoreIfNeeded();
    final theme = Theme.of(context);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final curatedFiles = widget.controller.curatedFiles;
            final sideRailFiles = widget.controller.sideRailFiles;
            final sessionLogFiles = widget.controller.sessionLogFiles;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Cold Log',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Persistent recap and long-term log files stored privately inside the app. Open, clear, or delete them here.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Session Logging',
                                      style: theme.textTheme.labelLarge,
                                    ),
                                  ),
                                  Switch(
                                    value:
                                        widget.controller.sessionLoggingEnabled,
                                    onChanged: widget.controller.isSaving
                                        ? null
                                        : widget
                                              .controller
                                              .setSessionLoggingEnabled,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.controller.sessionLoggingEnabled
                                    ? 'New chat sessions are stored locally in private app storage.'
                                    : 'Raw chat transcripts are not currently being archived.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text(
                                      '${widget.controller.sessionLogCount} session logs',
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      '${widget.controller.curatedFileCount} cold files',
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      '${sideRailFiles.length} side rail files',
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      _formatBytes(
                                        widget.controller.totalBytes,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      'Keep last ${widget.controller.sessionLogRetentionCount}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<int>(
                                initialValue:
                                    widget.controller.sessionLogRetentionCount,
                                decoration: const InputDecoration(
                                  labelText: 'Retention cap',
                                ),
                                items: _retentionOptions
                                    .map(
                                      (count) => DropdownMenuItem<int>(
                                        value: count,
                                        child: Text('Keep last $count logs'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: widget.controller.isSaving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          widget.controller
                                              .setSessionLogRetentionCount(
                                                value,
                                              );
                                        }
                                      },
                              ),
                              if (widget.controller.sessionLogCount > 0) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: widget.controller.isSaving
                                      ? null
                                      : widget.controller.clearSessionLogs,
                                  icon: const Icon(Icons.delete_sweep_outlined),
                                  label: const Text('Clear session logs'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              '${widget.controller.files.length} files',
                            ),
                          ),
                          Chip(
                            label: Text(
                              '${widget.controller.selectedPaths.length} selected',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: widget.controller.isLoading
                                ? null
                                : widget.controller.refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                          TextButton.icon(
                            onPressed:
                                widget.controller.selectedPaths.isEmpty ||
                                    widget.controller.isSaving
                                ? null
                                : widget.controller.deleteSelected,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (widget.controller.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: Text(
                      widget.controller.error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                if (widget.controller.statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: Text(
                      widget.controller.statusMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                Expanded(
                  child: widget.controller.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                          children: [
                            _MemorySection(
                              title: 'Side Rail Memory',
                              subtitle:
                                  'Hot Context and Rolling Summary files shown in the chat side bumps.',
                              files: sideRailFiles,
                              controller: widget.controller,
                              onFileOpened: widget.onFileOpened,
                            ),
                            const SizedBox(height: 14),
                            _MemorySection(
                              title: 'Cold Log',
                              subtitle:
                                  'Long-term notes and maintained memory files.',
                              files: curatedFiles,
                              controller: widget.controller,
                              onFileOpened: widget.onFileOpened,
                            ),
                            const SizedBox(height: 14),
                            _MemorySection(
                              title: 'Session Logs',
                              subtitle:
                                  'Raw transcript archives created when session logging is enabled.',
                              files: sessionLogFiles,
                              controller: widget.controller,
                              onFileOpened: widget.onFileOpened,
                              emptyLabel: 'No session logs stored yet.',
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _scheduleRestoreIfNeeded() {
    if (_didAttemptRestore) {
      return;
    }
    final restoreFilePath = widget.restoreFilePath;
    if (restoreFilePath == null || restoreFilePath.isEmpty) {
      _didAttemptRestore = true;
      return;
    }
    _didAttemptRestore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      MemoryFileEntry? file;
      for (final entry in widget.controller.files) {
        if (entry.relativePath == restoreFilePath) {
          file = entry;
          break;
        }
      }
      if (file != null) {
        _openFile(file);
      }
    });
  }

  Future<void> _openFile(MemoryFileEntry file) {
    widget.onFileOpened?.call(file.relativePath);
    return _showMemoryEditor(context, widget.controller, file);
  }
}

class _MemorySection extends StatelessWidget {
  const _MemorySection({
    required this.title,
    required this.subtitle,
    required this.files,
    required this.controller,
    required this.onFileOpened,
    this.emptyLabel = 'No files in this section.',
  });

  final String title;
  final String subtitle;
  final List<MemoryFileEntry> files;
  final MemoryController controller;
  final ValueChanged<String>? onFileOpened;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 10),
        if (files.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Text(emptyLabel, style: theme.textTheme.bodyMedium),
            ),
          )
        else
          ...files.map(
            (file) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MemoryFileCard(
                file: file,
                isSelected: controller.selectedPaths.contains(
                  file.relativePath,
                ),
                onSelectedChanged: (_) =>
                    controller.toggleSelected(file.relativePath),
                onOpen: () {
                  onFileOpened?.call(file.relativePath);
                  _showMemoryEditor(context, controller, file);
                },
                onClear: () => controller.clearFile(file.relativePath),
              ),
            ),
          ),
      ],
    );
  }
}

class _MemoryFileCard extends StatelessWidget {
  const _MemoryFileCard({
    required this.file,
    required this.isSelected,
    required this.onSelectedChanged,
    required this.onOpen,
    required this.onClear,
  });

  final MemoryFileEntry file;
  final bool isSelected;
  final ValueChanged<bool?> onSelectedChanged;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(value: isSelected, onChanged: onSelectedChanged),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.relativePath,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatBytes(file.sizeBytes)} | ${_formatDate(file.modifiedAt)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: onOpen,
                  child: const Text('Open'),
                ),
                FilledButton.tonal(
                  onPressed: onClear,
                  child: const Text('Clear contents'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showMemoryEditor(
  BuildContext context,
  MemoryController controller,
  MemoryFileEntry file,
) async {
  final initialContent = await controller.readFile(file.relativePath);
  if (!context.mounted) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _MemoryEditorSheet(
        controller: controller,
        file: file,
        initialContent: initialContent,
      );
    },
  );
}

class _MemoryEditorSheet extends StatefulWidget {
  const _MemoryEditorSheet({
    required this.controller,
    required this.file,
    required this.initialContent,
  });

  final MemoryController controller;
  final MemoryFileEntry file;
  final String initialContent;

  @override
  State<_MemoryEditorSheet> createState() => _MemoryEditorSheetState();
}

class _MemoryEditorSheetState extends State<_MemoryEditorSheet> {
  late final TextEditingController _editorController = TextEditingController(
    text: widget.initialContent,
  );

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.file.relativePath,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: widget.controller,
                    builder: (context, _) {
                      final navigator = Navigator.of(context);
                      return TextButton(
                        onPressed: widget.controller.isSaving
                            ? null
                            : () async {
                                await widget.controller.saveFile(
                                  widget.file.relativePath,
                                  _editorController.text,
                                );
                                if (!mounted ||
                                    widget.controller.error != null) {
                                  return;
                                }
                                navigator.pop();
                              },
                        child: const Text('Save'),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _editorController,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Edit persistent log contents...',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
