// lib/features/profile/presentation/providers/appointments_providers.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/appointment.dart';
import 'profile_providers.dart';

/// Upcoming appointments for the signed-in user (used by `UpcomingCareList`).
final upcomingAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(const <Appointment>[]);
  return ref.watch(watchAppointmentsProvider).call(user.uid, isUpcoming: true);
});

/// Past appointments for a given patient ID (used by `PatientProfileScreen`,
/// which already has the patient's ID from the loaded profile).
final pastAppointmentsProvider =
    StreamProvider.family<List<Appointment>, String>((ref, patientId) {
      return ref
          .watch(watchAppointmentsProvider)
          .call(patientId, isUpcoming: false);
    });