import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

/// Mobile/Desktop implementation of file download (Android, iOS, Windows, macOS, Linux).
Future<void> downloadFile(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  Directory directory;

  if (Platform.isAndroid || Platform.isIOS) {
    directory = await getApplicationDocumentsDirectory();
  } else if (Platform.isWindows) {
    // Use Downloads folder on Windows
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    directory = Directory('$home\\Downloads');
    if (!await directory.exists()) {
      directory = await getApplicationDocumentsDirectory();
    }
  } else if (Platform.isMacOS || Platform.isLinux) {
    final home = Platform.environment['HOME'] ?? '';
    directory = Directory('$home/Downloads');
    if (!await directory.exists()) {
      directory = await getApplicationDocumentsDirectory();
    }
  } else {
    directory = await getApplicationDocumentsDirectory();
  }

  final filePath = '${directory.path}${Platform.pathSeparator}$fileName';
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  await OpenFile.open(filePath);
}
