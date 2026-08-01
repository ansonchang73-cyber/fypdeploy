// lib/features/profile/data/services/pdf_saver_native.dart
// Native (Android / iOS / Desktop) implementation — uses dart:io + path_provider.

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'pdf_report_renderer.dart' show PdfSaveResult;

Future<PdfSaveResult> savePdfToDownloads(pw.Document pdf, String fileName) async {
  final bytes = await pdf.save();

  try {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) dir = await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getDownloadsDirectory();
    }

    if (dir != null) {
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return PdfSaveResult(path: file.path, bytes: bytes);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return PdfSaveResult(path: "Shared via OS", bytes: bytes);
    }
  } catch (e) {
    await Printing.sharePdf(bytes: bytes, filename: fileName);
    return PdfSaveResult(path: "Shared via OS Fallback", bytes: bytes);
  }
}
