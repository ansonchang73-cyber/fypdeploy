// lib/features/caregiver_dashboard/presentation/widgets/link_patient_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/linked_patients_provider.dart';

void showLinkPatientDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const _LinkPatientDialog(),
  );
}

class _LinkPatientDialog extends ConsumerStatefulWidget {
  const _LinkPatientDialog();

  @override
  ConsumerState<_LinkPatientDialog> createState() => _LinkPatientDialogState();
}

class _LinkPatientDialogState extends ConsumerState<_LinkPatientDialog> {
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a code.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(linkCaregiverToPatientProvider).call(
            invitationCode: code,
            caregiverUserId: user.uid,
          );

      // The list is a FutureProvider — it won't know a new patient exists
      // until something tells it to refetch.
      ref.invalidate(linkedPatientsProvider);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient linked successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyMessageFor(e);
        _isSubmitting = false;
      });
    }
  }

  String _friendlyMessageFor(Object error) {
    final raw = error.toString();
    if (raw.contains('INVALID_CODE')) {
      return "That code doesn't match any active invitation. Double-check it and try again.";
    }
    if (raw.contains('CODE_USED')) {
      return 'That code has already been used.';
    }
    if (raw.contains('CODE_EXPIRED')) {
      return 'That code has expired — ask the patient to generate a new one from their Settings screen.';
    }
    return 'Something went wrong: $raw';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF0058BC).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(LucideIcons.link, color: Color(0xFF0058BC), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Link a Patient', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A8A))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the invitation code your patient generated from their Settings screen.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600, height: 1.3),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              autofocus: true,
              textAlign: TextAlign.center,
              // Codes are a case-sensitive slice of a Firestore document ID
              // (see GenerateInvitationCode / SharedAccessRepositoryImpl),
              // so no auto-uppercasing here — that would break valid codes.
              inputFormatters: [LengthLimitingTextInputFormatter(6)],
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4, color: const Color(0xFF1E3A8A)),
              decoration: InputDecoration(
                hintText: 'CODE',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade300, letterSpacing: 4),
                filled: true,
                fillColor: const Color(0xFFF8F9FE),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0058BC), width: 2)),
              ),
              onSubmitted: (_) => _isSubmitting ? null : _submit(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0058BC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Link', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
