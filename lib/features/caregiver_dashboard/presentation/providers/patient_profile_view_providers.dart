// lib/features/caregiver_dashboard/presentation/providers/patient_profile_view_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/domain/entities/appointment.dart';
import '../../../profile/domain/entities/patient_profile.dart';
import '../../../profile/presentation/providers/appointments_providers.dart' show pastAppointmentsProvider;
import '../../../profile/presentation/providers/profile_providers.dart'
    show watchAppointmentsProvider, watchPatientProfileProvider;

/// Reuses `profile`'s [PatientProfile] entity and its already-parameterized
/// `WatchPatientProfile`/`WatchAppointments` use cases directly, rather
/// than re-deriving a parallel "caregiver's view of a patient" shape.
/// Unlike `Appointment` in `system_health` or `MedicationTask` in
/// `adherence_analytics` — where each feature genuinely needed a
/// different slice of the data — this screen wants the *exact* same full
/// profile `PatientProfileScreen` shows, just read-only. Re-deriving that
/// would be pure duplication for no benefit, so this composes with
/// `profile`'s domain layer directly, the same way this feature already
/// does for `SharedAccessRepository`.
final patientProfileForCaregiverProvider =
    StreamProvider.family.autoDispose<PatientProfile, String>((ref, patientId) {
      return ref.watch(watchPatientProfileProvider).call(patientId);
    });

/// `profile` already exposes `pastAppointmentsProvider(patientId)` in
/// exactly this shape — reused directly below. Upcoming appointments
/// aren't parameterized on that side (`upcomingAppointmentsProvider`
/// there is locked to the signed-in user), so that half is added here.
final patientUpcomingAppointmentsForCaregiverProvider =
    StreamProvider.family.autoDispose<List<Appointment>, String>((ref, patientId) {
      return ref.watch(watchAppointmentsProvider).call(patientId, isUpcoming: true);
    });

/// Re-exported under this feature's naming for symmetry with the
/// provider above — same provider, same behavior as `profile`'s.
final patientPastAppointmentsForCaregiverProvider = pastAppointmentsProvider;
