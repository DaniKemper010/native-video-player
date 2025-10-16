package com.huddlecommunity.native_video_player.handlers

import android.util.Log
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player

/**
 * Observes ExoPlayer state changes and reports them via EventHandler
 * Equivalent to iOS VideoPlayerObserver
 */
class VideoPlayerObserver(
    private val eventHandler: VideoPlayerEventHandler
) : Player.Listener {

    companion object {
        private const val TAG = "VideoPlayerObserver"
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
            }
            Player.STATE_ENDED -> {
                eventHandler.sendEvent("completed")
            }
        }
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        Log.d(TAG, "Is playing changed: $isPlaying")
        if (isPlaying) {
            eventHandler.sendEvent("play")
        } else {
            eventHandler.sendEvent("pause")
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
