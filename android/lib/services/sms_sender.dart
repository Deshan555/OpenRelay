import 'dart:async';
import 'package:flutter/services.dart';

/// Platform channel bridge for native Android SMS operations.
/// Uses MethodChannel to call native Kotlin code for SmsManager.
class SmsSender {
  static const MethodChannel _channel = MethodChannel('com.openrelay.app/sms');

  /// Send an SMS message via Android's native SmsManager.
  /// Returns the delivery status: 'SENT', 'FAILED', or 'GENERIC_FAILURE'.
  static Future<String> sendSms({
    required String to,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('sendSms', {
        'to': to,
        'message': message,
      });
      return result ?? 'FAILED';
    } on PlatformException catch (e) {
      return 'FAILED: ${e.message}';
    }
  }

  /// Get the carrier name from native TelephonyManager.
  static Future<String> getCarrierName() async {
    try {
      final result = await _channel.invokeMethod<String>('getCarrierName');
      return result ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }
}
