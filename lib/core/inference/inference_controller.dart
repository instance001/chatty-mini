import 'dart:async';

import 'package:flutter/foundation.dart';

import 'inference_models.dart';
import 'inference_service.dart';
import 'cloud_inference_service.dart';
import '../../features/models/model_models.dart';

class InferenceController extends ChangeNotifier {
  InferenceController({
    required this.service,
    CloudInferenceService? cloudService,
  }) : cloudService = cloudService ?? CloudInferenceService();

  final InferenceService service;
  final CloudInferenceService cloudService;

  InferenceStatus _status = InferenceStatus.idle;
  StreamSubscription<Map<Object?, Object?>>? _eventsSub;
  bool _awaitingRequestStart = false;

  InferenceStatus get status => _status;

  Future<void> initialize() async {
    _eventsSub ??= service.generationEvents().listen(_handleEvent);
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  Future<void> loadModel(String modelPath) async {
    await loadModelWithSettings(
      modelPath: modelPath,
      contextSize: 1536,
      gpuLayers: 0,
    );
  }

  Future<void> loadModelWithSettings({
    required String modelPath,
    required int contextSize,
    required int gpuLayers,
  }) async {
    try {
      final result = await service.loadModel(
        modelPath: modelPath,
        contextSize: contextSize,
        gpuLayers: gpuLayers,
      );
      _status = _status.copyWith(
        state: (result['state'] as String?) ?? 'loaded',
        loadedModelPath: modelPath,
        statusMessage: result['message'] as String?,
        clearError: true,
      );
      if (_status.state == 'failed') {
        _status = _status.copyWith(
          error: result['message'] as String? ?? 'Model load failed.',
          clearLoadedModelPath: true,
        );
      }
    } catch (error) {
      _status = _status.copyWith(
        state: 'failed',
        error: error.toString(),
        clearLoadedModelPath: true,
      );
    }
    notifyListeners();
  }

  Future<void> startGeneration({required GenerationRequest request}) async {
    try {
      if (_status.loadedModelPath != request.modelPath) {
        await loadModelWithSettings(
          modelPath: request.modelPath,
          contextSize: request.contextSize,
          gpuLayers: request.gpuLayers,
        );
      }
      _awaitingRequestStart = true;
      final result = await service.startGeneration(request);
      final returnedState = (result['state'] as String?) ?? 'generating';
      final returnedRequestId = result['requestId'] as String?;
      if (returnedState == 'failed') {
        _awaitingRequestStart = false;
        _status = _status.copyWith(
          state: 'failed',
          assistantDraft: '',
          error:
              result['message'] as String? ??
              'Generation could not be started.',
          statusMessage: result['message'] as String?,
          clearCurrentRequestId: true,
        );
      } else if (_awaitingRequestStart) {
        _status = _status.copyWith(
          state: returnedState,
          currentRequestId: returnedRequestId,
          assistantDraft: '',
          statusMessage: result['message'] as String?,
          clearCompletedResponse: true,
          clearError: true,
        );
      }
    } catch (error) {
      _awaitingRequestStart = false;
      _status = _status.copyWith(
        state: 'failed',
        assistantDraft: '',
        error: error.toString(),
        clearCurrentRequestId: true,
      );
    }
    notifyListeners();
  }

  Future<void> startCloudGeneration({
    required CloudModelRecord model,
    required String prompt,
    required int maxTokens,
    required double temperature,
  }) async {
    _status = _status.copyWith(
      state: 'generating',
      currentRequestId: 'cloud:${DateTime.now().microsecondsSinceEpoch}',
      assistantDraft: '',
      statusMessage: 'Generating with ${model.label}…',
      clearCompletedResponse: true,
      clearError: true,
    );
    notifyListeners();
    try {
      String? response;
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          response = await cloudService.generate(
            model: model,
            prompt: prompt,
            maxTokens: maxTokens,
            temperature: temperature,
            onChunk: (chunk) {
              _status = _status.copyWith(
                state: 'generating',
                assistantDraft: _status.assistantDraft + chunk,
              );
              notifyListeners();
            },
          );
          break;
        } on CloudRequestException catch (error) {
          final canRetry =
              attempt == 0 &&
              error.isTransient &&
              _status.assistantDraft.isEmpty;
          if (!canRetry) rethrow;
          _status = _status.copyWith(
            statusMessage: '${model.label} is busy. Retrying once…',
          );
          notifyListeners();
          await Future<void>.delayed(const Duration(milliseconds: 900));
        }
      }
      _status = _status.copyWith(
        state: 'completed',
        assistantDraft: '',
        completedResponse: response ?? '',
        statusMessage: 'Cloud generation completed.',
        clearCurrentRequestId: true,
      );
    } catch (error) {
      final message = error is CloudRequestException
          ? _friendlyCloudError(model.label, error)
          : error.toString();
      _status = _status.copyWith(
        state: 'failed',
        assistantDraft: '',
        error: message,
        statusMessage: 'Cloud generation failed.',
        clearCurrentRequestId: true,
      );
    }
    notifyListeners();
  }

  String _friendlyCloudError(String label, CloudRequestException error) {
    if (error.statusCode == 503 ||
        error.statusCode == 502 ||
        error.statusCode == 504) {
      return '$label is temporarily at capacity (${error.statusCode}). Nothing was sent to another provider. Please try again shortly.';
    }
    if (error.statusCode == 429) {
      return '$label rate limit reached (429). Nothing was sent to another provider. Please wait briefly and try again.';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return '$label rejected the API credentials (${error.statusCode}). Check the stored key and verify the model again.';
    }
    if (error.statusCode == 404) {
      return '$label could not find that model or endpoint (404). Check the model name and base URL.';
    }
    return '$label request failed (${error.statusCode}): ${error.message}';
  }

  Future<void> cancelGeneration() async {
    final requestId = _status.currentRequestId;
    if (requestId == null) {
      return;
    }
    if (requestId.startsWith('cloud:')) {
      cloudService.cancel();
      _status = _status.copyWith(
        state: 'cancelled',
        assistantDraft: '',
        statusMessage: 'Cloud generation cancelled.',
        clearCurrentRequestId: true,
      );
      notifyListeners();
      return;
    }
    try {
      await service.cancelGeneration(requestId: requestId);
    } catch (error) {
      _status = _status.copyWith(error: error.toString());
      notifyListeners();
    }
  }

  void clearCompletedResponse() {
    _status = _status.copyWith(clearCompletedResponse: true);
    notifyListeners();
  }

  void _handleEvent(Map<Object?, Object?> rawEvent) {
    final event = GenerationEvent.fromMap(rawEvent);
    if (_status.currentRequestId == null && !_awaitingRequestStart) {
      return;
    }
    if (_status.currentRequestId != null &&
        event.requestId != _status.currentRequestId) {
      return;
    }

    switch (event.type) {
      case 'started':
        _awaitingRequestStart = false;
        _status = _status.copyWith(
          state: 'generating',
          currentRequestId: event.requestId,
          assistantDraft: '',
          clearCompletedResponse: true,
          clearError: true,
        );
      case 'token':
        _awaitingRequestStart = false;
        final nextDraft = _status.assistantDraft + (event.text ?? '');
        _status = _status.copyWith(
          state: 'generating',
          currentRequestId: event.requestId,
          assistantDraft: nextDraft,
        );
      case 'completed':
        _awaitingRequestStart = false;
        final finalText = event.text ?? _status.assistantDraft;
        _status = _status.copyWith(
          state: 'completed',
          assistantDraft: '',
          completedResponse: finalText,
          statusMessage: 'Local generation completed.',
          clearCurrentRequestId: true,
        );
      case 'cancelled':
        _awaitingRequestStart = false;
        _status = _status.copyWith(
          state: 'cancelled',
          assistantDraft: '',
          statusMessage: 'Local generation cancelled.',
          clearCurrentRequestId: true,
        );
      case 'failed':
        _awaitingRequestStart = false;
        _status = _status.copyWith(
          state: 'failed',
          error: event.message ?? 'Generation failed.',
          statusMessage: event.message ?? 'Generation failed.',
          assistantDraft: '',
          clearCurrentRequestId: true,
        );
    }
    notifyListeners();
  }
}
