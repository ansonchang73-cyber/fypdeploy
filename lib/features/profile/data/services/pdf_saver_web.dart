// lib/features/profile/data/services/pdf_saver_web.dart
// Web-specific implementation — no dart:io, no path_provider.

import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'pdf_report_renderer.dart' show PdfSaveResult;

Future<PdfSaveResult> savePdfToDownloads(pw.Document pdf, String fileName) async {
  final bytes = await pdf.save();
  await Printing.sharePdf(bytes: bytes, filename: fileName);
  return PdfSaveResult(path: "Browser Downloads folder", bytes: bytes);
}
