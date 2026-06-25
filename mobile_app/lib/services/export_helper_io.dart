import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> saveExportFile(String filename, String content) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$filename');
  await file.writeAsString(content);
  return file.path;
}
