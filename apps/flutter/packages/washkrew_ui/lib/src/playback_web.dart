import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'media_clip.dart';

Future<
  ({
    Source audio,
    VideoPlayerController? video,
    Future<void> Function() cleanup,
  })
>
playbackSource(MediaClip clip) async {
  final blob = web.Blob(
    [clip.bytes.toJS].toJS,
    web.BlobPropertyBag(type: clip.contentType),
  );
  final url = web.URL.createObjectURL(blob);
  return (
    audio: UrlSource(url, mimeType: clip.contentType),
    video: clip.video ? VideoPlayerController.networkUrl(Uri.parse(url)) : null,
    cleanup: () async {
      web.URL.revokeObjectURL(url);
    },
  );
}
