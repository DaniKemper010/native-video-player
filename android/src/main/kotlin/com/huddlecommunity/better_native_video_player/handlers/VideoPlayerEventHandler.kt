package com.huddlecommunity.better_native_video_player.handlers

import io.flutter.plugin.common.EventChannel

/**
 * Handles sending events from native Android to Flutter via EventChannel
 * Equivalent to iOS VideoPlayerEventHandler
 */
class VideoPlayerEventHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // Send initial event when EventChannel is connected
        sendEvent("isInitialized")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /**
     * Sends an event to Flutter
     * @param name Event name (e.g., "play", "pause", "loading")
     * @param data Optional additional data to send with the event
     */
    fun sendEvent(name: String, data: Map<String, Any>? = null) {
        val event = mutableMapOf<String, Any>("event" to name)
        data?.let { event.putAll(it) }
        eventSink?.success(event)
    }
}
