/// Returns a short, human-readable relative time string for the given [dateTime].
///
/// Examples: "just now", "2m ago", "5h ago", "3d ago", "2w ago"
String relativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.isNegative) {
    return 'just now';
  }

  if (diff.inSeconds < 60) {
    return 'just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  } else if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  } else if (diff.inDays < 30) {
    return '${diff.inDays ~/ 7}w ago';
  } else if (diff.inDays < 365) {
    return '${diff.inDays ~/ 30}mo ago';
  } else {
    return '${diff.inDays ~/ 365}y ago';
  }
}
