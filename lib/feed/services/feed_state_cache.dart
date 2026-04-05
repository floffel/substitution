import 'feed_candidate.dart';

/// Caches the feed scroll position and loaded items so that navigating away
/// from the home page (e.g. to a post detail) and back restores the user's
/// previous position instead of reloading from scratch.
///
/// This object lives in the Provider tree above the router and therefore
/// survives route changes that unmount [HomePage]. It does NOT persist
/// across app restarts.
class FeedStateCache {
  /// The flat list of loaded feed items across all pages.
  List<FeedCandidate>? cachedItems;

  /// The scroll offset the user was at when they navigated away.
  double scrollOffset = 0.0;

  /// The latest next-page key from the paginator so pagination can continue
  /// from where it left off. Keyed by room ID (not Timeline object) so the
  /// key survives widget lifecycle changes.
  PageKey? lastPageKey;

  /// Map of room ID -> first (newest) event ID displayed for that room.
  /// Used by the "fetch future events" pull-to-refresh logic.
  Map<String, String>? firstEventIds;

  /// Whether the page key was already initialized from timelines.
  bool wasPageKeyInitialized = false;

  /// Carry-forward candidate event IDs per room. Stored so that events
  /// fetched but not yet displayed survive widget dispose/recreate cycles.
  /// Each entry maps a room ID to a list of origEvent IDs that can be
  /// resolved from the room's timeline on restore.
  Map<String, List<String>>? carryForwardEventIds;

  /// The frontier timestamp (t_safe from the last page). Used for
  /// frontier-aware loading decisions after cache restore.
  DateTime? frontier;

  /// Whether there is cached data worth restoring.
  bool get hasCache => cachedItems?.isNotEmpty ?? false;

  /// Wipe all cached state (e.g. when the room set changes and a full
  /// reload is required).
  void clear() {
    cachedItems = null;
    scrollOffset = 0.0;
    lastPageKey = null;
    firstEventIds = null;
    wasPageKeyInitialized = false;
    carryForwardEventIds = null;
    frontier = null;
  }
}
