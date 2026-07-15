import 'package:flutter/material.dart';

import '../memory/memory_controller.dart';
import 'settings_controller.dart';

const _retentionOptions = [10, 25, 50, 100];
const _sandboxModeOptions = {
  'target_file': 'Target file',
  'new_file': 'New file',
};

Future<void> showSettingsSheet({
  required BuildContext context,
  required MemoryController memoryController,
  required SettingsController settingsController,
  required VoidCallback onOpenColdLog,
  required VoidCallback onOpenModels,
  required VoidCallback onOpenHelp,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SettingsSheet(
      memoryController: memoryController,
      settingsController: settingsController,
      onOpenColdLog: onOpenColdLog,
      onOpenModels: onOpenModels,
      onOpenHelp: onOpenHelp,
    ),
  );
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.memoryController,
    required this.settingsController,
    required this.onOpenColdLog,
    required this.onOpenModels,
    required this.onOpenHelp,
  });

  final MemoryController memoryController;
  final SettingsController settingsController;
  final VoidCallback onOpenColdLog;
  final VoidCallback onOpenModels;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([memoryController, settingsController]),
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Settings',
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
                  'Practical app controls for local logging, retention, and maintenance shortcuts.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                              value: memoryController.sessionLoggingEnabled,
                              onChanged: memoryController.isSaving
                                  ? null
                                  : memoryController.setSessionLoggingEnabled,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          memoryController.sessionLoggingEnabled
                              ? 'New chat sessions will be archived locally inside private app storage.'
                              : 'Raw chat sessions are not currently being archived.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue:
                              memoryController.sessionLogRetentionCount,
                          decoration: const InputDecoration(
                            labelText: 'Session log retention',
                          ),
                          items: _retentionOptions
                              .map(
                                (count) => DropdownMenuItem<int>(
                                  value: count,
                                  child: Text('Keep last $count logs'),
                                ),
                              )
                              .toList(),
                          onChanged: memoryController.isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    memoryController
                                        .setSessionLogRetentionCount(value);
                                  }
                                },
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                '${memoryController.sessionLogCount} session logs',
                              ),
                            ),
                            Chip(
                              label: Text(
                                '${memoryController.curatedFileCount} curated files',
                              ),
                            ),
                            Chip(
                              label: Text(
                                _formatBytes(memoryController.totalBytes),
                              ),
                            ),
                          ],
                        ),
                        if (memoryController.sessionLogCount > 0) ...[
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: memoryController.isSaving
                                ? null
                                : memoryController.clearSessionLogs,
                            icon: const Icon(Icons.delete_sweep_outlined),
                            label: const Text('Clear session logs'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Startup and Composer',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue:
                              settingsController.defaultSandboxTaskMode,
                          decoration: const InputDecoration(
                            labelText: 'Default sandbox task mode',
                          ),
                          items: _sandboxModeOptions.entries
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: settingsController.isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    settingsController
                                        .setDefaultSandboxTaskMode(value);
                                  }
                                },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String?>(
                          initialValue:
                              settingsController.startupCharacterProfileId,
                          decoration: const InputDecoration(
                            labelText: 'Startup character profile',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Keep current profile'),
                            ),
                            ...settingsController.characterProfiles.map(
                              (profile) => DropdownMenuItem<String?>(
                                value: profile.id,
                                child: Text(profile.name),
                              ),
                            ),
                          ],
                          onChanged: settingsController.isSaving
                              ? null
                              : settingsController.setStartupCharacterProfileId,
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: settingsController
                              .autoOpenModelInventoryIfUnassigned,
                          onChanged: settingsController.isSaving
                              ? null
                              : settingsController
                                    .setAutoOpenModelInventoryIfUnassigned,
                          title: const Text(
                            'Auto-open Model Inventory when no Main AI model is assigned',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: settingsController.reopenLastSurfaceOnLaunch,
                          onChanged: settingsController.isSaving
                              ? null
                              : settingsController.setReopenLastSurfaceOnLaunch,
                          title: const Text(
                            'Re-open last workspace surface on launch',
                          ),
                          subtitle: const Text(
                            'Resume the most recent tray or sheet before any fallback Model Inventory prompt.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (memoryController.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    memoryController.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                if (memoryController.statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    memoryController.statusMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                if (settingsController.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    settingsController.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                if (settingsController.statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    settingsController.statusMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text('Shortcuts', style: theme.textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onOpenColdLog();
                      },
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Cold Log'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onOpenModels();
                      },
                      icon: const Icon(Icons.tune_outlined),
                      label: const Text('Models'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onOpenHelp();
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Help'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notes', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Chatty-mini keeps models, memory, logs, and sandbox files in private app storage. Import, cleanup, and review flows are intentionally handled inside the app rather than through hidden Android folders.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
