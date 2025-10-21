import 'dart:io';

/// Native platform implementation using dart:io
class PlatformUtils {
  /// Returns true if the current platform is Android
  static bool get isAndroid => Platform.isAndroid;

  /// Returns true if the current platform is iOS
  static bool get isIOS => Platform.isIOS;

  /// Returns true if the current platform is web
  static bool get isWeb => false;
}
