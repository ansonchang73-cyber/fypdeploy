// lib/features/medication_management/presentation/providers/medication_management_providers.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/appointment_repository_impl.dart';
import '../../data/repositories/hardware_sync_repository_impl.dart';
import '../../data/repositories/medication_schedule_repository_impl.dart';

import '../../domain/repositories/appointment_repository.dart';
import '../../domain/repositories/hardware_sync_repository.dart';
import '../../domain/repositories/medication_schedule_repository.dart';

import '../../domain/usecases/build_medication_schedule_plan.dart';
import '../../domain/usecases/compute_hardware_eligible_task.dart';
import '../../domain/usecases/schedule_usecases.dart';
import '../../domain/usecases/should_show_task_at_hour.dart';
import '../../domain/usecases/validate_appointment_request.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// --- Repositories ---
final medicationScheduleRepositoryProvider = Provider<MedicationScheduleRepository>((
  ref,
) {
  return MedicationScheduleRepositoryImpl(ref.watch(firestoreProvider));
});

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return AppointmentRepositoryImpl(ref.watch(firestoreProvider));
});

/// `.watch(firestoreProvider)` here — deliberately NOT recreated per
/// listener — the single instance is what makes the shared debounce flag
/// (see `HardwareSyncRepositoryImpl`) actually shared across every call
/// site, the same way the original's `static bool` was.
final hardwareSyncRepositoryProvider = Provider<HardwareSyncRepository>((ref) {
  return HardwareSyncRepositoryImpl(ref.watch(firestoreProvider));
});

// --- Use cases ---
final watchTodayScheduleProvider = Provider<WatchTodaySchedule>((ref) {
  return WatchTodaySchedule(ref.watch(medicationScheduleRepositoryProvider));
});

final markDoseTakenProvider = Provider<MarkDoseTaken>((ref) {
  return MarkDoseTaken(ref.watch(medicationScheduleRepositoryProvider));
});

final resetDailyAdherenceIfNeededProvider = Provider<ResetDailyAdherenceIfNeeded>((
  ref,
) {
  return ResetDailyAdherenceIfNeeded(ref.watch(medicationScheduleRepositoryProvider));
});

final buildMedicationSchedulePlanProvider = Provider<BuildMedicationSchedulePlan>((
  ref,
) {
  return const BuildMedicationSchedulePlan();
});

final validateAppointmentRequestProvider = Provider<ValidateAppointmentRequest>((
  ref,
) {
  return const ValidateAppointmentRequest();
});

final shouldShowTaskAtHourProvider = Provider<ShouldShowTaskAtHour>((ref) {
  return const ShouldShowTaskAtHour();
});

final computeHardwareEligibleTaskProvider = Provider<ComputeHardwareEligibleTask>((
  ref,
) {
  return const ComputeHardwareEligibleTask();
});
