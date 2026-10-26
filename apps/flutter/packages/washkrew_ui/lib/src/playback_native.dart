import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
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
  final directory = await getTemporaryDirectory();
  final suffix = clip.video
      ? (clip.contentType == 'video/quicktime' ? 'mov' : 'mp4')
      : 'm4a';
  final file = File(
    '${directory.path}/washkrew-playback-${DateTime.now().microsecondsSinceEpoch}.$suffix',
  );
  await file.writeAsBytes(clip.bytes, flush: true);
  return (
    audio: DeviceFileSource(file.path),
    video: clip.video ? VideoPlayerController.file(file) : null,
    cleanup: () async {
      if (await file.exists()) await file.delete();
    },
  );
}
