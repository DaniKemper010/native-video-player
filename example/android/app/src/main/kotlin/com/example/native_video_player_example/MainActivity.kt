package com.example.native_video_player_example

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private var pipEventChannel: EventChannel? = null
    private var pipEventSink: EventChannel.EventSink? = null

    override fun onPostResume() {
        super.onPostResume()
        setupPipEventChannel()
    }

    private fun setupPipEventChannel() {
        if (pipEventChannel == null && flutterEngine != null) {
            pipEventChannel = EventChannel(flutterEngine!!.dartExecutor.binaryMessenger, "native_video_player_pip_events")
            pipEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d(TAG, "PiP event channel listener attached")
                    pipEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    Log.d(TAG, "PiP event channel listener cancelled")
                    pipEventSink = null
                }
            })
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        Log.d(TAG, "PiP mode changed: $isInPictureInPictureMode")

        // Restore ExoPlayer controls when exiting PiP
        if (!isInPictureInPictureMode) {
            try {
                val allViews = com.huddlecommunity.native_video_player.NativeVideoPlayerPlugin.getAllViews()
                allViews.forEach { view ->
                    view.onExitPictureInPicture()
                }
                Log.d(TAG, "Restored controls for ${allViews.size} video players")
            } catch (e: Exception) {
                Log.e(TAG, "Error restoring controls: ${e.message}", e)
            }
        }

        // Send event to Flutter
        pipEventSink?.success(mapOf(
            "event" to if (isInPictureInPictureMode) "pipStart" else "pipStop",
            "isInPictureInPictureMode" to isInPictureInPictureMode
        ))
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        Log.d(TAG, "onUserLeaveHint called - user pressed home button")

        // Note: Automatic PiP on home button is disabled because it minimizes the entire app
        // Users should use the PiP button in the UI to enter PiP mode manually
        // This keeps the app usable while video is in PiP

        // Uncomment below to enable automatic PiP when home button is pressed:
        /*
        try {
            val allViews = com.huddlecommunity.native_video_player.NativeVideoPlayerPlugin.getAllViews()
            Log.d(TAG, "Found ${allViews.size} registered video players")

            for (view in allViews) {
                if (view.tryAutoPictureInPicture()) {
                    Log.d(TAG, "Successfully entered auto PiP mode")
                    return // Only enter PiP for the first playing video
                }
            }
            Log.d(TAG, "No video entered auto PiP mode")
        } catch (e: Exception) {
            Log.e(TAG, "Error trying auto PiP: ${e.message}", e)
        }
        */
    }
}
