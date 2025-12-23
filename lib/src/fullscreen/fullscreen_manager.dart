import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/platform_utils.dart';

/// Manages fullscreen state, system UI visibility, and device orientation
class FullscreenManager {
  /// Tracks whether we're currently in fullscreen mode
  static bool _isInFullscreen = false;

  /// Enters fullscreen mode
  ///
  /// This method:
  /// - Hides system UI (status bar, navigation bar on Android)
  /// - Sets orientation preferences based on provided parameters (only applies in fullscreen)
  ///
  /// **Parameters:**
  /// - fullScreenPreferredOrientations: Optional list of orientations allowed in fullscreen.
  ///   If provided, these orientations are used. If null, falls back to lockToLandscape behavior.
  /// - lockToLandscape: If true and fullScreenPreferredOrientations is null, locks orientation to landscape modes only
  static Future<void> enterFullscreen({
    List<DeviceOrientation>? fullScreenPreferredOrientations,
    bool lockToLandscape = true,
  }) async {
    _isInFullscreen = true;
    // Hide system UI
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []);

    // Set orientation preferences for fullscreen
    if (fullScreenPreferredOrientations != null && fullScreenPreferredOrientations.isNotEmpty) {
      // Use provided fullscreen orientations
      await SystemChrome.setPreferredOrientations(fullScreenPreferredOrientations);
    } else if (lockToLandscape) {
      // Fall back to lockToLandscape behavior
      final landscapeOrientations = [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];
      await SystemChrome.setPreferredOrientations(landscapeOrientations);
    } else {
      // Allow all orientations
      final allOrientations = [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ];
      await SystemChrome.setPreferredOrientations(allOrientations);
    }
  }

  /// Exits fullscreen mode
  ///
  /// This method:
  /// - Restores system UI visibility
  /// - Removes fullscreen orientation restrictions by setting all orientations
  ///   The app's manifest/Info.plist will then enforce its own orientation restrictions
  static Future<void> exitFullscreen() async {
    if (!_isInFullscreen) {
      return;
    }
    _isInFullscreen = false;

    // Restore system UI
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);

    // Remove our fullscreen orientation restrictions
    // By setting all orientations, we remove our restrictions and let the app's
    // manifest/Info.plist settings take effect. The system will enforce the manifest
    // restrictions automatically (e.g., if manifest says portrait-only, only portrait will be allowed)
    if (PlatformUtils.isAndroid || PlatformUtils.isIOS) {
      final allOrientations = [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];
      await SystemChrome.setPreferredOrientations(allOrientations);
    }
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
