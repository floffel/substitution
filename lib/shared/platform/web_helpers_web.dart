// Web implementation of browser-specific helpers.
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// Creates a blob object URL from raw bytes.
String createBlobUrl(Uint8List bytes) {
  final blob = web.Blob([bytes.toJS].toJS);
  return web.URL.createObjectURL(blob);
}

/// Revokes a previously created blob object URL.
void revokeBlobUrl(String url) {
  web.URL.revokeObjectURL(url);
}

/// Returns the current window's origin (e.g. "https://example.com").
String getWindowLocationOrigin() {
  return web.window.location.origin;
}

/// Navigates the current window to the given URL.
void windowLocationAssign(String url) {
  web.window.location.assign(url);
}
