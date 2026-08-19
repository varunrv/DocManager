import 'dart:typed_data';
import 'dart:ui' as ui;

import 'mime_utils.dart';

Future<Uint8List?> generateThumbnail(Uint8List bytes, String mimeType) async {
  if (!isImageMime(mimeType)) return null;
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
