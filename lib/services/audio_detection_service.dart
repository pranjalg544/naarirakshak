import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

// ─────────────────────────────────────────────────────────────────────────────
// Public types
// ─────────────────────────────────────────────────────────────────────────────

/// Pipeline state machine: idle → listening → detecting → triggered.
enum DetectionState { idle, listening, detecting, triggered }

/// User-selectable sensitivity preset.
enum SensitivityLevel { low, medium, high }

/// A single frame of analysis data emitted at ~60 fps while listening.
class AudioDetectionSnapshot {
  final DetectionState state;

  /// Normalised RMS amplitude (0.0–1.0).
  final double amplitude;

  /// Weighted confidence score (0.0–1.0).
  final double confidence;

  /// Ratio of energy in the 1–4 kHz band vs. total.
  final double highFreqRatio;

  const AudioDetectionSnapshot({
    required this.state,
    this.amplitude = 0,
    this.confidence = 0,
    this.highFreqRatio = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

/// On-device audio detection service backed by the **Web Audio API**.
///
/// Captures microphone input, runs real-time FFT analysis, and flags sustained
/// high-amplitude, high-frequency sounds (screams / distress) using
/// signal-processing heuristics.
///
/// The classifier is intentionally isolated behind the [snapshots] and
/// [onDistressDetected] streams so that a real CNN / LSTM TFLite model can
/// replace the heuristic later without touching any consumer code.
class AudioDetectionService {
  // ── Web Audio objects ──────────────────────────────────────────────
  web.AudioContext? _ctx;
  web.AnalyserNode? _analyser;
  web.MediaStream? _mediaStream;
  JSUint8Array? _timeDataJS;
  JSUint8Array? _freqDataJS;

  // ── Internal state ─────────────────────────────────────────────────
  DetectionState _state = DetectionState.idle;
  SensitivityLevel _sensitivity = SensitivityLevel.medium;
  DateTime? _sustainStart;
  Timer? _loopTimer;

  // ── Public streams ─────────────────────────────────────────────────
  final _snapshots = StreamController<AudioDetectionSnapshot>.broadcast();
  final _triggers = StreamController<double>.broadcast();

  /// Real-time analysis snapshots (~60 fps while listening).
  Stream<AudioDetectionSnapshot> get snapshots => _snapshots.stream;

  /// Fires **once** when a sustained distress sound is confirmed.
  /// The payload is the detection confidence (0.0–1.0).
  Stream<double> get onDistressDetected => _triggers.stream;

  /// Current pipeline state.
  DetectionState get state => _state;

  /// Change the sensitivity preset (takes effect on next analysis frame).
  set sensitivity(SensitivityLevel level) => _sensitivity = level;

  // ── Thresholds ─────────────────────────────────────────────────────
  //  amp   – minimum RMS amplitude to consider "loud"
  //  freq  – minimum ratio of energy in the 1–4 kHz band
  //  ms    – how long both conditions must be sustained
  static const _thresholds = <SensitivityLevel, ({double amp, double freq, int ms})>{
    SensitivityLevel.low: (amp: 0.45, freq: 0.40, ms: 900),
    SensitivityLevel.medium: (amp: 0.30, freq: 0.35, ms: 600),
    SensitivityLevel.high: (amp: 0.20, freq: 0.28, ms: 400),
  };

  // ── Lifecycle ──────────────────────────────────────────────────────

  /// Request the microphone, wire the Web Audio graph, and start analysing.
  /// Returns `true` on success, `false` if permission is denied or unavailable.
  Future<bool> startListening() async {
    if (_state != DetectionState.idle) return true;

    try {
      // 1. Microphone access
      _mediaStream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;

      // 2. Web Audio graph: mic → analyser (no speakers)
      _ctx = web.AudioContext();
      _analyser = _ctx!.createAnalyser();
      _analyser!.fftSize = 2048;
      _analyser!.smoothingTimeConstant = 0.3;

      final source = _ctx!.createMediaStreamSource(_mediaStream!);
      source.connect(_analyser!);

      // 3. Pre-allocate FFT buffers
      final bins = _analyser!.frequencyBinCount;
      _timeDataJS = Uint8List(bins).toJS;
      _freqDataJS = Uint8List(bins).toJS;

      // 4. Start the analysis loop (~60 fps)
      _state = DetectionState.listening;
      _sustainStart = null;
      _emit();

      _loopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
        _analyzeFrame();
      });

      return true;
    } catch (_) {
      _state = DetectionState.idle;
      _emit();
      return false;
    }
  }

  /// Stop the microphone and release all Web Audio resources.
  void stopListening() {
    _loopTimer?.cancel();
    _loopTimer = null;

    // Stop every mic track
    final tracks = _mediaStream?.getTracks().toDart;
    if (tracks != null) {
      for (final t in tracks) {
        t.stop();
      }
    }

    _ctx?.close();
    _ctx = null;
    _analyser = null;
    _mediaStream = null;
    _timeDataJS = null;
    _freqDataJS = null;
    _state = DetectionState.idle;
    _sustainStart = null;
    _emit();
  }

  /// After the user cancels an auto-SOS countdown, resume listening.
  void resetAfterCancel() {
    if (_state == DetectionState.triggered) {
      _state = DetectionState.listening;
      _sustainStart = null;
      _emit();
    }
  }

  /// Permanently tear down – call when the service is no longer needed.
  void dispose() {
    stopListening();
    _snapshots.close();
    _triggers.close();
  }

  // ── Frame analysis ─────────────────────────────────────────────────

  void _analyzeFrame() {
    if (_analyser == null ||
        _state == DetectionState.idle ||
        _state == DetectionState.triggered) {
      return;
    }

    // ── Read raw data ───────────────────────────────────────────────
    _analyser!.getByteTimeDomainData(_timeDataJS!);
    _analyser!.getByteFrequencyData(_freqDataJS!);

    final timeData = _timeDataJS!.toDart;
    final freqData = _freqDataJS!.toDart;
    final bufLen = timeData.length;

    // ── RMS amplitude (0.0 – ~1.0) ─────────────────────────────────
    double sumSq = 0;
    for (int i = 0; i < bufLen; i++) {
      final v = (timeData[i] - 128) / 128.0;
      sumSq += v * v;
    }
    final amplitude = math.sqrt(sumSq / bufLen);

    // ── High-frequency energy ratio ─────────────────────────────────
    // Screams concentrate energy between 1 kHz and 4 kHz.
    final sampleRate = _ctx!.sampleRate.toDouble();
    final binWidth = sampleRate / _analyser!.fftSize;
    final lowBin = (1000 / binWidth).round();
    final highBin = math.min((4000 / binWidth).round(), bufLen - 1);

    double highEnergy = 0, totalEnergy = 0;
    for (int i = 0; i < bufLen; i++) {
      final e = freqData[i].toDouble();
      totalEnergy += e;
      if (i >= lowBin && i <= highBin) highEnergy += e;
    }
    final highFreqRatio = totalEnergy > 0 ? highEnergy / totalEnergy : 0.0;

    // ── Confidence ──────────────────────────────────────────────────
    final t = _thresholds[_sensitivity]!;
    final ampNorm = (amplitude / t.amp).clamp(0.0, 1.0);
    final freqNorm = (highFreqRatio / t.freq).clamp(0.0, 1.0);
    final confidence = ampNorm * 0.5 + freqNorm * 0.5;

    // ── Detection decision ──────────────────────────────────────────
    final isScreamLike = amplitude > t.amp && highFreqRatio > t.freq;

    if (isScreamLike) {
      _sustainStart ??= DateTime.now();
      _state = DetectionState.detecting;

      final elapsed = DateTime.now().difference(_sustainStart!).inMilliseconds;
      if (elapsed >= t.ms) {
        _state = DetectionState.triggered;
        _triggers.add(confidence);
      }
    } else {
      _sustainStart = null;
      if (_state == DetectionState.detecting) {
        _state = DetectionState.listening;
      }
    }

    _emit(amplitude: amplitude, confidence: confidence, highFreqRatio: highFreqRatio);
  }

  // ── Helpers ────────────────────────────────────────────────────────

  void _emit({double amplitude = 0, double confidence = 0, double highFreqRatio = 0}) {
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
