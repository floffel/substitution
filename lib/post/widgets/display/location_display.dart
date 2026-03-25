import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

/// Displays an m.location event as a tappable map card with coordinates.
class LocationDisplay extends StatelessWidget {
  const LocationDisplay({super.key, required this.event});

  final Event event;

  String? get _geoUri => event.content.tryGet<String>('geo_uri');
  String? get _body => event.content.tryGet<String>('body');

  ({double lat, double lon})? get _coordinates {
    final uri = _geoUri;
    if (uri == null || !uri.startsWith('geo:')) return null;
    final coords = uri.substring(4).split(';').first.split(',');
    if (coords.length < 2) return null;
    final lat = double.tryParse(coords[0]);
    final lon = double.tryParse(coords[1]);
    if (lat == null || lon == null) return null;
    return (lat: lat, lon: lon);
  }

  String get _mapTileUrl {
    final coords = _coordinates;
    if (coords == null) return '';
    // OpenStreetMap static tile at zoom 15 — shows a 256x256 tile centered at the location
    // We use a slightly different approach: a URL that opens in any map app
    return 'https://tile.openstreetmap.org/15/'
        '${_lonToTileX(coords.lon, 15)}/'
        '${_latToTileY(coords.lat, 15)}.png';
  }

  int _lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }

  int _latToTileY(double lat, int zoom) {
    final latRad = lat * 3.14159265358979 / 180.0;
    return ((1.0 -
                (latRad.abs() < 1.5707963
                    ? (1.0 / 3.14159265358979) *
                        (3.14159265358979 / 4.0 + latRad / 2.0) /
                        (3.14159265358979 / 4.0)
                    : 0.0)) /
            2.0 *
            (1 << zoom))
        .floor();
  }

  Future<void> _openInMaps() async {
    final coords = _coordinates;
    if (coords == null) return;
    final uri = Uri.parse(
      'geo:${coords.lat},${coords.lon}?q=${coords.lat},${coords.lon}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to OpenStreetMap web
      final webUri = Uri.parse(
        'https://www.openstreetmap.org/?mlat=${coords.lat}&mlon=${coords.lon}&zoom=15',
      );
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final coords = _coordinates;
    final desc = _body ?? 'post.location.shared'.tr();

    if (coords == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.location_off_rounded, color: colorScheme.error),
            const SizedBox(width: 8),
            Text('post.location.invalid'.tr()),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _openInMaps,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Map tile background
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.network(
                _mapTileUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.map_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
              ),
            ),
            // Pin overlay
            Positioned.fill(
              child: Center(
                child: Icon(
                  Icons.location_on_rounded,
                  color: colorScheme.error,
                  size: 40,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            // Bottom info bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        desc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'post.location.tap_to_open'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
