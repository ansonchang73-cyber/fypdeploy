// lib/features/profile/domain/usecases/merge_live_overdue_doses.dart
//
// Shared adherence-period helpers used by every feature that can report on
// a period covering *today* — the caregiver Storage page's monthly card,
// the patient's own "Medication Adherence Logs" export, and the
// appointment-record export's embedded monthly summary. Pulled out into
// one place specifically so all three stay consistent by construction:
// fixing something in only one of them is exactly how they previously
// ended up showing different numbers for what should be the same month.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../medication_management/domain/entities/medication_task.dart';
import '../../../medication_management/presentation/providers/medication_management_providers.dart';
import '../entities/adherence_report.dart';

/// Fetches a patient's current daily dose schedule once — the shared
/// input for [liveOverdueEntriesForToday], [expectedTotalDosesFor], and
/// [sortedMedicationSchedule], so a single report only ever fetches this
/// once instead of three times.
Future<List<MedicationTask>> fetchDailySchedule(
  Ref ref,
  String patientId,
) async {
  try {
    return await ref
        .read(medicationScheduleRepositoryProvider)
        .watchSchedule(patientId)
        .first;
  } catch (_) {
    return const [];
  }
}

/// `medication_logs` only ever has an entry once a dose has been
/// explicitly confirmed taken/missed, or once a day boundary has passed
/// and the daily reset has backfilled anything left unconfirmed. That
/// means a query reaching into *today* would otherwise miss today's doses
/// that are already overdue but not yet confirmed (or reset) — which is
/// exactly what made "2 confirmed doses out of 2 logged" read as 100%,
/// even with other reminders sitting ignored. This merges those in live,
/// computed fresh from [schedule] every time a report is built, so it
/// self-corrects the moment a dose becomes overdue rather than waiting
/// for the next daily reset.
///
/// Only worth calling when [queryWindowCoversToday] is true — [schedule]
/// is always *today's* schedule, so there's nothing to add otherwise.
/// [alreadyLogged] excludes anything that — despite still showing
/// 'upcoming' on the live schedule — already has a same-day log entry
/// (e.g. from a previous call, or a reset that ran moments ago), so a
/// dose can never be double-counted.
List<DoseLogEntry> liveOverdueEntriesForToday(
  List<MedicationTask> schedule,
  List<DoseLogEntry> alreadyLogged,
) {
  final now = DateTime.now();
  final loggedToday = alreadyLogged
      .where((l) =>
          l.timestamp.year == now.year &&
          l.timestamp.month == now.month &&
          l.timestamp.day == now.day)
      .map((l) => '${l.medicationName}|${l.reminderTime}')
      .toSet();

  final entries = <DoseLogEntry>[];
  for (final task in schedule) {
    if (task.status != TaskStatus.upcoming) continue;
    if (loggedToday.contains('${task.name}|${task.time}')) continue;
    final due = _timeToday(task.time, now);
    if (due == null || !due.isBefore(now)) continue;
    entries.add(DoseLogEntry(
      timestamp: due,
      reminderTime: task.time,
      medicationName: task.name,
      isCompleted: false,
    ));
  }
  return entries;
}

/// Whether [targetMonthStart] (always the 1st of some month, across every
/// caller) is the *current* calendar month — the only case where today's
/// live schedule has anything relevant to add. Deliberately not based on
/// comparing a `to` boundary against "now": `resolveQueryEnd` always
/// resolves to "midnight today" regardless of which month is being
/// targeted (that's what makes "the whole previous month" query work
/// correctly when checked on the 1st), so a `to`-based check can't
/// actually tell "this month" apart from "last month" in that case —
/// checking the target month directly can. The second parameter is
/// accepted-and-ignored so existing `(from, to)` call sites don't need to
/// change.
bool queryWindowCoversToday(DateTime targetMonthStart, [DateTime? _]) {
  final now = DateTime.now();
  return targetMonthStart.year == now.year &&
      targetMonthStart.month == now.month;
}

/// "July 2026 Adherence Report (Up to Jul 29)" — or, for a fully-elapsed
/// past month, "July 2026 Adherence Report (Full Month)". The standard
/// label for a calendar-month adherence report, shared by every feature
/// that generates one — the patient's own "Medication Adherence Logs"
/// checkboxes and the appointment-record export both use this, so a
/// report for the same month always reads identically everywhere it
/// shows up instead of two near-identical implementations quietly
/// drifting apart.
String adherenceReportLabelForMonth(DateTime monthStart) {
  final monthLabel = DateFormat('MMMM yyyy').format(monthStart);
  if (queryWindowCoversToday(monthStart)) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '$monthLabel Adherence Report (Up to ${DateFormat('MMM d').format(yesterday)})';
  }
  return '$monthLabel Adherence Report (Full Month)';
}

/// How many days a report period actually spans, given [monthStart]
/// (always the 1st of the target month): the *full* number of days in
/// that month if it's a fully-elapsed past month, or just the number of
/// days elapsed *so far* if it's the current, still-in-progress month —
/// "up to the current date", per how every monthly adherence report in
/// the app is worded.
int daysInReportPeriod(DateTime monthStart) {
  final now = DateTime.now();
  if (queryWindowCoversToday(monthStart)) {
    return now.day;
  }
  // Last day of that month = days in that month (day-0-of-next-month
  // trick), regardless of the month's actual length (28/29/30/31).
  return DateTime(monthStart.year, monthStart.month + 1, 0).day;
}

/// The *theoretical* number of doses expected to have occurred over
/// [daysInPeriod] days, based on how many daily dose slots [schedule]
/// says the patient currently has active. Deliberately not just "how many
/// log entries exist" — a scheduling gap, an app-not-opened stretch, or
/// any other logging blind spot shouldn't quietly shrink the denominator
/// and inflate the percentage; e.g. 2 medications/day x 30 days = 60
/// expected doses for a full month, regardless of how many actually ended
/// up logged. Assumes a constant dose count across the whole period — if
/// the patient added or removed a medication partway through, this won't
/// retroactively account for that (there's no historical schedule-size
/// tracking in this app to do so accurately).
int expectedTotalDosesFor(List<MedicationTask> schedule, int daysInPeriod) {
  if (daysInPeriod <= 0) return 0;
  return schedule.length * daysInPeriod;
}

/// [schedule] turned into the medication-name/reminder-time pairs a
/// report lists above its detailed dose log — latest time of day first,
/// so e.g. a bedtime dose leads and a breakfast dose trails.
List<MedicationScheduleEntry> sortedMedicationSchedule(
  List<MedicationTask> schedule,
) {
  final entries = schedule
      .map((t) => MedicationScheduleEntry(
            medicationName: t.name,
            reminderTime: t.time,
          ))
      .toList();
  entries.sort((a, b) => _minutesSinceMidnight(b.reminderTime)
      .compareTo(_minutesSinceMidnight(a.reminderTime)));
  return entries;
}

/// Mirrors `BuildAdherenceReport._parseHour`'s tolerant parsing (handles
/// both "8:00 AM" and 24-hour "08:00", whichever format reminder times end
/// up stored in) but keeps minutes too.
({int hour, int minute})? _parseTimeComponents(String timeStr) {
  try {
    final cleanTime = timeStr.toUpperCase().trim();
    final isPM = cleanTime.contains('PM');
    final isAM = cleanTime.contains('AM');
    final rawTimeStr = cleanTime.replaceAll(RegExp(r'[A-Z\s]'), '');
    final parts = rawTimeStr.split(':');
    if (parts.isEmpty) return null;
    int hour = int.parse(parts[0].trim());
    final int minute = parts.length > 1 ? int.parse(parts[1].trim()) : 0;
    if (isPM && hour < 12) hour += 12;
    if (isAM && hour == 12) hour = 0;
    return (hour: hour, minute: minute);
  } catch (_) {
    return null;
  }
}

DateTime? _timeToday(String timeStr, DateTime today) {
  final t = _parseTimeComponents(timeStr);
  if (t == null) return null;
  return DateTime(today.year, today.month, today.day, t.hour, t.minute);
}

int _minutesSinceMidnight(String timeStr) {
  final t = _parseTimeComponents(timeStr);
  if (t == null) return 0;
  return t.hour * 60 + t.minute;
}
