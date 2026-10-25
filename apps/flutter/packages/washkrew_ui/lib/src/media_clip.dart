import 'dart:typed_data';

class MediaClip {
  const MediaClip({
    required this.bytes,
    required this.contentType,
    required this.seconds,
  });
  final Uint8List bytes;
  final String contentType;
  final int seconds;
  bool get video => contentType.startsWith('video/');
}
