// lib/features/profile/presentation/providers/profile_providers.dart
//
// Composition root for the profile feature: this is the ONLY file that
// wires a domain interface to its concrete `data/` implementation. Every
// other provider/controller/screen depends on the domain interfaces
// (`PatientRepository`, `CareCircleRepository`, etc.) or on the use case
// classes below — never on `PatientRepositoryImpl` etc. directly.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/adherence_repository_impl.dart';
import '../../data/repositories/adherence_reports_repository_impl.dart';
import '../../data/repositories/care_circle_repository_impl.dart';
import '../../data/repositories/linked_caregivers_repository_impl.dart';
import '../../data/repositories/patient_repository_impl.dart';
import '../../data/repositories/shared_access_repository_impl.dart';
import '../../data/services/pdf_report_renderer.dart';

import '../../domain/repositories/adherence_repository.dart';
import '../../domain/repositories/adherence_reports_repository.dart';
import '../../domain/repositories/care_circle_repository.dart';
import '../../domain/repositories/linked_caregivers_repository.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../domain/repositories/shared_access_repository.dart';

import '../../domain/usecases/appointment_usecases.dart';
import '../../domain/usecases/build_adherence_report.dart';
import '../../domain/usecases/care_circle_usecases.dart';
import '../../domain/usecases/generate_invitation_code.dart';
import '../../domain/usecases/get_linked_caregivers.dart';
import '../../domain/usecases/link_caregiver_to_patient.dart';
import '../../domain/usecases/patient_profile_usecases.dart';

// ---------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final pdfReportRendererProvider = Provider<PdfReportRenderer>((ref) {
  return PdfReportRenderer();
});

// ---------------------------------------------------------------------
// Repositories — exposed only as their domain interface type
// ---------------------------------------------------------------------
final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepositoryImpl(ref.watch(firestoreProvider));
});

final careCircleRepositoryProvider = Provider<CareCircleRepository>((ref) {
  return CareCircleRepositoryImpl();
});

final adherenceRepositoryProvider = Provider<AdherenceRepository>((ref) {
  return AdherenceRepositoryImpl(ref.watch(firestoreProvider));
});

final sharedAccessRepositoryProvider = Provider<SharedAccessRepository>((ref) {
  return SharedAccessRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

final adherenceReportsRepositoryProvider = Provider<AdherenceReportsRepository>((
  ref,
) {
  return AdherenceReportsRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  );
});

final linkedCaregiversRepositoryProvider = Provider<LinkedCaregiversRepository>((
  ref,
) {
  return LinkedCaregiversRepositoryImpl(
    ref.watch(sharedAccessRepositoryProvider),
    ref.watch(firestoreProvider),
  );
});

// ---------------------------------------------------------------------
// Use cases
// ---------------------------------------------------------------------
final watchPatientProfileProvider = Provider<WatchPatientProfile>((ref) {
  return WatchPatientProfile(ref.watch(patientRepositoryProvider));
});

final updatePatientProfileProvider = Provider<UpdatePatientProfile>((ref) {
  return UpdatePatientProfile(ref.watch(patientRepositoryProvider));
});

final updatePatientAvatarProvider = Provider<UpdatePatientAvatar>((ref) {
  return UpdatePatientAvatar(ref.watch(patientRepositoryProvider));
});

final watchAppointmentsProvider = Provider<WatchAppointments>((ref) {
  return WatchAppointments(ref.watch(patientRepositoryProvider));
});

final getCareCircleProvider = Provider<GetCareCircle>((ref) {
  return GetCareCircle(ref.watch(careCircleRepositoryProvider));
});

final generateInvitationCodeProvider = Provider<GenerateInvitationCode>((ref) {
  return GenerateInvitationCode(ref.watch(sharedAccessRepositoryProvider));
});

final linkCaregiverToPatientProvider = Provider<LinkCaregiverToPatient>((ref) {
  return LinkCaregiverToPatient(ref.watch(sharedAccessRepositoryProvider));
});

final getLinkedCaregiversProvider = Provider<GetLinkedCaregivers>((ref) {
  return GetLinkedCaregivers(ref.watch(linkedCaregiversRepositoryProvider));
});

final buildAdherenceReportProvider = Provider<BuildAdherenceReport>((ref) {
  return const BuildAdherenceReport();
});
