import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../constants.dart';
import '../models/models.dart';
import 'database.dart';
import 'sms_sender.dart';

/// Connection state for the WebSocket.
enum WsConnectionState { disconnected, connecting, connected }

/// Manages WebSocket connection to the OpenRelay backend.
/// Handles receiving SMS commands, sending results, and status updates.
class WebSocketService {
  final String serverUrl;
  final String token;

  WebSocketChannel? _channel;
  Timer? _statusTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _intentionalDisconnect = false;

  WsConnectionState _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  // Callbacks
  void Function(WsConnectionState state)? onStateChanged;
  void Function(String jobId, String status)? onSmsResult;
  void Function(String message)? onLog;

  // Status data (set externally by the provider)
  int? currentBattery;
  int? currentSignal;
  String? currentCarrier;
  double? currentLatitude;
  double? currentLongitude;

  WebSocketService({required this.serverUrl, required this.token});

  /// Connect to the WebSocket server.
  void connect() {
    if (_state == WsConnectionState.connected || _state == WsConnectionState.connecting) {
      return;
    }

    _intentionalDisconnect = false;
    _setState(WsConnectionState.connecting);
    _log('Connecting to server...');

    try {
      // Build WebSocket URL: convert http(s) to ws(s)
      String wsUrl = serverUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      // Remove trailing slash if present
      if (wsUrl.endsWith('/')) {
        wsUrl = wsUrl.substring(0, wsUrl.length - 1);
      }
      wsUrl = '$wsUrl/ws/device?token=$token';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: _onError,
      );

      // Mark as connected after successful channel creation
      _setState(WsConnectionState.connected);
      _reconnectAttempts = 0;
      _log('Connected to server successfully.');

      // Start periodic status updates
      _startStatusUpdates();
    } catch (e) {
      _log('Connection error: $e');
      _setState(WsConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Disconnect from the WebSocket server.
  void disconnect() {
    _intentionalDisconnect = true;
    _stopStatusUpdates();
    _reconnectTimer?.cancel();
    _channel?.sink.close(ws_status.goingAway);
    _channel = null;
    _setState(WsConnectionState.disconnected);
    _log('Disconnected from server.');
  }

  /// Handle incoming WebSocket messages.
  void _onMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;

      if (type == 'SEND_SMS') {
        _handleSmsCommand(SmsCommand.fromJson(message));
      } else {
        _log('Received unknown message type: $type');
      }
    } catch (e) {
      _log('Error parsing message: $e');
    }
  }

  /// Process an incoming SMS send command.
  Future<void> _handleSmsCommand(SmsCommand command) async {
    _log('SMS Job ${command.jobId}: Sending to ${command.to}');

    // Save to local database
    await AppDatabase.insertJob(
      jobId: command.jobId,
      recipient: command.to,
      message: command.message,
      status: 'SENDING',
    );

    // Send SMS via native platform
    final status = await SmsSender.sendSms(
      to: command.to,
      message: command.message,
    );

    // Determine result
    final resultStatus = status.startsWith('SENT') ? 'SENT' : 'FAILED';

    // Update local database
    await AppDatabase.updateJobStatus(command.jobId, resultStatus);

    // Send result back to server
    final result = SmsResult(
      type: 'RESULT',
      jobId: command.jobId,
      status: resultStatus,
    );
    _sendMessage(result.toJson());

    _log('SMS Job ${command.jobId}: $resultStatus');
    onSmsResult?.call(command.jobId, resultStatus);
  }

  /// Send a JSON message through the WebSocket.
  void _sendMessage(Map<String, dynamic> message) {
    if (_state == WsConnectionState.connected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        _log('Error sending message: $e');
      }
    }
  }

  /// Start periodic status update broadcasts.
  void _startStatusUpdates() {
    _stopStatusUpdates();
    _statusTimer = Timer.periodic(
      Duration(seconds: AppConstants.statusUpdateIntervalSeconds),
      (_) => _sendStatusUpdate(),
    );
    // Send an immediate status update
    _sendStatusUpdate();
  }

  void _stopStatusUpdates() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  /// Send current device status to the server.
  void _sendStatusUpdate() {
    final update = StatusUpdate(
      battery: currentBattery,
      signal: currentSignal,
      carrier: currentCarrier,
      latitude: currentLatitude,
      longitude: currentLongitude,
    );
    _sendMessage(update.toJson());
  }

  /// Handle WebSocket disconnection.
  void _onDisconnected() {
    _setState(WsConnectionState.disconnected);
    _stopStatusUpdates();
    _channel = null;
    _log('WebSocket connection closed.');

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  /// Handle WebSocket errors.
  void _onError(dynamic error) {
    _log('WebSocket error: $error');
    _setState(WsConnectionState.disconnected);
    _stopStatusUpdates();
    _channel = null;

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  /// Schedule a reconnection attempt with exponential backoff.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delayMs = min(
      AppConstants.wsReconnectBaseDelayMs * pow(2, _reconnectAttempts - 1),
      AppConstants.wsReconnectMaxDelayMs,
    ).toInt();
    _log('Reconnecting in ${delayMs}ms (attempt $_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), connect);
  }

  void _setState(WsConnectionState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  void _log(String message) {
    onLog?.call('[WS] $message');
  }

  /// Clean up resources.
  void dispose() {
    disconnect();
    _reconnectTimer?.cancel();
  }
}
