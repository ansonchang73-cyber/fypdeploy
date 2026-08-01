// lib/features/medication_management/presentation/widgets/medication_time_picker.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extracted from `_showCustomTimePicker` in the old `add_medication_screen.dart`.
///
/// The original had one method serving two call sites via an
/// `isAppointment` bool flag, branching internally on whether to write
/// the result into `_selectedTime` or `_selectedDateTime`. That branching
/// only made sense because the method was a closure over the screen's
/// State; as a standalone widget it shouldn't need to know either field
/// exists. Both call sites now just pass an [initialTime] and an
/// [onTimeSelected] callback, and decide for themselves what to do with
/// the result.
void showMedicationTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  required ValueChanged<TimeOfDay> onTimeSelected,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      bool isDialMode = true;
      bool isSelectingHours = true;

      int tempHour = initialTime.hourOfPeriod == 0 ? 12 : initialTime.hourOfPeriod;
      int tempMinute = initialTime.minute;
      String tempPeriod = initialTime.period == DayPeriod.am ? 'AM' : 'PM';

      final textHourController = TextEditingController();
      final textMinuteController = TextEditingController();
      final FocusNode hourFocusNode = FocusNode();
      final FocusNode minuteFocusNode = FocusNode();

      return StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: const Color(0xFFF3EDF7),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Container(
              padding: const EdgeInsets.all(24),
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDialMode ? 'Select time' : 'Enter time',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setModalState(() => isSelectingHours = true);
                          if (!isDialMode) hourFocusNode.requestFocus();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelectingHours ? const Color(0xFFE8DDFF) : const Color(0xFFE7E0EC),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelectingHours ? Border.all(color: const Color(0xFF6750A4), width: 2) : Border.all(color: Colors.transparent, width: 2),
                          ),
                          child: isDialMode
                              ? Text('$tempHour', style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w400, color: const Color(0xFF21005D)))
                              : SizedBox(
                                  width: 48,
                                  child: TextFormField(
                                    controller: textHourController,
                                    focusNode: hourFocusNode,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 36, color: const Color(0xFF21005D)),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                      hintText: '$tempHour',
                                      hintStyle: GoogleFonts.inter(fontSize: 36, color: Colors.black26),
                                    ),
                                    onTap: () => setModalState(() => isSelectingHours = true),
                                    onChanged: (val) {
                                      final int? h = int.tryParse(val);
                                      if (h != null && h >= 1 && h <= 12) tempHour = h;
                                    },
                                  ),
                                ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(':', style: TextStyle(fontSize: 36, color: Colors.black87)),
                      ),
                      GestureDetector(
                        onTap: () {
                          setModalState(() => isSelectingHours = false);
                          if (!isDialMode) minuteFocusNode.requestFocus();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: !isSelectingHours ? const Color(0xFFE8DDFF) : const Color(0xFFE7E0EC),
                            borderRadius: BorderRadius.circular(8),
                            border: !isSelectingHours ? Border.all(color: const Color(0xFF6750A4), width: 2) : Border.all(color: Colors.transparent, width: 2),
                          ),
                          child: isDialMode
                              ? Text(tempMinute.toString().padLeft(2, '0'), style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w400, color: Colors.black87))
                              : SizedBox(
                                  width: 48,
                                  child: TextFormField(
                                    controller: textMinuteController,
                                    focusNode: minuteFocusNode,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 36, color: Colors.black87),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                      hintText: tempMinute.toString().padLeft(2, '0'),
                                      hintStyle: GoogleFonts.inter(fontSize: 36, color: Colors.black26),
                                    ),
                                    onTap: () => setModalState(() => isSelectingHours = false),
                                    onChanged: (val) {
                                      final int? m = int.tryParse(val);
                                      if (m != null && m >= 0 && m <= 59) tempMinute = m;
                                    },
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () => setModalState(() => tempPeriod = 'AM'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: tempPeriod == 'AM' ? const Color(0xFFFFD8E4) : Colors.transparent,
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              ),
                              child: Text('AM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tempPeriod == 'AM' ? const Color(0xFF31111D) : Colors.black87)),
                             ),
                          ),
                          InkWell(
                            onTap: () => setModalState(() => tempPeriod = 'PM'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: tempPeriod == 'PM' ? const Color(0xFFFFD8E4) : Colors.transparent,
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                              ),
                              child: Text('PM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tempPeriod == 'PM' ? const Color(0xFF31111D) : Colors.black87)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isDialMode) ...[
                    Center(
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: const BoxDecoration(color: Color(0xFFE7E0EC), shape: BoxShape.circle),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(210, 210),
                              painter: OperationalDialPainter(
                                selectedValue: isSelectingHours ? tempHour : tempMinute,
                                isHoursMode: isSelectingHours,
                                color: const Color(0xFF6750A4),
                              ),
                            ),
                            ...List.generate(12, (index) {
                              final int valueNumber = isSelectingHours ? (index == 0 ? 12 : index) : index * 5;
                              final double angle = (index - 3) * 30 * math.pi / 180;

                              return Positioned(
                                left: 105 + 80 * math.cos(angle) - 16,
                                top: 105 + 80 * math.sin(angle) - 16,
                                child: InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelectingHours) {
                                        tempHour = valueNumber;
                                        isSelectingHours = false;
                                      } else {
                                        tempMinute = valueNumber;
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(99),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    child: Text(
                                      isSelectingHours ? '$valueNumber' : valueNumber.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: (isSelectingHours && tempHour == valueNumber) || (!isSelectingHours && tempMinute == valueNumber)
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          setModalState(() {
                            isDialMode = !isDialMode;
                            if (!isDialMode) {
                              textHourController.clear();
                              textMinuteController.clear();
                            }
                          });
                        },
                        child: CustomPaint(
                          size: const Size(24, 24),
                          painter: ModeToggleIconPainter(isDialMode: isDialMode, color: const Color(0xFF6750A4)),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              hourFocusNode.dispose();
                              minuteFocusNode.dispose();
                              Navigator.pop(context);
                            },
                            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6750A4), fontWeight: FontWeight.w600)),
                          ),
                          TextButton(
                            onPressed: () {
                              int finalHour = tempHour;
                              if (tempPeriod == 'PM' && finalHour != 12) finalHour += 12;
                              if (tempPeriod == 'AM' && finalHour == 12) finalHour = 0;

                              onTimeSelected(TimeOfDay(hour: finalHour, minute: tempMinute));

                              hourFocusNode.dispose();
                              minuteFocusNode.dispose();
                              Navigator.pop(context);
                            },
                            child: Text('OK', style: GoogleFonts.inter(color: const Color(0xFF6750A4), fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class OperationalDialPainter extends CustomPainter {
  final int selectedValue;
  final bool isHoursMode;
  final Color color;

  OperationalDialPainter({required this.selectedValue, required this.isHoursMode, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centerPaint = Paint()..color = color..style = PaintingStyle.fill;
    final linePaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0;

    Offset center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 4, centerPaint);

    int targetIndex = isHoursMode ? (selectedValue == 12 ? 0 : selectedValue) : (selectedValue ~/ 5);
    double angle = (targetIndex - 3) * 30 * math.pi / 180;

    Offset targetDialPos = Offset(center.dx + 80 * math.cos(angle), center.dy + 80 * math.sin(angle));
    canvas.drawLine(center, targetDialPos, linePaint);
    canvas.drawCircle(targetDialPos, 16, centerPaint);
  }

  @override
  bool shouldRepaint(covariant OperationalDialPainter oldDelegate) =>
      oldDelegate.selectedValue != selectedValue || oldDelegate.isHoursMode != isHoursMode;
}

class ModeToggleIconPainter extends CustomPainter {
  final bool isDialMode;
  final Color color;
  ModeToggleIconPainter({required this.isDialMode, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0;

    if (isDialMode) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 4, size.width, size.height - 8), const Radius.circular(4)), paint);
      canvas.drawLine(Offset(4, size.height / 2), Offset(size.width - 4, size.height / 2), paint);
    } else {
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), (size.width / 2) - 2, paint);
      canvas.drawLine(Offset(size.width / 2, size.height / 2), Offset(size.width / 2, 6), paint);
      canvas.drawLine(Offset(size.width / 2, size.height / 2), Offset(size.width * 0.7, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
