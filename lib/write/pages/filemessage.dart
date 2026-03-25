import '/write/widgets/room_header.dart';
import '/write/widgets/reply_preview.dart';
import '/write/widgets/send_progress_dialog.dart';

import '/shared/platform/image_helper.dart' show imageFromPath;
import 'package:provider/provider.dart';
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

class FileMessageWriteState extends State<FileMessageWrite> {
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

  // todo: make client a mixin
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

    // TODO: change for ios, file types are unsupported
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
    if (files.isEmpty) return;

    final scavMsg = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final goRouter = GoRouter.of(context);

    debugPrint("started sending message...");

    showSendLoadingDialog(
      context,
      messageKey: 'write.filemessage.upload_start',
    );

    Event? answerEvent = await event;
    var eventThreadId = widget.eventId;

    if (answerEvent?.relationshipType == RelationshipTypes.thread) {
      // commenting a comment => we can't start a new thread, rather use the existing one
      eventThreadId = answerEvent?.relationshipEventId;
    }

    navigator.pop(); // pop the "starting upload" overlay

    for (var f in files) {
      String? ret;
      bool userCancel = false;
      // try uploading the file as long as it did not succeed or the user did not cancel
      while (ret == null && !userCancel) {
        final String uploadFileName = [
          f.textEditController.text,
          _extensionOf(f.file),
        ].join(".");

        if (!mounted) return;
        showSendLoadingDialog(
          context,
          messageKey: 'write.filemessage.upload_file_process',
          args: [uploadFileName],
        );

        final MatrixFile uploadFile = MatrixFile(
          bytes: await f.file.readAsBytes(),
          name: uploadFileName,
        );
        final caption = f.captionController.text.trim();
        ret = await room!.sendFileEvent(
          uploadFile,
          threadRootEventId: eventThreadId,
          inReplyTo: answerEvent,
          extraContent:
              caption.isNotEmpty
                  ? {'body': caption, 'filename': uploadFileName}
                  : null,
        );

        navigator.pop(); // pop the Uploading file ... dialog

        if (ret == null) {
          if (!mounted) break;
          userCancel = await showSendErrorDialog(
            context,
            errorMessageKey: 'write.filemessage.upload_error',
            errorArgs: [f.textEditController.text],
            retryKey: 'write.filemessage.buttons.upload_retry',
            cancelKey: 'write.filemessage.buttons.upload_stop',
          );
        } else {
          if (mounted) {
            scavMsg.showSnackBar(
              SnackBar(
                content: Text(
                  'write.filemessage.upload_file_complete'.tr(
                    args: [uploadFileName],
                  ),
                ),
              ),
            );
          }
        }
      }
    }

    if (mounted) {
      scavMsg.showSnackBar(
        SnackBar(content: Text('write.filemessage.upload_complete'.tr())),
      );
    }

    if (answerEvent != null) {
      goRouter.go(
        Uri(
          path: "/post/${answerEvent.eventId}",
          queryParameters: {'room': answerEvent.room.id},
        ).toString(),
      );
    } else if (room != null) {
      goRouter.go("/feed/${room!.id}");
    } else {
      goRouter.go("/");
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
