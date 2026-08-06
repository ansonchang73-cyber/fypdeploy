// lib/features/caregiver_dashboard/presentation/screens/caregiver_storage_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/adherence_report_summary.dart';
import '../providers/caregiver_dashboard_providers.dart';
import '../providers/linked_patients_provider.dart';
import '../widgets/link_patient_dialog.dart';
import '../widgets/link_patient_empty_state.dart';

import '../../../profile/domain/entities/adherence_report.dart';
import '../../../profile/presentation/providers/report_export_controller.dart';
import '../../../profile/presentation/providers/profile_providers.dart' as profile_providers;

import '../../../adherence_analytics/domain/entities/adherence_summary.dart';
import '../../../adherence_analytics/presentation/providers/adherence_summary_provider.dart';

import '../../../profile/domain/usecases/merge_live_overdue_doses.dart';
import '../providers/patient_routine_provider.dart';
import '../../domain/entities/routine_dose.dart';

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  switch (day % 10) {
    case 1: return '${day}st';
    case 2: return '${day}nd';
    case 3: return '${day}rd';
    default: return '${day}th';
  }
}

final _monthlyAdherenceProvider = FutureProvider.family<AdherenceReportData, ({String patientId, String patientName})>((ref, params) async {
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1, 1);
  final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);
  
  final buildReport = ref.read(profile_providers.buildAdherenceReportProvider);

  var logs = await ref.read(profile_providers.adherenceRepositoryProvider).fetchLogs(
    patientId: params.patientId, from: lastMonth, to: endOfLastMonth,
  );

  DateTime targetMonth = lastMonth;
  DateTime queryEnd = endOfLastMonth;

  if (logs.isEmpty) {
    targetMonth = DateTime(now.year, now.month, 1);
    queryEnd = buildReport.resolveQueryEnd(now);
    logs = await ref.read(profile_providers.adherenceRepositoryProvider).fetchLogs(
      patientId: params.patientId, from: targetMonth, to: queryEnd,
    );
  }

  final schedule = await fetchDailySchedule(ref, params.patientId);

  final mergedLogs = targetMonth.year == now.year && targetMonth.month == now.month
      ? [...logs, ...liveOverdueEntriesForToday(schedule, logs)]
      : logs;

  final daysInPeriod = daysInReportPeriod(targetMonth);

  return buildReport(
    logs: mergedLogs,
    reportLabel: monthlyReportLabel(targetMonth),
    patientName: params.patientName,
    expectedTotalDoses: expectedTotalDosesFor(schedule, daysInPeriod),
    dosesPerDay: schedule.length,
    periodStart: targetMonth,
    daysInPeriod: daysInPeriod,
    medicationSchedule: sortedMedicationSchedule(schedule),
  );
});

String monthlyReportLabel(DateTime targetMonth) {
  final now = DateTime.now();
  final monthLabel = DateFormat('MMMM yyyy').format(targetMonth);
  if (targetMonth.year == now.year && targetMonth.month == now.month) {
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
    if (now.day < lastDayOfMonth) {
      return '$monthLabel Adherence Report (up to ${_ordinal(now.day)})';
    }
  }
  return '$monthLabel Adherence Report';
}

final _patientReportsProvider = FutureProvider.family<List<AdherenceReportSummary>, String>(
  (ref, patientId) => ref.read(getAdherenceReportsForPatientProvider).call(patientId),
);

class CaregiverStorageScreen extends ConsumerWidget {
  const CaregiverStorageScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(linkedPatientsProvider);
    ref.invalidate(_monthlyAdherenceProvider);
    ref.invalidate(_patientReportsProvider);
    ref.invalidate(adherenceSummaryForPatientProvider);
    await ref.read(linkedPatientsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(linkedPatientsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Storage', style: GoogleFonts.inter(color: const Color(0xFF1E3A8A), fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus, color: Color(0xFF0058BC)),
            tooltip: 'Link a patient',
            onPressed: () => showLinkPatientDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: patientsAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
        error: (err, stack) => Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('Failed to load patients: $err', style: GoogleFonts.inter(color: Colors.grey.shade600)))),
        data: (patients) {
          if (patients.isEmpty) {
            return const LinkPatientEmptyState();
          }

          return RefreshIndicator(
            color: const Color(0xFF0058BC),
            onRefresh: () => _onRefresh(ref),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
              itemCount: patients.length,
              itemBuilder: (context, index) {
                final patient = patients[index];
                return _PatientReportsSection(
                  patientId: patient.id,
                  patientName: patient.fullName,
                  avatarUrl: patient.avatarUrl,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PatientReportsSection extends ConsumerStatefulWidget {
  const _PatientReportsSection({required this.patientId, required this.patientName, required this.avatarUrl});
  final String patientId;
  final String patientName;
  final String avatarUrl;

  @override
  ConsumerState<_PatientReportsSection> createState() => _PatientReportsSectionState();
}

class _PatientReportsSectionState extends ConsumerState<_PatientReportsSection> {
  bool _isGenerating = false;

  ({String patientId, String patientName}) get _monthlyKey => (patientId: widget.patientId, patientName: widget.patientName);

  DateTime _parseTime(String timeStr) {
    try {
      final cleanTime = timeStr.toUpperCase().trim();
      final isPM = cleanTime.contains('PM');
      final isAM = cleanTime.contains('AM');
      final rawTimeStr = cleanTime.replaceAll(RegExp(r'[A-Z\s]'), '');
      final parts = rawTimeStr.split(':');
      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0].trim());
        final int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
    } catch (_) {}
    return DateTime.now();
  }

  Future<void> _generateAndDownload() async {
    setState(() => _isGenerating = true);
    try {
      final reportData = ref.read(_monthlyAdherenceProvider(_monthlyKey)).value;
      if (reportData == null) return;
      final targetMonth = reportData.periodStart;
      final label = reportData.reportLabel;

      await ref.read(reportExportControllerProvider).exportAdherenceReports(
        patientId: widget.patientId, patientName: widget.patientName, chosenReports: [label], reportTargetMonths: {label: targetMonth},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report downloaded and saved to your device.'), backgroundColor: Color(0xFF10B981)));
      ref.invalidate(_monthlyAdherenceProvider(_monthlyKey));
      ref.invalidate(_patientReportsProvider(widget.patientId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate report: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Color _adherenceColor(int percent) {
    if (percent >= 80) return const Color(0xFF10B981);
    if (percent >= 50) return const Color(0xFFF59E0B);
    return Colors.red.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(_patientReportsProvider(widget.patientId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(radius: 18, backgroundImage: NetworkImage(widget.avatarUrl)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.patientName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A))),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildMonthlySummaryCard(),
        _buildDailyAdherenceCard(),

        const SizedBox(height: 4),
        Text('REPORT HISTORY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.6)),
        const SizedBox(height: 10),

        reportsAsync.when(
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: GlassPanel(
              padding: const EdgeInsets.all(16), borderRadius: 14,
              child: Row(
                children: [
                  Icon(LucideIcons.alertCircle, size: 18, color: Colors.red.shade400),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Unable to load reports.', style: GoogleFonts.inter(fontSize: 13, color: Colors.red.shade700))),
                ],
              ),
            ),
          ),
          data: (reports) {
            final now = DateTime.now();
            final startMonth = DateTime(2026, 7, 1);
            final List<DateTime> months = [];
            
            DateTime current = DateTime(now.year, now.month, 1);
            while (!current.isBefore(startMonth)) {
              months.add(current);
              current = DateTime(current.year, current.month - 1, 1);
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(vertical: 8),
                borderRadius: 18,
                child: Column(
                  children: months.map((month) {
                    final label = adherenceReportLabelForMonth(month);
                    final report = reports.cast<AdherenceReportSummary?>().firstWhere(
                          (r) => r?.reportLabel == label,
                          orElse: () => null,
                        );

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                      subtitle: Text(
                        report != null ? 'Generated ${DateFormat('MMM d, yyyy').format(report.generatedAt)}' : 'Detailed compliance metrics history export.',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: report != null
                        ? OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.tryParse(report.downloadUrl);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(LucideIcons.downloadCloud, size: 14),
                            label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            ),
                          )
                        : TextButton(
                            onPressed: () async {
                              setState(() => _isGenerating = true);
                              try {
                                await ref.read(reportExportControllerProvider).exportAdherenceReports(
                                  patientId: widget.patientId, patientName: widget.patientName, chosenReports: [label], reportTargetMonths: {label: month},
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report generated successfully.'), backgroundColor: Color(0xFF10B981)));
                                ref.invalidate(_patientReportsProvider(widget.patientId));
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate report: $e'), backgroundColor: Colors.red));
                              } finally {
                                if (mounted) setState(() => _isGenerating = false);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0256B4),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Generate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDailyAdherenceCard() {
    final dailyAsync = ref.watch(adherenceSummaryForPatientProvider(widget.patientId));
    final routineAsync = ref.watch(patientRoutineProvider(widget.patientId));
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassPanel(
        padding: const EdgeInsets.all(18),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF0058BC).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(LucideIcons.calendarCheck, color: Color(0xFF0058BC), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily Adherence', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A))),
                      Text(DateFormat('EEEE, MMM d').format(DateTime.now()), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            dailyAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (err, stack) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Unable to load today\'s adherence right now.', style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade400))),
              data: (AdherenceSummary summary) {
                if (summary.totalDoses == 0) {
                  return Text('No doses scheduled for today yet.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500));
                }
                final missed = summary.totalDoses - summary.completedDoses;
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _statChip('${summary.overallAdherencePercent}%', 'Adherence', _adherenceColor(summary.overallAdherencePercent))),
                        const SizedBox(width: 10),
                        Expanded(child: _statChip('${summary.completedDoses}', 'Taken', const Color(0xFF10B981))),
                        const SizedBox(width: 10),
                        Expanded(child: _statChip('$missed', 'Missed', Colors.red.shade400)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    routineAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      error: (err, stack) => const SizedBox(),
                      data: (doses) {
                        if (doses.isEmpty) return const SizedBox();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: doses.map((dose) {
                            final doseTime = _parseTime(dose.time);
                            final minsLate = now.difference(doseTime).inMinutes;
                            
                            String statusText = 'Pending';
                            Color statusColor = Colors.grey.shade400;
                            IconData statusIcon = LucideIcons.circle;

                            if (dose.isCompleted) {
                              statusText = 'Taken';
                              statusColor = const Color(0xFF10B981);
                              statusIcon = LucideIcons.checkCircle2;
                            } else if (dose.isMarkedMissed) {
                              statusText = 'Missed';
                              statusColor = Colors.red.shade400;
                              statusIcon = LucideIcons.xCircle;
                            } else if (minsLate > 15) {
                              statusText = 'Delayed';
                              statusColor = Colors.amber.shade600;
                              statusIcon = LucideIcons.clock;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(statusIcon, size: 14, color: statusColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(dose.name, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(statusText, style: GoogleFonts.inter(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 6),
                                  Text(dose.time, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummaryCard() {
    final summaryAsync = ref.watch(_monthlyAdherenceProvider(_monthlyKey));
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GlassPanel(
        padding: const EdgeInsets.all(18),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF0058BC).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(LucideIcons.activity, color: Color(0xFF0058BC), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Last Month's Medication Adherence", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A))),
                      summaryAsync.when(
                        data: (report) => Text(
                          report.periodStart.year == now.year && report.periodStart.month == now.month 
                            ? now.day < DateTime(now.year, now.month + 1, 0).day ? '${DateFormat('MMMM yyyy').format(now)} (up to ${_ordinal(now.day)})' : DateFormat('MMMM yyyy').format(now)
                            : DateFormat('MMMM yyyy').format(report.periodStart),
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
                        ),
                        loading: () => const SizedBox(), error: (_, __) => const SizedBox(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => ref.invalidate(_monthlyAdherenceProvider(_monthlyKey)),
                  icon: Icon(LucideIcons.refreshCw, size: 16, color: Colors.grey.shade500),
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            summaryAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (err, stack) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Unable to load adherence data right now.', style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade400))),
              data: (report) => _buildFullSummary(report),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullSummary(AdherenceReportData report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _statChip('${report.overallAdherencePercent}%', 'Adherence', _adherenceColor(report.overallAdherencePercent))),
            const SizedBox(width: 10),
            Expanded(child: _statChip('${report.completedDoses}', 'Taken', const Color(0xFF10B981))),
            const SizedBox(width: 10),
            Expanded(child: _statChip('${report.missedDoses}', 'Missed', Colors.red.shade400)),
          ],
        ),

        if (report.totalDoses > 0) ...[
          const SizedBox(height: 16),
          Text('TIME OF DAY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          _timeOfDayRow('Morning', report.morningAdherence),
          const SizedBox(height: 6),
          _timeOfDayRow('Afternoon', report.afternoonAdherence),
          const SizedBox(height: 6),
          _timeOfDayRow('Evening', report.eveningAdherence),

          const SizedBox(height: 16),
          Text('RECENT DOSES', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          ..._recentLogEntries(report.logs).map(_doseLogRow),
          if (report.logs.length > 10) ...[
            const SizedBox(height: 6),
            Text('Showing 10 most recent of ${report.logs.length} doses — full log is in the PDF.', style: GoogleFonts.inter(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey.shade500)),
          ],
        ] else
          Padding(padding: const EdgeInsets.only(top: 12), child: Text('No doses logged for this patient this month yet.', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500))),

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isGenerating ? null : () => _generateAndDownload(),
            icon: _isGenerating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.download, size: 16),
            label: Text(_isGenerating ? 'Generating...' : 'Download PDF Report', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0058BC),
              side: const BorderSide(color: Color(0xFF0058BC)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  List<DoseLogEntry> _recentLogEntries(List<DoseLogEntry> logs) {
    final sorted = [...logs]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(10).toList();
  }

  Widget _doseLogRow(DoseLogEntry log) {
    final Color statusColor = log.isCompleted ? const Color(0xFF10B981) : Colors.red.shade400;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(log.isCompleted ? LucideIcons.checkCircle2 : LucideIcons.xCircle, size: 14, color: statusColor),
          const SizedBox(width: 8),
          Expanded(child: Text(log.medicationName, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(DateFormat('MMM d').format(log.timestamp), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(width: 6),
          Text(log.reminderTime, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _timeOfDayRow(String label, double fraction) {
    final percent = (fraction * 100).round();
    return Row(
      children: [
        SizedBox(width: 68, child: Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0), minHeight: 8,
              backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(_adherenceColor(percent)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 34, child: Text('$percent%', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}