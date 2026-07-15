import 'package:flutter/material.dart';

import '../models/model_models.dart';
import 'character_controller.dart';

Future<void> showCharacterTray({
  required BuildContext context,
  required CharacterController controller,
  String? restoreProfileId,
  ValueChanged<String?>? onProfileEditorOpened,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CharacterTray(
      controller: controller,
      restoreProfileId: restoreProfileId,
      onProfileEditorOpened: onProfileEditorOpened,
    ),
  );
}

class CharacterTray extends StatefulWidget {
  const CharacterTray({
    super.key,
    required this.controller,
    this.restoreProfileId,
    this.onProfileEditorOpened,
  });

  final CharacterController controller;
  final String? restoreProfileId;
  final ValueChanged<String?>? onProfileEditorOpened;

  @override
  State<CharacterTray> createState() => _CharacterTrayState();
}

class _CharacterTrayState extends State<CharacterTray> {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Character Prompt',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Import from sandbox JSON',
                            onPressed: widget.controller.isSaving
                                ? null
                                : () => _showImportPicker(
                                    context,
                                    widget.controller,
                                  ),
                            icon: const Icon(Icons.download_outlined),
                          ),
                          IconButton(
                            tooltip: 'Export all to sandbox',
                            onPressed: widget.controller.isSaving
                                ? null
                                : widget.controller.exportProfilesToSandbox,
                            icon: const Icon(Icons.upload_outlined),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: widget.controller.isSaving
                                ? null
                                : () => _openProfileEditor(),
                            icon: const Icon(Icons.add),
                            label: const Text('New'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Save named personas and switch between them for different tasks. The active profile is persisted across sessions.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.68,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active profile',
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.controller.activeProfile.name,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.controller.activeProfile.prompt,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.controller.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: Text(
                      widget.controller.error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                if (widget.controller.statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
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
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                          itemCount: widget.controller.profiles.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final profile = widget.controller.profiles[index];
                            final isActive =
                                profile.id == widget.controller.activeProfileId;
                            return _CharacterProfileCard(
                              profile: profile,
                              isActive: isActive,
                              isSaving: widget.controller.isSaving,
                              onSelect: () =>
                                  widget.controller.selectProfile(profile.id),
                              onEdit: () =>
                                  _openProfileEditor(profile: profile),
                              onDuplicate: () => widget.controller
                                  .duplicateProfile(profile.id),
                              onExport: () =>
                                  widget.controller.exportProfilesToSandbox(
                                    profileId: profile.id,
                                  ),
                              onDelete: widget.controller.profiles.length == 1
                                  ? null
                                  : () => widget.controller.deleteProfile(
                                      profile.id,
                                    ),
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
    final restoreProfileId = widget.restoreProfileId;
    if (restoreProfileId == null || restoreProfileId.isEmpty) {
      _didAttemptRestore = true;
      return;
    }
    _didAttemptRestore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final profile = widget.controller.findById(restoreProfileId);
      if (profile != null) {
        _openProfileEditor(profile: profile);
      }
    });
  }

  Future<void> _openProfileEditor({CharacterProfile? profile}) {
    widget.onProfileEditorOpened?.call(profile?.id);
    return _showProfileEditor(context, widget.controller, profile: profile);
  }
}

class _CharacterProfileCard extends StatelessWidget {
  const _CharacterProfileCard({
    required this.profile,
    required this.isActive,
    required this.isSaving,
    required this.onSelect,
    required this.onEdit,
    required this.onDuplicate,
    required this.onExport,
    required this.onDelete,
  });

  final CharacterProfile profile;
  final bool isActive;
  final bool isSaving;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onExport;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(profile.name, style: theme.textTheme.labelLarge),
                ),
                if (isActive) const Chip(label: Text('Active')),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              profile.prompt,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: isActive || isSaving ? null : onSelect,
                  child: Text(isActive ? 'In use' : 'Use this'),
                ),
                FilledButton.tonal(
                  onPressed: isSaving ? null : onEdit,
                  child: const Text('Edit'),
                ),
                FilledButton.tonal(
                  onPressed: isSaving ? null : onDuplicate,
                  child: const Text('Duplicate'),
                ),
                TextButton(
                  onPressed: isSaving ? null : onExport,
                  child: const Text('Export'),
                ),
                if (onDelete != null)
                  TextButton(
                    onPressed: isSaving ? null : onDelete,
                    child: const Text('Delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showProfileEditor(
  BuildContext context,
  CharacterController controller, {
  CharacterProfile? profile,
}) async {
  controller.clearStatus();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _CharacterProfileEditorSheet(
        controller: controller,
        profile: profile,
      );
    },
  );
}

class _CharacterProfileEditorSheet extends StatefulWidget {
  const _CharacterProfileEditorSheet({
    required this.controller,
    required this.profile,
  });

  final CharacterController controller;
  final CharacterProfile? profile;

  @override
  State<_CharacterProfileEditorSheet> createState() =>
      _CharacterProfileEditorSheetState();
}

class _CharacterProfileEditorSheetState
    extends State<_CharacterProfileEditorSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.profile?.name ?? '',
  );
  late final TextEditingController _promptController = TextEditingController(
    text: widget.profile?.prompt ?? '',
  );
  late bool _makeActive =
      widget.profile == null ||
      widget.profile!.id == widget.controller.activeProfileId;

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
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
                      widget.profile == null ? 'New profile' : 'Edit profile',
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
                                await widget.controller.saveProfile(
                                  existingProfileId: widget.profile?.id,
                                  name: _nameController.text,
                                  prompt: _promptController.text,
                                  makeActive: _makeActive,
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
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Profile name',
                  hintText: 'Research partner',
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _makeActive,
                    onChanged: widget.controller.isSaving
                        ? null
                        : (value) => setState(() => _makeActive = value),
                    title: const Text('Make active after save'),
                  );
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _promptController,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'System prompt',
                    hintText:
                        'Describe how this persona should behave, speak, and prioritize.',
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

Future<void> _showImportPicker(
  BuildContext context,
  CharacterController controller,
) async {
  controller.clearStatus();
  await controller.refresh();
  if (!context.mounted) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final theme = Theme.of(context);
      return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Import Profiles', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Pick a sandbox JSON export to merge into the current persona list.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 12),
              if (controller.importableSandboxFiles.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No sandbox JSON files found yet. Export a profile first or drop a JSON pack into the sandbox tray.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: controller.importableSandboxFiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final file = controller.importableSandboxFiles[index];
                      return Card(
                        child: ListTile(
                          title: Text(file.relativePath),
                          subtitle: Text(file.fileType),
                          onTap: () async {
                            await controller.importProfilesFromSandbox(
                              file.relativePath,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
