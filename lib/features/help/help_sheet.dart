import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _externalLinksChannel = MethodChannel('chatty_mini/external_links');
const _privacyPolicyUrl =
    'https://instance001.github.io/privacy/chatty-mini.html';
const _sourceCodeUrl = 'https://github.com/instance001/chatty-mini';

Future<void> showHelpSheet({
  required BuildContext context,
  required VoidCallback onOpenSandbox,
  required VoidCallback onOpenCharacters,
  required VoidCallback onOpenModels,
  required VoidCallback onOpenMemory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => HelpSheet(
      onOpenSandbox: onOpenSandbox,
      onOpenCharacters: onOpenCharacters,
      onOpenModels: onOpenModels,
      onOpenMemory: onOpenMemory,
    ),
  );
}

class HelpSheet extends StatelessWidget {
  const HelpSheet({
    super.key,
    required this.onOpenSandbox,
    required this.onOpenCharacters,
    required this.onOpenModels,
    required this.onOpenMemory,
  });

  final VoidCallback onOpenSandbox;
  final VoidCallback onOpenCharacters;
  final VoidCallback onOpenModels;
  final VoidCallback onOpenMemory;

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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Help and About',
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
              'Local GGUF chat for small portrait Android phones. The app is designed to stay simple on the main screen and put the heavier controls into trays and sheets.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 14),
            _HelpSection(
              title: 'First Steps',
              lines: const [
                '1. Open Model Inventory and import a .gguf file.',
                '2. Assign that model to Main AI.',
                '3. Check the runtime row says the app is ready enough.',
                '4. Type a message and chat.',
              ],
            ),
            const SizedBox(height: 12),
            _HelpSection(
              title: 'What Local Means',
              lines: const [
                'Your model runs on the device instead of a cloud AI service.',
                'Imported models, sandbox files, and logs live in private app storage.',
                'Large models may be slow or unstable on small phones.',
              ],
            ),
            const SizedBox(height: 12),
            _HelpSection(
              title: 'Top Bar Controls',
              lines: const [
                'Sandbox: local .md, .txt, and .json files.',
                'Characters: saved persona / system prompt profiles.',
                'Model Inventory: import GGUF files and assign Main AI / Bookkeeper.',
                'Info: this help sheet and app guidance.',
              ],
            ),
            const SizedBox(height: 12),
            _HelpSection(
              title: 'Sandbox Task Mode',
              lines: const [
                'Turn on Sandbox task near the composer when your next message is about reading, editing, or drafting a sandbox file.',
                'Use Target for an existing file.',
                'Use New file when you want the model to help draft content for a new sandbox file.',
              ],
            ),
            const SizedBox(height: 12),
            _HelpSection(
              title: 'Privacy and Logs',
              lines: const [
                'Local GGUF chats, imported models, sandbox files, settings, and logs remain in private app storage.',
                'Cloud use is optional. When a cloud model is selected, the prompt and relevant Chatty-mini context are sent directly to that provider or custom endpoint. FMI runs no intermediary inference server.',
                'Cloud API keys are encrypted locally with Android Keystore. Chatty-mini contains no ads, analytics SDK, tracking, or FMI account system.',
                'Session logging can be enabled or disabled in the Cold Log area.',
                'Cold Log files and session logs can be opened, cleared, and deleted in-app.',
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openExternalLink(
                    context,
                    _privacyPolicyUrl,
                    'privacy policy',
                  ),
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Privacy Policy'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _openExternalLink(context, _sourceCodeUrl, 'source code'),
                  icon: const Icon(Icons.code),
                  label: const Text('Source Code'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Quick Open', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
                    onOpenCharacters();
                  },
                  icon: const Icon(Icons.face_5_outlined),
                  label: const Text('Characters'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenSandbox();
                  },
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Sandbox'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onOpenMemory();
                  },
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Cold Log'),
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
                    Text('About This Build', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Chatty-mini is an open-source Android app published by Fractal Media Infrastructure, built around local GGUF support, optional user-configured cloud models, private model storage, and compact small-phone UX.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openExternalLink(
  BuildContext context,
  String url,
  String label,
) async {
  try {
    await _externalLinksChannel.invokeMethod<void>('openUrl', {'url': url});
  } on PlatformException catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $label: ${error.message}')),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
