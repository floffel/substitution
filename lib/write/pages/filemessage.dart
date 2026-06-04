import '/write/mixins/send_with_retry.dart';
import '/write/widgets/room_header.dart';
import '/write/widgets/reply_preview.dart';
import '/write/widgets/send_progress_dialog.dart';
import '/shared/mixins/matrix_essentials.dart';

import '/shared/platform/image_helper.dart' show imageFromPath;
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:file_selector/file_selector.dart';
import 'package:easy_localization/easy_localization.dart';

@immutable
class FileMessageWrite extends StatefulWidget {
  const FileMessageWrite({super.key, required this.roomId, this.eventId});

  final String roomId;
  final String? eventId;

  static FileMessageWriteState of(BuildContext context) {
    return context.findAncestorStateOfType<FileMessageWriteState>()!;
  }

  @override
  FileMessageWriteState createState() => FileMessageWriteState();
}

class FileMessageWriteState extends State<FileMessageWrite>
    with MatrixEssentials, SendWithRetry {
  final List<String> imageExtensions = const [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];
  final List<String> videoExtensions = const ['mp4', 'mov', 'webm'];
  final List<String> audioExtensions = const ['mp3', 'ogg', 'wav', 'm4a'];
  final List<String> documentExtensions = const [
    'pdf',
    'doc',
    'docx',
    'txt',
    'zip',
  ];

  late final XTypeGroup imgTypeGroup = XTypeGroup(
    label: 'Images',
    extensions: imageExtensions,
  );
  late final XTypeGroup videoTypeGroup = XTypeGroup(
    label: 'Videos',
    extensions: videoExtensions,
  );
  late final XTypeGroup audioTypeGroup = XTypeGroup(
    label: 'Audio',
    extensions: audioExtensions,
  );
  late final XTypeGroup documentTypeGroup = XTypeGroup(
    label: 'Documents',
    extensions: documentExtensions,
  );

  List<
    ({
      XFile file,
      TextEditingController textEditController,
      TextEditingController captionController,
    })
  >
  files = [];

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

  String _extensionOf(XFile f) => f.name.split('.').last.toLowerCase();

  bool _isImage(XFile f) => imageExtensions.contains(_extensionOf(f));
  bool _isVideo(XFile f) => videoExtensions.contains(_extensionOf(f));
  bool _isAudio(XFile f) => audioExtensions.contains(_extensionOf(f));

  IconData _fileIcon(XFile f) {
    if (_isImage(f)) return Icons.image_rounded;
    if (_isVideo(f)) return Icons.videocam_rounded;
    if (_isAudio(f)) return Icons.audiotrack_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  void dispose() {
    for (final f in files) {
      f.textEditController.dispose();
      f.captionController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFiles() async {
    for (var f in files) {
      f.textEditController.dispose();
      f.captionController.dispose();
    }

    // Opens the platform file picker filtered to the supported media /
    // document types. `file_selector` v9+ (the version this project
    // uses) fully supports `acceptedTypeGroups` on iOS via UTType,
    // so the previous "iOS unsupported" caveat is no longer relevant.
    final List<XFile> newFiles = await openFiles(
      acceptedTypeGroups: [
        imgTypeGroup,
        videoTypeGroup,
        audioTypeGroup,
        documentTypeGroup,
      ],
    );
    if (newFiles.isEmpty) return;

    setState(() {
      files =
          newFiles.map((f) {
            final nameWithoutExt = f.name
                .split('.')
                .reversed
                .skip(1)
                .toList()
                .reversed
                .join('.');
            return (
              file: f,
              textEditController: TextEditingController(text: nameWithoutExt),
              captionController: TextEditingController(),
            );
          }).toList();
    });
  }

  Future<void> _send() async {
    if (files.isEmpty || room == null) return;

    // Capture context objects up-front (before any `await`) so we
    // don't have to use `context` across async gaps below.
    final scavMsg = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final goRouter = GoRouter.of(context);

    // Compute the event + thread relationship once. The mixin handles
    // per-file retry, so we don't want to re-fetch the parent event
    // every time.
    Event? answerEvent;
    var eventThreadId = widget.eventId;
    try {
      answerEvent = await event;
      if (answerEvent?.relationshipType == RelationshipTypes.thread) {
        // commenting a comment => we can't start a new thread, rather
        // use the existing one
        eventThreadId = answerEvent?.relationshipEventId;
      }
    } catch (e) {
      debugPrint('Event fetch error: $e');
    }

    // Show the initial "starting upload" overlay while the per-file
    // loop kicks in. (Each subsequent per-file showSendLoadingDialog
    // is managed by the mixin.)
    showSendLoadingDialog(
      // `mounted` is checked at the top of the function; the dialog
      // uses the captured `scavMsg` / `navigator` above, not `context`.
      // ignore: use_build_context_synchronously
      context,
      messageKey: 'write.filemessage.upload_start',
    );

    // Upload each file with its own retry loop. We pass
    // [navigateOnSuccess] = false so the mixin doesn't navigate after
    // each individual file — we do that once, at the end, after the
    // whole batch succeeds.
    var allSucceeded = true;
    for (final f in files) {
      final uploadFileName = '${f.textEditController.text}.${_extensionOf(f.file)}';
      final caption = f.captionController.text.trim();

      // The mixin captures `context` synchronously at entry. We check
      // `mounted` before each iteration below.
      final success = await sendWithRetry(
        // ignore: use_build_context_synchronously
        context: context,
        room: room!,
        client: client,
        threadRootEventId: eventThreadId,
        navigateOnSuccess: false,
        loadingMessageKey: 'write.filemessage.upload_file_process',
        loadingArgs: [uploadFileName],
        errorMessageKey: 'write.filemessage.upload_error',
        errorArgs: [f.textEditController.text],
        successMessageKey: 'write.filemessage.upload_file_complete',
        send: () async {
          final bytes = await f.file.readAsBytes();
          final matrixFile = MatrixFile(bytes: bytes, name: uploadFileName);
          return room!.sendFileEvent(
            matrixFile,
            threadRootEventId: eventThreadId,
            inReplyTo: answerEvent,
            extraContent: caption.isNotEmpty
                ? {'body': caption, 'filename': uploadFileName}
                : null,
          );
        },
      );

      if (!success) {
        // User cancelled — stop uploading remaining files.
        allSucceeded = false;
        break;
      }
    }

    navigator.pop(); // pop the "starting upload" overlay
    if (!mounted) return;

    if (allSucceeded) {
      scavMsg.showSnackBar(
        SnackBar(content: Text('write.filemessage.upload_complete'.tr())),
      );
    }

    // Navigate once at the end, mirroring the original behavior.
    if (answerEvent != null) {
      goRouter.go('/room/${answerEvent.room.id}/${answerEvent.eventId}');
    } else if (room != null) {
      goRouter.go('/feed/${room!.id}');
    } else {
      goRouter.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (widget.eventId != null) ReplyPreviewWidget(future: eventData),

              if (room != null) ...[
                const SizedBox(height: 4),
                RoomHeaderWidget(room: room!),
              ],

              const SizedBox(height: 12),

              // File picker button
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add_rounded),
                label: Text('write.filemessage.upload_files'.tr()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),

              const SizedBox(height: 8),

              // File entries
              if (files.isNotEmpty) ...[
                ...files.map(
                  (f) => _FileEntryCard(
                    key: ValueKey(f.file.path),
                    file: f.file,
                    textEditController: f.textEditController,
                    captionController: f.captionController,
                    fileIcon: _fileIcon(f.file),
                    isImage: _isImage(f.file),
                    isVideo: _isVideo(f.file),
                    isAudio: _isAudio(f.file),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Send button
        FilledButton.icon(
          onPressed: files.isNotEmpty ? _send : null,
          icon: const Icon(Icons.send_rounded),
          label: Text(
            files.isEmpty
                ? 'write.filemessage.send_button_empty'.tr()
                : 'write.filemessage.send_button'.tr(
                  args: [files.length.toString()],
                ),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _FileEntryCard extends StatelessWidget {
  const _FileEntryCard({
    super.key,
    required this.file,
    required this.textEditController,
    required this.captionController,
    required this.fileIcon,
    required this.isImage,
    required this.isVideo,
    required this.isAudio,
  });

  final XFile file;
  final TextEditingController textEditController;
  final TextEditingController captionController;
  final IconData fileIcon;
  final bool isImage;
  final bool isVideo;
  final bool isAudio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File preview
            if (isImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageFromPath(file.path),
              ),
              const SizedBox(height: 8),
            ] else ...[
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        fileIcon,
                        size: 32,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVideo
                            ? 'write.filemessage.video_preview'.tr()
                            : isAudio
                            ? 'write.filemessage.audio_preview'.tr()
                            : file.name.split('.').last.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Title field
            TextFormField(
              controller: textEditController,
              decoration: InputDecoration(
                labelText: 'write.filemessage.title_header'.tr(),
                prefixIcon: const Icon(Icons.title_rounded),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),

            // Caption field
            TextFormField(
              controller: captionController,
              decoration: InputDecoration(
                labelText: 'write.filemessage.caption_header'.tr(),
                prefixIcon: const Icon(Icons.short_text_rounded),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
