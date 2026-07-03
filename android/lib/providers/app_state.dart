import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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

    // Check if background service is running
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      _serviceRunning = true;
      _setupBackgroundServiceListeners(service);
    } else if (_isSetupComplete && _serviceRunning && _serverUrl.isNotEmpty && _deviceToken.isNotEmpty) {
      startService();
    }

    _initialized = true;
    notifyListeners();
  }

  void _setupBackgroundServiceListeners(FlutterBackgroundService service) {
    service.on('connection_state').listen((event) {
      if (event != null) {
        final stateStr = event['state'] as String;
        _connectionState = WsConnectionState.values.firstWhere(
          (e) => e.name == stateStr,
          orElse: () => WsConnectionState.disconnected,
        );
        notifyListeners();
      }
    });

    service.on('log').listen((event) {
      if (event != null) {
        final msg = event['message'] as String;
        _addLogDirectly(msg);
      }
    });

    service.on('sms_result').listen((event) {
      refreshJobStats();
    });

    service.on('sensor_update').listen((event) {
      if (event != null) {
        if (event['battery'] != null) _battery = event['battery'] as int;
        if (event['carrier'] != null) _carrier = event['carrier'] as String;
        if (event['latitude'] != null) _latitude = event['latitude'] as double;
        if (event['longitude'] != null) _longitude = event['longitude'] as double;
        notifyListeners();
      }
    });
  }

  void _addLogDirectly(String message) {
    _logs.insert(0, message);
    if (_logs.length > 200) {
      _logs.removeRange(200, _logs.length);
    }
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_mode', value);
    _addLog('Developer Mode: ${value ? "ENABLED" : "DISABLED"}');
    
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('update_config', {
        'dev_mode': value,
      });
    }
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

  /// Start the Background service.
  void startService() async {
    if (_serverUrl.isEmpty || _deviceToken.isEmpty) return;

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }

    _setupBackgroundServiceListeners(service);
    _serviceRunning = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefServiceEnabled, true);

    _addLog('Background service started.');
    notifyListeners();
  }

  /// Stop the Background service.
  void stopService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('stop_service');
    }
    _serviceRunning = false;
    _connectionState = WsConnectionState.disconnected;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefServiceEnabled, false);

    _addLog('Background service stopped.');
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
    _urlUpdate(newUrl);
  }

  Future<void> _urlUpdate(String newUrl) async {
    _serverUrl = newUrl.trimRight().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefServerUrl, _serverUrl);
    _addLog('Server URL updated to $_serverUrl');
    
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (isRunning) {
      service.invoke('update_config', {
        'server_url': _serverUrl,
        'token': _deviceToken,
      });
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
