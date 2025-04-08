import 'dart:io';

Future<String> readFileAsString(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw Exception('SVG file not found: $path');
  }
  return await file.readAsString();
}

bool fileSourceAvailable() => true;
