import 'package:flutter/foundation.dart';

import 'runtime_models.dart';
import 'runtime_service.dart';

class RuntimeController extends ChangeNotifier {
  RuntimeController({required this.service});

  final RuntimeService service;

  bool _isLoading = false;
  String? _error;
  RuntimeStatus _status = RuntimeStatus.initial;
  String? _runtimeDirPath;

  bool get isLoading => _isLoading;
  String? get error => _error;
  RuntimeStatus get status => _status;

  Future<void> initialize({required String runtimeDirPath}) async {
    _runtimeDirPath = runtimeDirPath;
    await refresh();
  }

  Future<void> refresh() async {
    final runtimeDirPath = _runtimeDirPath;
    if (runtimeDirPath == null) {
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      _status = await service.getRuntimeStatus(runtimeDirPath: runtimeDirPath);
      _error = null;
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
