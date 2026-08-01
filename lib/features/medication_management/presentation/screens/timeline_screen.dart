// lib/features/medication_management/presentation/screens/timeline_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/medication_task.dart';
import '../providers/hardware_sync_controller.dart';
import '../providers/medication_management_providers.dart';
import '../providers/timeline_provider.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  late Timer _currentTimeTimer;
  late FixedExtentScrollController _wheelScrollController;
  late PageController _dayPageController;
  DateTime _now = DateTime.now();

  static const int startHour = 0;
  static const int endHour = 23;
  int _focusedHour = DateTime.now().hour;
  int _selectedDayNumber = DateTime.now().day;

  @override
  void initState() {
    super.initState();
    _selectedDayNumber = _now.day;
    _wheelScrollController = FixedExtentScrollController(initialItem: _now.hour);

    _dayPageController = PageController(
      initialPage: _selectedDayNumber - 1,
      viewportFraction: 0.15,
    );

    // 🚀 GRAB THE REAL USER ID DYNAMICALLY
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // 🚀 USE THE DYNAMIC ID FOR HARDWARE SYNC
    ref.read(hardwareSyncControllerProvider).listenToHardwareTrigger(currentUserId);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(hardwareSyncControllerProvider).checkAndSyncHardware(currentUserId);
      if (mounted) _animateToCurrentTime();
    });

    _currentTimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
        _animateToCurrentTime();
        // 🚀 ENSURE TIMER LOOP ALSO USES DYNAMIC ID
        await ref.read(hardwareSyncControllerProvider).checkAndSyncHardware(currentUserId);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _animateToCurrentTime();
      });
    });
  }

  @override
  void dispose() {
    _currentTimeTimer.cancel();
    _wheelScrollController.dispose();
    _dayPageController.dispose();
    super.dispose();
  }

  void _animateToCurrentTime() {
    if (_wheelScrollController.hasClients) {
      _wheelScrollController.animateToItem(
        _now.hour,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showMedicationDetails(BuildContext context, MedicationTask task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
              left: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.0),
              right: BorderSide(color: Colors.white.withValues(alpha: 0.6), width: 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: -4,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(task.name, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildDetailRow(LucideIcons.clock, "Time", task.time),
              _buildDetailRow(LucideIcons.repeat, "Frequency", task.frequency),
              // Assuming these fields exist in your MedicationTask object
              _buildDetailRow(LucideIcons.pill, "Dosage", "1 Tablet"),
              _buildDetailRow(LucideIcons.info, "Instructions", "Take with water after meal"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0058BC)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
              Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  int _getDaysInCurrentMonth() {
    final nextMonth = DateTime(_now.year, _now.month + 1, 1);
    final lastDayOfThisMonth = nextMonth.subtract(const Duration(days: 1));
    return lastDayOfThisMonth.day;
  }

  /// Deterministic color-from-name hash — purely a display choice (which
  /// shade to render a pill in), not a business rule, so it stays here
  /// rather than moving to the domain layer.
  Color _getMedicationColor(String name, bool isDarkText) {
    final int hash = name.hashCode;
    final double hue = (hash.abs() % 360).toDouble();
    return isDarkText
        ? HSLColor.fromAHSL(1.0, hue, 0.65, 0.30).toColor()
        : HSLColor.fromAHSL(1.0, hue, 0.70, 0.93).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(timelineProvider);
    final int totalHoursTracked = endHour - startHour + 1;
    final int totalDaysInMonth = _getDaysInCurrentMonth();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Medication Agenda',
          style: GoogleFonts.inter(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.navigation, size: 18, color: Color(0xFF0058BC)),
            tooltip: 'Jump to Current Hour',
            onPressed: _animateToCurrentTime,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0058BC))),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.black87))),
        data: (rawSchedule) {
          final schedule = List<MedicationTask>.from(rawSchedule);

          return Column(
            children: [
              RepaintBoundary(
                child: Container(
                  height: 85,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withAlpha(115),
                                Colors.white.withAlpha(38),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withAlpha(153),
                              width: 1.2,
                            ),
                          ),
                          child: PageView.builder(
                            controller: _dayPageController,
                            itemCount: totalDaysInMonth,
                            padEnds: true,
                            onPageChanged: (index) {
                              setState(() {
                                _selectedDayNumber = index + 1;
                              });
                            },
                            itemBuilder: (context, index) {
                              final int dayNum = index + 1;
                              final DateTime calculatedDate = DateTime(_now.year, _now.month, dayNum);
                              final String dayLabel = DateFormat('EEE').format(calculatedDate).toUpperCase();
                              final bool isSelected = dayNum == _selectedDayNumber;

                              return Container(
                                color: Colors.transparent,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      dayLabel,
                                      maxLines: 1,
                                      softWrap: false,
                                      style: GoogleFonts.inter(
                                        fontSize: isSelected ? 12 : 10,
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                        color: const Color(0xFF0058BC),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$dayNum',
                                      maxLines: 1,
                                      softWrap: false,
                                      style: GoogleFonts.inter(
                                        fontSize: isSelected ? 18 : 15,
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                        color: const Color(0xFF0058BC),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: SizedBox(
                          width: (MediaQuery.of(context).size.width - 32) * 0.2,
                          height: 68,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Positioned.fill(
                                child: RawMagnifier(
                                  size: Size.infinite,
                                  magnificationScale: 1.18,
                                  focalPointOffset: Offset.zero,
                                ),
                              ),
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF0058BC).withAlpha(216),
                                      width: 1.8,
                                    ),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withAlpha(89),
                                        width: 1.0,
                                      ),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withAlpha(30),
                                          Colors.white.withAlpha(0),
                                          Colors.white.withAlpha(15),
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // The highlighted "now" box below is always 110px tall
                    // and centered in this Stack. Compute where its top
                    // edge sits so the live clock badge can be pinned right
                    // on that line, regardless of screen height.
                    final double highlightBoxTop =
                        (constraints.maxHeight - 110) / 2;
                    final double badgeTop = (highlightBoxTop - 14).clamp(
                      0.0,
                      constraints.maxHeight,
                    );

                    return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // =========================================================
                    // LAYER 1: FROSTED GLASS BASE (Background)
                    // =========================================================
                    Container(
                      height: 110,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.0),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.3),
                                  const Color(0xFF0058BC).withOpacity(0.01),
                                  Colors.white.withOpacity(0.2),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // =========================================================
                    // LAYER 2: THE DETAILED CONTENT (Magnified)
                    // =========================================================
                    ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withAlpha(20),
                            Colors.black,
                            Colors.black,
                            Colors.black,
                            Colors.black.withAlpha(20),
                          ],
                          stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // The Scroll View
                          ListWheelScrollView.useDelegate(
                            controller: _wheelScrollController,
                            itemExtent: 110,
                            perspective: 0.0018,
                            diameterRatio: 2.8,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setState(() {
                                _focusedHour = startHour + index;
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: totalHoursTracked,
                              builder: (context, index) {
                                final currentHourItem = startHour + index;
                                final period = currentHourItem >= 12 ? 'PM' : 'AM';
                                final formattedHour = currentHourItem > 12
                                    ? currentHourItem - 12
                                    : (currentHourItem == 0 ? 12 : currentHourItem);

                                final bool isCurrentHourRow = currentHourItem == _focusedHour;
                                final hourMeds = schedule
                                    .where((task) => ref
                                        .read(shouldShowTaskAtHourProvider)
                                        .call(task, currentHourItem, _selectedDayNumber))
                                    .toList();

                                return Container(
                                  height: 110,
                                  alignment: Alignment.center,
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 32),
                                      SizedBox(
                                        width: 55,
                                        child: Text(
                                          '$formattedHour:00\n$period',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: isCurrentHourRow ? const Color(0xFF0058BC) : Colors.black38,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: hourMeds.length,
                                          shrinkWrap: true,
                                          physics: const BouncingScrollPhysics(),
                                          padding: const EdgeInsets.only(right: 64),
                                          itemBuilder: (context, medIndex) {
                                            final task = hourMeds[medIndex];
                                            return InkWell(
                                              onTap: () => _showMedicationDetails(context, task),
                                              borderRadius: BorderRadius.circular(14),
                                              child: Container(
                                                width: 110,
                                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      _getMedicationColor(task.name, false).withAlpha(115),
                                                      _getMedicationColor(task.name, false).withAlpha(38),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: isCurrentHourRow
                                                        ? const Color(0xFF0058BC).withAlpha(204)
                                                        : Colors.white.withAlpha(127),
                                                    width: isCurrentHourRow ? 1.8 : 1.2,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Expanded(
                                                      child: Center(
                                                        child: Icon(
                                                          LucideIcons.pill,
                                                          size: 20,
                                                          color: _getMedicationColor(task.name, true),
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      width: double.infinity,
                                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                                      child: Text(
                                                        task.name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: _getMedicationColor(task.name, true),
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // The Magnifier (Applied specifically to the content, below the border)
                        ],
                      ),
                    ),

                    // =========================================================
                    // LAYER 3: FOREGROUND BORDER (Draws last, on top of Magnifier)
                    // =========================================================
                    IgnorePointer(
                      child: Container(
                        height: 110,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0058BC).withAlpha(40),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: const RawMagnifier(
                            size: Size.infinite,
                            magnificationScale: 1.05,
                            focalPointOffset: Offset.zero,
                          ),
                        ),
                      ),
                    ),

                    // =========================================================
                    // LIVE CLOCK BADGE — pinned to the top-middle border of
                    // the highlighted "now" box, always showing the current
                    // time (kept in sync by the same `_now` ticker used to
                    // scroll the wheel to the current hour).
                    // =========================================================
                    Positioned(
                      top: badgeTop,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildCurrentTimeBadge()),
                    ),
                  ],
                );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }

  /// Small pill showing the live current time, pinned to the top-middle
  /// border of the highlighted "now" box in the timeline wheel.
  Widget _buildCurrentTimeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0058BC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0058BC).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.clock, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            DateFormat('h:mm a').format(_now),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
