import 'dart:io';
import 'dart:typed_data';

Future< String > saveOriginalFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  Directory targetDir = Directory.systemTemp;

  if (Platform.isAndroid) {
    final downloadDir = Directory('/storage/emulated/0/Download');
    if (await downloadDir.exists()) {
      targetDir = downloadDir;
    }
  } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final home = Platform.environment['USERPROFILE'] ??
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