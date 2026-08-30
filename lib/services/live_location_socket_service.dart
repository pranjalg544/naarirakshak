import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class LiveLocationSocketService {
  static final LiveLocationSocketService _instance = LiveLocationSocketService._internal();
  factory LiveLocationSocketService() => _instance;
  LiveLocationSocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  String? _activeTrackingToken;

  bool get isConnected => _isConnected;

  void connect({String serverUrl = 'http://localhost:3000'}) {
    if (_socket != null && _isConnected) return;

    _socket = io.io(serverUrl, io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableAutoConnect()
        .build());

    _socket?.onConnect((_) {
      _isConnected = true;
      if (kDebugMode) {
        print('📡 Connected to NaariRakshak Socket.io Gateway');
      }
      if (_activeTrackingToken != null) {
        joinTrackingRoom(_activeTrackingToken!);
      }
    });

    _socket?.onDisconnect((_) {
      _isConnected = false;
      if (kDebugMode) {
        print('🔌 Disconnected from Socket.io Gateway');
      }
    });

    _socket?.onError((err) {
      if (kDebugMode) {
        print('❌ Socket error: $err');
      }
    });
  }

  void joinTrackingRoom(String trackingToken) {
    _activeTrackingToken = trackingToken;
    _socket?.emit('join_tracking_room', trackingToken);
  }

  void sendTelemetry({
    required String trackingToken,
    required String incidentId,
    required double lat,
    required double lng,
    double speed = 0.0,
    double heading = 0.0,
    int batteryLevel = 100,
  }) {
    if (_socket == null || !_isConnected) {
      connect();
    }

    _socket?.emit('telemetry_update', {
      'trackingToken': trackingToken,
      'incidentId': incidentId,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'heading': heading,
      'batteryLevel': batteryLevel,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
  }
}
