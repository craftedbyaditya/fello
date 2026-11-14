import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void downloadBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  final dataUrl =
      'data:$mimeType;base64,${base64Encode(bytes)}';
  final anchor = web.HTMLAnchorElement()
    ..href = dataUrl
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
}
