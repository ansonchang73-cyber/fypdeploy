// lib/features/system_health/presentation/providers/system_health_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/appointment_repository_impl.dart';
import '../../data/repositories/medication_status_repository_impl.dart';
import '../../data/repositories/system_health_repository_impl.dart';

import '../../domain/entities/system_health_state.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../../domain/repositories/medication_status_repository.dart';
import '../../domain/repositories/system_health_repository.dart';
import '../../domain/usecases/resolve_caregiver_link.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final systemHealthRepositoryProvider = Provider<SystemHealthRepository>((ref) {
  return SystemHealthRepositoryImpl(ref.watch(firestoreProvider));
});

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return AppointmentRepositoryImpl(ref.watch(firestoreProvider));
});

final medicationStatusRepositoryProvider = Provider<MedicationStatusRepository>((
  ref,
) {
  return MedicationStatusRepositoryImpl(ref.watch(firestoreProvider));
});

final resolveCaregiverLinkProvider = Provider<ResolveCaregiverLink>((ref) {
  return const ResolveCaregiverLink();
});

/// Same public name and behavior as the old `systemHealthProvider`: emits
/// an empty state when signed out, otherwise streams the current user's
/// health snapshot via [SystemHealthRepository].
final systemHealthProvider = StreamProvider<SystemHealthState>((ref) {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return Stream.value(
      const SystemHealthState(
        isSyncing: false,
        activeAlerts: [],
        devices: [],
        eventsLoggedToday: 0,
        caregiverName: null,
      ),
    );
  }

  return ref.watch(systemHealthRepositoryProvider).watchSystemHealth(user.uid);
});
