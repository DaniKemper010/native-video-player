package com.example.native_video_player_example

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // PiP mode changes are automatically detected by the NativeVideoPlayerPlugin
    // via ComponentActivity.addOnPictureInPictureModeChangedListener()
    // No additional code needed here - the plugin sends pipStart/pipStop events
}
