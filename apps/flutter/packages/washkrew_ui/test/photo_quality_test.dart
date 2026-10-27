import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:washkrew_ui/washkrew_ui.dart';

void main() {
  test(
    'capture checks distinguish unreadable, tiny, dark and obscured photos',
    () async {
      expect(
        await checkPhotoQuality(Uint8List.fromList([1, 2, 3])),
        PhotoIssue.unreadable,
      );
      expect(
        await checkPhotoQuality(
          Uint8List.fromList(
            image.encodePng(image.Image(width: 16, height: 16)),
          ),
        ),
        PhotoIssue.tooSmall,
      );
      final sample = image.Image(width: 640, height: 480);
      expect(
        await checkPhotoQuality(Uint8List.fromList(image.encodePng(sample))),
        PhotoIssue.tooDark,
      );
      image.fill(sample, color: image.ColorRgb8(255, 255, 255));
      expect(
        await checkPhotoQuality(Uint8List.fromList(image.encodePng(sample))),
        PhotoIssue.obscured,
      );
      for (var y = 0; y < 480; y++) {
        for (var x = 0; x < 640; x++) {
          sample.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
        }
      }
      expect(
        await checkPhotoQuality(Uint8List.fromList(image.encodeJpg(sample))),
        isNull,
      );
    },
  );
}
