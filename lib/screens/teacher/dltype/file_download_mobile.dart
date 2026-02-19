import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

/// Mobile implementation of file download (Android/iOS)
Future<void> downloadFile(Uint8List bytes, String fileName, String mimeType) async {
  // Get the downloads directory
  final directory = await getApplicationDocumentsDirectory();
  final filePath = '${directory.path}/$fileName';
  
  // Write the file
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  
  // Open the file
  await OpenFile.open(filePath);
}
