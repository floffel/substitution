import '/write/widgets/room_header.dart';
import '/write/widgets/reply_preview.dart';
import '/write/widgets/send_progress_dialog.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class LocationMessageWrite extends StatefulWidget {
  const LocationMessageWrite({super.key, required this.roomId, this.eventId});

  final String roomId;
  final String? eventId;

  @override
  LocationMessageWriteState createState() => LocationMessageWriteState();
}

class LocationMessageWriteState extends State<LocationMessageWrite> {
  Client get client => Provider.of<Client>(context, listen: false);
  Room? get room => client.getRoomById(widget.roomId);
  Future<Event?> get event async =>
      widget.eventId == null || room == null
          ? null
          : Event.fromMatrixEvent(
            await client.getOneRoomEvent(widget.roomId, widget.eventId!),
            room!,
          );

  Future<({Event event, Event displayEvent})?> get eventData async {
    final e = await event;
    if (e == null) return null;
    final timeline = await e.room.getTimeline(eventContextId: e.eventId);
    return (event: e, displayEvent: e.getDisplayEvent(timeline));
  }

  final MapController _mapController = MapController();
  final TextEditingController _descriptionController = TextEditingController();

  // Default to a central location; updated when the user moves the pin or uses GPS
  LatLng _pinLocation = const LatLng(51.5, -0.09);
  bool _locationLoading = false;

  @override
  void dispose() {
    _mapController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locationLoading = true);

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('write.locationmessage.location_disabled'.tr()),
          ),
        );
      }
      setState(() => _locationLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('write.locationmessage.permission_denied'.tr()),
            ),
          );
        }
        setState(() => _locationLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'write.locationmessage.permission_denied_forever'.tr(),
            ),
          ),
        );
      }
      setState(() => _locationLoading = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        _pinLocation = newLocation;
        _locationLoading = false;
      });
      _mapController.move(newLocation, 15.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('write.locationmessage.location_error'.tr())),
        );
      }
      setState(() => _locationLoading = false);
    }
  }

  Future<void> _send() async {
    final scavMsg = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final goRouter = GoRouter.of(context);

    final description =
        _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : 'write.locationmessage.default_body'.tr();
    final geoUri = 'geo:${_pinLocation.latitude},${_pinLocation.longitude}';

    String? ret;
    var eventThreadId = widget.eventId;
    bool userCancel = false;

    while (ret == null && !userCancel) {
      if (!mounted) return;

      showSendLoadingDialog(
        context,
        messageKey: 'write.locationmessage.send_start',
      );

      try {
        final currentEvent = await event;
        if (currentEvent?.relationshipType == RelationshipTypes.thread) {
          eventThreadId = currentEvent?.relationshipEventId;
        }

        // Use sendEvent directly (sendLocation lacks reply/thread support)
        ret = await room!.sendEvent(
          {
            'msgtype': MessageTypes.Location,
            'body': description,
            'geo_uri': geoUri,
          },
          threadRootEventId: eventThreadId,
          inReplyTo: currentEvent,
        );
      } catch (e) {
        debugPrint('Location send error: $e');
        // ret stays null so the error dialog below is shown
      }

      navigator.pop();

      if (ret == null) {
        if (!mounted) break;
        userCancel = await showSendErrorDialog(
          context,
          errorMessageKey: 'write.locationmessage.send_failed',
        );
      } else {
        if (mounted) {
          scavMsg.showSnackBar(
            SnackBar(content: Text('write.locationmessage.send_complete'.tr())),
          );
        }
      }
    }

    if (eventThreadId != null) {
      final answerEvent = Event.fromMatrixEvent(
        await client.getOneRoomEvent(widget.roomId, eventThreadId),
        room!,
      );
      goRouter.go('/room/${answerEvent.room.id}/${answerEvent.eventId}');
    } else if (room != null) {
      goRouter.go('/feed/${room!.id}');
    } else {
      goRouter.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.eventId != null || room != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.eventId != null)
                  ReplyPreviewWidget(future: eventData),
                if (room != null) ...[
                  const SizedBox(height: 4),
                  RoomHeaderWidget(room: room!),
                ],
              ],
            ),
          ),

        // Map
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pinLocation,
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) {
                      setState(() => _pinLocation = point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.substitution.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pinLocation,
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.location_on_rounded,
                            color: colorScheme.primary,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // GPS button overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: FloatingActionButton.small(
                    heroTag: 'locationGps',
                    onPressed: _locationLoading ? null : _useCurrentLocation,
                    tooltip: 'write.locationmessage.use_current_location'.tr(),
                    child:
                        _locationLoading
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Coordinates display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'write.locationmessage.coordinates'.tr(
              args: [
                _pinLocation.latitude.toStringAsFixed(6),
                _pinLocation.longitude.toStringAsFixed(6),
              ],
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Description field
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'write.locationmessage.description_label'.tr(),
            hintText: 'write.locationmessage.description_hint'.tr(),
            prefixIcon: const Icon(Icons.edit_location_rounded),
            border: const OutlineInputBorder(),
          ),
          maxLines: 2,
          minLines: 1,
        ),

        const SizedBox(height: 12),

        // Send button
        FilledButton.icon(
          onPressed: _send,
          icon: const Icon(Icons.send_rounded),
          label: Text('write.locationmessage.send_button'.tr()),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
