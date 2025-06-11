import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';

class DownloadUtils {
  static Future<void> downloadCsv(String csvContent, String filename) async {
    final directory = await _getDownloadDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsString(csvContent);
    // Present "Open with" dialog so user can pick viewer app.
    await OpenFilex.open(file.path);
  }

  static Future<void> downloadPdf(Uint8List bytes, String filename) async {
    final directory = await _getDownloadDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }

  /// Optional helper: allows the UI to trigger a share sheet manually if the
  /// user wants to share the already-saved files.
  static Future<void> shareFiles(List<File> files, {String? text}) async {
    await Share.shareXFiles(files.map((f) => XFile(f.path)).toList(),
        text: text);
  }

  /// Picks an appropriate directory for exported documents. Tries the
  /// platform downloads folder first and falls back to the app documents
  /// directory.
  static Future<Directory> _getDownloadDirectory() async {
    Directory? directory;

    // Use platform-specific folders when possible
    try {
      if (Platform.isAndroid) {
        // On Android, this requires MANAGE_EXTERNAL_STORAGE or scoped storage;
        // using the app-specific directory so we don't need extra permissions.
        directory = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      directory = await getApplicationDocumentsDirectory();
    }

    // Ensure the directory exists
    if (directory != null && !await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory!;
  }
}
