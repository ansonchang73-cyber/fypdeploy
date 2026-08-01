// lib/features/medication_management/presentation/screens/add_medication_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../domain/entities/appointment_request.dart';
import '../../domain/entities/medication_schedule_plan.dart';
import '../../domain/usecases/validate_appointment_request.dart';
import '../providers/medication_management_providers.dart';
import '../widgets/appointment_date_picker.dart';
import '../widgets/clinic_map_picker.dart';
import '../widgets/medication_form_widgets.dart';
import '../widgets/medication_time_picker.dart';

class CreateMedicationScheduleScreen extends ConsumerStatefulWidget {
  final String userId;

  const CreateMedicationScheduleScreen({super.key, required this.userId});

  @override
  ConsumerState<CreateMedicationScheduleScreen> createState() =>
      _CreateMedicationScheduleScreenState();
}

class _CreateMedicationScheduleScreenState
    extends ConsumerState<CreateMedicationScheduleScreen> {
  int _selectedSegmentIndex = 0; // 0 = Medication, 1 = Appointment
  final _formKey = GlobalKey<FormState>();

  // ===========================================================================
  // 💊 ADVANCED MEDICATION CONTROLLERS & STATE
  // ===========================================================================
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dosageValueController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController();

  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  String _selectedDosageUnit = 'mg';
  final List<String> _dosageUnits = ['mg', 'mcg', 'g', 'mg/mL', 'mL', 'Pills', 'Drops', 'Capsules'];

  int _selectedFreqNumber = 1;
  final List<int> _freqNumbers = List.generate(24, (index) => index + 1);

  String _selectedFreqType = 'Once daily (QD)';
  final List<String> _freqTypes = [
    'Once daily (QD)',
    'Time(s) a day',
    'Hour(s) (Every X hours)',
    'Day(s) (Every X days)',
    'As needed (PRN)',
    'Immediately (STAT)'
  ];

  // ===========================================================================
  // 🩺 CLINICAL APPOINTMENT CONTROLLERS & STATE
  // ===========================================================================
  final TextEditingController _appointmentTitleController = TextEditingController();
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime? _selectedDateTime;

  String _selectedVisitReason = 'General Checkup';
  final List<String> _visitReasons = [
    'General Checkup',
    'Specialist Consultation',
    'Follow-up Visit',
    'Therapy / Rehab',
    'Blood Test / Lab',
    'Surgery / Procedure',
    'Other'
  ];

  List<String> _previousDoctors = [];
  List<String> _previousLocations = [];

  @override
  void initState() {
    super.initState();
    _appointmentTitleController.text = _selectedVisitReason;
    _fetchPreviousAppointmentData();
  }

  Future<void> _fetchPreviousAppointmentData() async {
    try {
      final suggestions = await ref
          .read(appointmentRepositoryProvider)
          .fetchSuggestions(widget.userId);

      if (mounted) {
        setState(() {
          _previousDoctors = suggestions.doctorNames;
          _previousLocations = suggestions.locations;
        });
      }
    } catch (e) {
      debugPrint("Error fetching past appointment data: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageValueController.dispose();
    _instructionsController.dispose();
    _intervalController.dispose();
    _appointmentTitleController.dispose();
    _doctorNameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _openMedicationTimePicker() {
    showMedicationTimePicker(
      context,
      initialTime: _selectedTime,
      onTimeSelected: (time) => setState(() => _selectedTime = time),
    );
  }

  void _openAppointmentDateTimePicker() {
    showAppointmentDatePicker(
      context,
      initialDateTime: _selectedDateTime,
      onDateSelected: (date) {
        // No setState here — matches the original exactly: picking a date
        // doesn't itself trigger a rebuild, it just stages the value and
        // immediately chains into the time picker, which does.
        _selectedDateTime = date;
        showMedicationTimePicker(
          context,
          initialTime: TimeOfDay.fromDateTime(date),
          onTimeSelected: (time) {
            setState(() {
              _selectedDateTime = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            });
          },
        );
      },
    );
  }

  // ===========================================================================
  // 💾 FIRESTORE DISPATCH ENGINE
  // ===========================================================================
  Future<void> _submitCareForm() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_selectedSegmentIndex == 1) {
      final error = const ValidateAppointmentRequest().call(_selectedDateTime, DateTime.now());
      if (error == AppointmentValidationError.missingDateTime) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an appointment date and time.'), backgroundColor: Colors.red),
        );
        return;
      }
      if (error == AppointmentValidationError.dateTimeInPast) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointments cannot be scheduled in the past. Please select a future time.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (_selectedSegmentIndex == 0) {
        final request = MedicationScheduleRequest(
          name: _nameController.text.trim(),
          dosageValue: _dosageValueController.text,
          dosageUnit: _selectedDosageUnit,
          frequencyType: _selectedFreqType,
          frequencyNumber: _selectedFreqNumber,
          intervalHours: _selectedFreqType == 'Hour(s) (Every X hours)'
              ? int.parse(_intervalController.text.trim())
              : null,
          initialTime: ScheduleTime(hour: _selectedTime.hour, minute: _selectedTime.minute),
          instructions: _instructionsController.text.trim(),
        );

        final plan = ref.read(buildMedicationSchedulePlanProvider).call(request, DateTime.now());

        final savedSlotsCount = await ref
            .read(medicationScheduleRepositoryProvider)
            .createScheduleSlots(
              userId: widget.userId,
              medicationName: request.name,
              plan: plan,
              instructions: request.instructions,
            );

        if (!mounted) return;
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(savedSlotsCount > 0
              ? 'Medication schedule successfully logged ($savedSlotsCount future active slots created)!'
              : 'Passed slots skipped! First doses will generate on tomorrow\'s tracking cycle.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await ref.read(appointmentRepositoryProvider).createAppointment(
              widget.userId,
              AppointmentRequest(
                title: _selectedVisitReason,
                doctorName: _doctorNameController.text.trim(),
                location: _locationController.text.trim(),
                dateTime: _selectedDateTime!,
              ),
            );

        if (!mounted) return;
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical appointment successfully booked!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to persist record parameters: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hideNumberPicker = _selectedFreqType == 'Once daily (QD)' ||
                                  _selectedFreqType == 'Hour(s) (Every X hours)' ||
                                  _selectedFreqType == 'As needed (PRN)' ||
                                  _selectedFreqType == 'Immediately (STAT)';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _selectedSegmentIndex == 0 ? 'Add New Medication' : 'Schedule Medical Care',
          style: GoogleFonts.inter(color: const Color(0xFF1E3A8A), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 🚀 HIGH-FIDELITY TOP SELECTION SEGMENT CAPSULE BAR
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Container(
              height: 56,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentButton(
                    isSelected: _selectedSegmentIndex == 0,
                    label: 'Medication',
                    icon: LucideIcons.pill,
                    activeColor: const Color(0xFF0058BC),
                    onTap: () => setState(() => _selectedSegmentIndex = 0),
                  ),
                  SegmentButton(
                    isSelected: _selectedSegmentIndex == 1,
                    label: 'Doctor Appointment',
                    icon: LucideIcons.calendar,
                    activeColor: const Color(0xFF8E24AA),
                    onTap: () => setState(() => _selectedSegmentIndex = 1),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _selectedSegmentIndex == 0
                        ? _buildAdvancedMedicationForm(hideNumberPicker)
                        : _buildClinicalAppointmentForm(),

                    const SizedBox(height: 24),

                    ActionSubmitButton(
                      label: _selectedSegmentIndex == 0 ? 'Create Medication Schedule' : 'Book Appointment Slot',
                      themeAccentColor: _selectedSegmentIndex == 0 ? const Color(0xFF0058BC) : const Color(0xFF8E24AA),
                      onSubmit: _submitCareForm,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 💊 ADVANCED FORM UI COMPONENTS
  // ===========================================================================
  Widget _buildAdvancedMedicationForm(bool hideNumberPicker) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Set up a new routine entry tracking instance for SynchroM.', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 24),
        GlassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CleanFormField(
                label: 'Medication Name',
                controller: _nameController,
                hint: 'e.g., Penicillin',
                validator: (val) => val == null || val.isEmpty ? 'Please enter a medication name' : null,
              ),

              Text('Dosage Strength', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _dosageValueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (double.tryParse(val) == null) return 'Invalid number';
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'e.g., 500',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red)),
                        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDosageUnit,
                      icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.black45),
                      items: _dosageUnits.map((unit) => DropdownMenuItem(value: unit, child: Text(unit, style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (val) => setState(() => _selectedDosageUnit = val!),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text('Intake Frequency', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (!hideNumberPicker) ...[
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedFreqNumber,
                        icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.black45),
                        items: _freqNumbers.map((value) => DropdownMenuItem(value: value, child: Text(value.toString()))).toList(),
                        onChanged: (val) => setState(() => _selectedFreqNumber = val!),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedFreqType,
                      icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.black45),
                      items: _freqTypes.map((type) => DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() {
                        _selectedFreqType = val!;
                        if (hideNumberPicker) _selectedFreqNumber = 1;
                      }),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_selectedFreqType == 'Hour(s) (Every X hours)') ...[
                CleanFormField(
                  label: 'Interval Between Doses (Hours)',
                  controller: _intervalController,
                  hint: 'e.g., 4',
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Please supply the intake interval hour span';
                    final int? hourlyNum = int.tryParse(val);
                    if (hourlyNum == null || hourlyNum <= 0 || hourlyNum > 24) {
                      return 'Please enter a valid hour interval constraint (1-24)';
                    }
                    return null;
                  },
                ),
              ],

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Initial Anchor Reminder Time', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: TextEditingController(text: _selectedTime.format(context)),
                    readOnly: true,
                    onTap: _openMedicationTimePicker,
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Select Time',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                      suffixIcon: const Icon(LucideIcons.clock, color: Colors.black45, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),

              CleanFormField(
                label: 'Special Instructions (Optional)',
                controller: _instructionsController,
                hint: 'e.g., Take after food with water',
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 🩺 CLINICAL FORM UI COMPONENTS
  // ===========================================================================
  Widget _buildClinicalAppointmentForm() {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 1. REASON DROPDOWN
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reason for Visit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedVisitReason,
                icon: const Icon(LucideIcons.chevronDown, size: 18, color: Colors.black45),
                items: _visitReasons.map((reason) => DropdownMenuItem(value: reason, child: Text(reason, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedVisitReason = val!;
                    _appointmentTitleController.text = val;
                  });
                },
                validator: (val) => val == null || val.isEmpty ? 'Reason is required' : null,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade300)),
                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade400)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),

          // 2. DOCTOR AUTOCOMPLETE
          AutocompleteFormField(
            label: 'Doctor Name / Specialist',
            controller: _doctorNameController,
            hint: 'Dr. Sarah Jenkins',
            suggestions: _previousDoctors,
            validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a doctor name' : null,
          ),

          // 3. LOCATION AUTOCOMPLETE WITH LOCAL MAP API TRIGGER
          AutocompleteFormField(
            label: 'Clinic / Hospital Location',
            controller: _locationController,
            hint: 'St. Mary\'s Clinic - North Wing',
            suggestions: _previousLocations,
            validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a location' : null,
            onMapIconTap: () => showClinicMapPicker(
              context,
              onLocationSelected: (location) => setState(() => _locationController.text = location),
            ),
          ),

          // 4. CUSTOM CALENDAR & TIME LAUNCHER
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appointment Calendar Window', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: TextEditingController(
                    text: _selectedDateTime == null ? '' : DateFormat('MMM dd, yyyy - hh:mm AM').format(_selectedDateTime!)
                  ),
                  readOnly: true,
                  onTap: _openAppointmentDateTimePicker,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Select Consultation Date & Time',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade300)),
                    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade400)),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: const Icon(LucideIcons.calendarDays, color: Color(0xFF8E24AA), size: 20),
                  ),
                  validator: (val) => _selectedDateTime == null ? 'Please select a date and time' : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
