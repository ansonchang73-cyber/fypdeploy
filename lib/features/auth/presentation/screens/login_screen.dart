// lib/features/auth/presentation/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_controller.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/providers/user_role_provider.dart';
import '../../../../core/utils/validators.dart';
import '../../../profile/presentation/providers/patient_profile_controller.dart';
import '../../../profile/presentation/providers/linked_caregivers_provider.dart';
import '../../../system_health/presentation/providers/system_health_providers.dart';
import '../../../caregiver_dashboard/presentation/providers/linked_patients_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isPasswordHidden = true; // State for viewing/hiding password
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Once the user has tried to submit once, keep validating live as they
    // fix each field instead of only re-checking on the next tap.
    setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);

    // Dismiss the keyboard so the error banner (if any) is visible.
    FocusManager.instance.primaryFocus?.unfocus();

    if (!_formKey.currentState!.validate()) return;

    final authNotifier = ref.read(authProvider.notifier);
    await authNotifier.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      UserRole.none,
    );

    if (ref.read(authProvider).errorMessage == null) {
      if (!context.mounted) return;
      // Invalidate all user-dependent providers so the
      // new user's data is fetched fresh.
      ref.invalidate(currentUserRoleProvider);
      ref.invalidate(patientProfileProvider);
      ref.invalidate(systemHealthProvider);
      ref.invalidate(linkedPatientsProvider);
      ref.invalidate(linkedCaregiversProvider);
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFfaf9fe),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: GlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SynchroM',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1a1b1f),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Inline error banner for auth failures (wrong
                    // credentials, network issues, etc.)
                    if (authState.errorMessage != null) ...[
                      _buildErrorBanner(authState.errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // Email Input
                    _buildInput(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: LucideIcons.mail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: Validators.validateEmail,
                      onFieldSubmitted: (_) => FocusScope.of(
                        context,
                      ).requestFocus(_passwordFocusNode),
                    ),
                    const SizedBox(height: 16),

                    // Password Input with dynamic view toggle eye icon
                    _buildInput(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      label: 'Password',
                      icon: LucideIcons.lock,
                      obscure: _isPasswordHidden,
                      textInputAction: TextInputAction.done,
                      validator: Validators.validatePassword,
                      // Pressing Enter/Return on the keyboard (physical or
                      // on-screen) while this field is focused submits the
                      // form, same as tapping "Sign In".
                      onFieldSubmitted: (_) => _handleLogin(),
                      suffix: IconButton(
                        icon: Icon(
                          _isPasswordHidden
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          color: const Color(0xFF414755),
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordHidden = !_isPasswordHidden,
                        ),
                      ),
                    ),

                    // Forgot Password Link Row
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // to do: Implement forgot password reset flow link
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password reset link coming soon!'),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF414755),
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0058bc),
                          disabledBackgroundColor: const Color(
                            0xFF0058bc,
                          ).withValues(alpha: 0.6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Sign In',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () => context.push('/register'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF414755),
                      ),
                      child: Text(
                        'Need an account? Register',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: Color(0xFFDC2626), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: label == 'Password' ? [AutofillHints.password] : [AutofillHints.email],
      style: GoogleFonts.inter(color: const Color(0xFF1a1b1f)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: const Color(0xFF414755)),
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF0058bc), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.6),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF414755), size: 20),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
