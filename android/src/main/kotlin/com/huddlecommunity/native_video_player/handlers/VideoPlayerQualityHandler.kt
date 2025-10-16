package com.huddlecommunity.native_video_player.handlers

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.URL

/**
 * Handles HLS quality parsing and management
 * Equivalent to iOS VideoPlayerQualityHandler
 */
object VideoPlayerQualityHandler {
    private const val TAG = "VideoPlayerQuality"

    /**
     * Fetches and parses HLS qualities from an M3U8 playlist URL
     * @param url The M3U8 playlist URL
     * @return List of quality maps with "label" and "url" keys
     */
    suspend fun fetchHLSQualities(url: String): List<Map<String, String>> = withContext(Dispatchers.IO) {
        try {
            val connection = URL(url).openConnection()
            val playlist = connection.getInputStream().bufferedReader().use { it.readText() }

            val qualities = mutableListOf<Map<String, String>>()
            val lines = playlist.lines()
            var lastResolution = ""

            for (line in lines) {
                when {
                    line.contains("#EXT-X-STREAM-INF") -> {
                        // Extract resolution using regex
                        val resolutionMatch = Regex("RESOLUTION=(\\d+x\\d+)").find(line)
                        lastResolution = resolutionMatch?.groupValues?.get(1) ?: ""
                    }
                    line.endsWith(".m3u8") && lastResolution.isNotEmpty() -> {
                        qualities.add(
                            mapOf(
                                "label" to lastResolution,
                                "url" to line
                            )
                        )
                        lastResolution = ""
                    }
                }
            }

            Log.d(TAG, "Parsed ${qualities.size} quality variants from HLS playlist")
            qualities
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching HLS qualities: ${e.message}", e)
            emptyList()
        }
    }
}
