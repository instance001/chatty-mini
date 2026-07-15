class InferenceConfig {
  const InferenceConfig({
    required this.id,
    required this.label,
    required this.description,
    required this.contextSize,
    required this.maxTokens,
    required this.temperature,
    required this.topP,
    required this.topK,
    required this.gpuLayers,
  });

  final String id;
  final String label;
  final String description;
  final int contextSize;
  final int maxTokens;
  final double temperature;
  final double topP;
  final int topK;
  final int gpuLayers;

  Map<String, Object> toMap() {
    return {
      'id': id,
      'contextSize': contextSize,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'topP': topP,
      'topK': topK,
      'gpuLayers': gpuLayers,
    };
  }
}

const inferencePresets = <InferenceConfig>[
  InferenceConfig(
    id: 'balanced_mobile',
    label: 'Balanced Mobile',
    description: 'Default small-phone chat preset with cautious memory use.',
    contextSize: 1536,
    maxTokens: 256,
    temperature: 0.72,
    topP: 0.92,
    topK: 40,
    gpuLayers: 0,
  ),
  InferenceConfig(
    id: 'tight_mobile',
    label: 'Tight Mobile',
    description: 'Lower memory use and shorter replies for weaker phones.',
    contextSize: 1024,
    maxTokens: 160,
    temperature: 0.64,
    topP: 0.9,
    topK: 32,
    gpuLayers: 0,
  ),
  InferenceConfig(
    id: 'roomy_mobile',
    label: 'Roomy Mobile',
    description: 'Longer context and output for stronger devices.',
    contextSize: 2048,
    maxTokens: 384,
    temperature: 0.78,
    topP: 0.94,
    topK: 48,
    gpuLayers: 0,
  ),
  InferenceConfig(
    id: 'tiny_summary',
    label: 'Tiny Summary',
    description: 'Short, conservative bookkeeper profile for summaries.',
    contextSize: 768,
    maxTokens: 192,
    temperature: 0.35,
    topP: 0.88,
    topK: 24,
    gpuLayers: 0,
  ),
];

InferenceConfig inferencePresetById(String? id) {
  for (final preset in inferencePresets) {
    if (preset.id == id) {
      return preset;
    }
  }
  return inferencePresets.first;
}
