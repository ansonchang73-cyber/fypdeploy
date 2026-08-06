// lib/features/profile/presentation/screens/patient_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/appointment.dart';
import '../providers/appointments_providers.dart';
import '../providers/patient_profile_controller.dart';
import '../providers/report_export_controller.dart';
import '../providers/linked_caregivers_provider.dart';
import '../../domain/usecases/merge_live_overdue_doses.dart';
import '../../../../core/widgets/glass_panel.dart';
import 'settings_screen.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  ConsumerState<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  late TextEditingController _allergiesController;
  late TextEditingController _caregiverNameController;
  late TextEditingController _caregiverPhoneController;

  bool _isInitialized = false;
  bool _isDirty = false;
  dynamic _originalState;

  final Map<String, bool> _selectedReports = {};
  final Map<String, DateTime> _reportTargetMonths = {};

  @override
  void initState() {
    super.initState();
    _allergiesController = TextEditingController();
    _caregiverNameController = TextEditingController();
    _caregiverPhoneController = TextEditingController();

    _allergiesController.addListener(_evaluateDirtyState);

    _generateDynamicReportMonths();
  }

  @override
  void dispose() {
    _allergiesController.dispose();
    _caregiverNameController.dispose();
    _caregiverPhoneController.dispose();
    super.dispose();
  }

  void _generateDynamicReportMonths() {
    final now = DateTime.now();
    DateTime currentMonthToGenerate = DateTime(now.year, now.month, 1);
    final DateTime startMonth = DateTime(2026, 7, 1);

    while (!currentMonthToGenerate.isBefore(startMonth)) {
      final String label = adherenceReportLabelForMonth(currentMonthToGenerate);
      _selectedReports[label] = false;
      _reportTargetMonths[label] = currentMonthToGenerate;

      currentMonthToGenerate = DateTime(currentMonthToGenerate.year, currentMonthToGenerate.month - 1, 1);
    }
  }

  void _populateInitialData(dynamic patient) {
    if (!_isInitialized) {
      _originalState = patient;
      _allergiesController.text = patient.allergies;
      _caregiverNameController.text = patient.primaryDoctor;
      _caregiverPhoneController.text = patient.doctorContact;
      _isInitialized = true;
    }
  }

  void _evaluateDirtyState() {
    if (!_isInitialized || _originalState == null) return;

    final hasChanges = _allergiesController.text != _originalState.allergies;

    if (hasChanges != _isDirty) {
      setState(() => _isDirty = hasChanges);
    }
  }

  /// UI no longer touches Firestore directly — it hands the update payload
  /// to the controller, which delegates to the `UpdatePatientProfile` use
  /// case.
  Future<void> _persistCareProfile(String userId) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      await ref.read(patientProfileProvider.notifier).updateProfile({
        'allergies': _allergiesController.text.trim(),
      });
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Care parameters successfully updated!'), backgroundColor: Colors.green));
      setState(() { _isInitialized = false; _isDirty = false; });
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save parameters: $e'), backgroundColor: Colors.red));
    }
  }

  void _downloadSelectedReports(String patientId) async {
    final chosen = _selectedReports.entries.where((e) => e.value).map((e) => e.key).toList();

    if (chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one report to export.'), backgroundColor: Colors.orange));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text('Querying database & generating exports...', style: GoogleFonts.inter(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: Colors.grey.shade800,
        duration: const Duration(seconds: 4),
      ),
    );

    try {
      final reportExport = ref.read(reportExportControllerProvider);
      final patientName = _originalState?.fullName ?? "Unknown Patient";

      List<String> paths = await reportExport.exportAdherenceReports(
        patientId: patientId,
        patientName: patientName,
        chosenReports: chosen,
        reportTargetMonths: _reportTargetMonths,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      for (String path in paths) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Saved to: $path', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() {
      for (var key in _selectedReports.keys) {
        _selectedReports[key] = false;
      }
    });
  }

  Future<void> _initiateEmergencyCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  /// Was `_getWeekRangeFileName`, then `Appointment_Record_{Month}_{Year}`
  /// — both were a naming scheme of their own, disconnected from the
  /// "Medication Adherence Logs" report this same PDF embeds. Now it's
  /// named identically to that report (e.g. "July 2026 Adherence Report
  /// (Up to Jul 29)", sanitized), via the exact same shared label
  /// function `exportAppointmentRecord` uses internally — so the two can
  /// never drift into looking like different reports for the same month.
  String _appointmentRecordFileName(DateTime appointmentDate) {
    final monthStart = DateTime(appointmentDate.year, appointmentDate.month, 1);
    final label = adherenceReportLabelForMonth(monthStart);
    return '${label.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(patientProfileProvider);
    final totalSelected = _selectedReports.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Patient Profile', style: GoogleFonts.inter(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(LucideIcons.settings, color: Colors.black87), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()))),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Failed to load profile: $err')),
        data: (patient) {
          _populateInitialData(patient);

          // Get the linked caregiver from the shared_access system.
          final linkedCaregiversAsync = ref.watch(linkedCaregiversProvider);
          final linkedCaregiver = linkedCaregiversAsync.whenOrNull(
            data: (list) => list.isNotEmpty ? list.first : null,
          );

          // Determine emergency contact: prioritize linked caregiver,
          // then fall back to manually-entered emergency contact fields.
          // Use .isNotEmpty checks (not just null) since empty strings
          // are common defaults.
          final String emergencyName = 
              (linkedCaregiver != null && linkedCaregiver.fullName.isNotEmpty)
                  ? linkedCaregiver.fullName
                  : (patient.emergencyContactName.isNotEmpty 
                      ? patient.emergencyContactName : '');
          final String emergencyPhone = 
              (linkedCaregiver != null && linkedCaregiver.phone.isNotEmpty)
                  ? linkedCaregiver.phone
                  : (patient.emergencyContactPhone.isNotEmpty 
                      ? patient.emergencyContactPhone : '');
          // A linked caregiver counts as "has emergency contact" even
          // without a phone number — we still show their name.
          final bool hasLinkedCaregiver = linkedCaregiver != null && linkedCaregiver.fullName.isNotEmpty;
          final bool hasEmergencyContact = hasLinkedCaregiver || 
              (emergencyName.isNotEmpty && emergencyPhone.isNotEmpty);

          // Pre-populate the caregiver form fields from the linked
          // caregiver. The linked caregiver is the authoritative source,
          // so always overwrite unless the user has manually typed
          // something different.
          if (linkedCaregiver != null && _isInitialized) {
            if (linkedCaregiver.fullName.isNotEmpty) {
              _caregiverNameController.text = linkedCaregiver.fullName;
            }
            if (linkedCaregiver.phone.isNotEmpty) {
              _caregiverPhoneController.text = linkedCaregiver.phone;
            }
          }

          final pastAppointmentsAsync = ref.watch(pastAppointmentsProvider(patient.id));

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(radius: 45, backgroundImage: NetworkImage(patient.avatarUrl)),
                const SizedBox(height: 16),
                Text(patient.fullName, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A))),
                const SizedBox(height: 4),
                Text('Patient ID: #${patient.id}', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${patient.gender}, ${patient.age} yrs old', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Text('Blood Type: ${patient.bloodType}', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Emergency Router Card ──
                Container(
                  decoration: BoxDecoration(
                    color: hasEmergencyContact ? const Color(0xFFEF4444) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: hasEmergencyContact 
                            ? const Color(0xFFEF4444).withValues(alpha: 0.3) 
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Shows the linked caregiver's actual profile photo
                      // (set from their own Caregiver Settings screen) when
                      // one is linked, falling back to the phone/alert icon
                      // otherwise — so it's immediately recognizable whose
                      // emergency line this card routes to.
                      (hasLinkedCaregiver && linkedCaregiver!.avatarUrl.isNotEmpty)
                          ? Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: hasEmergencyContact
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 21,
                                backgroundImage: NetworkImage(linkedCaregiver!.avatarUrl),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: hasEmergencyContact 
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hasEmergencyContact ? LucideIcons.phoneCall : LucideIcons.alertTriangle,
                                color: hasEmergencyContact ? Colors.white : const Color(0xFFF59E0B),
                                size: 22,
                              ),
                            ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMERGENCY ROUTER',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: hasEmergencyContact ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade500,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasEmergencyContact ? emergencyName : 'No Caregiver Linked',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: hasEmergencyContact ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (hasEmergencyContact && emergencyPhone.isNotEmpty)
                              Text(
                                emergencyPhone,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (hasEmergencyContact && emergencyPhone.isNotEmpty)
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: const Icon(LucideIcons.phone, color: Color(0xFFEF4444), size: 18),
                          onPressed: () => _initiateEmergencyCall(emergencyPhone),
                        )
                      else if (!hasEmergencyContact)
                        Tooltip(
                          message: 'Caution: Please link a caregiver profile in Settings to enable emergency voice routing.',
                          triggerMode: TooltipTriggerMode.tap, preferBelow: false,
                          child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(LucideIcons.helpCircle, color: Color(0xFFF59E0B), size: 18)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                Row(
                  children: [
                    const Icon(LucideIcons.history, color: Color(0xFF8E24AA), size: 20),
                    const SizedBox(width: 8),
                    Text('Past Scheduled Appointments', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 12),

                pastAppointmentsAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                  error: (err, stack) => Text('Failed to load appointments: $err'),
                  data: (pastAppointments) {
                    if (pastAppointments.isEmpty) return _buildEmptyAppointmentsCard();

                    final visibleAppointments = pastAppointments.length > 3
                        ? pastAppointments.sublist(0, 3)
                        : pastAppointments;

                    return ListView.separated(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.zero, itemCount: visibleAppointments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final Appointment appointment = visibleAppointments[index];
                        final String fileName = _appointmentRecordFileName(appointment.dateTime);

                        return GlassPanel(
                          padding: const EdgeInsets.all(16),
                          borderRadius: 16,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: Icon(LucideIcons.checkCircle, color: Colors.grey.shade500, size: 22)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(appointment.title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade600)),
                                    const SizedBox(height: 4),
                                    Text('Dr. ${appointment.doctorName} • ${appointment.location}', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(LucideIcons.clock, size: 14, color: Colors.grey.shade500),
                                              const SizedBox(width: 6),
                                              Text(DateFormat('EEE, MMM d, yyyy • h:mm a').format(appointment.dateTime), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    InkWell(
                                      onTap: () async {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), const SizedBox(width: 12), Expanded(child: Text('Generating $fileName...', style: GoogleFonts.inter(fontWeight: FontWeight.w500)))]), backgroundColor: Colors.grey.shade800));

                                        try {
                                          final path = await ref.read(reportExportControllerProvider).exportAppointmentRecord(appointment, fileName, patientId: patient.id, patientName: patient.fullName);
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Saved to: $path', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)), backgroundColor: const Color(0xFF10B981), duration: const Duration(seconds: 6)));
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(LucideIcons.fileText, size: 16, color: Colors.grey.shade600), const SizedBox(width: 8), Flexible(child: Text(fileName, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Icon(LucideIcons.downloadCloud, size: 16, color: Colors.grey.shade600)]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 28),

                Card(
                  elevation: 0, margin: EdgeInsets.zero, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)), child: const Icon(LucideIcons.heartPulse, color: Color(0xFF0256B4), size: 22)),
                      title: Text('Medical & Care Circle Setup', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                      subtitle: Text('Manage allergies, emergency details, and export medication logs dynamically.', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 11, height: 1.3)),
                      trailing: const Icon(LucideIcons.chevronDown, color: Colors.black45, size: 18), childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      children: [
                        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)), const SizedBox(height: 16),
                        _buildDropdownFieldHeader(LucideIcons.alertTriangle, 'Emergency Medical Indicators', Colors.red.shade700), const SizedBox(height: 8),
                        _buildInlineFormInputField(label: 'Known Active Allergies', controller: _allergiesController, hint: 'e.g., Penicillin, Nuts, None'), const SizedBox(height: 20),
                        _buildDropdownFieldHeader(LucideIcons.users, 'Family & Primary Caregivers', Colors.purple), const SizedBox(height: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 4), TextFormField(controller: _caregiverNameController, readOnly: true, style: const TextStyle(fontSize: 13, color: Colors.black87), decoration: InputDecoration(hintText: 'Enter emergency contact name', labelText: 'Caregiver Name (Emergency Contact)', labelStyle: const TextStyle(fontSize: 12, color: Colors.black54), hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12), suffixIcon: const Icon(LucideIcons.lock, size: 16, color: Colors.grey), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), filled: true, fillColor: const Color(0xFFF1F5F9), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF3B82F6))))) ]), const SizedBox(height: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 4), TextFormField(controller: _caregiverPhoneController, readOnly: true, keyboardType: TextInputType.phone, style: const TextStyle(fontSize: 13, color: Colors.black87), decoration: InputDecoration(hintText: 'Enter mobile voice line', labelText: 'Caregiver Phone Number', labelStyle: const TextStyle(fontSize: 12, color: Colors.black54), hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12), suffixIcon: const Icon(LucideIcons.lock, size: 16, color: Colors.grey), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), filled: true, fillColor: const Color(0xFFF1F5F9), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF3B82F6))))) ]),
                        if (_isDirty) ...[
                          const SizedBox(height: 16),
                          SizedBox(width: double.infinity, height: 44, child: ElevatedButton.icon(onPressed: () => _persistCareProfile(patient.id), icon: const Icon(LucideIcons.save, size: 16, color: Colors.white), label: const Text('Save Form Updates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0))),
                        ],
                        const SizedBox(height: 24),
                        _buildDropdownFieldHeader(LucideIcons.fileText, 'Medication Adherence Logs', Colors.blue.shade700), const SizedBox(height: 10),
                        ..._selectedReports.keys.map((reportName) {
                          return CheckboxListTile(
                            title: Text(reportName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)), subtitle: const Text('Detailed compliance metrics history export sheet.', style: TextStyle(fontSize: 11)),
                            value: _selectedReports[reportName], activeColor: const Color(0xFF0256B4), contentPadding: EdgeInsets.zero, dense: true,
                            onChanged: (bool? value) { setState(() { _selectedReports[reportName] = value ?? false; }); },
                          );
                        }),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () => _downloadSelectedReports(patient.id),
                            icon: const Icon(LucideIcons.download, size: 14),
                            label: Text(totalSelected > 0 ? 'Export Selected PDF ($totalSelected)' : 'Select Logs to Export', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF0256B4), side: BorderSide(color: Colors.blue.shade200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyAppointmentsCard() {
    return GlassPanel(
      padding: const EdgeInsets.all(20), borderRadius: 16,
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle), child: Icon(LucideIcons.history, color: Colors.grey.shade500, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Past Appointments', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)), const SizedBox(height: 2),
                Text('Your clinical visit history will appear here.', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFieldHeader(IconData icon, String title, Color accentColor) {
    return Row(children: [Icon(icon, size: 16, color: accentColor), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700))]);
  }

  Widget _buildInlineFormInputField({required String label, required TextEditingController controller, required String hint, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        TextFormField(
          controller: controller, keyboardType: keyboardType, style: const TextStyle(fontSize: 13, color: Colors.black87),
          decoration: InputDecoration(hintText: hint, labelText: label, labelStyle: const TextStyle(fontSize: 12, color: Colors.black54), hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), filled: true, fillColor: const Color(0xFFF8F9FE), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF3B82F6)))),
        ),
      ],
    );
  }
}