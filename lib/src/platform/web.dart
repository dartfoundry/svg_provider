Future<String> readFileAsString(String path) async {
  throw UnsupportedError(
    'File operations are not supported on the web platform',
  );
}

bool fileSourceAvailable() => false;
