import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/database.dart';
import '../services/websocket_service.dart';
import '../services/sms_sender.dart';

/// Central application state managed with ChangeNotifier (Provider pattern).
class AppState extends ChangeNotifier {
  // Initialization state
  bool _initialized = false;
  bool get initialized => _initialized;

  // Theme state
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // Setup state
  bool _isSetupComplete = false;
  bool get isSetupComplete => _isSetupComplete;

  String _serverUrl = '';
  String get serverUrl => _serverUrl;

  String _deviceToken = '';
  String get deviceToken => _deviceToken;

  String _deviceUuid = '';
  String get deviceUuid => _deviceUuid;

  String _deviceName = '';
  String get deviceName => _deviceName;

  bool _devMode = false;
  bool get devMode => _devMode;

  // Connection state
  WsConnectionState _connectionState = WsConnectionState.disconnected;
  WsConnectionState get connectionState => _connectionState;

  // Service state
  bool _serviceRunning = false;
  bool get serviceRunning => _serviceRunning;

  // Device info
  String _deviceModel = '';
  String get deviceModel => _deviceModel;

  String _androidVersion = '';
  String get androidVersion => _androidVersion;

  String _carrier = '';
  String get carrier => _carrier;

  int _battery = 0;
  int get battery => _battery;

  int _signal = 0;
  int get signal => _signal;

  double? _latitude;
  double? get latitude => _latitude;

  double? _longitude;
  double? get longitude => _longitude;

  bool _useWhiteTheme = false;
  bool get useWhiteTheme => _useWhiteTheme;

  // SMS stats
  Map<String, int> _jobStats = {};
  Map<String, int> get jobStats => _jobStats;

  int _todayCount = 0;
  int get todayCount => _todayCount;

  // Recent jobs
  List<Map<String, dynamic>> _recentJobs = [];
  List<Map<String, dynamic>> get recentJobs => _recentJobs;

  // Logs
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  // Services
  WebSocketService? _wsService;
  ApiClient? _apiClient;
  final Battery _batteryPlugin = Battery();
  Timer? _sensorTimer;

  /// Initialize app state from persisted preferences.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isSetupComplete = prefs.getBool(AppConstants.prefIsSetupComplete) ?? false;
    _serverUrl = prefs.getString(AppConstants.prefServerUrl) ?? '';
    _deviceToken = prefs.getString(AppConstants.prefDeviceToken) ?? '';
    _deviceUuid = prefs.getString(AppConstants.prefDeviceUuid) ?? '';
    _deviceName = prefs.getString(AppConstants.prefDeviceName) ?? '';
    _serviceRunning = prefs.getBool(AppConstants.prefServiceEnabled) ?? false;

    // Load theme setting
    final themeStr = prefs.getString('theme_mode') ?? 'system';
    if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    _useWhiteTheme = prefs.getBool('use_white_theme') ?? false;
    _devMode = prefs.getBool('dev_mode') ?? false;

    // Load device info
    await _loadDeviceInfo();

    // Load job stats
    await refreshJobStats();

    // If setup is complete and service was running, auto-connect
    if (_isSetupComplete && _serviceRunning && _serverUrl.isNotEmpty && _deviceToken.isNotEmpty) {
      startService();
    }

    _initialized = true;
    notifyListeners();
  }

  void setUseWhiteTheme(bool value) async {
    _useWhiteTheme = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_white_theme', value);
    notifyListeners();
  }

  void setDevMode(bool value) async {
    _devMode = value;
    if (_wsService != null) {
      _wsService!.devMode = value;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_mode', value);
    _addLog('Developer Mode: ${value ? "ENABLED" : "DISABLED"}');
    notifyListeners();
  }

  /// Load hardware info about this device.
  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      _androidVersion = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
    } catch (_) {
      _deviceModel = 'Unknown';
      _androidVersion = 'Unknown';
    }

    // Battery
    try {
      _battery = await _batteryPlugin.batteryLevel;
    } catch (_) {
      _battery = -1;
    }
  }

  /// Register device with the server and save credentials.
  Future<void> registerDevice({
    required String serverUrl,
    required String deviceName,
  }) async {
    _serverUrl = serverUrl.trimRight().replaceAll(RegExp(r'/+$'), '');

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    // Fetch carrier and location before registering
    try {
      _carrier = await SmsSender.getCarrierName();
    } catch (_) {}

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          _latitude = position.latitude;
          _longitude = position.longitude;
        }
      }
    } catch (_) {}

    _apiClient = ApiClient(baseUrl: _serverUrl);

    final request = DeviceRegisterRequest(
      uuid: androidInfo.id,
      name: deviceName,
      model: '${androidInfo.manufacturer} ${androidInfo.model}',
      androidVersion: 'Android ${androidInfo.version.release}',
      carrier: _carrier.isNotEmpty ? _carrier : null,
      latitude: _latitude,
      longitude: _longitude,
    );

    final response = await _apiClient!.registerDevice(request);

    _deviceToken = response.token;
    _deviceUuid = response.deviceId;
    _deviceName = deviceName;
    _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
    _androidVersion = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
    _isSetupComplete = true;

    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefServerUrl, _serverUrl);
    await prefs.setString(AppConstants.prefDeviceToken, _deviceToken);
    await prefs.setString(AppConstants.prefDeviceUuid, _deviceUuid);
    await prefs.setString(AppConstants.prefDeviceName, _deviceName);
    await prefs.setBool(AppConstants.prefIsSetupComplete, true);

    _addLog('Device registered successfully as $_deviceUuid');
    notifyListeners();
  }

  /// Start the WebSocket service.
  void startService() {
    if (_serverUrl.isEmpty || _deviceToken.isEmpty) return;

    _wsService?.dispose();
    _wsService = WebSocketService(serverUrl: _serverUrl, token: _deviceToken);
    _wsService!.devMode = _devMode;

    _wsService!.onStateChanged = (state) {
      _connectionState = state;
      notifyListeners();
    };

    _wsService!.onSmsResult = (jobId, status) {
      refreshJobStats();
    };

    _wsService!.onLog = (message) {
      _addLog(message);
    };

    _wsService!.connect();
    _serviceRunning = true;

    // Start sensor monitoring
    _startSensorMonitoring();

    // Persist service state
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(AppConstants.prefServiceEnabled, true);
    });

    _addLog('Service started.');
    notifyListeners();
  }

  /// Stop the WebSocket service.
  void stopService() {
    _wsService?.disconnect();
    _wsService = null;
    _serviceRunning = false;
    _connectionState = WsConnectionState.disconnected;
    _sensorTimer?.cancel();

    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(AppConstants.prefServiceEnabled, false);
    });

    _addLog('Service stopped.');
    notifyListeners();
  }

  /// Toggle service on/off.
  void toggleService() {
    if (_serviceRunning) {
      stopService();
    } else {
      startService();
    }
  }

  /// Start monitoring battery and connectivity sensors.
  void _startSensorMonitoring() {
    _sensorTimer?.cancel();
    _sensorTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _updateSensorData();
    });
    _updateSensorData();
  }

  Future<void> _updateSensorData() async {
    try {
      _battery = await _batteryPlugin.batteryLevel;
    } catch (_) {}

    // Fetch Carrier from native side
    try {
      _carrier = await SmsSender.getCarrierName();
    } catch (_) {}

    // Fetch GPS coordinates
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          _latitude = position.latitude;
          _longitude = position.longitude;
        }
      }
    } catch (_) {}

    // Update WebSocket service with latest sensor data
    if (_wsService != null) {
      _wsService!.currentBattery = _battery;
      _wsService!.currentSignal = _signal;
      _wsService!.currentCarrier = _carrier.isNotEmpty ? _carrier : null;
      _wsService!.currentLatitude = _latitude;
      _wsService!.currentLongitude = _longitude;
    }

    notifyListeners();
  }

  /// Refresh SMS job statistics from local database.
  Future<void> refreshJobStats() async {
    _jobStats = await AppDatabase.getJobStats();
    _todayCount = await AppDatabase.getTodayJobCount();
    _recentJobs = await AppDatabase.getRecentJobs(limit: 20);
    notifyListeners();
  }

  /// Reset setup and clear all persisted data.
  Future<void> resetSetup() async {
    stopService();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isSetupComplete = false;
    _serverUrl = '';
    _deviceToken = '';
    _deviceUuid = '';
    _deviceName = '';
    _addLog('Setup reset. All data cleared.');
    notifyListeners();
  }

  /// Test server connection.
  Future<bool> testConnection(String serverUrl) async {
    final client = ApiClient(baseUrl: serverUrl.trimRight().replaceAll(RegExp(r'/+$'), ''));
    return await client.ping();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(0, '[$timestamp] $message');
    if (_logs.length > 200) {
      _logs.removeRange(200, _logs.length);
    }
    notifyListeners();
  }

  /// Update server URL dynamically and restart WebSocket service if active.
  Future<void> updateServerUrl(String newUrl) async {
    _serverUrl = newUrl.trimRight().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefServerUrl, _serverUrl);
    _addLog('Server URL updated to $_serverUrl');
    
    // Reset connection if running
    if (_serviceRunning) {
      _addLog('Restarting background service with new URL...');
      stopService();
      startService();
    }
    notifyListeners();
  }

  /// Change theme mode dynamically and persist.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    String themeStr = 'system';
    if (mode == ThemeMode.dark) themeStr = 'dark';
    if (mode == ThemeMode.light) themeStr = 'light';
    await prefs.setString('theme_mode', themeStr);
    _addLog('Theme changed to $themeStr');
  }

  @override
  void dispose() {
    _wsService?.dispose();
    _sensorTimer?.cancel();
    super.dispose();
  }
}
