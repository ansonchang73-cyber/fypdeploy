// lib/features/medication_management/domain/usecases/build_medication_schedule_plan.dart
import '../entities/medication_schedule_plan.dart';

/// Turns a [MedicationScheduleRequest] into a concrete [MedicationSchedulePlan]:
/// the actual list of dose times for the day, plus a human-readable
/// frequency label — one Firestore document gets created per slot later,
/// by the repository. Pure calculation, no Firestore, no Flutter widgets,
/// fully unit-testable.
///
/// Extracted from `_submitCareForm` in the old `add_medication_screen.dart`,
/// where this logic (frequency parsing, slot generation, filtering out
/// slots already in the past today) was interleaved with the Firestore
/// batch-write loop.
class BuildMedicationSchedulePlan {
  const BuildMedicationSchedulePlan();

  MedicationSchedulePlan call(MedicationScheduleRequest request, DateTime now) {
    final String dosage = '${request.dosageValue.trim()} ${request.dosageUnit}';

    final List<ScheduleTime> allSlots;
    final String frequencyLabel;

    switch (request.frequencyType) {
      case 'Once daily (QD)':
      case 'As needed (PRN)':
      case 'Immediately (STAT)':
        frequencyLabel = request.frequencyType;
        allSlots = [request.initialTime];
        break;

      case 'Time(s) a day':
        frequencyLabel = '${request.frequencyNumber} Times a day';
        allSlots = _evenlySpacedSlots(
          startHour: request.initialTime.hour,
          minute: request.initialTime.minute,
          count: request.frequencyNumber,
          intervalHours: (24 / request.frequencyNumber).floor(),
        );
        break;

      case 'Hour(s) (Every X hours)':
        final int intervalHours = request.intervalHours ?? 1;
        frequencyLabel = 'Every $intervalHours Hour(s)';
        allSlots = _evenlySpacedSlots(
          startHour: request.initialTime.hour,
          minute: request.initialTime.minute,
          count: (24 / intervalHours).floor(),
          intervalHours: intervalHours,
        );
        break;

      default:
        // "Day(s) (Every X days)" and anything else falls back to this —
        // matches the original exactly, including reusing the first word
        // of the frequency-type label ("Day(s)") verbatim.
        frequencyLabel =
            'Every ${request.frequencyNumber} ${request.frequencyType.split(' ')[0]}';
        allSlots = [request.initialTime];
    }

    final int nowMinutes = now.hour * 60 + now.minute;
    final List<ScheduleTime> futureSlots = [];
    int skippedCount = 0;

    for (final slot in allSlots) {
      final int slotMinutes = slot.hour * 60 + slot.minute;
      final bool isPastSlot = slotMinutes < nowMinutes;
      if (isPastSlot) {
        skippedCount++;
      } else {
        futureSlots.add(slot);
      }
    }

    return MedicationSchedulePlan(
      dosage: dosage,
      frequencyLabel: frequencyLabel,
      slotTimes: futureSlots,
      skippedPastSlotCount: skippedCount,
    );
  }

  List<ScheduleTime> _evenlySpacedSlots({
    required int startHour,
    required int minute,
    required int count,
    required int intervalHours,
  }) {
    final slots = <ScheduleTime>[];
    int currentHour = startHour;
    for (int i = 0; i < count; i++) {
      slots.add(ScheduleTime(hour: currentHour, minute: minute));
      currentHour = (currentHour + intervalHours) % 24;
    }
    return slots;
  }
}
