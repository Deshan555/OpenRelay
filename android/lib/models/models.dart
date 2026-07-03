// Data models matching the FastAPI backend schemas.

class DeviceRegisterRequest {
  final String uuid;
  final String? name;
  final String? model;
  final String? androidVersion;
  final String? carrier;
  final double? latitude;
  final double? longitude;

  DeviceRegisterRequest({
    required this.uuid,
    this.name,
    this.model,
    this.androidVersion,
    this.carrier,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    if (name != null) 'name': name,
    if (model != null) 'model': model,
    if (androidVersion != null) 'android_version': androidVersion,
    if (carrier != null) 'carrier': carrier,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}

class DeviceRegisterResponse {
  final String deviceId;
  final String token;

  DeviceRegisterResponse({required this.deviceId, required this.token});

  factory DeviceRegisterResponse.fromJson(Map<String, dynamic> json) {
    return DeviceRegisterResponse(
      deviceId: (json['device_id'] ?? json['deviceId']) as String,
      token: json['token'] as String,
    );
  }
}

class DeviceInfo {
  final String uuid;
  final String? name;
  final String? model;
  final String? androidVersion;
  final int? battery;
  final String? carrier;
  final int? signal;
  final String status;
  final String? lastSeen;
  final double? latitude;
  final double? longitude;

  DeviceInfo({
    required this.uuid,
    this.name,
    this.model,
    this.androidVersion,
    this.battery,
    this.carrier,
    this.signal,
    required this.status,
    this.lastSeen,
    this.latitude,
    this.longitude,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      uuid: json['uuid'] as String,
      name: json['name'] as String?,
      model: json['model'] as String?,
      androidVersion: json['android_version'] as String?,
      battery: json['battery'] as int?,
      carrier: json['carrier'] as String?,
      signal: json['signal'] as int?,
      status: json['status'] as String,
      lastSeen: json['last_seen'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

/// WebSocket incoming command to send an SMS.
class SmsCommand {
  final String type;
  final String jobId;
  final String to;
  final String message;

  SmsCommand({
    required this.type,
    required this.jobId,
    required this.to,
    required this.message,
  });

  factory SmsCommand.fromJson(Map<String, dynamic> json) {
    return SmsCommand(
      type: json['type'] as String,
      jobId: (json['job_id'] ?? json['jobId'] ?? '') as String,
      to: json['to'] as String,
      message: json['message'] as String,
    );
  }
}

/// WebSocket outgoing result after sending SMS.
class SmsResult {
  final String type;
  final String jobId;
  final String status;

  SmsResult({
    required this.type,
    required this.jobId,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'job_id': jobId,
    'status': status,
  };
}

/// WebSocket outgoing status update.
class StatusUpdate {
  final String type;
  final int? battery;
  final int? signal;
  final String? carrier;
  final double? latitude;
  final double? longitude;

  StatusUpdate({
    this.type = 'STATUS_UPDATE',
    this.battery,
    this.signal,
    this.carrier,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    if (battery != null) 'battery': battery,
    if (signal != null) 'signal': signal,
    if (carrier != null) 'carrier': carrier,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}
