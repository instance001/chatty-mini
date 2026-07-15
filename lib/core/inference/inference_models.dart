class InferenceStatus {
  const InferenceStatus({
    required this.state,
    this.loadedModelPath,
    this.currentRequestId,
    this.assistantDraft = '',
    this.completedResponse,
    this.error,
    this.statusMessage,
  });

  final String state;
  final String? loadedModelPath;
  final String? currentRequestId;
  final String assistantDraft;
  final String? completedResponse;
  final String? error;
  final String? statusMessage;

  bool get isGenerating => state == 'generating';

  InferenceStatus copyWith({
    String? state,
    String? loadedModelPath,
    bool clearLoadedModelPath = false,
    String? currentRequestId,
    bool clearCurrentRequestId = false,
    String? assistantDraft,
    String? completedResponse,
    bool clearCompletedResponse = false,
    String? error,
    bool clearError = false,
    String? statusMessage,
  }) {
    return InferenceStatus(
      state: state ?? this.state,
      loadedModelPath: clearLoadedModelPath
          ? null
          : (loadedModelPath ?? this.loadedModelPath),
      currentRequestId: clearCurrentRequestId
          ? null
          : (currentRequestId ?? this.currentRequestId),
      assistantDraft: assistantDraft ?? this.assistantDraft,
      completedResponse: clearCompletedResponse
          ? null
          : (completedResponse ?? this.completedResponse),
      error: clearError ? null : (error ?? this.error),
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  static const idle = InferenceStatus(state: 'idle');
}

class GenerationRequest {
  const GenerationRequest({
    required this.prompt,
    required this.modelPath,
    required this.contextSize,
    required this.maxTokens,
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.gpuLayers,
  });

  final String prompt;
  final String modelPath;
  final int contextSize;
  final int maxTokens;
  final double temperature;
  final double topP;
  final int topK;
  final int gpuLayers;

  Map<String, Object> toMap() {
    return {
      'prompt': prompt,
      'modelPath': modelPath,
      'contextSize': contextSize,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'topP': topP,
      'topK': topK,
      'gpuLayers': gpuLayers,
    };
  }
}

class GenerationEvent {
  const GenerationEvent({
    required this.type,
    required this.requestId,
    this.text,
    this.message,
  });

  final String type;
  final String requestId;
  final String? text;
  final String? message;

  factory GenerationEvent.fromMap(Map<Object?, Object?> map) {
    return GenerationEvent(
      type: (map['type'] as String?) ?? 'unknown',
      requestId: (map['requestId'] as String?) ?? '',
      text: map['text'] as String?,
      message: map['message'] as String?,
    );
  }
}
