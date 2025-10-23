package com.huddlecommunity.better_native_video_player

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
import com.huddlecommunity.better_native_video_player.handlers.VideoPlayerEventHandler
import com.huddlecommunity.better_native_video_player.handlers.VideoPlayerMethodHandler
import com.huddlecommunity.better_native_video_player.handlers.VideoPlayerNotificationHandler
import com.huddlecommunity.better_native_video_player.handlers.VideoPlayerObserver
import com.huddlecommunity.better_native_video_player.manager.SharedPlayerManager
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
    
    // Store media info for updating notification when playback starts
    private var currentMediaInfo: Map<String, Any>? = null

    // Channels
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

    // PiP settings
    private var allowsPictureInPicture: Boolean = true
    private var canStartPictureInPictureAutomatically: Boolean = false
    private var showNativeControlsOriginal: Boolean = true


    init {
        Log.d(TAG, "Creating VideoPlayerView with id: $viewId")

        // Extract controller ID from args
        controllerId = args?.get("controllerId") as? Int

        // Extract initial fullscreen state from args
        isFullScreen = args?.get("isFullScreen") as? Boolean ?: false
        Log.d(TAG, "Initial fullscreen state: $isFullScreen")

        // Extract PiP settings from args
        val argsAllowsPiP = args?.get("allowsPictureInPicture") as? Boolean ?: true
        val argsCanStartPiPAuto = args?.get("canStartPictureInPictureAutomatically") as? Boolean ?: false
        val argsShowNativeControls = args?.get("showNativeControls") as? Boolean ?: true

        // For shared players, try to get PiP settings from SharedPlayerManager
        // This ensures PiP settings persist across all views using the same controller
        if (controllerId != null) {
            val sharedSettings = SharedPlayerManager.getPipSettings(controllerId)
            if (sharedSettings != null) {
                // Use existing shared settings
                allowsPictureInPicture = sharedSettings.allowsPictureInPicture
                canStartPictureInPictureAutomatically = sharedSettings.canStartPictureInPictureAutomatically
                showNativeControlsOriginal = sharedSettings.showNativeControls
                Log.d(TAG, "Using shared PiP settings for controller $controllerId - allows: $allowsPictureInPicture, autoStart: $canStartPictureInPictureAutomatically")
            } else {
                // First view for this controller - store the settings
                allowsPictureInPicture = argsAllowsPiP
                canStartPictureInPictureAutomatically = argsCanStartPiPAuto
                showNativeControlsOriginal = argsShowNativeControls
                SharedPlayerManager.setPipSettings(
                    controllerId = controllerId,
                    allowsPictureInPicture = allowsPictureInPicture,
                    canStartPictureInPictureAutomatically = canStartPictureInPictureAutomatically,
                    showNativeControls = showNativeControlsOriginal
                )
                Log.d(TAG, "Stored new PiP settings for controller $controllerId - allows: $allowsPictureInPicture, autoStart: $canStartPictureInPictureAutomatically")
            }
        } else {
            // Non-shared player - use settings from args
            allowsPictureInPicture = argsAllowsPiP
            canStartPictureInPictureAutomatically = argsCanStartPiPAuto
            showNativeControlsOriginal = argsShowNativeControls
            Log.d(TAG, "PiP settings for non-shared player - allows: $allowsPictureInPicture, autoStart: $canStartPictureInPictureAutomatically, showControls: $showNativeControlsOriginal")
        }
        
        // Extract and store media info from args (if provided during initialization)
        // This ensures we have the correct media info even for shared players
        currentMediaInfo = args?.get("mediaInfo") as? Map<String, Any>
        currentMediaInfo?.let { mediaInfo ->
            val title = mediaInfo["title"] as? String
            Log.d(TAG, "📱 Stored media info during init: $title")
        }

        // Get or create shared player
        val isSharedPlayer: Boolean
        player = if (controllerId != null) {
            val (sharedPlayer, alreadyExisted) = SharedPlayerManager.getOrCreatePlayer(context, controllerId)
            isSharedPlayer = alreadyExisted
            if (alreadyExisted) {
                Log.d(TAG, "Using existing shared player for controller ID: $controllerId")
            } else {
                Log.d(TAG, "Creating new shared player for controller ID: $controllerId")
            }
            sharedPlayer
        } else {
            Log.d(TAG, "No controller ID provided, creating new player")
            isSharedPlayer = false
            ExoPlayer.Builder(context).build()
        }

        // Create PlayerView and attach player
        val showNativeControls = args?.get("showNativeControls") as? Boolean ?: true
        playerView = PlayerView(context).apply {
            this.player = this@VideoPlayerView.player
            useController = showNativeControls
            controllerShowTimeoutMs = 5000
            controllerHideOnTouch = true

            // Hide unnecessary buttons: settings, next, previous
            setShowNextButton(false)
            setShowPreviousButton(false)
            // Note: There's no direct method to hide settings button, but we can hide it via layout

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
                Log.d(TAG, "Fullscreen button clicked, wants to enter: $enteringFullScreen, current state: $isFullScreen")
                
                // The button sends us the state it wants to ENTER
                // If we're already in that state, the button is out of sync (e.g., when Flutter triggered fullscreen)
                // In that case, we should do the opposite action
                val shouldEnter = if (isFullScreen && enteringFullScreen) {
                    // Button wants to enter fullscreen, but we're already in fullscreen
                    // This means the button icon is out of sync - we should exit instead
                    Log.d(TAG, "Button out of sync: wants to enter but already in fullscreen, exiting instead")
                    false
                } else if (!isFullScreen && !enteringFullScreen) {
                    // Button wants to exit fullscreen, but we're not in fullscreen
                    // This means the button icon is out of sync - we should enter instead
                    Log.d(TAG, "Button out of sync: wants to exit but not in fullscreen, entering instead")
                    true
                } else {
                    // Button is in sync with our state
                    enteringFullScreen
                }
                
                handleFullscreenToggleNative(shouldEnter)
            }
        }

        // Setup event handler (pass isSharedPlayer flag)
        eventHandler = VideoPlayerEventHandler(isSharedPlayer = isSharedPlayer)

        // Setup notification handler (shared for shared players)
        notificationHandler = if (controllerId != null) {
            val handler = SharedPlayerManager.getOrCreateNotificationHandler(context, controllerId, player, eventHandler)
            // Update event handler for shared notification handler (in case it's being reused)
            handler.updateEventHandler(eventHandler)
            handler
        } else {
            VideoPlayerNotificationHandler(context, player, eventHandler)
        }

        // Setup method handler with callback to update media info
        methodHandler = VideoPlayerMethodHandler(
            context = context,
            player = player,
            eventHandler = eventHandler,
            notificationHandler = notificationHandler,
            updateMediaInfo = { mediaInfo -> currentMediaInfo = mediaInfo }
        )

        // Set fullscreen callback for method handler
        methodHandler.onFullscreenRequest = { enterFullscreen ->
            handleFullscreenToggleNative(enterFullscreen)
        }

        // Set PiP callbacks for method handler
        methodHandler.onEnterPictureInPictureRequest = {
            enterPictureInPictureInternal()
        }
        methodHandler.onExitPictureInPictureRequest = {
            exitPictureInPictureInternal()
        }

        // Setup observer with notification handler and media info getter
        observer = VideoPlayerObserver(
            player = player,
            eventHandler = eventHandler,
            notificationHandler = notificationHandler,
            getMediaInfo = { currentMediaInfo },
            controllerId = controllerId,
            viewId = viewId,
            canStartPictureInPictureAutomatically = canStartPictureInPictureAutomatically
        )
        player.addListener(observer)

        // Register this view with SharedPlayerManager if using a shared player
        // This allows other views to notify us when they're disposed
        if (controllerId != null) {
            SharedPlayerManager.registerView(controllerId, viewId) {
                reconnectSurface()
            }
        }

        // Setup event channel
        val eventChannelName = "native_video_player_$viewId"
        eventChannel = EventChannel(binaryMessenger, eventChannelName)
        eventChannel.setStreamHandler(eventHandler)

        // For shared players, set up callback to send the current playback state
        // when the event listener is attached (in onListen)
        // This ensures the new view knows if the video is playing or paused
        if (controllerId != null) {
            eventHandler.setInitialStateCallback {
                Log.d(TAG, "Sending initial state for shared player - isPlaying: ${player.isPlaying}, playbackState: ${player.playbackState}, duration: ${player.duration}")
                
                // Send loaded event first if the player has content loaded
                // Check duration >= 0 because C.TIME_UNSET is a large negative value
                if (player.playbackState != ExoPlayer.STATE_IDLE && player.duration >= 0) {
                    eventHandler.sendEvent("loaded", mapOf(
                        "duration" to player.duration.toInt()
                    ))
                }
                
                // Then send the current playback state
                if (player.isPlaying) {
                    eventHandler.sendEvent("play")
                } else if (player.playbackState != ExoPlayer.STATE_IDLE) {
                    eventHandler.sendEvent("pause")
                }
            }
        }

        // Method channel is handled at the plugin level
        // No need to set up individual method channels for each view

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
            "setShowNativeControls" -> {
                val show = call.argument<Boolean>("show") ?: true
                playerView.useController = show
                result.success(null)
            }
            else -> {
                methodHandler.handleMethodCall(call, result)
            }
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
            
            // Notify Flutter that fullscreen was entered
            eventHandler.sendEvent("fullscreenChange", mapOf("isFullscreen" to true))
        } else {
            exitFullscreenNative(activity)
            
            // Notify Flutter that fullscreen was exited
            eventHandler.sendEvent("fullscreenChange", mapOf("isFullscreen" to false))
        }

        // Update internal state
        isFullScreen = enteringFullScreen
        
        // Update the fullscreen button icon to reflect the new state
        // Use a delay to ensure the view transition has completed
        playerView.postDelayed({
            updateFullscreenButtonState(enteringFullScreen)
        }, 100)
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
                    // Trigger the fullscreen toggle to exit (it will handle state and events)
                    playerView.post {
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

        // Force the PlayerView to reattach its surface to the player
        // This is necessary because moving the view between parents can disconnect the surface
        playerView.post {
            // Temporarily detach and reattach the player to ensure surface is connected
            val currentPlayer = playerView.player
            if (currentPlayer != null) {
                playerView.player = null
                playerView.player = currentPlayer
                Log.d(TAG, "Reattached player to surface after exiting fullscreen")
            }
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
     * Updates the fullscreen button icon to match the current fullscreen state
     * This is needed when fullscreen is toggled from Flutter rather than from the button itself
     */
    private fun updateFullscreenButtonState(isFullscreen: Boolean) {
        try {
            // Access the fullscreen button using reflection
            // The button is part of the PlayerView's controller
            val fullscreenButton = playerView.findViewById<android.widget.ImageButton>(
                androidx.media3.ui.R.id.exo_fullscreen
            )
            
            if (fullscreenButton != null) {
                Log.d(TAG, "Fullscreen button found, current selected state: ${fullscreenButton.isSelected}, setting to: $isFullscreen")
                
                // Try multiple approaches to update the button icon
                
                // Approach 1: Update selected state
                fullscreenButton.isSelected = isFullscreen
                fullscreenButton.refreshDrawableState()
                
                // Approach 2: Update content description (helps with accessibility)
                fullscreenButton.contentDescription = if (isFullscreen) "Exit fullscreen" else "Enter fullscreen"
                
                // Approach 3: Directly set the image resource based on fullscreen state
                // ExoPlayer uses exo_icon_fullscreen_enter and exo_icon_fullscreen_exit
                try {
                    val iconResourceId = if (isFullscreen) {
                        androidx.media3.ui.R.drawable.exo_icon_fullscreen_exit
                    } else {
                        androidx.media3.ui.R.drawable.exo_icon_fullscreen_enter
                    }
                    fullscreenButton.setImageResource(iconResourceId)
                    Log.d(TAG, "Set fullscreen button icon directly to: ${if (isFullscreen) "exit" else "enter"}")
                } catch (e: Exception) {
                    Log.w(TAG, "Could not set fullscreen button icon directly: ${e.message}")
                }
                
                // Force redraw
                fullscreenButton.invalidate()
                
                Log.d(TAG, "Fullscreen button state updated successfully (new selected=${fullscreenButton.isSelected})")
            } else {
                Log.w(TAG, "Fullscreen button not found in PlayerView")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error updating fullscreen button state: ${e.message}", e)
        }
    }

    /**
     * Enter Picture-in-Picture mode
     */
    /**
     * Enters Picture-in-Picture mode (internal method called by methodHandler)
     * Returns true if PiP was entered successfully, false otherwise
     */
    private fun enterPictureInPictureInternal(): Boolean {
        Log.d(TAG, "Attempting to enter PiP mode")

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            // Try to get activity from plugin first
            val pluginActivity = NativeVideoPlayerPlugin.getActivity()
            val activity = pluginActivity ?: getActivity(context)

            if (activity != null) {
                Log.d(TAG, "Activity found for PiP: ${activity.javaClass.simpleName}")

                val aspectRatio = player.videoSize.let { size ->
                    if (size.width > 0 && size.height > 0) {
                        Log.d(TAG, "Using video aspect ratio: ${size.width}x${size.height}")
                        android.util.Rational(size.width, size.height)
                    } else {
                        Log.d(TAG, "Using default aspect ratio 16:9")
                        android.util.Rational(16, 9)
                    }
                }

                val params = android.app.PictureInPictureParams.Builder()
                    .setAspectRatio(aspectRatio)
                    .build()

                // Hide ExoPlayer controls BEFORE entering PiP mode - only system PiP controls will show
                // Setting useController to false removes the controller UI completely
                Log.d(TAG, "Current useController: ${playerView.useController}")
                playerView.useController = false
                playerView.controllerAutoShow = false
                playerView.hideController()
                Log.d(TAG, "ExoPlayer controls hidden (useController: ${playerView.useController})")

                val entered = activity.enterPictureInPictureMode(params)
                Log.d(TAG, "PiP mode entered: $entered")

                if (entered) {
                    eventHandler.sendEvent("pipStart", mapOf("isPictureInPicture" to true))
                    return true
                } else {
                    // Restore controls if PiP failed
                    playerView.useController = showNativeControlsOriginal
                    Log.e(TAG, "Failed to enter PiP mode")
                    return false
                }
            } else {
                Log.e(TAG, "No activity found for PiP")
                return false
            }
        } else {
            Log.e(TAG, "PiP not supported on Android version: ${android.os.Build.VERSION.SDK_INT}")
            return false
        }
    }

    /**
     * Exits Picture-in-Picture mode (internal method called by methodHandler)
     * Returns true if PiP was exited successfully, false otherwise
     */
    @RequiresApi(Build.VERSION_CODES.O)
    private fun exitPictureInPictureInternal(): Boolean {
        Log.d(TAG, "Attempting to exit PiP mode")

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            val pluginActivity = NativeVideoPlayerPlugin.getActivity()
            val activity = pluginActivity ?: getActivity(context)

            if (activity != null && activity.isInPictureInPictureMode) {
                Log.d(TAG, "Activity is in PiP mode, exiting...")
                // Restore controls when exiting PiP
                playerView.useController = showNativeControlsOriginal
                playerView.showController()
                
                // Exit PiP by going back to normal mode (no direct API for this)
                // The system will call onPictureInPictureModeChanged which we handle in the observer
                eventHandler.sendEvent("pipStop", mapOf("isPictureInPicture" to false))
                return true
            } else {
                Log.d(TAG, "Activity not in PiP mode")
                return false
            }
        } else {
            Log.e(TAG, "PiP not supported on Android version: ${android.os.Build.VERSION.SDK_INT}")
            return false
        }
    }

    /**
     * Automatically enters PiP when user leaves the app (if enabled)
     * This is called from the activity's onUserLeaveHint
     */
    fun tryAutoPictureInPicture(): Boolean {
        if (!canStartPictureInPictureAutomatically || !allowsPictureInPicture) {
            Log.d(TAG, "Auto PiP not enabled - auto: $canStartPictureInPictureAutomatically, allows: $allowsPictureInPicture")
            return false
        }

        // Only auto-enter PiP if video is playing
        if (!player.isPlaying) {
            Log.d(TAG, "Auto PiP skipped - video not playing")
            return false
        }

        Log.d(TAG, "Attempting auto PiP entry")

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val pluginActivity = NativeVideoPlayerPlugin.getActivity()
            val activity = pluginActivity ?: getActivity(context)

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

                // Hide ExoPlayer controls BEFORE entering PiP mode
                playerView.useController = false
                playerView.controllerAutoShow = false
                playerView.hideController()
                Log.d(TAG, "ExoPlayer controls hidden before entering auto PiP mode")

                val entered = activity.enterPictureInPictureMode(params)
                Log.d(TAG, "Auto PiP entered: $entered")

                if (entered) {
                    eventHandler.sendEvent("pipStart", mapOf("isPictureInPicture" to true, "auto" to true))
                } else {
                    // Restore controls if PiP failed
                    playerView.useController = showNativeControlsOriginal
                }

                return entered
            }
        }

        return false
    }

    /**
     * Restores ExoPlayer controls when exiting PiP mode
     * This should be called when onPictureInPictureModeChanged detects exit from PiP
     */
    fun onExitPictureInPicture() {
        Log.d(TAG, "Exiting PiP mode - restoring controls")
        playerView.useController = showNativeControlsOriginal
        playerView.controllerAutoShow = true
        if (showNativeControlsOriginal) {
            playerView.showController()
        }
        Log.d(TAG, "ExoPlayer controls restored to: $showNativeControlsOriginal")
    }

    /**
     * Reconnects the player's surface to the PlayerView
     * This is called when another platform view using the same shared player is disposed
     */
    private fun reconnectSurface() {
        if (isDisposed) {
            Log.d(TAG, "Ignoring surface reconnect - view is disposed")
            return
        }

        Log.d(TAG, "Reconnecting surface for view $viewId (notified by another view disposal)")
        playerView.post {
            // Temporarily detach and reattach the player to ensure surface is connected
            val currentPlayer = playerView.player
            if (currentPlayer != null) {
                playerView.player = null
                playerView.player = currentPlayer
                Log.d(TAG, "Surface reconnected successfully for view $viewId")
            } else {
                Log.w(TAG, "Cannot reconnect surface - player is null")
            }
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
        eventChannel.setStreamHandler(null)

        // Note: player and notification handler are NOT released here if they're shared
        // The shared player and notification handler will be kept alive for reuse
        if (controllerId != null) {
            Log.d(TAG, "Platform view disposed but player and notification handler kept alive for controller ID: $controllerId")

            // IMPORTANT: For shared players, detach the player from this PlayerView to prevent
            // disconnecting the surface. Another platform view may still be using the player.
            // If we don't detach here, disposing this view will disconnect the player's surface,
            // leaving other views without video frames.
            playerView.player = null
            Log.d(TAG, "Detached player from PlayerView to preserve surface for other views")

            // Unregister this view and notify remaining views to reconnect their surfaces
            SharedPlayerManager.unregisterView(controllerId, viewId)
        } else {
            // Only release if not shared
            notificationHandler.release()
            player.release()
        }
    }
}

