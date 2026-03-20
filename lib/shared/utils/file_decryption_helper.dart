import '/shared/platform/platform.dart';
import '/shared/platform/web_helpers.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads and decrypts an encrypted attachment, saves it to a temporary
/// file on disk, and returns the [File] handle. If the file already exists
/// on disk it is returned directly without re-downloading.
Future<File> getDecryptedFileForEvent(Event e) async {
  MatrixFile f = await e.downloadAndDecryptAttachment();

  final dir = await getTemporaryDirectory();
  final fileName = Uri.encodeComponent(
    e
        .attachmentOrThumbnailMxcUrl()!
        .pathSegments
        .last, // or event.content.tryGet<String>('filename') ?? 'somefile..';
  );
  final file = File('${dir.path}/${fileName}_${f.name}');
  if (await file.exists() == false) {
    await file.writeAsBytes(f.bytes);
  }
  return file;
}

/// Downloads and decrypts an encrypted attachment and returns a blob URL
/// pointing to the decrypted bytes. Callers are responsible for tracking
/// the returned URL and revoking it when no longer needed.
Future<String> getDecryptedFileObjectUrlForEvent(Event e) async {
  final file = await e.downloadAndDecryptAttachment();
  final url = createBlobUrl(file.bytes);
  return url;
}
