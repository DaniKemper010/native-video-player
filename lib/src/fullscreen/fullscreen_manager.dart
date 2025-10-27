import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../platform/platform_utils.dart';

/// Manages fullscreen state, system UI visibility, and device orientation
class FullscreenManager {
  /// Enters fullscreen mode
  ///
  /// This method:
  /// - Hides system UI (status bar, navigation bar on Android)
  /// - Allows all orientations (or locks to landscape if specified)
  ///
  /// **Parameters:**
  /// - lockToLandscape: If true, locks orientation to landscape modes only
  static Future<void> enterFullscreen({bool lockToLandscape = true}) async {
    // Hide system UI
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );

    // Set orientation preferences
    if (lockToLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  /// Exits fullscreen mode
  ///
  /// This method:
  /// - Restores system UI visibility
  /// - Restores original orientation preferences
  static Future<void> exitFullscreen() async {
    // Restore system UI
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );

    // Restore orientation preferences
    // Default to all orientations or portrait up
    if (PlatformUtils.isAndroid || PlatformUtils.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
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
  /// - lockToLandscape: If true, locks orientation to landscape
  /// - onExit: Optional callback when fullscreen is exited
  ///
  /// **Returns:**
  /// The result from the dialog when it's dismissed
  static Future<T?> showFullscreenDialog<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool lockToLandscape = true,
    VoidCallback? onExit,
  }) async {
    // Enter fullscreen mode
    await enterFullscreen(lockToLandscape: lockToLandscape);

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
