package com.example.my_first_app

import android.content.Context
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle

class MainActivity: FlutterActivity() {

    private lateinit var methodChannelHandler: MethodChannelHandler
    private var pendingPermissionRefresh = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        methodChannelHandler = MethodChannelHandler(this)
        checkAndProcessPendingPermissionRefresh()
    }

    override fun onResume() {
        super.onResume()
        checkAndProcessPendingPermissionRefresh()
    }

    private fun checkAndProcessPendingPermissionRefresh() {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val shouldRefresh = prefs.getBoolean(KEY_REFRESH_PERMISSIONS, false)
        if (shouldRefresh) {
            prefs.edit().remove(KEY_REFRESH_PERMISSIONS).apply()
            pendingPermissionRefresh = true
            notifyFlutterToRefresh()
        }
    }

    private fun notifyFlutterToRefresh() {
        try {
            val binaryMessenger = flutterEngine?.dartExecutor?.binaryMessenger ?: run {
                pendingPermissionRefresh = true
                return
            }
            val channel = MethodChannel(
                binaryMessenger,
                MethodChannelHandler.CHANNEL_NAME
            )
            channel.invokeMethod(MethodChannelHandler.METHOD_REFRESH_PERMISSIONS, null)
            pendingPermissionRefresh = false
        } catch (e: Exception) {
            pendingPermissionRefresh = true
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        setupMethodChannel()
        if (pendingPermissionRefresh) {
            notifyFlutterToRefresh()
        }
    }

    private fun setupMethodChannel() {
        val binaryMessenger = flutterEngine?.dartExecutor?.binaryMessenger ?: return
        val channel = MethodChannel(
            binaryMessenger,
            MethodChannelHandler.CHANNEL_NAME
        )

        channel.setMethodCallHandler { call, result ->
            methodChannelHandler.handleMethodCall(call, result)
        }
    }

    companion object {
        private const val PREFS_NAME = MethodChannelHandler.PREFS_NAME
        private const val KEY_REFRESH_PERMISSIONS = MethodChannelHandler.KEY_REFRESH_PERMISSIONS
    }
}

