package com.huddlecommunity.better_native_video_player.handlers

import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player

/**
 * Observes ExoPlayer state changes and reports them via EventHandler
 * Equivalent to iOS VideoPlayerObserver
 */
class VideoPlayerObserver(
    private val player: Player,
    private val eventHandler: VideoPlayerEventHandler
) : Player.Listener {

    companion object {
        private const val TAG = "VideoPlayerObserver"
        private const val UPDATE_INTERVAL_MS = 500L // Update every 500ms
    }

    private val handler = Handler(Looper.getMainLooper())
    private val timeUpdateRunnable = object : Runnable {
        override fun run() {
            // Send time update event
            val position = player.currentPosition.toInt() // milliseconds
            val duration = player.duration.toInt() // milliseconds

            // Get buffered position
            val bufferedPosition = player.bufferedPosition.toInt() // milliseconds

            if (duration > 0) {
                eventHandler.sendEvent("timeUpdate", mapOf(
                    "position" to position,
                    "duration" to duration,
                    "bufferedPosition" to bufferedPosition
                ))
            }

            // Schedule next update
            handler.postDelayed(this, UPDATE_INTERVAL_MS)
        }
    }

    init {
        // Start periodic time updates
        handler.post(timeUpdateRunnable)
    }

    fun release() {
        // Stop periodic updates
        handler.removeCallbacks(timeUpdateRunnable)
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        Log.d(TAG, "Playback state changed: $playbackState")
        when (playbackState) {
            Player.STATE_IDLE -> {
                // Player is idle
            }
            Player.STATE_BUFFERING -> {
                eventHandler.sendEvent("buffering")
            }
            Player.STATE_READY -> {
                eventHandler.sendEvent("loading")
                // Send initial duration when player is ready
                val duration = player.duration.toInt()
                if (duration > 0) {
                    eventHandler.sendEvent("videoLoaded", mapOf("duration" to duration))
                }
            }
            Player.STATE_ENDED -> {
                eventHandler.sendEvent("completed")
            }
        }
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        Log.d(TAG, "Is playing changed: $isPlaying, playbackState: ${player.playbackState}")
        if (isPlaying) {
            eventHandler.sendEvent("play")
        } else {
            // Only send pause event if not buffering
            // When seeking to unbuffered position, isPlaying becomes false but player is buffering
            // We should not report this as a pause - the buffering event will be sent instead
            if (player.playbackState != Player.STATE_BUFFERING) {
                eventHandler.sendEvent("pause")
            }
        }
    }

    override fun onPlayerError(error: PlaybackException) {
        Log.e(TAG, "Player error: ${error.message}", error)
        eventHandler.sendEvent(
            "error",
            mapOf("message" to (error.message ?: "Unknown error"))
        )
    }
}
