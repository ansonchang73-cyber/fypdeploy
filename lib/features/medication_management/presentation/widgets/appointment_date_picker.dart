// lib/features/medication_management/presentation/widgets/appointment_date_picker.dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Extracted from `_showCustomDatePicker` in the old `add_medication_screen.dart`.
///
/// The original chained straight into the time picker after a date was
/// picked (`_showCustomTimePicker(isAppointment: true)`), writing
/// directly to `_selectedDateTime` along the way. That chaining is now
/// the caller's responsibility — this widget only ever reports back a
/// picked date via [onDateSelected]; it doesn't know a time picker
/// exists. See `add_medication_screen.dart`'s `_openAppointmentDateTimePicker`
/// for how the two are composed together, same as before.
void showAppointmentDatePicker(
  BuildContext context, {
  required DateTime? initialDateTime,
  required ValueChanged<DateTime> onDateSelected,
}) {
  DateTime viewMonth = initialDateTime ?? DateTime.now();
  DateTime? pickedDate = initialDateTime ?? DateTime.now();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          int daysInMonth = DateUtils.getDaysInMonth(viewMonth.year, viewMonth.month);
          int firstWeekday = DateTime(viewMonth.year, viewMonth.month, 1).weekday;
          int offset = firstWeekday == 7 ? 0 : firstWeekday;

          return Dialog(
            backgroundColor: const Color(0xFFF3EDF7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Container(
              padding: const EdgeInsets.all(24),
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select Appointment Date', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.chevronLeft, color: Color(0xFF21005D)),
                        onPressed: () => setModalState(() => viewMonth = DateTime(viewMonth.year, viewMonth.month - 1)),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(viewMonth),
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF21005D)),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.chevronRight, color: Color(0xFF21005D)),
                        onPressed: () => setModalState(() => viewMonth = DateTime(viewMonth.year, viewMonth.month + 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) => Text(day, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black54))).toList(),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: daysInMonth + offset,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.0),
                    itemBuilder: (context, index) {
                      if (index < offset) return const SizedBox.shrink();
                      int day = index - offset + 1;

                      DateTime thisGridDate = DateTime(viewMonth.year, viewMonth.month, day);
                      bool isSelected = pickedDate?.year == viewMonth.year && pickedDate?.month == viewMonth.month && pickedDate?.day == day;
                      bool isPastDate = thisGridDate.isBefore(today);

                      return GestureDetector(
                        onTap: isPastDate ? null : () {
                          setModalState(() => pickedDate = thisGridDate);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF6750A4) : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$day',
                            style: GoogleFonts.inter(
                              color: isSelected
                                ? Colors.white
                                : isPastDate
                                  ? Colors.black26
                                  : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              decoration: isPastDate ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6750A4), fontWeight: FontWeight.w600)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (pickedDate != null) {
                            onDateSelected(pickedDate!);
                          }
                        },
                        child: Text('Next', style: GoogleFonts.inter(color: const Color(0xFF6750A4), fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
