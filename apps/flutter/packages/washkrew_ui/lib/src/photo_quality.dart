import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

enum PhotoIssue { unreadable, tooSmall, tooDark, obscured }

/// Conservative capture-quality checks, not a cleanliness or identity verdict.
Future<PhotoIssue?> checkPhotoQuality(Uint8List bytes) =>
    compute(_inspect, bytes);
PhotoIssue? _inspect(Uint8List bytes) {
  try {
    final source = image.decodeImage(bytes);
    if (source == null) return PhotoIssue.unreadable;
    if (source.width < 320 || source.height < 240) return PhotoIssue.tooSmall;
    final sample = image.copyResize(source, width: 128);
    double sum = 0, squares = 0;
    int count = 0, dark = 0;
    for (final pixel in sample) {
      final value = .2126 * pixel.r + .7152 * pixel.g + .0722 * pixel.b;
      sum += value;
      squares += value * value;
      count++;
      if (value < 25) dark++;
    }
    final mean = sum / count, variance = squares / count - mean * mean;
    if (mean < 25 && dark / count > .8) return PhotoIssue.tooDark;
    if (variance < 8) return PhotoIssue.obscured;
    return null;
  } catch (_) {
    return PhotoIssue.unreadable;
  }
}

String photoIssueMessage(PhotoIssue issue) => switch (issue) {
  PhotoIssue.tooDark => 'The photo is too dark. Add light and take it again.',
  PhotoIssue.tooSmall => 'Move closer and take a full-size photo.',
  PhotoIssue.obscured =>
    'The lens appears covered or the photo has no visible detail. Take it again.',
  PhotoIssue.unreadable => 'This photo could not be read. Take it again.',
};
