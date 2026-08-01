// lib/features/profile/data/services/pdf_report_renderer.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';

// PDF Imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Conditional import: picks the right save strategy at compile time.
// Web targets get pdf_saver_web.dart (no dart:io), everything else
// gets pdf_saver_native.dart (dart:io + path_provider).
import 'pdf_saver_stub.dart'
    if (dart.library.io) 'pdf_saver_native.dart'
    if (dart.library.html) 'pdf_saver_web.dart';

import '../../domain/entities/adherence_report.dart';
import '../../domain/entities/appointment.dart';

/// Where a PDF ended up locally, plus the raw bytes — the bytes are only
/// needed so a caller can also upload the same PDF elsewhere (Firebase
/// Storage, for the caregiver dashboard's report list) without redrawing
/// it from scratch.
class PdfSaveResult {
  final String path;
  final Uint8List bytes;
  const PdfSaveResult({required this.path, required this.bytes});
}

/// Infrastructure adapter: turns already-computed report data into PDF
/// bytes and saves them to disk (or shares them, on platforms without
/// direct file access). This is the ONLY file in the profile feature that
/// touches PDF drawing or the filesystem — it does no querying and no
/// adherence math of its own; it just renders what it's given.
///
/// Extracted from the old `PdfExportService` (`providers/pdf_export_provider.dart`),
/// which used to also run the Firestore query and the percentage
/// calculations in the same class. The drawing code below is unchanged.
class PdfReportRenderer {

  /// Draws the monthly adherence PDF from an already-built [AdherenceReportData].
  Future<PdfSaveResult> renderAdherenceReport(AdherenceReportData report) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'SynchroM Adherence Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ),
            pw.Text(
              'Report Period: ${report.reportLabel}',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'Patient Name: ${report.patientName}',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(report.generatedAt)}',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.SizedBox(height: 30),

            if (report.totalDoses == 0)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.red50,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  'NO DATA FOUND. Add a medication schedule to start tracking adherence.',
                  style: pw.TextStyle(
                    color: PdfColors.red800,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              )
            else
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Container(
                      height: 200,
                      child: pw.Chart(
                        title: pw.Text(
                          'Adherence (${report.overallAdherencePercent}%)',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        grid: pw.PieGrid(),
                        datasets: [
                          pw.PieDataSet(
                            value: report.completedDoses.toDouble(),
                            color: PdfColors.green600,
                            legend: 'Completed',
                          ),
                          pw.PieDataSet(
                            value: report.missedDoses.toDouble(),
                            color: PdfColors.red600,
                            legend: 'Missed',
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Summary Metrics',
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Divider(),
                          pw.Text(
                            'Total Tracked Doses: ${report.totalDoses}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            'Medications per Day: ${report.dosesPerDay}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            'Successfully Taken: ${report.completedDoses}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            'Time-of-Day Compliance:',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '• Morning (5AM - 12PM): ${(report.morningAdherence * 100).round()}%',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            '• Afternoon (12PM - 6PM): ${(report.afternoonAdherence * 100).round()}%',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            '• Evening (6PM - 5AM): ${(report.eveningAdherence * 100).round()}%',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            pw.SizedBox(height: 30),
            pw.Text(
              'Medications',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            _buildMedicationScheduleSection(report.medicationSchedule),

            pw.SizedBox(height: 30),
            pw.Text(
              'Detailed Log',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            if (report.totalDoses > 0)
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.centerLeft,
                data: [
                  ['Date', 'Doses Taken', 'Adherence Rate'],
                  ..._buildDailyAdherenceRows(report),
                ],
              ),
          ];
        },
      ),
    );

    final safeFilename =
        '${report.reportLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
    return savePdfToDownloads(pdf, safeFilename);
  }

  /// "Your medications, at these times" — shown above the detailed dose
  /// log in a report so it's clear what the log is measuring against,
  /// latest time of day first. Shared between [renderAdherenceReport] and
  /// [renderAppointmentRecord]'s embedded adherence section.
  pw.Widget _buildMedicationScheduleSection(
    List<MedicationScheduleEntry> schedule,
  ) {
    if (schedule.isEmpty) {
      return pw.Text(
        'No active medications on file.',
        style: pw.TextStyle(
          fontSize: 11,
          color: PdfColors.grey600,
          fontStyle: pw.FontStyle.italic,
        ),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: schedule.map((entry) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            children: [
              pw.Container(
                width: 5,
                height: 5,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue800,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Text(
                  entry.medicationName,
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ),
              pw.Text(
                entry.reminderTime,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Turns [report]'s individual dose log entries into one row per
  /// calendar day of the report period — including days with zero
  /// entries, which show as a 0% row rather than being silently absent.
  /// [AdherenceReportData.periodStart]/[AdherenceReportData.daysInPeriod]
  /// (not just what happens to be in `logs`) drive which days get a row,
  /// so a day nothing was ever logged for still shows up.
  List<List<String>> _buildDailyAdherenceRows(AdherenceReportData report) {
    final Map<String, int> takenByDate = {};
    for (final log in report.logs) {
      if (!log.isCompleted) continue;
      final key = DateFormat('yyyy-MM-dd').format(log.timestamp);
      takenByDate[key] = (takenByDate[key] ?? 0) + 1;
    }

    final rows = <List<String>>[];
    for (int i = 0; i < report.daysInPeriod; i++) {
      final day = report.periodStart.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(day);
      final taken = takenByDate[key] ?? 0;
      rows.add([
        DateFormat('MMM d, yyyy').format(day),
        '$taken / ${report.dosesPerDay}',
        _formatDailyRate(taken, report.dosesPerDay),
      ]);
    }
    return rows;
  }

  /// Truncated (not rounded) to 2 decimal places — same convention
  /// `BuildAdherenceReport` uses for the overall percentage, so e.g.
  /// 2 taken out of 23 reads as "8.69%", not "8.70%". Whole-number rates
  /// (0%, 100%) show without decimals.
  String _formatDailyRate(int taken, int dosesPerDay) {
    if (dosesPerDay <= 0) return '—';
    final int centiPercent = (taken * 10000) ~/ dosesPerDay;
    if (centiPercent % 100 == 0) {
      return '${centiPercent ~/ 100}%';
    }
    return '${(centiPercent / 100).toStringAsFixed(2)}%';
  }

  /// Draws and exports a quick individual appointment record, plus — when
  /// available — the medication adherence summary for the calendar month
  /// the appointment fell in. Unlike [renderAdherenceReport], this one
  /// still returns just the path — it's not published to Storage, so the
  /// caller has no use for the bytes.
  Future<String> renderAppointmentRecord(
    Appointment appointment, {
    required String fileName,
    AdherenceReportData? monthlyAdherence,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Text(
              'SynchroM Appointment Record',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Title: ${appointment.title}'),
            pw.Text('Doctor: ${appointment.doctorName}'),
            pw.Text('Location: ${appointment.location}'),
            pw.Text(
              'Date & Time: ${DateFormat('EEE, MMM d, yyyy • h:mm a').format(appointment.dateTime)}',
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'System Notes: This record was extracted dynamically from your historical medical timeline.',
            ),

            if (monthlyAdherence != null) ...[
              pw.SizedBox(height: 30),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 20),
              pw.Header(
                level: 1,
                child: pw.Text(
                  'Medication Adherence — ${monthlyAdherence.reportLabel}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
              ),
              if (monthlyAdherence.totalDoses == 0)
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.red50,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Text(
                    'No adherence data recorded for this period.',
                    style: pw.TextStyle(
                      color: PdfColors.red800,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                )
              else ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Overall Adherence: ${monthlyAdherence.overallAdherencePercent}%',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Total Tracked Doses: ${monthlyAdherence.totalDoses}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        'Medications per Day: ${monthlyAdherence.dosesPerDay}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        'Successfully Taken: ${monthlyAdherence.completedDoses}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        'Missed: ${monthlyAdherence.missedDoses}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Time-of-Day Compliance:',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '• Morning (5AM - 12PM): ${(monthlyAdherence.morningAdherence * 100).round()}%',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        '• Afternoon (12PM - 6PM): ${(monthlyAdherence.afternoonAdherence * 100).round()}%',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        '• Evening (6PM - 5AM): ${(monthlyAdherence.eveningAdherence * 100).round()}%',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Medications',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                _buildMedicationScheduleSection(monthlyAdherence.medicationSchedule),

                pw.SizedBox(height: 20),
                pw.Text(
                  'Detailed Log',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: [
                    ['Date', 'Doses Taken', 'Adherence Rate'],
                    ..._buildDailyAdherenceRows(monthlyAdherence),
                  ],
                ),
              ],
            ],
          ];
        },
      ),
    );

    final result = await savePdfToDownloads(pdf, fileName);
    return result.path;
  }
}
