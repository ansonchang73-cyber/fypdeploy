// lib/features/profile/presentation/widgets/upcoming_care_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/appointment.dart';
import '../providers/appointments_providers.dart';

/// NOTE: like `EmergencyContactCard`, this widget isn't placed in any
/// screen yet — `PatientProfileScreen` has its own inline appointments
/// list. Kept and cleaned up as-is.
///
/// Previously built its own `FirebaseAuth` + Firestore
/// `StreamBuilder<QuerySnapshot>` query. Now watches
/// [upcomingAppointmentsProvider], the same appointments stream the rest
/// of the feature uses, so there's one query implementation instead of
/// several slightly different copies of it.
class UpcomingCareList extends ConsumerStatefulWidget {
  const UpcomingCareList({super.key});

  @override
  ConsumerState<UpcomingCareList> createState() => _UpcomingCareListState();
}

class _UpcomingCareListState extends ConsumerState<UpcomingCareList> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(upcomingAppointmentsProvider);

    return appointmentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'Failed to load appointments: $err',
            style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
          ),
        ),
      ),
      data: (appointments) {
        final totalItems = appointments.length;
        final List<Appointment> visibleItems =
            _isExpanded ? appointments : appointments.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Doctor Appointments',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E24AA).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalItems Scheduled',
                    style: GoogleFonts.inter(color: const Color(0xFF8E24AA), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (appointments.isEmpty)
              GlassPanel(
                padding: const EdgeInsets.all(20),
                borderRadius: 16,
                child: Center(
                  child: Text(
                    'No upcoming medical appointments scheduled.',
                    style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
              )
            else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final appointment = visibleItems[index];
                  return GlassPanel(
                    padding: const EdgeInsets.all(14),
                    borderRadius: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E24AA).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.calendarCheck, color: Color(0xFF8E24AA), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointment.title,
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${appointment.doctorName} - ${appointment.location}',
                                style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('MMM dd').format(appointment.dateTime),
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF8E24AA)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('hh:mm AM').format(appointment.dateTime),
                              style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              if (totalItems > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InkWell(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withOpacity(0.04)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isExpanded ? "Show Less" : "Show More (+${totalItems - 3} items)",
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8E24AA), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                            size: 16,
                            color: const Color(0xFF8E24AA),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}