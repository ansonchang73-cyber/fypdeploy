// lib/features/profile/data/services/pdf_saver_stub.dart
// Fallback stub — used when neither dart:io nor dart:html is available
// (shouldn't happen in practice, but keeps the analyzer happy).

import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'pdf_report_renderer.dart' show PdfSaveResult;

Future<PdfSaveResult> savePdfToDownloads(pw.Document pdf, String fileName) async {
  final bytes = await pdf.save();
  await Printing.sharePdf(bytes: bytes, filename: fileName);
  return PdfSaveResult(path: "Shared via OS", bytes: bytes);
}
