package com.openrelay.openrelay

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony

/// Receiver for incoming SMS messages. Forwards them as notifications.
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            for (message in messages) {
                val sender = message.displayOriginatingAddress
                val body = message.displayMessageBody
                // Future: Forward incoming SMS to server via Flutter method channel
                // For now, just log it
                android.util.Log.d("OpenRelay", "Incoming SMS from $sender: $body")
            }
        }
    }
}
