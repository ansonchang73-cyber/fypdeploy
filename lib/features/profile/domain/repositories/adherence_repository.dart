// lib/features/profile/domain/repositories/adherence_repository.dart
import '../entities/adherence_report.dart';

abstract class AdherenceRepository {
  /// Raw dose history for [patientId] between [from] (inclusive) and
  /// [to] (exclusive). No aggregation/percentages here — that's the
  /// `BuildAdherenceReport` use case's job.
  Future<List<DoseLogEntry>> fetchLogs({
    required String patientId,
    required DateTime from,
    required DateTime to,
  });
}