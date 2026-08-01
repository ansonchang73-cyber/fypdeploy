// lib/features/caregiver_dashboard/presentation/providers/caregiver_dashboard_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/presentation/providers/profile_providers.dart' show sharedAccessRepositoryProvider;

import '../../data/repositories/adherence_reports_repository_impl.dart';
import '../../data/repositories/linked_patients_repository_impl.dart';

import '../../domain/repositories/adherence_reports_repository.dart';
import '../../domain/repositories/linked_patients_repository.dart';

import '../../domain/usecases/caregiver_dashboard_usecases.dart';
import '../../domain/usecases/compute_daily_adherence_percentage.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// --- Repositories ---
final linkedPatientsRepositoryProvider = Provider<LinkedPatientsRepository>((
  ref,
) {
  return LinkedPatientsRepositoryImpl(
    ref.watch(sharedAccessRepositoryProvider),
    ref.watch(firestoreProvider),
  );
});

final adherenceReportsRepositoryProvider = Provider<AdherenceReportsRepository>((
  ref,
) {
  return AdherenceReportsRepositoryImpl(ref.watch(firestoreProvider));
});

// --- Use cases ---
final getLinkedPatientsProvider = Provider<GetLinkedPatients>((ref) {
  return GetLinkedPatients(ref.watch(linkedPatientsRepositoryProvider));
});

final getAdherenceReportsForPatientProvider = Provider<GetAdherenceReportsForPatient>((
  ref,
) {
  return GetAdherenceReportsForPatient(ref.watch(adherenceReportsRepositoryProvider));
});

final computeDailyAdherencePercentageProvider = Provider<ComputeDailyAdherencePercentage>((
  ref,
) {
  return const ComputeDailyAdherencePercentage();
});
