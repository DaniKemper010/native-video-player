import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/platform_utils.dart';

/// Manages fullscreen state, system UI visibility, and device orientation
class FullscreenManager {
  /// Stores the current orientation preferences (tracked globally)
  static List<DeviceOrientation> _currentOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// Stores the orientation preferences before entering fullscreen
  static List<DeviceOrientation>? _savedOrientations;

  /// Enters fullscreen mode
  ///
  /// This method:
  /// - Saves current orientation preferences automatically
  /// - Hides system UI (status bar, navigation bar on Android)
  /// - Sets orientation preferences based on provided parameters
  ///
  /// **Parameters:**
  /// - fullScreenPreferredOrientations: Optional list of orientations allowed in fullscreen.
  ///   If provided, these orientations are used. If null, falls back to lockToLandscape behavior.
  /// - lockToLandscape: If true and fullScreenPreferredOrientations is null, locks orientation to landscape modes only
  static Future<void> enterFullscreen({
    List<DeviceOrientation>? fullScreenPreferredOrientations,
    bool lockToLandscape = true,
  }) async {
    // Save current orientation preferences before changing them
    _savedOrientations = List.from(_currentOrientations);
    // Hide system UI
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);

    // Set orientation preferences for fullscreen
    if (fullScreenPreferredOrientations != null && fullScreenPreferredOrientations.isNotEmpty) {
      // Use provided fullscreen orientations
      await SystemChrome.setPreferredOrientations(fullScreenPreferredOrientations);
      _currentOrientations = List.from(fullScreenPreferredOrientations);
    } else if (lockToLandscape) {
      // Fall back to lockToLandscape behavior
      final landscapeOrientations = [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];
      await SystemChrome.setPreferredOrientations(landscapeOrientations);
      _currentOrientations = landscapeOrientations;
    } else {
      // Allow all orientations
      final allOrientations = [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ];
      await SystemChrome.setPreferredOrientations(allOrientations);
      _currentOrientations = allOrientations;
    }
  }

  /// Exits fullscreen mode
  ///
  /// This method:
  /// - Restores system UI visibility
  /// - Restores original orientation preferences that were saved before entering fullscreen
  /// - Clears saved orientations to ensure clean state
  static Future<void> exitFullscreen() async {
    // Restore system UI
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);

    // Restore orientation preferences to what they were before fullscreen
    if (PlatformUtils.isAndroid || PlatformUtils.isIOS) {
      // Use saved orientations if available, otherwise restore to all orientations
      final orientations =
          _savedOrientations ??
          [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
      await SystemChrome.setPreferredOrientations(orientations);
      _currentOrientations = List.from(orientations);

      // Clear saved orientations to ensure clean state for next fullscreen entry
      _savedOrientations = null;
    }
  }

  /// Set orientation preferences that will be tracked by FullscreenManager
  ///
  /// Call this instead of `SystemChrome.setPreferredOrientations()` if you want
  /// FullscreenManager to automatically remember and restore these orientations
  /// when exiting fullscreen.
  ///
  /// **Example:**
  /// ```dart
  /// // Set your app to portrait only
  /// await FullscreenManager.setPreferredOrientations([
  ///   DeviceOrientation.portraitUp,
  /// ]);
  ///
  /// // Later when entering fullscreen, it will remember portrait-only
  /// await FullscreenManager.enterFullscreen();
  /// // Exits fullscreen
  /// await FullscreenManager.exitFullscreen();
  /// // Automatically restores to portrait-only
  /// ```
  static Future<void> setPreferredOrientations(List<DeviceOrientation> orientations) async {
    _currentOrientations = List.from(orientations);
    await SystemChrome.setPreferredOrientations(orientations);
  }

  /// Shows a fullscreen dialog with the provided widget
  ///
  /// This is a helper method that combines entering fullscreen mode
  /// with showing a dialog.
  ///
  /// **Parameters:**
  /// - context: BuildContext for showing the dialog
  /// - builder: Widget builder for the fullscreen content
  /// - fullScreenPreferredOrientations: Optional list of orientations allowed in fullscreen.
  ///   If provided, these orientations are used. If null, falls back to lockToLandscape behavior.
  /// - lockToLandscape: If true and fullScreenPreferredOrientations is null, locks orientation to landscape
  /// - onExit: Optional callback when fullscreen is exited
  ///
  /// **Returns:**
  /// The result from the dialog when it's dismissed
  static Future<T?> showFullscreenDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    List<DeviceOrientation>? fullScreenPreferredOrientations,
    bool lockToLandscape = true,
    VoidCallback? onExit,
  }) async {
    // Enter fullscreen mode
    await enterFullscreen(
      fullScreenPreferredOrientations: fullScreenPreferredOrientations,
      lockToLandscape: lockToLandscape,
    );

    if (!context.mounted) {
      return null;
    }

    // Show the dialog using the root navigator to avoid nested navigator issues
    // rootNavigator: true ensures we use the topmost Navigator in the widget tree
    final result = await Navigator.of(context, rootNavigator: true).push<T>(
      PageRouteBuilder<T>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    // Exit fullscreen mode
    await exitFullscreen();

    // Call exit callback if provided
    onExit?.call();

    return result;
  }
}
