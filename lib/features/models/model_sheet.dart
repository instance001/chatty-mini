import 'package:flutter/material.dart';

import '../../core/inference/inference_presets.dart';
import 'model_controller.dart';
import 'model_models.dart';

Future<void> showModelSheet({
  required BuildContext context,
  required ModelController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ModelSheet(controller: controller),
  );
}

class ModelSheet extends StatelessWidget {
  const ModelSheet({super.key, required this.controller});

  final ModelController controller;

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
          animation: controller,
          builder: (context, _) {
            final settings = controller.settings;
            final mainModel = controller.findById(settings.mainModelId);
            final bookkeeperModel = controller.findById(
              settings.bookkeeperModelId,
            );
            final mainCloud = controller.findCloudBySelectionId(
              settings.mainModelId,
            );
            final bookkeeperCloud = controller.findCloudBySelectionId(
              settings.bookkeeperModelId,
            );
            final header = Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Model Inventory', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Choose local GGUF or optional cloud models independently for Main AI and Bookkeeper.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: controller.isLoading
                            ? null
                            : controller.importModelFromPicker,
                        icon: const Icon(Icons.file_open_outlined),
                        label: const Text('Import GGUF'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: controller.isLoading
                            ? null
                            : () => _showCloudModelEditor(context, controller),
                        icon: const Icon(Icons.cloud_outlined),
                        label: const Text('Add cloud'),
                      ),
                      if (controller.selectedCount > 0)
                        FilledButton.tonalIcon(
                          onPressed: controller.isLoading
                              ? null
                              : controller.deleteSelectedModels,
                          icon: const Icon(Icons.delete_outline),
                          label: Text('Delete ${controller.selectedCount}'),
                        ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: controller.isLoading
                            ? null
                            : controller.refreshModels,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            );
            final infoBlock = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  _StorageSummaryCard(controller: controller),
                  const SizedBox(height: 10),
                  _RoleSelectionCard(
                    label: 'Main AI',
                    subtitle: mainCloud != null
                        ? '${mainCloud.label} · Cloud'
                        : mainModel != null
                        ? '${mainModel.fileName} · Local'
                        : 'No model selected',
                    value: settings.mainModelId,
                    presetValue: settings.mainAiPreset,
                    models: controller.models,
                    cloudModels: controller.cloudModels,
                    onChanged: controller.selectMainModel,
                    onPresetChanged: controller.selectMainPreset,
                  ),
                  const SizedBox(height: 10),
                  _RoleSelectionCard(
                    label: 'Bookkeeper',
                    subtitle: bookkeeperCloud != null
                        ? '${bookkeeperCloud.label} · Cloud'
                        : bookkeeperModel != null
                        ? '${bookkeeperModel.fileName} · Local'
                        : 'No model selected',
                    value: settings.bookkeeperModelId,
                    presetValue: settings.bookkeeperPreset,
                    models: controller.models,
                    cloudModels: controller.cloudModels,
                    onChanged: controller.selectBookkeeperModel,
                    onPresetChanged: controller.selectBookkeeperPreset,
                  ),
                ],
              ),
            );

            return Column(
              children: [
                header,
                if (controller.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    child: Text(
                      controller.error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                if (controller.statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    child: Text(
                      controller.statusMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                Expanded(
                  child: controller.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : controller.models.isEmpty &&
                            controller.cloudModels.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 22),
                          children: [
                            infoBlock,
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 18),
                            _NoModelsState(
                              onImport: controller.importModelFromPicker,
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 22),
                          children: [
                            infoBlock,
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            ...controller.cloudModels.map(
                              (model) => Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  0,
                                  18,
                                  10,
                                ),
                                child: _CloudModelCard(
                                  model: model,
                                  isMain:
                                      model.selectionId == settings.mainModelId,
                                  isBookkeeper:
                                      model.selectionId ==
                                      settings.bookkeeperModelId,
                                  onVerify: () =>
                                      controller.verifyCloudModel(model.id),
                                  onEdit: () => _showCloudModelEditor(
                                    context,
                                    controller,
                                    existing: model,
                                  ),
                                  onUseForMain: () => controller
                                      .selectMainModel(model.selectionId),
                                  onUseForBookkeeper: () => controller
                                      .selectBookkeeperModel(model.selectionId),
                                  onDelete: () =>
                                      controller.deleteCloudModel(model.id),
                                ),
                              ),
                            ),
                            ...controller.models.map((model) {
                              final isMain = model.id == settings.mainModelId;
                              final isBookkeeper =
                                  model.id == settings.bookkeeperModelId;
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  0,
                                  18,
                                  10,
                                ),
                                child: _ModelCard(
                                  model: model,
                                  isMain: isMain,
                                  isBookkeeper: isBookkeeper,
                                  isSelected: controller.isSelected(model.id),
                                  onSelectionChanged: (selected) => controller
                                      .toggleModelSelection(model.id, selected),
                                  onUseForMain: () =>
                                      controller.selectMainModel(model.id),
                                  onUseForBookkeeper: () => controller
                                      .selectBookkeeperModel(model.id),
                                  onDelete: () =>
                                      controller.deleteModel(model.id),
                                ),
                              );
                            }),
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
}

class _RoleSelectionCard extends StatelessWidget {
  const _RoleSelectionCard({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.presetValue,
    required this.models,
    required this.cloudModels,
    required this.onChanged,
    required this.onPresetChanged,
  });

  final String label;
  final String subtitle;
  final String? value;
  final String presetValue;
  final List<ModelRecord> models;
  final List<CloudModelRecord> cloudModels;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onPresetChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _ModelChooserField(
              label: 'Assigned model',
              value: value,
              models: models,
              cloudModels: cloudModels,
              onChanged: onChanged,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: presetValue,
              isExpanded: true,
              items: inferencePresets
                  .map(
                    (preset) => DropdownMenuItem<String>(
                      value: preset.id,
                      child: Text(preset.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onPresetChanged(value);
                }
              },
              decoration: const InputDecoration(labelText: 'Generation preset'),
            ),
            const SizedBox(height: 6),
            Text(
              inferencePresetById(presetValue).description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelChooserField extends StatelessWidget {
  const _ModelChooserField({
    required this.label,
    required this.value,
    required this.models,
    required this.cloudModels,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<ModelRecord> models;
  final List<CloudModelRecord> cloudModels;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ModelRecord? selected;
    CloudModelRecord? selectedCloud;
    for (final model in models) {
      if (model.id == value) {
        selected = model;
        break;
      }
    }
    for (final model in cloudModels) {
      if (model.selectionId == value) selectedCloud = model;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final selection = await _showModelPicker(
          context: context,
          title: label,
          currentValue: value,
          models: models,
          cloudModels: cloudModels,
        );
        if (selection != null) {
          onChanged(selection.modelId);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedCloud?.label ?? selected?.fileName ?? 'No selection',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.unfold_more, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.isMain,
    required this.isBookkeeper,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onUseForMain,
    required this.onUseForBookkeeper,
    required this.onDelete,
  });

  final ModelRecord model;
  final bool isMain;
  final bool isBookkeeper;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onUseForMain;
  final VoidCallback onUseForBookkeeper;
  final VoidCallback onDelete;

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
                  child: Text(
                    model.fileName,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => onSelectionChanged(value ?? false),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatBytes(model.sizeBytes)} | ${_formatDate(model.modifiedAt)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            if (model.isTooLargeForSmallPhones) ...[
              const SizedBox(height: 6),
              Text(
                'Likely too large for the small-phone target.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ] else if (model.isLargeForSmallPhones) ...[
              const SizedBox(height: 6),
              Text(
                'Large for small phones. Prefer tighter presets and expect heavier memory pressure.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    isMain ? 'Assigned to Main AI' : 'Available for Main AI',
                  ),
                ),
                Chip(
                  label: Text(
                    isBookkeeper
                        ? 'Assigned to Bookkeeper'
                        : 'Available for Bookkeeper',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onUseForMain,
                    child: const Text('Set Main AI'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onUseForBookkeeper,
                    child: const Text('Set Bookkeeper'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoModelsState extends StatelessWidget {
  const _NoModelsState({required this.onImport});

  final VoidCallback onImport;

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
              Icons.folder_copy_outlined,
              size: 44,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 12),
            Text('No GGUF models found', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Import one or more .gguf files through Android. The picker will usually show Recent files or Downloads.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onImport,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Import GGUF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloudModelCard extends StatelessWidget {
  const _CloudModelCard({
    required this.model,
    required this.isMain,
    required this.isBookkeeper,
    required this.onVerify,
    required this.onEdit,
    required this.onUseForMain,
    required this.onUseForBookkeeper,
    required this.onDelete,
  });

  final CloudModelRecord model;
  final bool isMain;
  final bool isBookkeeper;
  final VoidCallback onVerify;
  final VoidCallback onEdit;
  final VoidCallback onUseForMain;
  final VoidCallback onUseForBookkeeper;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  model.label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Chip(label: Text(model.verified ? 'Verified' : 'Unverified')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_providerLabel(model.provider)} · ${model.model}\n${model.baseUrl}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isMain) const Chip(label: Text('Main AI')),
              if (isBookkeeper) const Chip(label: Text('Bookkeeper')),
              OutlinedButton(onPressed: onVerify, child: const Text('Verify')),
              OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
              OutlinedButton(
                onPressed: onUseForMain,
                child: const Text('Set Main'),
              ),
              OutlinedButton(
                onPressed: onUseForBookkeeper,
                child: const Text('Set Bookkeeper'),
              ),
              IconButton.outlined(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> _showCloudModelEditor(
  BuildContext context,
  ModelController controller, {
  CloudModelRecord? existing,
}) async {
  final result = await showDialog<_CloudEditorResult>(
    context: context,
    builder: (_) => _CloudModelEditorDialog(existing: existing),
  );
  if (result != null) {
    await controller.saveCloudModel(
      existingId: existing?.id,
      label: result.label,
      baseUrl: result.baseUrl,
      model: result.model,
      apiKey: result.apiKey,
      provider: result.provider,
    );
  }
}

class _CloudModelEditorDialog extends StatefulWidget {
  const _CloudModelEditorDialog({this.existing});

  final CloudModelRecord? existing;

  @override
  State<_CloudModelEditorDialog> createState() =>
      _CloudModelEditorDialogState();
}

class _CloudModelEditorDialogState extends State<_CloudModelEditorDialog> {
  late String provider;
  late final TextEditingController label;
  late final TextEditingController baseUrl;
  late final TextEditingController model;
  late final TextEditingController apiKey;

  @override
  void initState() {
    super.initState();
    provider = widget.existing?.provider ?? 'openai';
    final defaults = _providerDefaults(provider);
    label = TextEditingController(text: widget.existing?.label ?? defaults.$1);
    baseUrl = TextEditingController(
      text: widget.existing?.baseUrl ?? defaults.$2,
    );
    model = TextEditingController(text: widget.existing?.model ?? defaults.$3);
    apiKey = TextEditingController();
  }

  @override
  void dispose() {
    label.dispose();
    baseUrl.dispose();
    model.dispose();
    apiKey.dispose();
    super.dispose();
  }

  void _save() {
    if (label.text.trim().isEmpty ||
        baseUrl.text.trim().isEmpty ||
        model.text.trim().isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      _CloudEditorResult(
        provider: provider,
        label: label.text,
        baseUrl: baseUrl.text,
        model: model.text,
        apiKey: apiKey.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add cloud model' : 'Edit cloud model',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cloud is optional. When selected, the prompt and relevant Chatty-mini context are sent to this endpoint. No automatic fallback occurs.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: provider,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: const [
                DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                DropdownMenuItem(value: 'anthropic', child: Text('Anthropic')),
                DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
                DropdownMenuItem(value: 'xai', child: Text('xAI Grok')),
                DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek')),
                DropdownMenuItem(
                  value: 'openai_compatible',
                  child: Text('Custom OpenAI-compatible'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                provider = value;
                if (widget.existing == null) {
                  final defaults = _providerDefaults(value);
                  label.text = defaults.$1;
                  baseUrl.text = defaults.$2;
                  model.text = defaults.$3;
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: label,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: baseUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Base URL'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: model,
              decoration: const InputDecoration(labelText: 'Model name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: apiKey,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: widget.existing == null
                    ? 'API key'
                    : 'New API key (leave blank to keep)',
                helperText:
                    'Encrypted at rest using the device\'s Android Keystore.',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _CloudEditorResult {
  const _CloudEditorResult({
    required this.provider,
    required this.label,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  final String provider;
  final String label;
  final String baseUrl;
  final String model;
  final String apiKey;
}

(String, String, String) _providerDefaults(String provider) =>
    switch (provider) {
      'anthropic' => (
        'Anthropic',
        'https://api.anthropic.com/v1',
        'claude-sonnet-5',
      ),
      'gemini' => (
        'Gemini',
        'https://generativelanguage.googleapis.com/v1beta',
        'gemini-3.5-flash',
      ),
      'xai' => ('xAI', 'https://api.x.ai/v1', 'grok-4.5'),
      'deepseek' => (
        'DeepSeek',
        'https://api.deepseek.com',
        'deepseek-v4-flash',
      ),
      'openai_compatible' => (
        'Custom cloud',
        'https://example.com/v1',
        'model-name',
      ),
      _ => ('OpenAI', 'https://api.openai.com/v1', 'gpt-5.6-luna'),
    };

String _providerLabel(String provider) => switch (provider) {
  'openai' => 'OpenAI',
  'anthropic' => 'Anthropic',
  'gemini' => 'Google Gemini',
  'xai' => 'xAI',
  'deepseek' => 'DeepSeek',
  _ => 'OpenAI-compatible',
};

class _StorageSummaryCard extends StatelessWidget {
  const _StorageSummaryCard({required this.controller});

  final ModelController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Model Storage', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              '${controller.models.length} model(s) stored privately inside the app | ${_formatBytes(controller.totalModelBytes)} used',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Users cannot browse this folder directly after install, so import and deletion are handled here in the inventory.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

class _ModelPickerSelection {
  const _ModelPickerSelection(this.modelId);

  final String? modelId;
}

Future<_ModelPickerSelection?> _showModelPicker({
  required BuildContext context,
  required String title,
  required String? currentValue,
  required List<ModelRecord> models,
  required List<CloudModelRecord> cloudModels,
}) async {
  return showDialog<_ModelPickerSelection>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final maxHeight = MediaQuery.sizeOf(context).height * 0.58;
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        title: Text(title, style: theme.textTheme.titleMedium),
        contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('No selection'),
                  trailing: currentValue == null
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const _ModelPickerSelection(null)),
                ),
                if (cloudModels.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4),
                    child: Text('Cloud'),
                  ),
                ...cloudModels.map(
                  (model) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_outlined),
                    title: Text(model.label),
                    subtitle: Text(
                      '${_providerLabel(model.provider)} · ${model.model} · ${model.verified ? 'Verified' : 'Not verified'}',
                    ),
                    trailing: currentValue == model.selectionId
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_ModelPickerSelection(model.selectionId)),
                  ),
                ),
                if (models.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 4),
                    child: Text('Local GGUF'),
                  ),
                ...models.map(
                  (model) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      model.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_formatBytes(model.sizeBytes)),
                    trailing: currentValue == model.id
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_ModelPickerSelection(model.id)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
}
