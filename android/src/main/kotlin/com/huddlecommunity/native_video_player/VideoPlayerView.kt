package com.huddlecommunity.native_video_player

import android.app.Activity
import android.app.Dialog
import android.app.PictureInPictureParams
import android.content.Context
import android.content.pm.ActivityInfo
import android.os.Build
import android.util.Log
import android.util.Rational
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.annotation.RequiresApi
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.huddlecommunity.native_video_player.handlers.VideoPlayerEventHandler
import com.huddlecommunity.native_video_player.handlers.VideoPlayerMethodHandler
import com.huddlecommunity.native_video_player.handlers.VideoPlayerNotificationHandler
import com.huddlecommunity.native_video_player.handlers.VideoPlayerObserver
import com.huddlecommunity.native_video_player.manager.SharedPlayerManager
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Main platform view for the native video player
 * Handles fullscreen natively without creating multiple platform views
 */
@UnstableApi
class VideoPlayerView(
    private val context: Context,
    private val viewId: Long,
    private val args: Map<String, Any>?,
    private val binaryMessenger: io.flutter.plugin.common.BinaryMessenger
) : PlatformView {

    companion object {
        private const val TAG = "VideoPlayerView"
    }

    private val playerView: PlayerView
    private val player: ExoPlayer
    private val controllerId: Int?

    // Container that holds the player view
    // This is what Flutter sees - the player view can be moved in/out of it
    private val containerView: FrameLayout

    // Handlers
    private val eventHandler: VideoPlayerEventHandler
    private val notificationHandler: VideoPlayerNotificationHandler
    private val methodHandler: VideoPlayerMethodHandler
    private val observer: VideoPlayerObserver

    // Channels
    private val methodChannel: MethodChannel
    private val eventChannel: EventChannel

    // Track fullscreen state
    private var isFullScreen: Boolean = false

    // Track disposal state to prevent events after disposal
    private var isDisposed: Boolean = false

    // Fullscreen dialog
    private var fullscreenDialog: Dialog? = null

    // Store original system UI flags and orientation
    private var originalSystemUiVisibility: Int = 0
    private var originalOrientation: Int = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED


    init {
        Log.d(TAG, "Creating VideoPlayerView with id: $viewId")

        // Extract controller ID from args
        controllerId = args?.get("controllerId") as? Int

        // Extract initial fullscreen state from args
        isFullScreen = args?.get("isFullScreen") as? Boolean ?: false
        Log.d(TAG, "Initial fullscreen state: $isFullScreen")

        // Get or create shared player
        player = if (controllerId != null) {
            Log.d(TAG, "Using shared player for controller ID: $controllerId")
            SharedPlayerManager.getOrCreatePlayer(context, controllerId)
        } else {
            Log.d(TAG, "No controller ID provided, creating new player")
            ExoPlayer.Builder(context).build()
        }

        // Create PlayerView and attach player
        playerView = PlayerView(context).apply {
            this.player = this@VideoPlayerView.player
            useController = args?.get("showNativeControls") as? Boolean ?: true
            controllerShowTimeoutMs = 5000
            controllerHideOnTouch = true

            // Configure PiP from args
            val allowsPiP = args?.get("allowsPictureInPicture") as? Boolean ?: true
            if (allowsPiP && context is Activity) {
                Log.d(TAG, "PiP enabled for this player")
            }

            Log.d(TAG, "PlayerView configured")
        }

        // Create container view that holds the player view
        // This allows us to move the player view in/out for fullscreen
        containerView = FrameLayout(context).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            addView(playerView, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ))
        }

        // Set up fullscreen button listener after PlayerView is configured
        playerView.post {
            playerView.setFullscreenButtonClickListener { enteringFullScreen ->
                Log.d(TAG, "Fullscreen button clicked, entering fullscreen: $enteringFullScreen")
                handleFullscreenToggleNative(enteringFullScreen)
            }
        }

        // Setup event handler
        eventHandler = VideoPlayerEventHandler()

        // Setup notification handler (shared for shared players)
        notificationHandler = if (controllerId != null) {
            val handler = SharedPlayerManager.getOrCreateNotificationHandler(context, controllerId, player, eventHandler)
            // Update event handler for shared notification handler (in case it's being reused)
            handler.updateEventHandler(eventHandler)
            handler
        } else {
            VideoPlayerNotificationHandler(context, player, eventHandler)
        }

        // Setup method handler
        methodHandler = VideoPlayerMethodHandler(player, eventHandler, notificationHandler)

        // Set fullscreen callback for method handler
        methodHandler.onFullscreenRequest = { enterFullscreen ->
            handleFullscreenToggleNative(enterFullscreen)
        }

        // Setup observer
        observer = VideoPlayerObserver(player, eventHandler)
        player.addListener(observer)

        // Setup method channel
        val channelName = "native_video_player"
        methodChannel = MethodChannel(binaryMessenger, channelName)
        methodChannel.setMethodCallHandler { call, result ->
            Log.d(TAG, "Received method call: ${call.method}")
            handleMethodCall(call, result)
        }

        // Setup event channel
        val eventChannelName = "native_video_player_$viewId"
        eventChannel = EventChannel(binaryMessenger, eventChannelName)
        eventChannel.setStreamHandler(eventHandler)

        Log.d(TAG, "VideoPlayerView initialized")
    }

    override fun getView(): View {
        // Return the container view, not the player view directly
        // This allows us to move the player view in/out for fullscreen
        return containerView
    }

    /**
     * Handles method calls from Flutter
     */
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isPictureInPictureAvailable" -> {
                checkPictureInPictureAvailability(result)
            }
            "enterPictureInPicture" -> {
                enterPictureInPicture(result)
            }
            else -> {
                methodHandler.handleMethodCall(call, result)
            }
        }
    }

    /**
     * Checks if Picture-in-Picture is available on this device
     */
    private fun checkPictureInPictureAvailability(result: MethodChannel.Result) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val activity = getActivity(context)
            if (activity != null) {
                val packageManager = activity.packageManager
                val hasPipFeature = packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)
                result.success(hasPipFeature)
            } else {
                result.success(false)
            }
        } else {
            result.success(false)
        }
    }

    /**
     * Handles fullscreen toggle natively by moving the player view between container and fullscreen dialog
     * This uses ONE PlayerView instead of creating multiple platform views
     */
    private fun handleFullscreenToggleNative(enteringFullScreen: Boolean) {
        // Don't handle fullscreen if already disposed
        if (isDisposed) {
            Log.d(TAG, "Ignoring fullscreen toggle - view is disposed")
            return
        }

        // Get activity from plugin (most reliable) or context
        val activity = NativeVideoPlayerPlugin.getActivity() ?: getActivity(context)
        if (activity == null) {
            Log.e(TAG, "Cannot get Activity, cannot handle fullscreen")
            return
        }

        Log.d(TAG, "Got activity: ${activity.javaClass.simpleName}")

        if (enteringFullScreen) {
            enterFullscreenNative(activity)
        } else {
            exitFullscreenNative(activity)
        }

        // Update internal state
        isFullScreen = enteringFullScreen
    }

    /**
     * Gets the Activity from a Context, handling ContextWrapper cases
     */
    private fun getActivity(context: Context?): Activity? {
        if (context == null) {
            Log.e(TAG, "Context is null")
            return null
        }

        Log.d(TAG, "Context type: ${context.javaClass.name}")

        if (context is Activity) {
            Log.d(TAG, "Context is Activity")
            return context
        }

        if (context is android.content.ContextWrapper) {
            Log.d(TAG, "Context is ContextWrapper, unwrapping...")
            return getActivity(context.baseContext)
        }

        Log.e(TAG, "Context is neither Activity nor ContextWrapper")
        return null
    }

    /**
     * Enters fullscreen by removing the player view from the container and adding it to a fullscreen dialog
     */
    private fun enterFullscreenNative(activity: Activity) {
        Log.d(TAG, "Entering fullscreen natively")

        // Store original orientation
        originalOrientation = activity.requestedOrientation

        // Hide system UI on the activity window
        activity.window?.let { activityWindow ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val controller = WindowCompat.getInsetsController(activityWindow, activityWindow.decorView)
                controller.hide(WindowInsetsCompat.Type.systemBars())
                controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            } else {
                @Suppress("DEPRECATION")
                activityWindow.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    )
            }
        }

        // Remove player view from container (important: remove from parent first!)
        (playerView.parent as? ViewGroup)?.removeView(playerView)

        // Create fullscreen dialog with black background and no title bar
        fullscreenDialog = Dialog(activity, android.R.style.Theme_Black_NoTitleBar_Fullscreen).apply {
            setContentView(playerView)

            // Handle back button to exit fullscreen
            setOnKeyListener { _, keyCode, event ->
                if (keyCode == android.view.KeyEvent.KEYCODE_BACK && event.action == android.view.KeyEvent.ACTION_UP) {
                    // Trigger the fullscreen button to exit
                    playerView.post {
                        // Simulate clicking the fullscreen button to exit
                        handleFullscreenToggleNative(false)
                    }
                    true
                } else {
                    false
                }
            }

            // Handle dialog dismissal
            setOnDismissListener {
                // Ensure we exit fullscreen if dialog is dismissed
                if (isFullScreen) {
                    exitFullscreenNative(activity)
                    isFullScreen = false
                }
            }

            show()
        }

        // Set fullscreen mode on dialog window
        fullscreenDialog?.window?.let { window ->
            // Make dialog cover the entire screen including status bar and navigation bar
            window.setLayout(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT
            )

            // Draw over the status bar and navigation bar areas
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                window.attributes.layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }

            // Set window flags to cover everything
            window.setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN
                    or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                    or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN
                    or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                    or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+ API
                window.setDecorFitsSystemWindows(false)
                val controller = WindowCompat.getInsetsController(window, window.decorView)
                controller.hide(WindowInsetsCompat.Type.systemBars())
                controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    )
            }

            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }

        // Allow all orientations in fullscreen
        activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR

        Log.d(TAG, "Entered fullscreen natively")
    }

    /**
     * Exits fullscreen by removing the player view from the dialog and adding it back to the container
     */
    private fun exitFullscreenNative(activity: Activity) {
        Log.d(TAG, "Exiting fullscreen natively")

        fullscreenDialog?.let { dialog ->
            // Remove player view from dialog
            (playerView.parent as? ViewGroup)?.removeView(playerView)

            // Dismiss dialog
            dialog.dismiss()
            fullscreenDialog = null
        }

        // Add player view back to container
        if (playerView.parent == null) {
            containerView.addView(playerView, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            ))
        }

        // Restore system UI on the activity window
        activity.window?.let { activityWindow ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val controller = WindowCompat.getInsetsController(activityWindow, activityWindow.decorView)
                controller.show(WindowInsetsCompat.Type.systemBars())
            } else {
                @Suppress("DEPRECATION")
                activityWindow.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
            }
        }

        // Restore original orientation
        activity.requestedOrientation = originalOrientation

        Log.d(TAG, "Exited fullscreen natively")
    }

    /**
     * Enter Picture-in-Picture mode
     */
    private fun enterPictureInPicture(result: MethodChannel.Result) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val activity = getActivity(context)
            if (activity != null) {
                val aspectRatio = player.videoSize.let { size ->
                    if (size.width > 0 && size.height > 0) {
                        android.util.Rational(size.width, size.height)
                    } else {
                        android.util.Rational(16, 9)
                    }
                }

                val params = android.app.PictureInPictureParams.Builder()
                    .setAspectRatio(aspectRatio)
                    .build()

                val entered = activity.enterPictureInPictureMode(params)
                if (entered) {
                    eventHandler.sendEvent("pictureInPictureStatusChanged", mapOf("isPictureInPicture" to true))
                    result.success(true)
                } else {
                    result.error("PIP_FAILED", "Failed to enter PiP mode", null)
                }
            } else {
                result.error("NO_ACTIVITY", "Context is not an Activity", null)
            }
        } else {
            result.error("NOT_SUPPORTED", "PiP not supported on this Android version", null)
        }
    }

    override fun dispose() {
        Log.d(TAG, "VideoPlayerView dispose for id: $viewId")

        // Mark as disposed to prevent any further events
        isDisposed = true

        // Exit fullscreen if active
        if (isFullScreen) {
            val activity = getActivity(context)
            if (activity != null) {
                exitFullscreenNative(activity)
            }
        }

        // Dismiss fullscreen dialog if it exists
        fullscreenDialog?.dismiss()
        fullscreenDialog = null

        // Remove fullscreen button listener to prevent clicks during disposal
        playerView.setFullscreenButtonClickListener(null)

        // Remove listeners and stop periodic updates
        player.removeListener(observer)
        observer.release()

        // Clean up channels
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)

        // Note: player and notification handler are NOT released here if they're shared
        // The shared player and notification handler will be kept alive for reuse
        if (controllerId != null) {
            Log.d(TAG, "Platform view disposed but player and notification handler kept alive for controller ID: $controllerId")
        } else {
            // Only release if not shared
            notificationHandler.release()
            player.release()
        }
    }
}

