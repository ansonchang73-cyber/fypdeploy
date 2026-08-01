// lib/features/caregiver_dashboard/presentation/widgets/patient_reports_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/adherence_report_summary.dart';
import '../../domain/entities/linked_patient_summary.dart';
import '../providers/caregiver_dashboard_providers.dart';

/// The popup that appears "on the same page" (a dialog, not a
/// navigation push) when a patient card is tapped in the Storage tab —
/// lists that patient's adherence reports earliest to latest, per the
/// spec.
void showPatientReportsDialog(BuildContext context, LinkedPatientSummary patient) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 20, backgroundImage: NetworkImage(patient.avatarUrl)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patient.fullName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Adherence Reports', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Flexible(child: _ReportsList(patientId: patient.id)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ReportsList extends ConsumerWidget {
  const _ReportsList({required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(getAdherenceReportsForPatientProvider).call(patientId),
      builder: (context, AsyncSnapshot<List<AdherenceReportSummary>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Failed to load reports: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13)),
          );
        }

        final reports = snapshot.data ?? const [];

        if (reports.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(LucideIcons.fileX, size: 32, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No reports have been generated for this patient yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          itemCount: reports.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final report = reports[index];
            return InkWell(
              onTap: () async {
                final uri = Uri.tryParse(report.downloadUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF0058BC).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(LucideIcons.fileText, color: Color(0xFF0058BC), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report.reportLabel, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(DateFormat('MMM d, yyyy').format(report.generatedAt), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Icon(LucideIcons.downloadCloud, size: 18, color: Colors.grey.shade500),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
