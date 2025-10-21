/// Platform utility to check the current platform without importing dart:io
///
/// This allows the package to be WASM compatible by using conditional imports.
library;

export 'platform_utils_stub.dart' if (dart.library.io) 'platform_utils_io.dart';
