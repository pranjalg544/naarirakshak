// Web fallback stub for tflite_flutter (since dart:ffi is not available on web browsers)
import 'package:flutter/foundation.dart';

class Interpreter {
  static Future<Interpreter> fromAsset(String assetName) async {
    debugPrint('TFLite: Native FFI unavailable on Web browser. Falling back to web mock interpreter.');
    return Interpreter();
  }

  void run(Object input, Object output) {
    // Web dummy run
  }

  void close() {}

  Tensor getInputTensor(int index) => Tensor();
  Tensor getOutputTensor(int index) => Tensor();
}

class Tensor {
  List<int> get shape => [1, 24000, 1];
}
