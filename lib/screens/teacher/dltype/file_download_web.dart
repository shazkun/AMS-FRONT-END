// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation of file download — triggers a browser download prompt.
Future<void> downloadFile(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor =
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
  html.Url.revokeObjectUrl(url);
}
