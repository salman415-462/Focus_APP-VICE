package com.example.my_first_app

import android.app.Activity
import android.os.Bundle
import android.view.WindowManager
import android.widget.TextView
import core.blocker.enforcement.OverlayController

class OverlayActivity : Activity() {

    private lateinit var overlayController: OverlayController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Make activity fullscreen and overlay
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )

        // Prevent activity from appearing in recent apps
        // (already set in manifest with excludeFromRecents="true")

        overlayController = OverlayController(this)

        // Get message from intent or use default
        val message = intent.getStringExtra("message") ?: "Apps are blocked"

        // Show overlay
        overlayController.showOverlay(message)
    }

    override fun onDestroy() {
        super.onDestroy()
        overlayController.removeOverlay()
    }

    override fun onBackPressed() {
        // Prevent back button from closing the overlay
        // User must use proper bypass mechanism
    }
}
