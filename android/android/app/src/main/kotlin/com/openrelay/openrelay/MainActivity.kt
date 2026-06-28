package com.openrelay.openrelay

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.openrelay.app/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> {
                        val to = call.argument<String>("to")
                        val message = call.argument<String>("message")
                        if (to != null && message != null) {
                            sendSms(to, message, result)
                        } else {
                            result.error("INVALID_ARGS", "Missing 'to' or 'message'", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun sendSms(to: String, message: String, result: MethodChannel.Result) {
        try {
            val sentAction = "SMS_SENT_${System.currentTimeMillis()}"
            val deliveredAction = "SMS_DELIVERED_${System.currentTimeMillis()}"

            val sentIntent = PendingIntent.getBroadcast(
                this, 0,
                Intent(sentAction),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val deliveredIntent = PendingIntent.getBroadcast(
                this, 0,
                Intent(deliveredAction),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            // Register receiver for send result
            val sentReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    try {
                        unregisterReceiver(this)
                    } catch (_: Exception) {}

                    when (resultCode) {
                        Activity.RESULT_OK -> result.success("SENT")
                        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> result.success("FAILED:GENERIC_FAILURE")
                        SmsManager.RESULT_ERROR_NO_SERVICE -> result.success("FAILED:NO_SERVICE")
                        SmsManager.RESULT_ERROR_NULL_PDU -> result.success("FAILED:NULL_PDU")
                        SmsManager.RESULT_ERROR_RADIO_OFF -> result.success("FAILED:RADIO_OFF")
                        else -> result.success("FAILED:UNKNOWN")
                    }
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(sentReceiver, IntentFilter(sentAction), Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(sentReceiver, IntentFilter(sentAction))
            }

            // Send the SMS
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            // Handle multipart messages
            val parts = smsManager.divideMessage(message)
            if (parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent>()
                for (i in parts.indices) {
                    sentIntents.add(sentIntent)
                }
                smsManager.sendMultipartTextMessage(to, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(to, null, message, sentIntent, deliveredIntent)
            }
        } catch (e: Exception) {
            result.success("FAILED:${e.message}")
        }
    }
}
