import 'package:flutter/material.dart';

import '../../core/reporting/ai_report_service.dart';
import 'chat_models.dart';

class ReportMessageSheet extends StatefulWidget {
  const ReportMessageSheet({
    super.key,
    required this.assistantResponse,
    required this.context,
    this.precedingUserPrompt,
  });

  final String assistantResponse;
  final AiReportContext context;
  final String? precedingUserPrompt;

  @override
  State<ReportMessageSheet> createState() => _ReportMessageSheetState();
}

class _ReportMessageSheetState extends State<ReportMessageSheet> {
  static const _reasons = <String, String>{
    'Offensive': 'offensive',
    'Hate or harassment': 'hate_or_harassment',
    'Sexual content': 'sexual_content',
    'Violence or self-harm': 'violence_or_self_harm',
    'Illegal or dangerous': 'illegal_or_dangerous',
    'Deceptive or impersonation': 'deceptive_or_impersonation',
    'Privacy or credentials': 'privacy_or_credentials',
    'Other': 'other',
  };

  final _note = TextEditingController();
  final _service = const AiReportService();
  String _reason = 'other';
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await _service.submit(
        reason: _reason,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        assistantResponse: widget.assistantResponse,
        precedingUserPrompt: widget.precedingUserPrompt,
        lane: widget.context.lane,
        providerLabel: widget.context.providerLabel,
        modelLabel: widget.context.modelLabel,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report was not sent: $error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Report message',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'This sends the selected response, its immediately preceding prompt, and the active model lane. Nothing else from this chat is included.',
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: _reasons.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.value,
                      child: Text(entry.key),
                    ),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (value) => setState(() => _reason = value ?? 'other'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              enabled: !_sending,
              maxLength: 2000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.flag_outlined),
              label: Text(_sending ? 'Sending…' : 'Send report'),
            ),
          ],
        ),
      ),
    );
  }
}
