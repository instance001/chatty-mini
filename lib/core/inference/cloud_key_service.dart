import 'package:flutter/services.dart';

class CloudKeyService {
  static const _channel = MethodChannel('chatty_mini/cloud_keys');

  Future<void> save(String providerId, String apiKey) => _channel.invokeMethod(
    'save',
    {'providerId': providerId, 'apiKey': apiKey},
  );

  Future<String?> read(String providerId) =>
      _channel.invokeMethod<String>('read', {'providerId': providerId});

  Future<void> delete(String providerId) =>
      _channel.invokeMethod('delete', {'providerId': providerId});

  Future<bool> has(String providerId) async =>
      await _channel.invokeMethod<bool>('has', {'providerId': providerId}) ??
      false;
}
