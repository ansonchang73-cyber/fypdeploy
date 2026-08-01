// lib/features/profile/presentation/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/linked_caregivers_provider.dart';
import '../providers/patient_profile_controller.dart';
import '../providers/profile_providers.dart';
import 'package:image_picker/image_picker.dart'; // Handles gallery/camera selection
import 'package:crop_your_image/crop_your_image.dart';
import 'dart:convert';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/providers/user_role_provider.dart';
import '../../../system_health/presentation/providers/system_health_providers.dart';
import '../../../caregiver_dashboard/presentation/providers/linked_patients_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal Profile Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _ageController;

  // Health Preferences Controllers
  late TextEditingController _doctorController;
  late TextEditingController _doctorContactController;
  late TextEditingController _allergiesController;

  bool _isInitialized = false;
  String? _selectedBloodType;
  String? _selectedGender;

  // Reference properties to track original database snapshot states
  dynamic _originalPatientState;
  bool _isDirty = false;
  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _ageController = TextEditingController();
    _allergiesController = TextEditingController();
    _doctorController = TextEditingController();
    _doctorContactController = TextEditingController();

    // Attach listeners to instantly detect text mutations
    _fullNameController.addListener(_checkIfDirty);
    _emailController.addListener(_checkIfDirty);
    _phoneController.addListener(_checkIfDirty);
    _ageController.addListener(_checkIfDirty);
    _doctorController.addListener(_checkIfDirty);
    _doctorContactController.addListener(_checkIfDirty);
    _allergiesController.addListener(_checkIfDirty);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _doctorController.dispose();
    _doctorContactController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  void _initializeFields(dynamic patient) {
    if (!_isInitialized) {
      _originalPatientState = patient;

      _fullNameController.text = patient.fullName ?? patient.name ?? '';
      _emailController.text = patient.email ?? '';
      // `phone` is now a real, always-present field on PatientProfile —
      // no more dynamic-cast/try-catch workaround needed here.
      _phoneController.text = patient.phone;

      _ageController.text = patient.age > 0 ? patient.age.toString() : '';
      _selectedGender = _genders.contains(patient.gender)
          ? patient.gender
          : null;

      const allowedBloodTypes = [
        'Unknown',
        'A+',
        'A-',
        'B+',
        'B-',
        'AB+',
        'AB-',
        'O+',
        'O-',
      ];

      if (allowedBloodTypes.contains(patient.bloodType)) {
        _selectedBloodType = patient.bloodType;
      } else {
        _selectedBloodType = 'Unknown';
      }

      _doctorController.text = patient.primaryDoctor ?? '';
      _doctorContactController.text = patient.doctorContact ?? '';
      _allergiesController.text = patient.allergies ?? '';

      _isInitialized = true;
    }
  }

  /// Evaluates if any UI field deviates from the loaded database snapshot state
  void _checkIfDirty() {
    if (!_isInitialized || _originalPatientState == null) return;

    final originalAgeStr = _originalPatientState.age > 0
        ? _originalPatientState.age.toString()
        : '';
    final originalFullName =
        _originalPatientState.fullName ?? _originalPatientState.name ?? '';
    final String originalPhone = _originalPatientState.phone;

    final hasChanges =
        _fullNameController.text != originalFullName ||
        _emailController.text != _originalPatientState.email ||
        _phoneController.text != originalPhone ||
        _ageController.text != originalAgeStr ||
        _selectedBloodType != _originalPatientState.bloodType ||
        _doctorController.text != _originalPatientState.primaryDoctor ||
        _doctorContactController.text != _originalPatientState.doctorContact ||
        _allergiesController.text != _originalPatientState.allergies ||
        _selectedGender != _originalPatientState.gender;

    if (hasChanges != _isDirty) {
      setState(() => _isDirty = hasChanges);
    }
  }

  /// UI builds the update payload from form fields, then hands it to the
  /// controller — no Firestore reference here at all.
  Future<void> _saveProfileChanges(String userId) async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));

    final data = {
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'age': int.tryParse(_ageController.text.trim()) ?? 0,
      'bloodType': _selectedBloodType,
      'primaryDoctor': _doctorController.text.trim(),
      'doctorContact': _doctorContactController.text.trim(),
      'allergies': _allergiesController.text.trim(),
      'gender': _selectedGender,
    };

    await ref.read(patientProfileProvider.notifier).updateProfile(data);

    if (mounted) Navigator.pop(context); // Close loading
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    setState(() => _isDirty = false);
  }

  Future<void> _pickAndUploadAvatar(String userId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;
    final Uint8List rawBytes = await pickedFile.readAsBytes();

    if (!mounted) return;
    final CropController cropController = CropController();
    Uint8List? croppedResultBytes;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Adjust Profile Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            height: 400,
            child: Crop(
              image: rawBytes,
              controller: cropController,
              aspectRatio: 1.0,
              withCircleUi: true,
              interactive: true,
              onCropped: (result) {
                if (result is CropSuccess) {
                      croppedResultBytes = result.croppedImage;
                    }
                  },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0256B4)),
              onPressed: () {
                cropController.crop();
                Future.delayed(const Duration(milliseconds: 300), () {
                  Navigator.pop(context);
                });
              },
              child: const Text('Apply Crop', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (croppedResultBytes == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final String base64Image = base64Encode(croppedResultBytes!);
      final String dataUrl = 'data:image/jpeg;base64,$base64Image';

      await ref.read(patientProfileProvider.notifier).updateAvatar(dataUrl);

      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully!'), backgroundColor: Colors.green),
      );

      setState(() {
        _isInitialized = false;
      });
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile photo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _generateAndShowInviteCode(String elderlyUserId) async {
    if (elderlyUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: User account details not fully loaded.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final invitation = await ref
          .read(generateInvitationCodeProvider)
          .call(elderlyUserId: elderlyUserId);
      final String code = invitation.code;
      final DateTime expiresAt = invitation.expiresAt;

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          backgroundColor: Colors.white,
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Caregiver Invitation Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share this secure code with your caregiver. Only a caregiver with this unique link can access your data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.copy,
                            color: Color(0xFF15803D),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invitation code copied!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Valid for 10 minutes (Expires at ${expiresAt.hour.toString().padLeft(2, '0')}:${expiresAt.minute.toString().padLeft(2, '0')})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to establish invitation parameters: $e'),
          ),
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Invalidate all user-dependent providers before signing out so that
    // a subsequent login with a different account gets fresh data.
    ref.invalidate(currentUserRoleProvider);
    ref.invalidate(patientProfileProvider);
    ref.invalidate(systemHealthProvider);
    ref.invalidate(linkedPatientsProvider);
    ref.invalidate(linkedCaregiversProvider);

    await ref.read(logoutProvider).call();

    if (!mounted) return;

    // `SettingsScreen` was reached via an imperative `Navigator.push`, not
    // a go_router route — it sits on top of go_router's own page for
    // `/home`. `context.go()` doesn't reliably clear routes that were
    // pushed imperatively like that, so without this, the pushed
    // `SettingsScreen` (and whatever tab was selected underneath it) can
    // linger and resurface on the next login. Popping back to root first
    // guarantees a clean slate before handing off to go_router.
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(patientProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E3A8A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: _isDirty
          ? profileAsync.maybeWhen(
              data: (patient) => FloatingActionButton.extended(
                onPressed: () => _saveProfileChanges(patient.id),
                backgroundColor: const Color(0xFF0256B4),
                icon: const Icon(
                  LucideIcons.save,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              orElse: () => null,
            )
          : null,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Failed to load settings data: $err')),
        data: (patient) {
          _initializeFields(patient);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 80.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Personal Profile Card
                  _buildSectionHeader('PERSONAL PROFILE'),
                  _buildSectionCard(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFFE0F2FE),
                            backgroundImage: patient.avatarUrl.isNotEmpty
                                ? NetworkImage(patient.avatarUrl)
                                : null,
                            child: patient.avatarUrl.isEmpty
                                ? const Icon(
                                    LucideIcons.user,
                                    size: 40,
                                    color: Color(0xFF0256B4),
                                  )
                                : null,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _pickAndUploadAvatar(patient.id),
                          child: const Text(
                            'Change Photo',
                            style: TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(
                          label: 'Full Name',
                          controller: _fullNameController,
                        ),
                        _buildTextField(
                          label: 'Email Address',
                          controller: _emailController,
                        ),
                        _buildTextField(
                          label: 'Phone Number',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Phone number field cannot be blank';
                            }
                            final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
                            if (!phoneRegex.hasMatch(value.trim())) {
                              return 'Please enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        _buildTextField(
                          label: 'Age',
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Age field cannot be blank';
                            }
                            final ageNum = int.tryParse(value.trim());
                            if (ageNum == null) {
                              return 'Age must be a valid number';
                            }
                            if (ageNum <= 0 || ageNum > 120) {
                              return 'Please enter a realistic age (1-120)';
                            }
                            return null;
                          },
                        ),
                        _buildDropdownField(
                          label: 'Gender Designation',
                          value: _selectedGender,
                          items: _genders,
                          onChanged: (val) {
                            setState(() {
                              _selectedGender = val;
                              _checkIfDirty();
                            });
                          },
                        ),
                        const Divider(
                          height: 24,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                        _buildDropdownField(
                          label: 'Blood Type',
                          value: _selectedBloodType,
                          items: const [
                            'Unknown',
                            'A+',
                            'A-',
                            'B+',
                            'B-',
                            'AB+',
                            'AB-',
                            'O+',
                            'O-',
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedBloodType = val;
                                _checkIfDirty();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Care Circle Card
                  _buildSectionHeader('CARE CIRCLE'),
                  _buildSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage Caregivers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Authorized members who can view your health data.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Consumer(
                          builder: (context, ref, _) {
                            final linkedCaregiversAsync = ref.watch(linkedCaregiversProvider);

                            return linkedCaregiversAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              error: (err, stack) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'Failed to load linked caregivers: $err',
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                ),
                              ),
                              data: (caregivers) {
                                if (caregivers.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Text(
                                      'No active caregiver linked to account.',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                    ),
                                  );
                                }

                                return Column(
                                  children: caregivers.map((caregiver) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        children: [
                                          CircleAvatar(radius: 18, backgroundImage: NetworkImage(caregiver.avatarUrl)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              caregiver.fullName,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Linked',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _generateAndShowInviteCode(patient.id),
                            icon: const Icon(LucideIcons.userPlus, size: 18),
                            label: const Text('Invite New Caregiver'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0256B4),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Log Out
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _confirmLogout,
                      icon: const Icon(LucideIcons.logOut, size: 18, color: Colors.red),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.red.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.black45,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return GlassPanel(
      padding: const EdgeInsets.all(16.0),
      borderRadius: 20.0,
      magnification: 1.00,
      child: child,
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            errorStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF3B82F6)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          items: items
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          icon: const Icon(LucideIcons.chevronsUpDown, size: 18),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
