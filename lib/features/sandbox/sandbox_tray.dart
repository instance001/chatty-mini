import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sandbox_controller.dart';
import 'sandbox_models.dart';

const _sandboxExportChannel = MethodChannel('chatty_mini/sandbox_export');

Future<void> showSandboxTray({
  required BuildContext context,
  required SandboxController controller,
  String? restoreFilePath,
  ValueChanged<String>? onFileOpened,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SandboxTray(
      controller: controller,
      restoreFilePath: restoreFilePath,
      onFileOpened: onFileOpened,
    ),
  );
}

class SandboxTray extends StatefulWidget {
  const SandboxTray({
    super.key,
    required this.controller,
    this.restoreFilePath,
    this.onFileOpened,
  });

  final SandboxController controller;
  final String? restoreFilePath;
  final ValueChanged<String>? onFileOpened;

  @override
  State<SandboxTray> createState() => _SandboxTrayState();
}

class _SandboxTrayState extends State<SandboxTray> {
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
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sandbox Tray',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Scoped local text files for notes, JSON state, and scratch work.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.68,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Import file',
                        onPressed: widget.controller.isSaving
                            ? null
                            : _importFiles,
                        icon: const Icon(Icons.file_upload_outlined),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Create file',
                        onPressed: widget.controller.isSaving
                            ? null
                            : () => _showCreateFileDialog(
                                context,
                                widget.controller,
                                onOpened: widget.onFileOpened,
                              ),
                        icon: const Icon(Icons.note_add_outlined),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(
                              '${widget.controller.files.length} files',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(
                              '${widget.controller.selectedPaths.length} selected',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed: widget.controller.isLoading
                                ? null
                                : widget.controller.refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                          ),
                          const SizedBox(width: 6),
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
                const SizedBox(height: 8),
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
                Expanded(
                  child: widget.controller.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : widget.controller.files.isEmpty
                      ? _SandboxEmptyState(
                          onCreate: () {
                            _showCreateFileDialog(
                              context,
                              widget.controller,
                              onOpened: widget.onFileOpened,
                            );
                          },
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                          itemCount: widget.controller.files.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final file = widget.controller.files[index];
                            final selected = widget.controller.selectedPaths
                                .contains(file.relativePath);
                            return _SandboxFileCard(
                              file: file,
                              isSelected: selected,
                              onSelectedChanged: (_) => widget.controller
                                  .toggleSelected(file.relativePath),
                              onOpen: () => _openFile(file),
                              onExport: () => _exportFile(file),
                            );
                          },
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
      SandboxFileEntry? file;
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

  Future<void> _openFile(SandboxFileEntry file) {
    widget.onFileOpened?.call(file.relativePath);
    return _showEditorSheet(context, widget.controller, file);
  }

  Future<void> _exportFile(SandboxFileEntry file) async {
    try {
      final content = await widget.controller.readFile(file.relativePath);
      final exported = await _sandboxExportChannel
          .invokeMethod<bool>('exportFile', <String, Object>{
            'fileName': file.relativePath.split('/').last,
            'bytes': Uint8List.fromList(utf8.encode(content)),
          });
      if (!mounted || exported != true) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${file.relativePath} exported')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export file: $error')));
    }
  }

  Future<void> _importFiles() async {
    try {
      final picked = await _sandboxExportChannel.invokeListMethod<Object?>(
        'importFiles',
      );
      if (picked == null || picked.isEmpty) {
        return;
      }
      final imported = await widget.controller.importFiles(
        picked.whereType<Map>().map((entry) => Map<Object?, Object?>.from(entry)),
      );
      if (!mounted) {
        return;
      }
      final message = imported.isEmpty
          ? 'No supported sandbox files selected'
          : 'Imported ${imported.length} sandbox file${imported.length == 1 ? '' : 's'}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not import file: $error')));
    }
  }
}

class _SandboxFileCard extends StatelessWidget {
  const _SandboxFileCard({
    required this.file,
    required this.isSelected,
    required this.onSelectedChanged,
    required this.onOpen,
    required this.onExport,
  });

  final SandboxFileEntry file;
  final bool isSelected;
  final ValueChanged<bool?> onSelectedChanged;
  final VoidCallback onOpen;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Checkbox(value: isSelected, onChanged: onSelectedChanged),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.relativePath, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      [
                        file.fileType,
                        _formatBytes(file.sizeBytes),
                        _formatDate(file.modifiedAt),
                      ].join(' | '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Export ${file.relativePath}',
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
              ),
              TextButton(onPressed: onOpen, child: const Text('Open')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SandboxEmptyState extends StatelessWidget {
  const _SandboxEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 42,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text('Sandbox is empty', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Create a markdown, text, or JSON file to start using the local sandbox tray.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onCreate,
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Create file'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showEditorSheet(
  BuildContext context,
  SandboxController controller,
  SandboxFileEntry file,
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
    builder: (_) => _SandboxEditorSheet(
      controller: controller,
      file: file,
      initialContent: initialContent,
    ),
  );
}

class _SandboxEditorSheet extends StatefulWidget {
  const _SandboxEditorSheet({
    required this.controller,
    required this.file,
    required this.initialContent,
  });

  final SandboxController controller;
  final SandboxFileEntry file;
  final String initialContent;

  @override
  State<_SandboxEditorSheet> createState() => _SandboxEditorSheetState();
}

class _SandboxEditorSheetState extends State<_SandboxEditorSheet> {
  late final TextEditingController _editorController;

  @override
  void initState() {
    super.initState();
    _editorController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await widget.controller.saveFile(
                        widget.file.relativePath,
                        _editorController.text,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Save'),
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
                    hintText: 'Edit sandbox file...',
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

Future<void> _showCreateFileDialog(
  BuildContext context,
  SandboxController controller, {
  ValueChanged<String>? onOpened,
}) async {
  final created = await showDialog<SandboxFileEntry>(
    context: context,
    builder: (_) => _CreateSandboxFileDialog(controller: controller),
  );

  if (created != null && context.mounted) {
    onOpened?.call(created.relativePath);
    await _showEditorSheet(context, controller, created);
  }
}

class _CreateSandboxFileDialog extends StatefulWidget {
  const _CreateSandboxFileDialog({required this.controller});

  final SandboxController controller;

  @override
  State<_CreateSandboxFileDialog> createState() =>
      _CreateSandboxFileDialogState();
}

class _CreateSandboxFileDialogState extends State<_CreateSandboxFileDialog> {
  final TextEditingController _fileNameController = TextEditingController();
  String _selectedType = 'markdown';

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create sandbox file'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _fileNameController,
            decoration: const InputDecoration(
              labelText: 'File name',
              hintText: 'meeting_notes',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            items: const [
              DropdownMenuItem(
                value: 'markdown',
                child: Text('Markdown (.md)'),
              ),
              DropdownMenuItem(value: 'text', child: Text('Text (.txt)')),
              DropdownMenuItem(value: 'json', child: Text('JSON (.json)')),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _selectedType = value);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final created = await widget.controller.createFile(
              fileName: _fileNameController.text,
              fileType: _selectedType,
            );
            if (created != null && context.mounted) {
              Navigator.of(context).pop(created);
            }
          },
          child: const Text('Create'),
        ),
      ],
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
