import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'tflite_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public types
// ─────────────────────────────────────────────────────────────────────────────

enum DetectionState { idle, listening, detecting, triggered }
enum SensitivityLevel { low, medium, high }

class AudioDetectionSnapshot {
  final DetectionState state;
  final double amplitude;
  final double confidence;
  final double highFreqRatio;

  const AudioDetectionSnapshot({
    required this.state,
    this.amplitude = 0,
    this.confidence = 0,
    this.highFreqRatio = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Service — On-device scream detection using TFLite 1D CNN on raw audio.
//
// Model details (from ml/train_scream_detector_v2.py):
//   - Input:  [1, 24000, 1]  (3 seconds at 8000 Hz, mono, normalized float32)
//   - Output: [1, 1]         (sigmoid probability: 0.0 = not scream, 1.0 = scream)
//   - Architecture: 4-block 1D CNN with BatchNorm, GlobalAvgPool, Dropout
//   - Test AUC: 0.9678, Accuracy: ~91%
//   - On-device only. Raw audio is never uploaded unless SOS is triggered.
// ─────────────────────────────────────────────────────────────────────────────

class AudioDetectionService {
  // ── Audio & ML objects ─────────────────────────────────────────────
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _audioStreamSub;
  Interpreter? _interpreter;

  // ── Internal state ─────────────────────────────────────────────────
  DetectionState _state = DetectionState.idle;
  SensitivityLevel _sensitivity = SensitivityLevel.medium;
  
  // Buffer to hold raw audio samples (PCM 16-bit → normalized float32)
  final List<double> _audioBuffer = [];

  // Must match the training config in ml/train_scream_detector_v2.py
  static const int _sampleRate = 8000;
  static const int _clipDurationSeconds = 3;
  static const int _requiredSamples = _sampleRate * _clipDurationSeconds; // 24000

  // Consecutive detection counter for false-positive reduction
  int _consecutiveDetections = 0;

  // ── Public streams ─────────────────────────────────────────────────
  final _snapshots = StreamController<AudioDetectionSnapshot>.broadcast();
  final _triggers = StreamController<double>.broadcast();

  Stream<AudioDetectionSnapshot> get snapshots => _snapshots.stream;
  Stream<double> get onDistressDetected => _triggers.stream;
  DetectionState get state => _state;
  set sensitivity(SensitivityLevel level) => _sensitivity = level;

  // ── Thresholds & Consecutive rules ──────────────────────────────────
  static const _thresholds = <SensitivityLevel, double>{
    SensitivityLevel.low: 0.85,    // Conservative — minimal false positives
    SensitivityLevel.medium: 0.60, // Balanced — responsive to screams
    SensitivityLevel.high: 0.50,   // High — fast trigger
  };

  static const _requiredConsecutiveMap = <SensitivityLevel, int>{
    SensitivityLevel.low: 2,
    SensitivityLevel.medium: 1,
    SensitivityLevel.high: 1,
  };

  // ── Lifecycle ──────────────────────────────────────────────────────

  Future<bool> startListening() async {
    if (_state != DetectionState.idle) return true;

    try {
      // 1. Check microphone permissions
      if (!await _audioRecorder.hasPermission()) {
        debugPrint('AudioDetection: Microphone permission denied');
        return false;
      }

      // 2. Load TFLite Model (lazy — only loads once)
      _interpreter ??= await Interpreter.fromAsset('assets/scream_detector.tflite');
      debugPrint('AudioDetection: TFLite model loaded successfully');
      debugPrint('  Input shape:  ${_interpreter!.getInputTensor(0).shape}');
      debugPrint('  Output shape: ${_interpreter!.getOutputTensor(0).shape}');

      // 3. Start audio recording stream (PCM 16-bit, Mono, 8000 Hz)
      final recordStream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ));

      _state = DetectionState.listening;
      _audioBuffer.clear();
      _consecutiveDetections = 0;
      _emit();

      // 4. Process incoming audio chunks
      _audioStreamSub = recordStream.listen(
        (data) => _processAudioChunk(data),
        onError: (err) {
          debugPrint('AudioDetection: Stream error: $err');
          _state = DetectionState.idle;
          _emit();
        },
      );

      return true;
    } catch (e) {
      debugPrint('AudioDetection: Startup error: $e');
      _state = DetectionState.idle;
      _emit();
      return false;
    }
  }

  void stopListening() {
    _audioStreamSub?.cancel();
    _audioStreamSub = null;
    _audioRecorder.stop();
    _state = DetectionState.idle;
    _audioBuffer.clear();
    _consecutiveDetections = 0;
    _emit();
  }

  void resetAfterCancel() {
    if (_state == DetectionState.triggered) {
      _state = DetectionState.listening;
      _audioBuffer.clear();
      _consecutiveDetections = 0;
      _emit();
    }
  }

  void dispose() {
    stopListening();
    _audioRecorder.dispose();
    _interpreter?.close();
    _snapshots.close();
    _triggers.close();
  }

  // ── Audio chunk processing ────────────────────────────────────────

  void _processAudioChunk(List<int> pcmData) {
    if (_state == DetectionState.idle || _state == DetectionState.triggered) {
      return;
    }

    // Convert 16-bit PCM (little-endian bytes) to normalized floats [-1.0, 1.0]
    final byteData = ByteData.view(Uint8List.fromList(pcmData).buffer);
    for (int i = 0; i < byteData.lengthInBytes - 1; i += 2) {
      final sample = byteData.getInt16(i, Endian.little) / 32768.0;
      _audioBuffer.add(sample);
    }

    // Compute running amplitude for UI visualization
    if (_audioBuffer.length >= 512) {
      final recent = _audioBuffer.sublist(_audioBuffer.length - 512);
      final rms = math.sqrt(
        recent.fold<double>(0.0, (sum, s) => sum + s * s) / recent.length,
      );
      _emit(amplitude: rms.clamp(0.0, 1.0));
    }

    // Every time we have 3 seconds of audio, run inference
    if (_audioBuffer.length >= _requiredSamples) {
      // Take the latest 3 seconds
      final analysisBuffer = _audioBuffer.sublist(
        _audioBuffer.length - _requiredSamples,
      );

      // Keep only the last 1.5 seconds to create a 50% sliding window overlap
      // This matches the training data augmentation strategy
      _audioBuffer.removeRange(0, _requiredSamples ~/ 2);

      _runInference(analysisBuffer);
    }
  }

  // ── TFLite inference ──────────────────────────────────────────────

  void _runInference(List<double> samples) {
    if (_interpreter == null) return;

    // Normalize to match librosa.util.normalize() used during training:
    // Scale so that max(abs(samples)) == 1.0
    double maxAbs = 0.0;
    for (final s in samples) {
      final abs = s.abs();
      if (abs > maxAbs) maxAbs = abs;
    }
    final List<double> normalized;
    if (maxAbs >= 0.025) {
      normalized = samples.map((s) => s / maxAbs).toList();
    } else {
      // Quiet background noise / silence — skip inference to avoid scaling up noise
      _state = DetectionState.listening;
      _consecutiveDetections = 0;
      _emit(confidence: 0.0);
      return;
    }

    // Reshape for model input: [1, 24000, 1]
    final input = [normalized.map((e) => [e]).toList()];

    // Model output: [1, 1] containing sigmoid scream probability
    final output = List.filled(1, List.filled(1, 0.0));

    try {
      _interpreter!.run(input, output);
      final double screamProbability = output[0][0];
      final threshold = _thresholds[_sensitivity]!;
      final requiredConsecutive = _requiredConsecutiveMap[_sensitivity]!;

      if (screamProbability >= threshold) {
        _consecutiveDetections++;
        if (_consecutiveDetections >= requiredConsecutive) {
          // Confirmed distress — trigger SOS pipeline
          _state = DetectionState.triggered;
          _triggers.add(screamProbability);
          debugPrint(
            'AudioDetection: ⚠️ DISTRESS TRIGGERED '
            '(confidence: ${(screamProbability * 100).toStringAsFixed(1)}%, '
            'threshold: ${(threshold * 100).toStringAsFixed(0)}%, '
            'consecutive: $_consecutiveDetections)',
          );
        } else {
          // Elevated — need one more window to confirm
          _state = DetectionState.detecting;
          debugPrint(
            'AudioDetection: 🔶 Elevated '
            '(confidence: ${(screamProbability * 100).toStringAsFixed(1)}%, '
            'need ${requiredConsecutive - _consecutiveDetections} more)',
          );
        }
      } else if (screamProbability >= threshold * 0.7) {
        // Slightly elevated but not above threshold — reset consecutive counter
        _state = DetectionState.detecting;
        _consecutiveDetections = 0;
      } else {
        // Normal — all clear
        _state = DetectionState.listening;
        _consecutiveDetections = 0;
      }

      _emit(confidence: screamProbability);
    } catch (e) {
      debugPrint('AudioDetection: Inference error: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  void _emit({
    double amplitude = 0,
    double confidence = 0,
    double highFreqRatio = 0,
  }) {
    if (!_snapshots.isClosed) {
      _snapshots.add(AudioDetectionSnapshot(
        state: _state,
        amplitude: amplitude,
        confidence: confidence,
        highFreqRatio: highFreqRatio,
      ));
    }
  }
}
