// lib/features/auth/presentation/screens/register.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_controller.dart';
import '../widgets/portal_selection_card.dart';
import '../../../../core/widgets/glass_panel.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();

  String? _selectedGender;
  String? _selectedBloodType;
  bool _isPasswordHidden = true; // State for viewing/hiding password

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = ref.watch(selectedRoleProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFfaf9fe),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text('Create Account', style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),

              // ==================== 1. ROLE SELECTION ====================
              GlassPanel(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      PortalSelectionCard(
                        title: 'I am a Patient',
                        description: 'Manage your health schedule.',
                        icon: LucideIcons.user,
                        themeColor: const Color(0xFF1E88E5),
                        buttonText: 'Select Patient',
                        isSelected: selectedRole == UserRole.patient,
                        onTap: () => ref.read(selectedRoleProvider.notifier).state = UserRole.patient,
                      ),
                      const SizedBox(height: 16),
                      PortalSelectionCard(
                        title: 'I am a Caregiver',
                        description: 'Monitor your patients.',
                        icon: LucideIcons.briefcase,
                        themeColor: const Color(0xFF8E24AA),
                        buttonText: 'Select Caregiver',
                        isSelected: selectedRole == UserRole.caregiver,
                        onTap: () => ref.read(selectedRoleProvider.notifier).state = UserRole.caregiver,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48), // Generous token layout spacing gutter

              // ==================== 2. INPUT FIELDS ====================
              _buildInput(controller: _nameController, label: 'Full Name', icon: LucideIcons.user),
              const SizedBox(height: 16),
              _buildInput(controller: _emailController, label: 'Email Address', icon: LucideIcons.mail),
              const SizedBox(height: 16),

              // Password input fields with dynamic active visibility sub-button toggle asset
              _buildInput(
                controller: _passwordController,
                label: 'Password',
                icon: LucideIcons.lock,
                obscure: _isPasswordHidden,
                suffix: IconButton(
                  icon: Icon(_isPasswordHidden ? LucideIcons.eyeOff : LucideIcons.eye, color: const Color(0xFF414755), size: 20),
                  onPressed: () => setState(() => _isPasswordHidden = !_isPasswordHidden),
                ),
              ),
              const SizedBox(height: 16),

              // Responsive Metrics Fields Area
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.inter(),
                      decoration: InputDecoration(
                        labelText: 'Age (Optional)',
                        labelStyle: GoogleFonts.inter(color: const Color(0xFF414755)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Blood Dropdown Configuration
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedBloodType,
                      hint: Text('Blood Type', style: GoogleFonts.inter(color: const Color(0xFF414755))),
                      icon: const Icon(LucideIcons.chevronDown, color: Color(0xFF414755)),
                      iconSize: 20,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                          .map((type) => DropdownMenuItem(value: type, child: Text(type, style: GoogleFonts.inter())))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedBloodType = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gender Dropdown Configuration
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                hint: Text('Gender (Optional)', style: GoogleFonts.inter(color: const Color(0xFF414755))),
                icon: const Icon(LucideIcons.chevronDown, color: Color(0xFF414755)),
                iconSize: 20,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: ['Male', 'Female']
                    .map((gender) => DropdownMenuItem(value: gender, child: Text(gender, style: GoogleFonts.inter())))
                    .toList(),
                onChanged: (value) => setState(() => _selectedGender = value),
              ),

              const SizedBox(height: 32),

              // ==================== 3. ACTIONS ====================
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedRole == UserRole.none) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a role!')));
                      return;
                    }

                    await ref.read(authProvider.notifier).register(
                      _emailController.text.trim(),
                      _passwordController.text.trim(),
                      selectedRole,
                      _nameController.text.trim(),
                      age: _ageController.text.trim(),
                      gender: _selectedGender ?? 'Not Specified',
                      bloodType: _selectedBloodType ?? 'Unknown',
                    );

                 if (ref.read(authProvider).errorMessage == null) {
                    if (!context.mounted) return; // ✅ Prevents using BuildContext across async gaps
                    context.go('/login');
                  }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0058bc),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Complete Registration', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF414755)),
                child: Text('Already have an account? Sign In', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({required TextEditingController controller, required String label, required IconData icon, bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(color: const Color(0xFF1a1b1f)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: const Color(0xFF414755)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: const Color(0xFF414755), size: 20),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
