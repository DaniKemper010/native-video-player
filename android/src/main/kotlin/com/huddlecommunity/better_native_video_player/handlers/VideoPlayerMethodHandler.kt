package com.huddlecommunity.better_native_video_player.handlers

import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.exoplayer.hls.HlsMediaSource
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Handles method calls from Flutter for video player control
 * Equivalent to iOS VideoPlayerMethodHandler
 */
@UnstableApi
class VideoPlayerMethodHandler(
    private val player: ExoPlayer,
    private val eventHandler: VideoPlayerEventHandler,
    private val notificationHandler: VideoPlayerNotificationHandler
) {
    companion object {
        private const val TAG = "VideoPlayerMethod"
    }

    private var availableQualities: List<Map<String, Any>> = emptyList()
    private var isAutoQuality = false
    private var lastBitrateCheck = 0L
    private val bitrateCheckInterval = 5000L // 5 seconds

    // Callback to handle fullscreen requests from Flutter
    var onFullscreenRequest: ((Boolean) -> Unit)? = null

    /**
     * Handles incoming method calls from Flutter
     */
    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "Handling method call: ${call.method}")

        when (call.method) {
            "load" -> handleLoad(call, result)
            "play" -> handlePlay(result)
            "pause" -> handlePause(result)
            "seekTo" -> handleSeekTo(call, result)
            "setVolume" -> handleSetVolume(call, result)
            "setSpeed" -> handleSetSpeed(call, result)
            "setQuality" -> handleSetQuality(call, result)
            "getAvailableQualities" -> handleGetAvailableQualities(result)
            "enterFullScreen" -> handleEnterFullScreen(result)
            "exitFullScreen" -> handleExitFullScreen(result)
            "dispose" -> handleDispose(result)
            else -> result.notImplemented()
        }
    }

    /**
     * Loads a video URL into the player
     */
    private fun handleLoad(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val url = args?.get("url") as? String

        if (url == null) {
            result.error("INVALID_URL", "URL is required", null)
            return
        }

        val autoPlay = args["autoPlay"] as? Boolean ?: false
        val headers = args["headers"] as? Map<String, String>
        val mediaInfo = args["mediaInfo"] as? Map<String, Any>

        Log.d(TAG, "Loading video: $url (autoPlay: $autoPlay)")

        eventHandler.sendEvent("loading")

        // Build data source factory with custom headers if provided
        val dataSourceFactory = DefaultHttpDataSource.Factory().apply {
            headers?.let { setDefaultRequestProperties(it) }
        }

        // Build MediaItem with metadata
        val mediaItemBuilder = MediaItem.Builder()
            .setUri(url)

        // Add metadata if provided
        if (mediaInfo != null) {
            val metadataBuilder = androidx.media3.common.MediaMetadata.Builder()
            (mediaInfo["title"] as? String)?.let { metadataBuilder.setTitle(it) }
            (mediaInfo["subtitle"] as? String)?.let { metadataBuilder.setArtist(it) }
            (mediaInfo["album"] as? String)?.let { metadataBuilder.setAlbumTitle(it) }
            mediaItemBuilder.setMediaMetadata(metadataBuilder.build())
        }

        val mediaItem = mediaItemBuilder.build()

        // Create appropriate MediaSource based on URL type
        val mediaSource: MediaSource = if (url.contains(".m3u8")) {
            // HLS stream
            HlsMediaSource.Factory(dataSourceFactory)
                .createMediaSource(mediaItem)
        } else {
            // Progressive download (MP4, etc.)
            ProgressiveMediaSource.Factory(dataSourceFactory)
                .createMediaSource(mediaItem)
        }

        // Set media source
        player.setMediaSource(mediaSource)
        player.prepare()

        // Set autoplay
        if (autoPlay) {
            player.play()
        }

        // Fetch qualities asynchronously for HLS streams
        if (url.contains(".m3u8")) {
            CoroutineScope(Dispatchers.Main).launch {
                availableQualities = VideoPlayerQualityHandler.fetchHLSQualities(url)
                Log.d(TAG, "Fetched ${availableQualities.size} qualities")
            }
        }

        // Setup media session with metadata
        notificationHandler.setupMediaSession(mediaInfo)
        mediaInfo?.let {
            notificationHandler.updateMediaMetadata(it)
        }

        // Wait for player to be ready
        val listener = object : androidx.media3.common.Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                if (playbackState == androidx.media3.common.Player.STATE_READY) {
                    eventHandler.sendEvent("loaded")
                    player.removeListener(this)
                    result.success(null)
                }
            }

            override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
                player.removeListener(this)
                result.error("LOAD_ERROR", error.message ?: "Unknown error", null)
            }
        }
        player.addListener(listener)
    }

    /**
     * Starts playback
     */
    private fun handlePlay(result: MethodChannel.Result) {
        player.play()
        result.success(null)
    }

    /**
     * Pauses playback
     */
    private fun handlePause(result: MethodChannel.Result) {
        player.pause()
        result.success(null)
    }

    /**
     * Seeks to a specific position
     */
    private fun handleSeekTo(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val milliseconds = args?.get("milliseconds") as? Int
        if (milliseconds != null) {
            player.seekTo(milliseconds.toLong())
            eventHandler.sendEvent("seek", mapOf("position" to milliseconds))
        }
        result.success(null)
    }

    /**
     * Sets playback volume
     */
    private fun handleSetVolume(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val volume = args?.get("volume") as? Double
        if (volume != null) {
            player.volume = volume.toFloat()
        }
        result.success(null)
    }

    /**
     * Sets playback speed
     */
    private fun handleSetSpeed(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val speed = args?.get("speed") as? Double
        if (speed != null) {
            player.setPlaybackSpeed(speed.toFloat())
            eventHandler.sendEvent("speedChange", mapOf("speed" to speed))
        }
        result.success(null)
    }

    /**
     * Changes video quality (for HLS streams)
     */
    private fun handleSetQuality(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        val qualityInfo = args?.get("quality") as? Map<*, *>
        
        if (qualityInfo == null) {
            result.error("INVALID_QUALITY", "Invalid quality data", null)
            return
        }

        val isAuto = qualityInfo["isAuto"] as? Boolean ?: false
        isAutoQuality = isAuto

        if (isAuto) {
            // Start with the middle quality for auto mode
            val midIndex = (availableQualities.size / 2 - 1).coerceAtLeast(0)
            if (midIndex >= availableQualities.size) {
                result.error("NO_QUALITIES", "No qualities available", null)
                return
            }

            val initialQuality = availableQualities[midIndex]
            switchToQuality(initialQuality, result)

            // Start monitoring quality
            startQualityMonitoring()
        } else {
            val url = qualityInfo["url"] as? String
            val label = qualityInfo["label"] as? String

            if (url == null) {
                result.error("INVALID_QUALITY", "Quality URL is required", null)
                return
            }

            eventHandler.sendEvent("loading")

            // Save current state
            val wasPlaying = player.isPlaying
            val currentPosition = player.currentPosition

            // Build new media source
            val dataSourceFactory = DefaultHttpDataSource.Factory()
            val mediaItem = MediaItem.fromUri(url)
            val mediaSource = HlsMediaSource.Factory(dataSourceFactory)
                .createMediaSource(mediaItem)

            // Switch to new quality
            player.setMediaSource(mediaSource)
            player.prepare()
            player.seekTo(currentPosition)
            
            // Only resume playback if it was playing before
            if (wasPlaying) {
                player.play()
            }

            eventHandler.sendEvent("qualityChange", mapOf(
                "url" to url,
                "label" to (label ?: ""),
                "isAuto" to false
            ))

            result.success(null)
        }
    }

    private fun startQualityMonitoring() {
        // Quality monitoring is simplified for now
        // In a production app, you would implement bandwidth monitoring here
        Log.d(TAG, "Auto quality monitoring enabled (simplified implementation)")
    }

    private fun switchToQuality(quality: Map<String, Any>, result: MethodChannel.Result?) {
        val url = quality["url"] as? String ?: return
        val label = quality["label"] as? String ?: "Unknown"

        eventHandler.sendEvent("loading")

        // Save current state
        val wasPlaying = player.isPlaying
        val currentPosition = player.currentPosition

        // Build new media source
        val dataSourceFactory = DefaultHttpDataSource.Factory()
        val mediaItem = MediaItem.fromUri(url)
        val mediaSource = HlsMediaSource.Factory(dataSourceFactory)
            .createMediaSource(mediaItem)

        // Switch to new quality
        player.setMediaSource(mediaSource)
        player.prepare()
        player.seekTo(currentPosition)

        // Only resume playback if it was playing before
        if (wasPlaying) {
            player.play()
        }

        eventHandler.sendEvent("qualityChange", mapOf(
            "url" to url,
            "label" to label,
            "isAuto" to isAutoQuality
        ))

        result?.success(null)
    }

    /**
     * Returns available video qualities
     */
    private fun handleGetAvailableQualities(result: MethodChannel.Result) {
        result.success(availableQualities)
    }

    /**
     * Disposes the player
     */
    private fun handleDispose(result: MethodChannel.Result) {
        player.stop()
        eventHandler.sendEvent("stopped")
        result.success(null)
    }

    /**
     * Enters fullscreen mode
     * Triggers the native fullscreen dialog
     */
    private fun handleEnterFullScreen(result: MethodChannel.Result) {
        Log.d(TAG, "Flutter requested enter fullscreen")
        onFullscreenRequest?.invoke(true)
        result.success(null)
    }

    /**
     * Exits fullscreen mode
     * Dismisses the native fullscreen dialog
     */
    private fun handleExitFullScreen(result: MethodChannel.Result) {
        Log.d(TAG, "Flutter requested exit fullscreen")
        onFullscreenRequest?.invoke(false)
        result.success(null)
    }
}
