// Web fallback interpreter for tflite_flutter (when running in browsers where dart:ffi is unavailable).
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class Interpreter {
  static Future<Interpreter> fromAsset(String assetName) async {
    debugPrint('TFLite: Web fallback audio analyzer initialized.');
    return Interpreter();
  }

  void run(Object input, Object output) {
    try {
      if (input is List && input.isNotEmpty) {
        final rawSamples = input[0] as List;
        final doubleProb = _analyzeWebAudio(rawSamples);
        if (output is List && output.isNotEmpty && output[0] is List) {
          (output[0] as List)[0] = doubleProb;
        }
      }
    } catch (e) {
      debugPrint('TFLite Web fallback error: $e');
    }
  }

  double _analyzeWebAudio(List rawSamples) {
    if (rawSamples.isEmpty) return 0.0;
    
    // Extract double sample array
    final samples = <double>[];
    for (final item in rawSamples) {
      if (item is List && item.isNotEmpty) {
        samples.add((item[0] as num).toDouble());
      } else if (item is num) {
        samples.add(item.toDouble());
      }
    }

    if (samples.length < 1000) return 0.0;

    // 1. RMS Energy
    double sumSq = 0.0;
    double maxAbs = 0.0;
    int zeroCrossings = 0;

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      final absVal = s.abs();
      sumSq += s * s;
      if (absVal > maxAbs) maxAbs = absVal;

      if (i > 0) {
        if ((samples[i] >= 0 && samples[i - 1] < 0) || (samples[i] < 0 && samples[i - 1] >= 0)) {
          zeroCrossings++;
        }
      }
    }

    final double rms = math.sqrt(sumSq / samples.length);
    final double zcr = zeroCrossings / samples.length;

    // Screams feature high energy (RMS > 0.20), high peak (maxAbs > 0.60), and high ZCR (0.10 - 0.45)
    if (rms > 0.22 && maxAbs > 0.65 && zcr > 0.08 && zcr < 0.45) {
      final double score = (0.75 + (rms * 0.5) + (zcr * 0.3)).clamp(0.0, 0.99);
      debugPrint('AudioDetection Web: 🚨 Scream signature detected! RMS=${rms.toStringAsFixed(3)}, ZCR=${zcr.toStringAsFixed(3)}, Score=${score.toStringAsFixed(2)}');
      return score;
    }

    return 0.05;
  }

  void close() {}

  Tensor getInputTensor(int index) => Tensor();
  Tensor getOutputTensor(int index) => Tensor();
}

class Tensor {
  List<int> get shape => [1, 24000, 1];
}
