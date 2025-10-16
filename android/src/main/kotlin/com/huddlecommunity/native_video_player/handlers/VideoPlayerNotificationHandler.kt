package com.huddlecommunity.native_video_player.handlers

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import com.huddlecommunity.huddle.MainActivity
import com.huddlecommunity.huddle.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL

/**
 * Handles MediaSession and notification controls for lock screen and notification area
 * Equivalent to iOS VideoPlayerNowPlayingHandler
 */
class VideoPlayerNotificationHandler(
    private val context: Context,
    private val player: ExoPlayer,
    private var eventHandler: VideoPlayerEventHandler
) {
    companion object {
        private const val TAG = "VideoPlayerNotification"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "video_player_channel"
        private var sessionCounter = 0
    }

    private var mediaSession: MediaSession? = null
    private val handler = Handler(Looper.getMainLooper())
    private var positionUpdateRunnable: Runnable? = null
    private val notificationManager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private var currentArtwork: Bitmap? = null
    private var currentArtworkUrl: String? = null // Track which artwork we're currently loading

    // Store current metadata separately to avoid reading stale data from player
    private var currentTitle: String = "Video"
    private var currentSubtitle: String = ""

    init {
        createNotificationChannel()
    }

    private val playerListener = object : Player.Listener {
        override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
            if (playWhenReady) {
                showNotification()
                eventHandler.sendEvent("play")
            } else {
                updateNotification()
                eventHandler.sendEvent("pause")
            }
        }

        override fun onPlaybackStateChanged(playbackState: Int) {
            when (playbackState) {
                Player.STATE_ENDED, Player.STATE_IDLE -> hideNotification()
                Player.STATE_READY -> if (player.playWhenReady) showNotification()
            }
        }
    }

    /**
     * Creates notification channel for Android O+
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Video Player",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Media playback controls"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }
    }

    /**
     * Updates the event handler (needed when shared NotificationHandler is reused by new VideoPlayerView)
     */
    fun updateEventHandler(newEventHandler: VideoPlayerEventHandler) {
        eventHandler = newEventHandler
        Log.d(TAG, "Event handler updated for shared notification handler")
    }

    /**
     * Updates the player's current MediaItem metadata (title, artist, album)
     * This is essential for MediaSession to display correct info in notification
     */
    private fun updatePlayerMediaItemMetadata(mediaInfo: Map<String, Any>?) {
        if (mediaInfo == null) return

        val currentItem = player.currentMediaItem ?: return

        // Build new metadata from mediaInfo
        val metadataBuilder = MediaMetadata.Builder()
        (mediaInfo["title"] as? String)?.let { metadataBuilder.setTitle(it) }
        (mediaInfo["subtitle"] as? String)?.let { metadataBuilder.setArtist(it) }
        (mediaInfo["album"] as? String)?.let { metadataBuilder.setAlbumTitle(it) }

        // Create updated MediaItem with new metadata
        val updatedItem = currentItem.buildUpon()
            .setMediaMetadata(metadataBuilder.build())
            .build()

        // Replace the MediaItem without interrupting playback
        val wasPlaying = player.isPlaying
        val position = player.currentPosition
        player.replaceMediaItem(player.currentMediaItemIndex, updatedItem)
        player.seekTo(position)
        if (wasPlaying) player.play()

        Log.d(TAG, "Updated player MediaItem metadata - title: ${mediaInfo["title"]}, subtitle: ${mediaInfo["subtitle"]}")
    }

    /**
     * Sets up MediaSession with metadata (title, subtitle, artwork)
     * Similar to iOS MPNowPlayingInfoCenter - shows on lock screen when playing
     * MediaSession automatically provides lock screen controls and system media notification
     */
    fun setupMediaSession(mediaInfo: Map<String, Any>?) {
        // Extract and store metadata immediately
        mediaInfo?.let { info ->
            currentTitle = (info["title"] as? String) ?: "Video"
            currentSubtitle = (info["subtitle"] as? String) ?: ""
            Log.d(TAG, "Stored metadata - title: $currentTitle, subtitle: $currentSubtitle")
        }

        // If MediaSession already exists, just update the metadata and clear old artwork
        if (mediaSession != null) {
            Log.d(TAG, "MediaSession already exists - updating for new video")
            currentArtwork = null // Clear old artwork
            currentArtworkUrl = null // Clear artwork URL to ignore pending loads

            // NOTE: We DON'T call updatePlayerMediaItemMetadata here because handleLoad()
            // already set the new MediaItem with correct metadata before calling this method

            // Set metadata if provided (loads artwork asynchronously)
            mediaInfo?.let { info ->
                updateMediaMetadata(info)
            }

            // Force MediaSession to refresh by invalidating and rebuilding the notification
            // This ensures the notification shows the new video info even if paused
            handler.post {
                updateNotification()
            }
            return
        }

        // Create pending intent to launch app when notification is clicked
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Create MediaSession with unique session ID and activity (opens app when notification is tapped)
        val sessionId = "huddle_video_player_${++sessionCounter}"
        mediaSession = MediaSession.Builder(context, player)
            .setId(sessionId)
            .setSessionActivity(pendingIntent)
            .build()

        // Add listener to track play/pause events
        player.addListener(playerListener)

        Log.d(TAG, "MediaSession created - lock screen and notification controls active")

        // Set metadata if provided
        mediaInfo?.let { info ->
            updateMediaMetadata(info)
        }

        // Start periodic position updates
        startPositionUpdates()
    }

    /**
     * Shows or updates the media notification
     */
    private fun showNotification() {
        try {
            val notification = buildNotification()
            notificationManager.notify(NOTIFICATION_ID, notification)
            Log.d(TAG, "Notification shown/updated")
        } catch (e: Exception) {
            Log.e(TAG, "Error showing notification: ${e.message}", e)
        }
    }

    /**
     * Updates the existing notification
     */
    private fun updateNotification() {
        showNotification()
    }

    /**
     * Hides the notification
     */
    private fun hideNotification() {
        notificationManager.cancel(NOTIFICATION_ID)
        Log.d(TAG, "Notification hidden")
    }

    /**
     * Builds the media notification
     */
    private fun buildNotification(): Notification {
        val session = mediaSession ?: throw IllegalStateException("MediaSession not initialized")

        // Read metadata from the player's current MediaItem (source of truth for MediaSession)
        // This ensures the notification always shows what the MediaSession is actually playing
        val mediaMetadata = player.currentMediaItem?.mediaMetadata
        val title = mediaMetadata?.title?.toString() ?: currentTitle
        val artist = mediaMetadata?.artist?.toString() ?: currentSubtitle

        // Create pending intent for the notification
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        Log.d(TAG, "Building notification - title: $title, subtitle: $artist (from player: ${mediaMetadata != null})")

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(artist)
            .setSmallIcon(R.drawable.ic_notification_statusbar)
            .setLargeIcon(currentArtwork)
            .setContentIntent(contentIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(session.sessionCompatToken)
                    .setShowActionsInCompactView(0) // Show play/pause in compact view
            )
            .build()
    }

    /**
     * Updates media metadata (title, artist, artwork)
     * This is called after the MediaItem is already set, so we just load artwork
     * The base metadata was already set when creating the MediaItem
     */
    fun updateMediaMetadata(mediaInfo: Map<String, Any>) {
        // Load artwork asynchronously if present and update the notification
        val artworkUrl = mediaInfo["artworkUrl"] as? String
        if (artworkUrl != null) {
            currentArtworkUrl = artworkUrl // Track the current artwork URL
            loadArtwork(artworkUrl) { bitmap ->
                // Only use this artwork if it's still the current one (prevent race conditions)
                if (artworkUrl != currentArtworkUrl) {
                    Log.d(TAG, "Ignoring outdated artwork for $artworkUrl")
                    return@loadArtwork
                }

                bitmap?.let {
                    currentArtwork = it

                    // Update artwork by rebuilding MediaItem with artwork
                    val currentItem = player.currentMediaItem
                    if (currentItem != null) {
                        val existingMetadata = currentItem.mediaMetadata
                        val updatedMetadata = existingMetadata.buildUpon()
                            .setArtworkData(bitmapToByteArray(it), MediaMetadata.PICTURE_TYPE_FRONT_COVER)
                            .build()

                        val updatedItem = currentItem.buildUpon()
                            .setMediaMetadata(updatedMetadata)
                            .build()

                        // Replace the item without interrupting playback
                        val wasPlaying = player.isPlaying
                        val position = player.currentPosition
                        player.replaceMediaItem(player.currentMediaItemIndex, updatedItem)
                        player.seekTo(position)
                        if (wasPlaying) player.play()

                        // Update notification with artwork
                        if (player.playWhenReady) {
                            updateNotification()
                        }

                        Log.d(TAG, "Artwork loaded and metadata updated for $artworkUrl")
                    }
                }
            }
        }

        Log.d(TAG, "Media metadata setup complete")
    }

    /**
     * Loads artwork from URL
     */
    private fun loadArtwork(url: String, callback: (Bitmap?) -> Unit) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val connection = URL(url).openConnection()
                val bitmap = BitmapFactory.decodeStream(connection.getInputStream())
                withContext(Dispatchers.Main) {
                    callback(bitmap)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error loading artwork: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    callback(null)
                }
            }
        }
    }

    /**
     * Converts Bitmap to ByteArray
     */
    private fun bitmapToByteArray(bitmap: Bitmap): ByteArray {
        val stream = java.io.ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        return stream.toByteArray()
    }

    /**
     * Starts periodic position updates (every second)
     */
    private fun startPositionUpdates() {
        positionUpdateRunnable = object : Runnable {
            override fun run() {
                // Position is automatically updated by ExoPlayer/MediaSession
                handler.postDelayed(this, 1000)
            }
        }
        handler.post(positionUpdateRunnable!!)
    }

    /**
     * Stops periodic position updates
     */
    private fun stopPositionUpdates() {
        positionUpdateRunnable?.let { handler.removeCallbacks(it) }
        positionUpdateRunnable = null
    }

    /**
     * Releases MediaSession and hides notification
     */
    fun release() {
        stopPositionUpdates()
        player.removeListener(playerListener)
        hideNotification()

        mediaSession?.release()
        mediaSession = null
        currentArtwork = null
        currentArtworkUrl = null
        currentTitle = "Video"
        currentSubtitle = ""
        Log.d(TAG, "MediaSession released")
    }
}
