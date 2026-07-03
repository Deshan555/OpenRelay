import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../constants.dart';
import '../models/models.dart';
import 'database.dart';
import 'sms_sender.dart';
import 'websocket_service.dart';

const String notificationChannelId = 'openrelay_foreground';
const int notificationId = 888;

/// Configures and initializes the background service.
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Create standard notification channel for foreground service
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'OpenRelay Background Service',
    description: 'Keeps OpenRelay SMS gateway active in the background.',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'OpenRelay Gateway',
      initialNotificationContent: 'Active and waiting for SMS requests',
      foregroundServiceNotificationId: notificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // Load configs
  final prefs = await SharedPreferences.getInstance();
  String serverUrl = prefs.getString(AppConstants.prefServerUrl) ?? '';
  String token = prefs.getString(AppConstants.prefDeviceToken) ?? '';
  bool devMode = prefs.getBool('dev_mode') ?? false;

  if (serverUrl.isEmpty || token.isEmpty) {
    service.stopSelf();
    return;
  }

  WebSocketService? wsService;
  Timer? sensorTimer;
  final batteryPlugin = Battery();

  void logToService(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    service.invoke('log', {'message': '[$timestamp] [BG] $message'});
  }

  void stopEverything() {
    sensorTimer?.cancel();
    wsService?.dispose();
    service.stopSelf();
    logToService('Background service stopped.');
  }

  void startWebSocket() {
    wsService?.dispose();
    wsService = WebSocketService(serverUrl: serverUrl, token: token);
    wsService!.devMode = devMode;

    wsService!.onStateChanged = (state) {
      service.invoke('connection_state', {'state': state.name});
    };

    wsService!.onLog = (message) {
      logToService(message);
    };

    wsService!.onSmsResult = (jobId, status) {
      service.invoke('sms_result', {'jobId': jobId, 'status': status});
    };

    wsService!.connect();
    logToService('WebSocket connection started.');
  }

  Future<void> updateSensors() async {
    int? batteryVal;
    try {
      batteryVal = await batteryPlugin.batteryLevel;
      wsService?.currentBattery = batteryVal;
    } catch (_) {}

    String? carrierVal;
    try {
      carrierVal = await SmsSender.getCarrierName();
      wsService?.currentCarrier = carrierVal.isNotEmpty ? carrierVal : null;
    } catch (_) {}

    double? lat;
    double? lng;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          lat = position.latitude;
          lng = position.longitude;
          wsService?.currentLatitude = lat;
          wsService?.currentLongitude = lng;
        }
      }
    } catch (_) {}

    service.invoke('sensor_update', {
      'battery': batteryVal,
      'carrier': carrierVal,
      'latitude': lat,
      'longitude': lng,
    });
  }

  // Start WS
  startWebSocket();

  // Poll sensor data every 15 seconds
  sensorTimer = Timer.periodic(const Duration(seconds: 15), (_) => updateSensors());
  updateSensors();

  // Listen to config updates from UI
  service.on('update_config').listen((event) async {
    final updatedPrefs = await SharedPreferences.getInstance();
    await updatedPrefs.reload();

    if (event != null) {
      if (event['server_url'] != null) {
        serverUrl = event['server_url'] as String;
      } else {
        serverUrl = updatedPrefs.getString(AppConstants.prefServerUrl) ?? '';
      }
      
      if (event['token'] != null) {
        token = event['token'] as String;
      } else {
        token = updatedPrefs.getString(AppConstants.prefDeviceToken) ?? '';
      }
      
      if (event['dev_mode'] != null) {
        devMode = event['dev_mode'] as bool;
      } else {
        devMode = updatedPrefs.getBool('dev_mode') ?? false;
      }
    } else {
      serverUrl = updatedPrefs.getString(AppConstants.prefServerUrl) ?? '';
      token = updatedPrefs.getString(AppConstants.prefDeviceToken) ?? '';
      devMode = updatedPrefs.getBool('dev_mode') ?? false;
    }

    logToService('Config updated (devMode: $devMode), restarting WebSocket connection...');
    startWebSocket();
    updateSensors();
  });

  // Listen to stop signal
  service.on('stop_service').listen((event) {
    stopEverything();
  });
}
