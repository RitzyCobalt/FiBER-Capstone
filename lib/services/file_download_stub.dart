import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveOriginalFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  if (Platform.isAndroid) {
    final extension = safeName.contains('.')
        ? safeName.split('.').last.toLowerCase()
        : '';
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save original file',
      fileName: safeName,
      type: extension.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: extension.isEmpty ? null : <String>[extension],
      bytes: bytes,
    );
  }

  Directory targetDir = Directory.systemTemp;

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    if (home.isNotEmpty) {
      final downloads = Directory('$home${Platform.pathSeparator}Downloads');
      if (await downloads.exists()) {
        targetDir = downloads;
      }
    }
  }

  final filePath = '${targetDir.path}${Platform.pathSeparator}$safeName';
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
