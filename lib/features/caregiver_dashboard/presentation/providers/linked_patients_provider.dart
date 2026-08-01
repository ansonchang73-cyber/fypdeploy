// lib/features/caregiver_dashboard/presentation/providers/linked_patients_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/linked_patient_summary.dart';
import 'caregiver_dashboard_providers.dart';

/// Every patient linked to the signed-in caregiver.
final linkedPatientsProvider = FutureProvider<List<LinkedPatientSummary>>((
  ref,
) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Future.value(const []);
  return ref.watch(getLinkedPatientsProvider).call(user.uid);
});
