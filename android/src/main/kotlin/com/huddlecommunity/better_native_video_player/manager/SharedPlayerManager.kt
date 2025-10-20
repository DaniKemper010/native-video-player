package com.huddlecommunity.better_native_video_player.manager

import android.content.Context
import android.content.Intent
import androidx.media3.exoplayer.ExoPlayer
import com.huddlecommunity.native_video_player.VideoPlayerMediaSessionService
import com.huddlecommunity.native_video_player.handlers.VideoPlayerNotificationHandler
import com.huddlecommunity.native_video_player.handlers.VideoPlayerEventHandler

/**
 * Manages shared ExoPlayer instances and NotificationHandlers across multiple platform views
 * Keeps players and notification handlers alive even when platform views are disposed
 * Note: Each platform view gets its own PlayerView, but they share the same ExoPlayer and NotificationHandler
 */
object SharedPlayerManager {
    private val players = mutableMapOf<Int, ExoPlayer>()
    private val notificationHandlers = mutableMapOf<Int, VideoPlayerNotificationHandler>()

    /**
     * Gets or creates a player for the given controller ID
     */
    fun getOrCreatePlayer(context: Context, controllerId: Int): ExoPlayer {
        return players.getOrPut(controllerId) {
            ExoPlayer.Builder(context).build()
        }
    }

    /**
     * Gets or creates a notification handler for the given controller ID
     */
    fun getOrCreateNotificationHandler(
        context: Context,
        controllerId: Int,
        player: ExoPlayer,
        eventHandler: VideoPlayerEventHandler
    ): VideoPlayerNotificationHandler {
        return notificationHandlers.getOrPut(controllerId) {
            VideoPlayerNotificationHandler(context, player, eventHandler)
        }
    }

    /**
     * Removes a player (called when explicitly disposed)
     */
    fun removePlayer(context: Context, controllerId: Int) {
        // Release notification handler
        notificationHandlers[controllerId]?.release()
        notificationHandlers.remove(controllerId)

        // Release player
        players[controllerId]?.release()
        players.remove(controllerId)

        // If no more players, stop the service
        if (players.isEmpty()) {
            stopMediaSessionService(context)
        }
    }

    /**
     * Clears all players (e.g., on logout)
     */
    fun clearAll(context: Context) {
        // Release all notification handlers
        notificationHandlers.values.forEach { it.release() }
        notificationHandlers.clear()

        // Release all players
        players.values.forEach { it.release() }
        players.clear()

        // Stop the service when clearing all players
        stopMediaSessionService(context)
    }

    /**
     * Stops the MediaSessionService
     */
    private fun stopMediaSessionService(context: Context) {
        VideoPlayerMediaSessionService.setMediaSession(null)
        val serviceIntent = Intent(context, VideoPlayerMediaSessionService::class.java)
        context.stopService(serviceIntent)
    }
}
