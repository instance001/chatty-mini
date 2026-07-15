import 'package:flutter/services.dart';

class ModelImportService {
  static const MethodChannel _channel = MethodChannel(
    'chatty_mini/model_import_bridge',
  );

  Future<List<String>> importModels({required String modelsDirPath}) async {
    final result = await _channel.invokeListMethod<Object?>('importModels', {
      'modelsDirPath': modelsDirPath,
    });
    return (result ?? const []).map((item) => item.toString()).toList();
  }
}
