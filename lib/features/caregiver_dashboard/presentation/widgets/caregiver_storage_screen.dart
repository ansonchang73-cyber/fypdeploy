// lib/features/caregiver_dashboard/presentation/screens/caregiver_storage_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/adherence_report_summary.dart';
import '../providers/caregiver_dashboard_providers.dart';
import '../providers/linked_patients_provider.dart';
import '../widgets/link_patient_dialog.dart';
import '../widgets/link_patient_empty_state.dart';

// Reused straight from the patient side rather than re-implemented: this is
// the exact same use case chain that powers "Medication Adherence Logs" on
// PatientProfileScreen (fetch logs -> compute adherence % -> render PDF ->
// publish to Storage), so the numbers a caregiver sees here always match
// what the patient sees on their own profile.
import '../../../profile/domain/entities/adherence_report.dart';
import '../../../profile/presentation/providers/report_export_controller.dart';
import '../../../profile/presentation/providers/profile_providers.dart'
    as profile_providers;

const String _kLast30DaysLabel = 'Last 30 Days Adherence Report';

/// Live "last 30 days" adherence data for one patient — real Riverpod
/// providers rather than a `Future` cached in `State`, specifically so
/// pull-to-refresh can force a genuinely fresh Firestore read. The
/// caregiver shell keeps every tab alive in an `IndexedStack`, so a
/// one-time fetch in `initState` would otherwise freeze on whatever was
/// true the moment this tab was first opened — which is exactly what
/// made this look like unchanging "mock" data as new doses came in.
final _last30DaysSummaryProvider = FutureProvider.family<AdherenceReportData,
    ({String patientId, String patientName})>((ref, params) async {
  final now = DateTime.now();
  final from = now.subtract(const Duration(days: 30));

  final logs =
      await ref.read(profile_providers.adherenceRepositoryProvider).fetchLogs(
            patientId: params.patientId,
            from: from,
            to: now,
          );

  return ref.read(profile_providers.buildAdherenceReportProvider).call(
        logs: logs,
        reportLabel: _kLast30DaysLabel,
        patientName: params.patientName,
      );
});

/// Previously generated report PDFs for a patient (the same reports that
/// show under Medical & Care Circle Setup -> Medication Adherence Logs on
/// the patient's own profile page).
final _patientReportsProvider =
    FutureProvider.family<List<AdherenceReportSummary>, String>(
  (ref, patientId) =>
      ref.read(getAdherenceReportsForPatientProvider).call(patientId),
);

class CaregiverStorageScreen extends ConsumerWidget {
  const CaregiverStorageScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(linkedPatientsProvider);
    // Invalidating the family itself (no specific argument) clears every
    // patient's cached instance at once.
    ref.invalidate(_last30DaysSummaryProvider);
    ref.invalidate(_patientReportsProvider);
    // Hold the pull-to-refresh spinner until the patient list is back,
    // so it doesn't snap shut before the new data has actually arrived.
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
        title: Text('Storage',
            style: GoogleFonts.inter(
                color: const Color(0xFF1E3A8A),
                fontSize: 18,
                fontWeight: FontWeight.bold)),
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
        loading: () => const Center(
            child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator())),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text('Failed to load patients: $err',
                style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ),
        ),
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

/// Shows a patient header, a live "last 30 days" adherence summary
/// (matching everything the patient's own downloadable PDF report
/// contains — overall stats, time-of-day breakdown, and the individual
/// dose log) with a one-tap PDF download, and the list of previously
/// generated report PDFs.
class _PatientReportsSection extends ConsumerStatefulWidget {
  const _PatientReportsSection({
    required this.patientId,
    required this.patientName,
    required this.avatarUrl,
  });

  final String patientId;
  final String patientName;
  final String avatarUrl;

  @override
  ConsumerState<_PatientReportsSection> createState() =>
      _PatientReportsSectionState();
}

class _PatientReportsSectionState
    extends ConsumerState<_PatientReportsSection> {
  bool _isGenerating = false;

  ({String patientId, String patientName}) get _summaryKey =>
      (patientId: widget.patientId, patientName: widget.patientName);

  Future<void> _generateAndDownload() async {
    setState(() => _isGenerating = true);
    try {
      final now = DateTime.now();
      await ref.read(reportExportControllerProvider).exportAdherenceReports(
        patientId: widget.patientId,
        patientName: widget.patientName,
        chosenReports: const [_kLast30DaysLabel],
        reportTargetMonths: {
          _kLast30DaysLabel: now.subtract(const Duration(days: 30)),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report downloaded and saved to your device.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      // Refresh just this patient's data so the new report shows up in
      // the history list below without needing a full pull-to-refresh.
      ref.invalidate(_last30DaysSummaryProvider(_summaryKey));
      ref.invalidate(_patientReportsProvider(widget.patientId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate report: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        // Patient header
        Row(
          children: [
            CircleAvatar(
                radius: 18, backgroundImage: NetworkImage(widget.avatarUrl)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.patientName,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A8A)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Live adherence summary — same numbers, same time-of-day
        // breakdown, same dose-by-dose log that's in the PDF, just
        // visible without downloading anything first.
        _buildLiveSummaryCard(),

        const SizedBox(height: 4),
        Text(
          'REPORT HISTORY',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),

        reportsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: GlassPanel(
              padding: const EdgeInsets.all(16),
              borderRadius: 14,
              child: Row(
                children: [
                  Icon(LucideIcons.alertCircle,
                      size: 18, color: Colors.red.shade400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Unable to load reports.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (reports) {
            if (reports.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: GlassPanel(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 14,
                  child: Row(
                    children: [
                      Icon(LucideIcons.fileX,
                          size: 20, color: Colors.grey.shade400),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No adherence reports generated yet.',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: reports.map((report) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () async {
                        final uri = Uri.tryParse(report.downloadUrl);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: GlassPanel(
                        padding: const EdgeInsets.all(14),
                        borderRadius: 14,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0058BC)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(LucideIcons.fileText,
                                  color: Color(0xFF0058BC), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report.reportLabel,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('MMM d, yyyy')
                                        .format(report.generatedAt),
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.downloadCloud,
                                      size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PDF',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLiveSummaryCard() {
    final summaryAsync = ref.watch(_last30DaysSummaryProvider(_summaryKey));

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
                  decoration: BoxDecoration(
                    color: const Color(0xFF0058BC).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.activity,
                      color: Color(0xFF0058BC), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medication Adherence Logs',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3A8A))),
                      Text('Last 30 days',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.invalidate(_last30DaysSummaryProvider(_summaryKey)),
                  icon: Icon(LucideIcons.refreshCw,
                      size: 16, color: Colors.grey.shade500),
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            summaryAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Unable to load adherence data right now.',
                  style:
                      GoogleFonts.inter(fontSize: 12, color: Colors.red.shade400),
                ),
              ),
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
        // Overall stats — the headline numbers.
        Row(
          children: [
            Expanded(
              child: _statChip(
                '${report.overallAdherencePercent}%',
                'Adherence',
                _adherenceColor(report.overallAdherencePercent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statChip(
                '${report.completedDoses}',
                'Taken',
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statChip(
                '${report.missedDoses}',
                'Missed',
                Colors.red.shade400,
              ),
            ),
          ],
        ),

        if (report.totalDoses > 0) ...[
          const SizedBox(height: 16),
          Text(
            'TIME OF DAY',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          _timeOfDayRow('Morning', report.morningAdherence),
          const SizedBox(height: 6),
          _timeOfDayRow('Afternoon', report.afternoonAdherence),
          const SizedBox(height: 6),
          _timeOfDayRow('Evening', report.eveningAdherence),

          const SizedBox(height: 16),
          Text(
            'RECENT DOSES',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          ..._recentLogEntries(report.logs).map(_doseLogRow),
          if (report.logs.length > 10) ...[
            const SizedBox(height: 6),
            Text(
              'Showing 10 most recent of ${report.logs.length} doses — full log is in the PDF.',
              style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500),
            ),
          ],
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'No doses logged for this patient in the last 30 days yet.',
              style:
                  GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isGenerating ? null : () => _generateAndDownload(),
            icon: _isGenerating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.download, size: 16),
            label: Text(
              _isGenerating ? 'Generating...' : 'Download PDF Report',
              style:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0058BC),
              side: const BorderSide(color: Color(0xFF0058BC)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
    final Color statusColor =
        log.isCompleted ? const Color(0xFF10B981) : Colors.red.shade400;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            log.isCompleted ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
            size: 14,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              log.medicationName,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('MMM d').format(log.timestamp),
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(width: 6),
          Text(
            log.reminderTime,
            style: GoogleFonts.inter(
                fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _timeOfDayRow(String label, double fraction) {
    final percent = (fraction * 100).round();
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(label,
              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  AlwaysStoppedAnimation<Color>(_adherenceColor(percent)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          child: Text('$percent%',
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
