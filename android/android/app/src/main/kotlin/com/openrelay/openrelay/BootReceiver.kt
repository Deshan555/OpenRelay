package com.openrelay.openrelay

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// Receiver that starts the OpenRelay service when the device boots.
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // The Flutter app will auto-start the WebSocket service
            // when it initializes and checks shared preferences.
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (launchIntent != null) {
                context.startActivity(launchIntent)
            }
        }
    }
}
