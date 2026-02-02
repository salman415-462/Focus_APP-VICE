package core.blocker.enforcement

import android.app.Service
import android.content.Context
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import com.example.my_first_app.R

class OverlayController(private val context: Context) {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayShowing = false

    init {
        windowManager = context.getSystemService(Service.WINDOW_SERVICE) as WindowManager
    }

    fun showOverlay(message: String) {
        if (isOverlayShowing) {
            updateOverlayMessage(message)
            return
        }

        try {
            val layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
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
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun showOverlayWithAutoRemove(message: String, delayMillis: Long = 2500) {
        showOverlay(message)
        overlayView?.postDelayed({
            removeOverlay()
        }, delayMillis)
    }

    fun updateOverlayMessage(message: String) {
        if (!isOverlayShowing || overlayView == null) return

        try {
            val messageTextView = overlayView?.findViewById<TextView>(R.id.overlay_message)
            messageTextView?.text = message
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun removeOverlay() {
        if (!isOverlayShowing || overlayView == null) return

        try {
            windowManager?.removeView(overlayView)
            overlayView = null
            isOverlayShowing = false
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun isShowing(): Boolean = isOverlayShowing
}
