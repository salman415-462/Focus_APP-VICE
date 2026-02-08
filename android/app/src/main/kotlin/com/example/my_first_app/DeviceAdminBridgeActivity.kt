package com.example.my_first_app

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.util.Log
import core.blocker.enforcement.BlockAdminReceiver

/**
 * Minimal bridge Activity for Device Admin activation on MIUI/HyperOS.
 * 
 * MIUI blocks ACTION_ADD_DEVICE_ADMIN when launched from non-foreground context.
 * This transparent Activity provides a proper foreground context for the intent.
 * 
 * Key rules:
 * - NO FLAG_ACTIVITY_NEW_TASK on the admin intent
 * - Finish immediately after launching (not startActivityForResult)
 */
class DeviceAdminBridgeActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "DeviceAdminBridgeActivity onCreate")

        val admin = ComponentName(this, BlockAdminReceiver::class.java)

        // Create the device admin intent
        // CRITICAL: Do NOT add any flags to this intent
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, admin)
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "This app needs device administrator permission to block distracting apps."
            )
        }

        Log.d(TAG, "Launching device admin intent from foreground Activity")
        
        // Launch the intent - MIUI will now allow it because we're in a foreground Activity
        startActivity(intent)
        
        // Finish immediately - the device admin dialog will stay visible
        Log.d(TAG, "Finishing bridge Activity")
        finish()
    }

    companion object {
        private const val TAG = "DeviceAdminBridge"
    }
}

