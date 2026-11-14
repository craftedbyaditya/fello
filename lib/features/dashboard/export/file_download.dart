import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart' as impl;

void downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  impl.downloadBytes(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
  );
}
