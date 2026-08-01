// lib/features/profile/domain/entities/linked_caregiver_summary.dart

/// Just enough about a linked caregiver to show them in a list — the
/// patient-side mirror of `caregiver_dashboard`'s `LinkedPatientSummary`.
class LinkedCaregiverSummary {
  final String id;
  final String fullName;
  final String avatarUrl;
  final String phone;

  const LinkedCaregiverSummary({
    required this.id,
    required this.fullName,
    required this.avatarUrl,
    this.phone = '',
  });
}
