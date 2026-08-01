// lib/features/caregiver_dashboard/presentation/screens/caregiver_settings_screen.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; // Handles gallery/camera selection
import 'package:crop_your_image/crop_your_image.dart';

import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/providers/user_role_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/patient_profile_controller.dart';
import '../../../profile/presentation/providers/linked_caregivers_provider.dart';
import '../../../system_health/presentation/providers/system_health_providers.dart';
import '../providers/linked_patients_provider.dart';
import '../widgets/link_patient_dialog.dart';

/// Caregiver-specific settings screen with profile editing capabilities.
class CaregiverSettingsScreen extends ConsumerStatefulWidget {
  const CaregiverSettingsScreen({super.key});

  @override
  ConsumerState<CaregiverSettingsScreen> createState() =>
      _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState
    extends ConsumerState<CaregiverSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _ageController;
  String _selectedGender = 'Male';
  String _selectedBloodType = 'O+';
  String _avatarUrl = '';

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isDirty = false;
  Map<String, dynamic> _originalData = {};

  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];
  static const List<String> _bloodTypeOptions = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _ageController = TextEditingController();

    _fullNameController.addListener(_checkDirty);
    _emailController.addListener(_checkDirty);
    _phoneController.addListener(_checkDirty);
    _ageController.addListener(_checkDirty);

    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _checkDirty() {
    final dirty = _fullNameController.text != (_originalData['fullName'] ?? '') ||
        _emailController.text != (_originalData['email'] ?? '') ||
        _phoneController.text != (_originalData['phone'] ?? '') ||
        _ageController.text != ((_originalData['age'] ?? '').toString()) ||
        _selectedGender != (_originalData['gender'] ?? 'Male') ||
        _selectedBloodType != (_originalData['bloodType'] ?? 'O+');
    if (dirty != _isDirty) setState(() => _isDirty = dirty);
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};

      setState(() {
        _originalData = data;
        _fullNameController.text = data['fullName'] ?? data['name'] ?? '';
        _emailController.text = data['email'] ?? user.email ?? '';
        _phoneController.text = data['phone'] ?? data['phoneNumber'] ?? '';
        _ageController.text = (data['age'] ?? '').toString();
        _selectedGender = data['gender'] ?? 'Male';
        _selectedBloodType = data['bloodType'] ?? 'O+';
        _avatarUrl = data['avatarUrl'] ?? '';
        _isLoading = false;
        _isDirty = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// Mirrors `SettingsScreen._pickAndUploadAvatar` on the patient side: pick
  /// -> crop to a circle -> encode as a base64 data URL -> persist on the
  /// caregiver's own `users/{uid}` document under `avatarUrl`.
  ///
  /// That same field is what `LinkedCaregiverSummary.avatarUrl` already
  /// reads (see `linked_caregivers_repository_impl.dart`), so once this is
  /// saved, it's what shows up wherever the app displays "your linked
  /// caregiver" on the patient's side — home screen and profile page alike
  /// — the next time that patient's app fetches it.
  Future<void> _pickAndUploadAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final Uint8List rawBytes = await pickedFile.readAsBytes();

    if (!mounted) return;
    final CropController cropController = CropController();
    Uint8List? croppedResultBytes;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Adjust Profile Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

    setState(() => _isUploadingAvatar = true);

    try {
      final String base64Image = base64Encode(croppedResultBytes!);
      final String dataUrl = 'data:image/jpeg;base64,$base64Image';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'avatarUrl': dataUrl}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _avatarUrl = dataUrl;
        _originalData = {..._originalData, 'avatarUrl': dataUrl};
        _isUploadingAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo updated successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'gender': _selectedGender,
        'bloodType': _selectedBloodType,
      }, SetOptions(merge: true));

      _originalData = {
        ..._originalData,
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'gender': _selectedGender,
        'bloodType': _selectedBloodType,
      };

      setState(() {
        _isSaving = false;
        _isDirty = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
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
        title: const Text('Log Out',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey.shade700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ref.invalidate(currentUserRoleProvider);
    ref.invalidate(patientProfileProvider);
    ref.invalidate(systemHealthProvider);
    ref.invalidate(linkedPatientsProvider);
    ref.invalidate(linkedCaregiversProvider);

    await ref.read(logoutProvider).call();

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(linkedPatientsProvider);

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 80.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Profile Editing Section
                    _buildSectionHeader('PERSONAL INFORMATION'),
                    GlassPanel(
                      padding: const EdgeInsets.all(20.0),
                      borderRadius: 20.0,
                      child: Column(
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 40,
                                      backgroundColor: const Color(0xFFE0F2FE),
                                      backgroundImage: _avatarUrl.isNotEmpty
                                          ? NetworkImage(_avatarUrl)
                                          : null,
                                      child: _avatarUrl.isEmpty
                                          ? Text(
                                              _fullNameController.text.isNotEmpty
                                                  ? _fullNameController.text[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0256B4),
                                              ),
                                            )
                                          : null,
                                    ),
                                    if (_isUploadingAvatar)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black38,
                                          ),
                                          child: const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: -2,
                                      right: -2,
                                      child: GestureDetector(
                                        onTap: _isUploadingAvatar
                                            ? null
                                            : _pickAndUploadAvatar,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0256B4),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(
                                            LucideIcons.camera,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _isUploadingAvatar
                                      ? null
                                      : _pickAndUploadAvatar,
                                  child: const Text(
                                    'Change Photo',
                                    style: TextStyle(
                                      color: Color(0xFF1D4ED8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8E24AA)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'CAREGIVER',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF8E24AA),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            label: 'Full Name',
                            controller: _fullNameController,
                            icon: LucideIcons.user,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            label: 'Email Address',
                            controller: _emailController,
                            icon: LucideIcons.mail,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            label: 'Phone Number',
                            controller: _phoneController,
                            icon: LucideIcons.phone,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            label: 'Age',
                            controller: _ageController,
                            icon: LucideIcons.calendar,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 14),
                          _buildDropdown(
                            label: 'Gender',
                            value: _selectedGender,
                            items: _genderOptions,
                            icon: LucideIcons.users,
                            onChanged: (val) {
                              setState(() => _selectedGender = val!);
                              _checkDirty();
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildDropdown(
                            label: 'Blood Type',
                            value: _selectedBloodType,
                            items: _bloodTypeOptions,
                            icon: LucideIcons.heart,
                            onChanged: (val) {
                              setState(() => _selectedBloodType = val!);
                              _checkDirty();
                            },
                          ),
                          if (_isDirty) ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveProfile,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(LucideIcons.save,
                                        size: 16, color: Colors.white),
                                label: Text(
                                  _isSaving ? 'Saving...' : 'Save Changes',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Linked Patients Card
                    _buildSectionHeader('LINKED PATIENTS'),
                    GlassPanel(
                      padding: const EdgeInsets.all(16.0),
                      borderRadius: 20.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patients Under Your Care',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Patients who have linked you via an invitation code.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          patientsAsync.when(
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
                                'Failed to load linked patients: $err',
                                style: TextStyle(
                                    color: Colors.red.shade700, fontSize: 12),
                              ),
                            ),
                            data: (patients) {
                              if (patients.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Text(
                                    'No patients linked to your account yet.',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14),
                                  ),
                                );
                              }
                              return Column(
                                children: patients.map((patient) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundImage:
                                              NetworkImage(patient.avatarUrl),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            patient.fullName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Linked',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => showLinkPatientDialog(context),
                              icon: const Icon(LucideIcons.userPlus, size: 18),
                              label: const Text('Link New Patient'),
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
                        icon: const Icon(LucideIcons.logOut,
                            size: 18, color: Colors.red),
                        label: const Text(
                          'Log Out',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0256B4)),
        filled: true,
        fillColor: const Color(0xFFF8F9FE),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0256B4)),
        filled: true,
        fillColor: const Color(0xFFF8F9FE),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
      ),
    );
  }
}

