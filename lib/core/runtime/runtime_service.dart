import 'package:flutter/services.dart';

import 'runtime_models.dart';

class RuntimeService {
  static const MethodChannel _channel = MethodChannel(
    'chatty_mini/runtime_bridge',
  );

  Future<RuntimeStatus> getRuntimeStatus({
    required String runtimeDirPath,
  }) async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getRuntimeStatus',
      {'runtimeDirPath': runtimeDirPath},
    );
    return RuntimeStatus.fromMap(result ?? const {});
  }
}
