// lib/features/caregiver_dashboard/domain/entities/linked_patient_summary.dart

/// Just enough about a linked patient to show them in a list — a name
/// and an avatar. Not the full `PatientProfile` from the `profile`
/// feature (allergies, emergency contacts, etc.) — this feature only
/// ever needs to display "who", not edit anything about them.
class LinkedPatientSummary {
  final String id;
  final String fullName;
  final String avatarUrl;

  const LinkedPatientSummary({
    required this.id,
    required this.fullName,
    required this.avatarUrl,
  });
}
