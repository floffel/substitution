import '/write/widgets/room_header.dart';
import '/write/widgets/reply_preview.dart';
import '/write/widgets/send_progress_dialog.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

@immutable
class VoiceMessageWrite extends StatefulWidget {
  const VoiceMessageWrite({super.key, required this.roomId, this.eventId});

  final String roomId;
  final String? eventId;

  @override
  VoiceMessageWriteState createState() => VoiceMessageWriteState();
}

class VoiceMessageWriteState extends State<VoiceMessageWrite> {
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

  final AudioRecorder _recorder = AudioRecorder();
  String? _recordingPath;
  bool _isRecording = false;
  bool _hasRecording = false;
  Duration _duration = Duration.zero;
  List<double> _amplitudes = [];

  // Simple periodic timer for updating duration and amplitude
  Stream<Amplitude>? _amplitudeStream;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('write.voicemessage.permission_denied'.tr())),
        );
      }
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );

    _amplitudeStream = _recorder.onAmplitudeChanged(
      const Duration(milliseconds: 100),
    );

    setState(() {
      _recordingPath = path;
      _isRecording = true;
      _hasRecording = false;
      _duration = Duration.zero;
      _amplitudes = [];
    });

    // Start a timer to update duration
    _updateDuration();
  }

  Future<void> _updateDuration() async {
    while (_isRecording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_isRecording && mounted) {
        setState(() => _duration = _duration + const Duration(seconds: 1));
      }
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _hasRecording = path != null;
      if (path != null) _recordingPath = path;
    });
  }

  Future<void> _discardRecording() async {
    if (_isRecording) {
      await _recorder.stop();
    }
    if (_recordingPath != null) {
      try {
        await File(_recordingPath!).delete();
      } catch (_) {}
    }
    setState(() {
      _isRecording = false;
      _hasRecording = false;
      _recordingPath = null;
      _duration = Duration.zero;
      _amplitudes = [];
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _send() async {
    if (_recordingPath == null) return;

    final scavMsg = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final goRouter = GoRouter.of(context);

    String? ret;
    var eventThreadId = widget.eventId;
    bool userCancel = false;

    while (ret == null && !userCancel) {
      if (!mounted) return;

      showSendLoadingDialog(
        context,
        messageKey: 'write.voicemessage.send_start',
      );

      final currentEvent = await event;
      if (currentEvent?.relationshipType == RelationshipTypes.thread) {
        eventThreadId = currentEvent?.relationshipEventId;
      }

      final bytes = await File(_recordingPath!).readAsBytes();
      final audioFile = MatrixAudioFile(
        bytes: bytes,
        name: 'voice_message.m4a',
        duration: _duration.inMilliseconds,
      );

      // Build waveform from amplitudes (normalize to 0-1024)
      final waveform =
          _amplitudes.isNotEmpty
              ? _amplitudes
                  .map((a) => ((a + 60) / 60 * 1024).clamp(0, 1024).round())
                  .toList()
              : null;

      ret = await room!.sendFileEvent(
        audioFile,
        threadRootEventId: eventThreadId,
        inReplyTo: currentEvent,
        extraContent: {
          'org.matrix.msc1767.audio': {
            'duration': _duration.inMilliseconds,
            if (waveform != null) 'waveform': waveform,
          },
          'org.matrix.msc3245.voice': {},
        },
      );

      navigator.pop();

      if (ret == null) {
        if (!mounted) break;
        userCancel = await showSendErrorDialog(
          context,
          errorMessageKey: 'write.voicemessage.send_failed',
        );
      } else {
        if (mounted) {
          scavMsg.showSnackBar(
            SnackBar(content: Text('write.voicemessage.send_complete'.tr())),
          );
        }
      }
    }

    if (eventThreadId != null) {
      final answerEvent = Event.fromMatrixEvent(
        await client.getOneRoomEvent(widget.roomId, eventThreadId),
        room!,
      );
      goRouter.go(
        Uri(
          path: '/post/${answerEvent.eventId}',
          queryParameters: {'room': answerEvent.room.id},
        ).toString(),
      );
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

        // Voice recorder area
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform / status indicator
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child:
                      _isRecording
                          ? StreamBuilder<Amplitude>(
                            stream: _amplitudeStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final amp = snapshot.data!.current;
                                // Store amplitude for waveform data
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (_isRecording) _amplitudes.add(amp);
                                });
                              }
                              return _WaveformIndicator(
                                isRecording: true,
                                color: colorScheme.error,
                              );
                            },
                          )
                          : _hasRecording
                          ? _WaveformIndicator(
                            isRecording: false,
                            color: colorScheme.primary,
                          )
                          : Icon(
                            Icons.mic_rounded,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                ),

                const SizedBox(height: 16),

                // Duration display
                Text(
                  _formatDuration(_duration),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: 'monospace',
                    color:
                        _isRecording
                            ? colorScheme.error
                            : _hasRecording
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _isRecording
                      ? 'write.voicemessage.recording'.tr()
                      : _hasRecording
                      ? 'write.voicemessage.recorded'.tr()
                      : 'write.voicemessage.tap_to_record'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 32),

                // Record/Stop button
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _isRecording
                              ? colorScheme.errorContainer
                              : colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 36,
                      color:
                          _isRecording
                              ? colorScheme.error
                              : colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),

                if (_hasRecording) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _discardRecording,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text('write.voicemessage.discard'.tr()),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Send button
        FilledButton.icon(
          onPressed: _hasRecording ? _send : null,
          icon: const Icon(Icons.send_rounded),
          label: Text('write.voicemessage.send_button'.tr()),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Simple animated waveform bars indicator.
class _WaveformIndicator extends StatefulWidget {
  const _WaveformIndicator({required this.isRecording, required this.color});

  final bool isRecording;
  final Color color;

  @override
  State<_WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends State<_WaveformIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.isRecording) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_WaveformIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isRecording) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(12, (i) {
            final phase = (i / 11 * 3.14159);
            final height =
                widget.isRecording
                    ? 10 +
                        50 *
                            (((_controller.value + phase / 6.28).remainder(
                              1.0,
                            )).abs())
                    : 20.0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
