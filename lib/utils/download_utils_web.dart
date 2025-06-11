import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:convert' show utf8;

class DownloadUtils {
  static void downloadCsv(String csvContent, String filename) {
    final utf8Bytes = utf8.encode(csvContent);
    final blob =
        html.Blob([Uint8List.fromList(utf8Bytes)], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  static void downloadPdf(Uint8List bytes, String filename) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url);
    anchor.download = filename;
    anchor.click();
    html.Url.revokeObjectUrl(url);
  }
}
