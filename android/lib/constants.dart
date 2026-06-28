/// Application-wide constants for the OpenRelay SMS Gateway app.
class AppConstants {
  // SharedPreferences keys
  static const String prefServerUrl = 'server_url';
  static const String prefDeviceToken = 'device_token';
  static const String prefDeviceUuid = 'device_uuid';
  static const String prefDeviceName = 'device_name';
  static const String prefIsSetupComplete = 'is_setup_complete';
  static const String prefServiceEnabled = 'service_enabled';

  // WebSocket
  static const int wsReconnectBaseDelayMs = 1000;
  static const int wsReconnectMaxDelayMs = 30000;
  static const int statusUpdateIntervalSeconds = 30;

  // Notification
  static const String notificationChannelId = 'openrelay_service';
  static const String notificationChannelName = 'OpenRelay Service';
  static const int notificationId = 888;

  // Database
  static const String dbName = 'openrelay.db';
  static const int dbVersion = 1;
}
