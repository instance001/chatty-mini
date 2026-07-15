import 'package:flutter/services.dart';

import 'inference_models.dart';

class InferenceService {
  static const MethodChannel _methodChannel = MethodChannel(
    'chatty_mini/inference_bridge',
  );
  static const EventChannel _eventChannel = EventChannel(
    'chatty_mini/inference_events',
  );

  Stream<Map<Object?, Object?>> generationEvents() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return Map<Object?, Object?>.from(event as Map);
    });
  }

  Future<Map<Object?, Object?>> loadModel({
    required String modelPath,
    required int contextSize,
    required int gpuLayers,
  }) async {
    final result = await _methodChannel.invokeMapMethod<Object?, Object?>(
      'loadModel',
      {
        'modelPath': modelPath,
        'contextSize': contextSize,
        'gpuLayers': gpuLayers,
      },
    );
    return result ?? const {};
  }

  Future<Map<Object?, Object?>> startGeneration(
    GenerationRequest request,
  ) async {
    final result = await _methodChannel.invokeMapMethod<Object?, Object?>(
      'startGeneration',
      request.toMap(),
    );
    return result ?? const {};
  }

  Future<void> cancelGeneration({required String requestId}) async {
    await _methodChannel.invokeMethod<void>('cancelGeneration', {
      'requestId': requestId,
    });
  }
}
