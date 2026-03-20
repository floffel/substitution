// Stub implementation of browser-specific helpers for native platforms.
import 'dart:typed_data';

/// Creates a blob object URL from raw bytes. Not supported on native.
String createBlobUrl(Uint8List bytes) {
  throw UnsupportedError('createBlobUrl is not supported on native platforms');
}

/// Revokes a previously created blob object URL. No-op on native.
void revokeBlobUrl(String url) {}

/// Returns the current window's origin. Not supported on native.
String getWindowLocationOrigin() {
  throw UnsupportedError(
    'getWindowLocationOrigin is not supported on native platforms',
  );
}

/// Navigates the current window to the given URL. Not supported on native.
void windowLocationAssign(String url) {
  throw UnsupportedError(
    'windowLocationAssign is not supported on native platforms',
  );
}
