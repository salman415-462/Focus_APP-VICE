package core.blocker.enforcement

import android.app.Service
import android.content.Context
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import android.util.Log
import com.example.my_first_app.R

class OverlayController(private val context: Context) {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayShowing = false

    init {
        // Use application context but get WindowManager properly
        windowManager = context.getSystemService(Service.WINDOW_SERVICE) as WindowManager
        Log.d(TAG, "OverlayController initialized")
    }

    fun showOverlay(message: String) {
        if (isOverlayShowing && overlayView != null) {
            Log.d(TAG, "Overlay already showing, updating message: $message")
            updateOverlayMessage(message)
            return
        }

        try {
            Log.d(TAG, "Creating overlay with message: $message")

            // Create layout params with proper flags for accessibility service context
            val layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }

            val inflater = context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
            overlayView = inflater.inflate(R.layout.block_overlay, null)

            val messageTextView = overlayView?.findViewById<TextView>(R.id.overlay_message)
            messageTextView?.text = message

            windowManager?.addView(overlayView, layoutParams)
            isOverlayShowing = true
            Log.d(TAG, "Overlay added successfully")
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException adding overlay - permission may have been revoked", e)
            isOverlayShowing = false
            overlayView = null
        } catch (e: Exception) {
            Log.e(TAG, "Exception adding overlay", e)
            isOverlayShowing = false
            overlayView = null
        }
    }

    fun showOverlayWithAutoRemove(message: String, delayMillis: Long = 2500) {
        showOverlay(message)
        overlayView?.postDelayed({
            removeOverlay()
        }, delayMillis)
    }

    fun updateOverlayMessage(message: String) {
        if (!isOverlayShowing || overlayView == null) {
            Log.d(TAG, "updateOverlayMessage: overlay not showing, ignoring")
            return
        }

        try {
            val messageTextView = overlayView?.findViewById<TextView>(R.id.overlay_message)
            messageTextView?.text = message
            Log.d(TAG, "Overlay message updated to: $message")
        } catch (e: Exception) {
            Log.e(TAG, "Exception updating overlay message", e)
        }
    }

    fun removeOverlay() {
        if (!isOverlayShowing || overlayView == null) {
            Log.d(TAG, "removeOverlay: overlay not showing, ignoring")
            return
        }

        try {
            windowManager?.removeView(overlayView)
            overlayView = null
            isOverlayShowing = false
            Log.d(TAG, "Overlay removed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Exception removing overlay", e)
            // Force reset state even on failure
            overlayView = null
            isOverlayShowing = false
        }
    }

    fun isShowing(): Boolean = isOverlayShowing

    companion object {
        private const val TAG = "OverlayController"
    }
}

