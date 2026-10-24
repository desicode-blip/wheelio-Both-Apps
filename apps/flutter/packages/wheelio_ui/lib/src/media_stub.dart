import 'package:flutter/material.dart';
import 'media_clip.dart';

Future<MediaClip?> captureVideo(BuildContext context) async => throw StateError(
  'Record a video in the iPhone app. Text and photos remain available here.',
);
Future<MediaClip?> captureVoice(BuildContext context) async => throw StateError(
  'Record a voice note in the iPhone app. Text and photos remain available here.',
);

class MediaPreview extends StatelessWidget {
  const MediaPreview(this.clip, {super.key});
  final MediaClip clip;
  @override
  Widget build(BuildContext context) =>
      Text('${clip.video ? 'Video' : 'Voice note'} · ${clip.seconds}s');
}
