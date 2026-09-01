// Conditional export: uses tflite_flutter on native platforms (Windows/Android/iOS)
// and tflite_web stub on Web (Chrome/Edge) where dart:ffi is unavailable.
export 'tflite_web.dart'
    if (dart.library.ffi) 'package:tflite_flutter/tflite_flutter.dart';
