package com.example.native_video_player_example

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import com.huddlecommunity.better_native_video_player.VideoPlayerView

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private var pipEventChannel: EventChannel? = null
    private var pipEventSink: EventChannel.EventSink? = null
    private var isInPipMode = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity onCreate called")
    }

    override fun onPostResume() {
        super.onPostResume()
        Log.d(TAG, "onPostResume called")
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
        Log.d(TAG, "⚠️ PiP mode changed: $isInPictureInPictureMode")

        // Update PiP state
        isInPipMode = isInPictureInPictureMode

        // Restore ExoPlayer controls when exiting PiP
        if (!isInPictureInPictureMode) {
            try {
                val allViews = com.huddlecommunity.better_native_video_player.NativeVideoPlayerPlugin.getAllViews()
                allViews.forEach { view: VideoPlayerView ->
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
        Log.d(TAG, "⚠️ onUserLeaveHint called - user pressed home button")

        tryEnterAutoPip("onUserLeaveHint")
    }

    override fun onStop() {
        Log.d(TAG, "⚠️ onStop called - isInPipMode: $isInPipMode, isFinishing: $isFinishing")

        // If onUserLeaveHint wasn't called (common on some Android versions),
        // try to enter PiP here when the app goes to background
        if (!isInPipMode && !isFinishing) {
            Log.d(TAG, "⚠️ onStop: Attempting PiP as onUserLeaveHint may not have been called")
            tryEnterAutoPip("onStop")
        }

        super.onStop()
    }

    private fun tryEnterAutoPip(calledFrom: String) {
        Log.d(TAG, "⚠️ tryEnterAutoPip called from: $calledFrom")

        // Automatically enter PiP mode when home button is pressed if video is playing
        try {
            val allViews = com.huddlecommunity.better_native_video_player.NativeVideoPlayerPlugin.getAllViews()
            Log.d(TAG, "⚠️ Found ${allViews.size} registered video players")

            for (view in allViews) {
                if (view.tryAutoPictureInPicture()) {
                    Log.d(TAG, "⚠️ Successfully entered auto PiP mode from $calledFrom")
                    isInPipMode = true
                    return // Only enter PiP for the first playing video
                }
            }
            Log.d(TAG, "⚠️ No video entered auto PiP mode from $calledFrom")
        } catch (e: Exception) {
            Log.e(TAG, "⚠️ Error trying auto PiP from $calledFrom: ${e.message}", e)
        }
    }
}
