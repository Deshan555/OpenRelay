package com.openrelay.sms_channel

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList

class SmsChannelPlugin : FlutterPlugin {
    private val SMS_CHANNEL = "com.openrelay.app/sms"
    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, SMS_CHANNEL)
        channel?.setMethodCallHandler { call, result ->
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
                "getCarrierName" -> {
                    try {
                        val tm = context?.getSystemService(Context.TELEPHONY_SERVICE) as android.telephony.TelephonyManager
                        result.success(tm.networkOperatorName ?: "Unknown")
                    } catch (e: Exception) {
                        result.success("Unknown")
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    private fun sendSms(to: String, message: String, result: MethodChannel.Result) {
        val ctx = context ?: return result.error("NO_CONTEXT", "Application context is null", null)
        try {
            val sentAction = "SMS_SENT_${System.currentTimeMillis()}"
            val deliveredAction = "SMS_DELIVERED_${System.currentTimeMillis()}"

            val sentIntent = PendingIntent.getBroadcast(
                ctx, 0,
                Intent(sentAction),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val deliveredIntent = PendingIntent.getBroadcast(
                ctx, 0,
                Intent(deliveredAction),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val sentReceiver = object : BroadcastReceiver() {
                override fun onReceive(c: Context?, intent: Intent?) {
                    try {
                        ctx.unregisterReceiver(this)
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
                ctx.registerReceiver(sentReceiver, IntentFilter(sentAction), Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(sentReceiver, IntentFilter(sentAction))
            }

            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                ctx.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

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
