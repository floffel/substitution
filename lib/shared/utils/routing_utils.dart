/// Routing utilities used by the deep-link / auth flow.
///
/// The flow:
/// 1. User opens a deep link (e.g. `/feed/photo_art:matrix.org`) while logged out.
/// 2. The protected route's `redirect` calls [preserveDestinationInIntroRedirect]
///    which returns `/intro?goto=/feed/photo_art%3Aphoto_art%3Amatrix.org`.
/// 3. The user completes the introduction / login flow.
/// 4. The final "Continue to App" button reads the `goto` query parameter,
///    validates it via [safeGotoDestination], and navigates there if safe.
library;

/// Pages that should not carry a `?goto=` parameter (avoids redirect loops
/// when an auth page tries to preserve a destination that's also an auth
/// page, or when a `?goto=` is already present and shouldn't be nested).
const Set<String> _kAuthPaths = {
  '/intro',
  '/auth/login',
  '/auth/host',
  '/age-gate',
  '/login-callback',
};

/// Returns a redirect path to `/intro` that preserves [requestedUri] as a
/// `?goto=` parameter, so the user can be returned to their original
/// destination after completing the login flow.
///
/// Returns the bare path `/intro` (with no `goto`) if [requestedUri] is
/// already an auth page, or if it already carries a `goto` parameter
/// (to prevent nested `?goto=` chains and redirect loops).
///
/// Pass the full `state.uri` from a `GoRouterState` to preserve both the
/// path and any query parameters of the original request.
String? preserveDestinationInIntroRedirect(Uri requestedUri) {
  if (_kAuthPaths.contains(requestedUri.path)) {
    return null;
  }
  if (requestedUri.queryParameters.containsKey('goto')) {
    return null;
  }
  final encoded = Uri.encodeComponent(requestedUri.toString());
  return '/intro?goto=$encoded';
}

/// Validates a `?goto=` query parameter value, returning a safe internal
/// destination path or `null` if the value is unsafe.
///
/// Rejects:
/// - null / empty strings
/// - External URLs (anything that doesn't start with `/`)
/// - Protocol-relative URLs (`//example.com`) which the browser would
///   interpret as cross-origin
/// - Auth pages (would create a redirect loop)
String? safeGotoDestination(String? goto) {
  if (goto == null || goto.isEmpty) return null;
  // Only allow internal absolute paths.
  if (!goto.startsWith('/')) return null;
  // Reject protocol-relative URLs ("//example.com").
  if (goto.startsWith('//')) return null;
  // Don't redirect back into the auth flow.
  final pathOnly = goto.split('?').first.split('#').first;
  if (_kAuthPaths.contains(pathOnly)) return null;
  return goto;
}
