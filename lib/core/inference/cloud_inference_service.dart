import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../features/models/model_models.dart';
import 'cloud_key_service.dart';

class CloudInferenceService {
  CloudInferenceService({CloudKeyService? keyService})
    : keyService = keyService ?? CloudKeyService();

  final CloudKeyService keyService;
  HttpClientRequest? _activeRequest;

  Future<void> verify(CloudModelRecord model) async {
    await generateWithRetry(
      model: model,
      prompt: 'Reply with OK.',
      maxTokens: 2,
      temperature: 0,
      onChunk: (_) {},
    );
  }

  Future<String> generateWithRetry({
    required CloudModelRecord model,
    required String prompt,
    required int maxTokens,
    required double temperature,
    required void Function(String chunk) onChunk,
    void Function()? onRetry,
  }) async {
    var receivedOutput = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await generate(
          model: model,
          prompt: prompt,
          maxTokens: maxTokens,
          temperature: temperature,
          onChunk: (chunk) {
            receivedOutput = true;
            onChunk(chunk);
          },
        );
      } on CloudRequestException catch (error) {
        final canRetry = attempt == 0 && error.isTransient && !receivedOutput;
        if (!canRetry) rethrow;
        onRetry?.call();
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }
    }
    throw StateError('Cloud retry loop ended unexpectedly.');
  }

  Future<String> generate({
    required CloudModelRecord model,
    required String prompt,
    required int maxTokens,
    required double temperature,
    required void Function(String chunk) onChunk,
  }) async {
    final apiKey = await keyService.read(model.id);
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError('No API key is stored for ${model.label}.');
    }
    final client = HttpClient();
    try {
      final effectiveMaxTokens = _effectiveMaxTokens(model, maxTokens);
      final base = model.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
      final endpoint = switch (model.provider) {
        'openai' => '$base/responses',
        'anthropic' => '$base/messages',
        'gemini' =>
          '$base/models/${Uri.encodeComponent(model.model.replaceFirst('models/', ''))}:streamGenerateContent?alt=sse',
        _ => '$base/chat/completions',
      };
      final request = await client.postUrl(Uri.parse(endpoint));
      _activeRequest = request;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      final body = switch (model.provider) {
        'openai' => {
          'model': model.model,
          'input': prompt,
          'max_output_tokens': effectiveMaxTokens,
          'stream': true,
        },
        'anthropic' => {
          'model': model.model,
          'max_tokens': effectiveMaxTokens,
          'temperature': temperature,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'stream': true,
        },
        'gemini' => {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': _geminiGenerationConfig(
            model.model,
            effectiveMaxTokens,
            temperature,
          ),
        },
        _ => {
          'model': model.model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': effectiveMaxTokens,
          'temperature': temperature,
          'stream': true,
        },
      };
      switch (model.provider) {
        case 'anthropic':
          request.headers
            ..set('x-api-key', apiKey)
            ..set('anthropic-version', '2023-06-01');
          break;
        case 'gemini':
          request.headers.set('x-goog-api-key', apiKey);
          break;
        default:
          request.headers.set(
            HttpHeaders.authorizationHeader,
            'Bearer $apiKey',
          );
          break;
      }
      request.write(jsonEncode(body));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decoder.bind(response).join();
        throw CloudRequestException(
          statusCode: response.statusCode,
          message: _errorMessage(body),
        );
      }
      final output = StringBuffer();
      await for (final line
          in response.transform(utf8.decoder).transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty || data == '[DONE]') continue;
        final decoded = jsonDecode(data);
        if (decoded is! Map) continue;
        final content = _extractText(model.provider, decoded);
        if (content is String && content.isNotEmpty) {
          output.write(content);
          onChunk(content);
        }
      }
      return output.toString();
    } finally {
      _activeRequest = null;
      client.close();
    }
  }

  int _effectiveMaxTokens(CloudModelRecord model, int requested) {
    final floor = switch (model.provider) {
      'openai' || 'gemini' || 'xai' => 1024,
      'anthropic' || 'deepseek' => 512,
      _ => 512,
    };
    return requested < floor ? floor : requested;
  }

  Map<String, Object> _geminiGenerationConfig(
    String model,
    int maxTokens,
    double temperature,
  ) {
    if (model.startsWith('gemini-3')) {
      return {
        'maxOutputTokens': maxTokens,
        'thinkingConfig': {'thinkingLevel': 'minimal'},
      };
    }
    return {
      'maxOutputTokens': maxTokens,
      'temperature': temperature,
      if (model.startsWith('gemini-2.5'))
        'thinkingConfig': {'thinkingBudget': 0},
    };
  }

  String? _extractText(String provider, Map decoded) {
    if (provider == 'openai') {
      return decoded['type'] == 'response.output_text.delta'
          ? decoded['delta'] as String?
          : null;
    }
    if (provider == 'anthropic') {
      final delta = decoded['delta'];
      return delta is Map && delta['type'] == 'text_delta'
          ? delta['text'] as String?
          : null;
    }
    if (provider == 'gemini') {
      final candidates = decoded['candidates'];
      if (candidates is! List ||
          candidates.isEmpty ||
          candidates.first is! Map) {
        return null;
      }
      final content = (candidates.first as Map)['content'];
      final parts = content is Map ? content['parts'] : null;
      if (parts is! List || parts.isEmpty || parts.first is! Map) return null;
      return (parts.first as Map)['text'] as String?;
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return null;
    }
    final delta = (choices.first as Map)['delta'];
    return delta is Map ? delta['content'] as String? : null;
  }

  void cancel() {
    _activeRequest?.abort(const HttpException('Cloud generation cancelled.'));
    _activeRequest = null;
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        return (decoded['error'] as Map)['message']?.toString() ?? body;
      }
    } catch (_) {}
    return body.length > 240 ? '${body.substring(0, 240)}…' : body;
  }
}

class CloudRequestException implements Exception {
  const CloudRequestException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  bool get isTransient =>
      statusCode == 429 ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;

  String friendlyMessage(String label) {
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return '$label is temporarily at capacity ($statusCode). Nothing was sent to another provider. Please try again shortly.';
    }
    if (statusCode == 429) {
      return '$label rate limit reached (429). Nothing was sent to another provider. Please wait briefly and try again.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return '$label rejected the API credentials ($statusCode). Check the stored key and verify the model again.';
    }
    if (statusCode == 404) {
      return '$label could not find that model or endpoint (404). Check the model name and base URL.';
    }
    return '$label request failed ($statusCode): $message';
  }

  @override
  String toString() => 'Cloud request failed ($statusCode): $message';
}
