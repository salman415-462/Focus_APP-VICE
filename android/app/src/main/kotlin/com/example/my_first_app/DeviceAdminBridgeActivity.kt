package com.example.my_first_app

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.os.Parcelable
import core.blocker.enforcement.BlockAdminReceiver

class DeviceAdminBridgeActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val admin = ComponentName(this, core.blocker.enforcement.BlockAdminReceiver::class.java)

        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(
                DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                admin as Parcelable
            )
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "Required to prevent app deletion and enforce focus lock."
            )
            // MIUI FIX: Add FLAG_ACTIVITY_NEW_TASK to ensure proper navigation
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        // Start admin request
        startActivityForResult(intent, REQUEST_CODE_DEVICE_ADMIN)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_DEVICE_ADMIN) {
            // Set flag in SharedPreferences to notify MainActivity to refresh permissions
            setRefreshPermissionsFlag(true)

            // Finish the activity
            finish()
        }
    }

    private fun setRefreshPermissionsFlag(flag: Boolean) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_REFRESH_PERMISSIONS, flag).apply()
    }

    companion object {
        private const val REQUEST_CODE_DEVICE_ADMIN = 1001
        private const val PREFS_NAME = MethodChannelHandler.PREFS_NAME
        private const val KEY_REFRESH_PERMISSIONS = MethodChannelHandler.KEY_REFRESH_PERMISSIONS
    }
}

