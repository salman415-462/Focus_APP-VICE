package com.example.my_first_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class PermissionRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("PermRefresh", "Received refresh intent: ${intent?.action}")
        // No-op: receiver exists to satisfy manifest registration and to allow
        // the app to respond to ACTION_REFRESH_PERMISSIONS if needed elsewhere.
    }
}
