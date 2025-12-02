package com.huddlecommunity.better_native_video_player.handlers

import android.app.Activity
import android.os.Build
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.core.app.PictureInPictureModeChangedInfo
import androidx.core.util.Consumer

/**
 * Handles Picture-in-Picture mode change detection for Android
 * Sends pipStart and pipStop events to Flutter when PiP mode changes
 */
class PictureInPictureHandler(
    private val onPipModeChanged: (isInPipMode: Boolean) -> Unit
) {
    companion object {
        private const val TAG = "PictureInPictureHandler"
    }

    private var activity: Activity? = null
    private var pipModeChangedListener: Consumer<PictureInPictureModeChangedInfo>? = null
    private var isInPipMode: Boolean = false

    /**
     * Attaches the handler to an activity to listen for PiP mode changes
     * PiP is only available on Android O (API 26) and above
     */
    fun attach(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.d(TAG, "PiP not supported on API < 26")
            return
        }

        this.activity = activity

        // Check if the activity supports PiP mode change callbacks
        if (activity is ComponentActivity) {
            Log.d(TAG, "Attaching PiP listener to ComponentActivity")

            pipModeChangedListener = Consumer { info ->
                val newPipMode = info.isInPictureInPictureMode
                if (newPipMode != isInPipMode) {
                    isInPipMode = newPipMode
                    Log.d(TAG, "PiP mode changed: $isInPipMode")
                    onPipModeChanged(isInPipMode)
                }
            }

            activity.addOnPictureInPictureModeChangedListener(pipModeChangedListener!!)
            Log.d(TAG, "PiP listener attached successfully")
        } else {
            Log.w(TAG, "Activity is not a ComponentActivity, PiP detection may not work")
        }

        // Check initial PiP state
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            isInPipMode = activity.isInPictureInPictureMode
            if (isInPipMode) {
                Log.d(TAG, "Activity is already in PiP mode")
                onPipModeChanged(true)
            }
        }
    }

    /**
     * Detaches the handler from the activity
     */
    fun detach() {
        val currentActivity = activity
        val listener = pipModeChangedListener

        if (currentActivity is ComponentActivity && listener != null) {
            Log.d(TAG, "Removing PiP listener from ComponentActivity")
            currentActivity.removeOnPictureInPictureModeChangedListener(listener)
        }

        activity = null
        pipModeChangedListener = null
        isInPipMode = false
    }

    /**
     * Returns whether the app is currently in PiP mode
     */
    fun isInPictureInPictureMode(): Boolean = isInPipMode
}
