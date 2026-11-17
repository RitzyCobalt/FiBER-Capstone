import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

const _brand = Color(0xFF00BCD4);

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey< FormState >();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmNewPasswordCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  AccountProfile? _profile;
  String? _loadError;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _obscureNew = true;
  bool _obscureConfirmNew = true;
  bool _obscureCurrent = true;

  // Section 1.1: Email Verification & 5-Minute OTP Expiration + Resend Cooldown state
  bool _isEmailVerified = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  String? _otpStatusMessage;
  bool _otpStatusIsError = false;
  String? _fallbackOtpHint;
  int _otpSecondsLeft = 0; // 300s (5 minutes)
  int _resendCooldownSeconds = 0; // 60s cooldown
  Timer? _otpTimer;

  // Base64-encoded thumbnail stored on the user's Firestore document.
  String? _photoBase64;
  Uint8List? _pendingAvatar;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmNewPasswordCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future< void > _sendPasswordChangeOtp() async {
    final targetEmail = (_profile?.email.trim().isNotEmpty == true)
        ? _profile!.email.trim().toLowerCase()
        : _emailCtrl.text.trim().toLowerCase();
    if (targetEmail.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(targetEmail)) {
      setState(() {
        _otpStatusMessage = 'Please enter a valid registered Gmail address.';
        _otpStatusIsError = true;
      });
      _snack('Please enter a valid registered Gmail address.', error: true);
      return;
    }
    if (_resendCooldownSeconds > 0 || _sendingOtp) return;

    setState(() {
      _sendingOtp = true;
      _otpStatusMessage = null;
      _otpStatusIsError = false;
      _fallbackOtpHint = null;
    });

    try {
      final result = await DataService.sendEmailOtp(
        email: targetEmail,
        purpose: 'change_password',
        recipientName: _usernameCtrl.text.trim(),
        uid: AuthService.currentUser?.id,
      );
      if (!mounted) return;

      final deliveredViaHttp = result['deliveredViaHttp'] == true;
      final generatedCode = (result['code'] ?? '').toString();
      final relayNotice = (result['relayNotice'] ?? '').toString();

      _otpTimer?.cancel();
      setState(() {
        _sendingOtp = false;
        _otpSent = true;
        _otpVerified = false;
        _otpCtrl.clear();
        _otpSecondsLeft = 300; // 5 minutes
        _resendCooldownSeconds = 60; // 60 seconds cooldown
        _otpStatusIsError = false;
        if (deliveredViaHttp) {
          _otpStatusMessage =
              '6-digit OTP sent to $targetEmail. Check your Gmail Inbox and Spam/Promotions folder.';
          _fallbackOtpHint = null;
        } else {
          _otpStatusMessage = relayNotice.isNotEmpty
              ? 'Email relay notice ($relayNotice). Use your verification code below:'
              : 'Direct Gmail relay requires first-time activation on this network. Use your generated verification code below:';
          _fallbackOtpHint = generatedCode;
        }
      });

      _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_otpSecondsLeft > 0) _otpSecondsLeft--;
          if (_resendCooldownSeconds > 0) _resendCooldownSeconds--;
          if (_otpSecondsLeft == 0 && !_otpVerified) {
            _otpStatusMessage =
                'Your OTP has expired (5-minute limit). Tap "Resend OTP" to request a new code.';
            _otpStatusIsError = true;
            _fallbackOtpHint = null;
          }
          if (_otpSecondsLeft == 0 && _resendCooldownSeconds == 0) {
            timer.cancel();
          }
        });
      });

      _snack(
        deliveredViaHttp
            ? '📧 6-digit OTP sent to $targetEmail! Valid for 5 minutes.'
            : '📧 Verification OTP generated for $targetEmail (Code: $generatedCode). Valid for 5 minutes.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingOtp = false;
        _otpStatusMessage =
            'Failed to send OTP to $targetEmail. Please check your connection and try again.';
        _otpStatusIsError = true;
      });
      _snack(
        'Failed to send OTP to $targetEmail. Please check your connection and try again.',
        error: true,
      );
    }
  }

  Future< void > _verifyPasswordChangeOtp() async {
    if (_verifyingOtp) return;
    final targetEmail = (_profile?.email.trim().isNotEmpty == true)
        ? _profile!.email.trim().toLowerCase()
        : _emailCtrl.text.trim().toLowerCase();

    if (_otpSecondsLeft <= 0 && _otpSent) {
      const expiredMsg =
          'Your OTP has expired (5-minute limit). Please tap "Resend OTP".';
      setState(() {
        _otpStatusMessage = expiredMsg;
        _otpStatusIsError = true;
      });
      _snack(expiredMsg, error: true);
      return;
    }

    setState(() => _verifyingOtp = true);
    final err = await DataService.verifyEmailOtpAndMarkVerified(
      email: targetEmail,
      purpose: 'change_password',
      enteredCode: _otpCtrl.text,
      uid: AuthService.currentUser?.id,
    );
    if (!mounted) return;
    setState(() => _verifyingOtp = false);

    if (err != null) {
      setState(() {
        _otpStatusMessage = err;
        _otpStatusIsError = true;
      });
      _snack(err, error: true);
      return;
    }

    _otpTimer?.cancel();
    setState(() {
      _otpVerified = true;
      _isEmailVerified = true;
      _fallbackOtpHint = null;
      _otpStatusIsError = false;
      _otpStatusMessage =
          'Email verification completed! Your account ($targetEmail) is now verified.';
    });
    _snack(
      '✅ Email verification completed! Your account is now marked as verified.',
    );
  }

  bool get _emailChanged =>
      _profile != null && _emailCtrl.text.trim() != _profile!.email;
  bool get _passwordChanged => _newPasswordCtrl.text.isNotEmpty;
  bool get _needsCurrentPassword => _emailChanged || _passwordChanged;

  Future< void > _load() async {
    try {
      final profile = await AccountService.loadProfile();
      final verified = await AccountService.checkEmailVerifiedStatus();
      if (!mounted) return;
      _usernameCtrl.text = profile.username;
      _emailCtrl.text = profile.email;
      _newPasswordCtrl.clear();
      _confirmNewPasswordCtrl.clear();
      _currentPasswordCtrl.clear();
      setState(() {
        _profile = profile;
        _isEmailVerified = verified;
        _photoBase64 = profile.photoUrl;
        _pendingAvatar = null;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      debugPrint('Account load error: $e');
      if (!mounted) return;
      setState(() {
        _loadError = e is AccountException
            ? e.message
            : 'Could not load your account. Check your connection.';
        _loading = false;
      });
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar || _saving) return;

    XFile? picked;
    Uint8List? bytes;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (picked == null) return; // User cancelled.
      bytes = await picked.readAsBytes();
    } catch (e) {
      debugPrint('Image picker error: $e');
      _snack(
        'Could not open your photos. Check that FiBER has permission to access them.',
        error: true,
      );
      return;
    }

    final previousBase64 = _photoBase64;
    setState(() {
      _pendingAvatar = bytes; // Show the new picture immediately.
      _uploadingAvatar = true;
    });

    try {
      final encoded = await AccountService.uploadAvatar(bytes);
      if (!mounted) return;
      AuthService.updateCachedProfile(photoUrl: encoded);
      setState(() {
        _photoBase64 = encoded;
        _pendingAvatar = null;
      });
      _snack('Profile picture updated.');
    } on AccountException catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingAvatar = null; // Revert to the previous picture.
        _photoBase64 = previousBase64;
      });
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  String? _validateUsername(String? value) {
    final v = (value ?? '').trim();
    if (v.length < 3) return 'Username must be at least 3 characters.';
    if (v.length > 30) return 'Username must be 30 characters or fewer.';
    return null;
  }

  String? _validateEmail(String? value) {
    final v = (value ?? '').trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  bool get _newPwdValidLen =>
      _newPasswordCtrl.text.length >= 8 && _newPasswordCtrl.text.length <= 20;
  bool get _newPwdHasUpper => RegExp(r'[A-Z]').hasMatch(_newPasswordCtrl.text);
  bool get _newPwdHasLower => RegExp(r'[a-z]').hasMatch(_newPasswordCtrl.text);
  bool get _newPwdHasNumber => RegExp(r'[0-9]').hasMatch(_newPasswordCtrl.text);

  String? _validateNewPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return null; // Optional.
    if (v.length < 8 || v.length > 20) {
      return 'Password must be 8 to 20 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(v) || !RegExp(r'[a-z]').hasMatch(v)) {
      return 'Include both uppercase (A–Z) and lowercase (a–z) letters.';
    }
    if (!RegExp(r'[0-9]').hasMatch(v)) {
      return 'Include at least one number (0–9).';
    }
    return null;
  }

  Widget _buildDynamicPasswordChecklist() {
    Widget item(String label, bool satisfied) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              satisfied
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 15,
              color: satisfied ? Colors.green.shade700 : Colors.blueGrey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: satisfied ? FontWeight.bold : FontWeight.normal,
                  color: satisfied ? Colors.green.shade800 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightBlue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password Requirements:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B3C5D),
            ),
          ),
          const SizedBox(height: 6),
          item('8 to 20 characters', _newPwdValidLen),
          item('At least 1 uppercase letter (A–Z)', _newPwdHasUpper),
          item('At least 1 lowercase letter (a–z)', _newPwdHasLower),
          item('At least 1 number (0–9)', _newPwdHasNumber),
        ],
      ),
    );
  }

  String? _validateConfirmNewPassword(String? value) {
    if (_newPasswordCtrl.text.isEmpty && (value ?? '').isEmpty) return null;
    if ((value ?? '') != _newPasswordCtrl.text) {
      return 'New passwords do not match.';
    }
    return null;
  }

  String? _validateCurrentPassword(String? value) {
    if (_emailChanged && !_otpVerified && (value ?? '').isEmpty) {
      return 'Enter your current password or verify via Gmail OTP.';
    }
    return null;
  }

  Future< void > _save() async {
    if (_saving || _profile == null) return;
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text;
    final usernameChanged = username != _profile!.username;
    final emailChanged = email != _profile!.email;
    final passwordChanged = newPassword.isNotEmpty;

    if (!usernameChanged && !emailChanged && !passwordChanged) {
      _snack('No changes to save.');
      return;
    }

    if ((passwordChanged || emailChanged) && !_otpVerified) {
      _snack(
        'Please complete Step 1 & Step 2 (Send and Verify your 6-digit Gmail OTP) before updating your password.',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (usernameChanged) {
        await AccountService.saveUsername(username);
        AuthService.updateCachedProfile(
          name: username,
          username: username,
        );
      }
      if (_currentPasswordCtrl.text.trim().isNotEmpty &&
          (emailChanged || passwordChanged)) {
        await AccountService.reauthenticate(_currentPasswordCtrl.text);
      }
      if (passwordChanged) {
        try {
          await AccountService.changePassword(newPassword);
          await DataService.sendPasswordChangedConfirmationEmail(
            email: _profile!.email,
            recipientName: username,
          );
        } catch (_) {
          // Fallback to OTP-verified in-app password update if Firebase session requires re-auth
          final ok = await AuthService.completeInAppOtpPasswordReset(
            email: _profile!.email,
            newPassword: newPassword,
          );
          if (!ok) {
            throw AccountException(
              AuthService.lastErrorMessage ?? 'Could not update password.',
            );
          }
        }
      }
      if (emailChanged) {
        await AccountService.requestEmailChange(email);
      }

      if (!mounted) return;
      setState(() {
        _otpSent = false;
        _otpVerified = false;
        _otpStatusMessage = null;
        _fallbackOtpHint = null;
        _otpCtrl.clear();
      });
      await _load(); // Refresh fields from the saved state.
      if (!mounted) return;
      _snack(
        passwordChanged
            ? '✅ Password updated directly in FiBER! A confirmation notification email has been sent to $email.'
            : emailChanged
                ? 'Saved. Check $email and click the link to confirm. '
                      'Your sign-in email changes after you confirm.'
                : 'Changes saved.',
      );
    } on AccountException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: border(Colors.lightBlue.shade100),
      enabledBorder: border(Colors.lightBlue.shade100),
      focusedBorder: border(_brand, 2),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _avatarSection() {
    ImageProvider? image;
    if (_pendingAvatar != null) {
      image = MemoryImage(_pendingAvatar!);
    } else if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      try {
        image = MemoryImage(base64Decode(_photoBase64!));
      } catch (_) {
        image = null;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B3C5D), Color(0xFF0288D1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.cyanAccent,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  backgroundImage: image,
                  child: image == null
                      ? const Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFF0277BD),
                        )
                      : null,
                ),
              ),
              if (_uploadingAvatar)
                const CircularProgressIndicator(color: Colors.cyanAccent),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _usernameCtrl.text.isNotEmpty ? _usernameCtrl.text : 'FiBER User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _emailCtrl.text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: (_uploadingAvatar || _saving) ? null : _pickAvatar,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Change Profile Picture'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0B3C5D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future< void > _sendEmailVerificationReset() async {
    final targetEmail = _emailCtrl.text.trim();
    if (targetEmail.isEmpty) {
      _snack('No registered email found.', error: true);
      return;
    }
    try {
      await AccountService.sendFirebaseVerificationEmail();
      if (!mounted) return;
      _snack(
        '📧 Firebase verification link sent to $targetEmail! After clicking the link in your Gmail, tap "Refresh Verification Status".',
      );
    } on AccountException catch (e) {
      if (!mounted) return;
      _snack(e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      _snack('Could not send verification email: $e', error: true);
    }
  }

  Future< void > _refreshVerificationStatus() async {
    try {
      final verified = await AccountService.checkEmailVerifiedStatus();
      if (!mounted) return;
      setState(() {
        _isEmailVerified = verified;
      });
      if (verified) {
        _snack('✅ Your email address is verified!');
      } else {
        _snack(
          'Email is not verified yet. Complete the 6-digit OTP verification above or click the verification link sent to your Gmail.',
          error: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _snack('Could not check verification status: $e', error: true);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Log Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await AuthService.logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Future< void > _saveUsernameOnly() async {
    if (_saving) return;
    final err = _validateUsername(_usernameCtrl.text);
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    final newUsername = _usernameCtrl.text.trim();
    setState(() => _saving = true);
    try {
      await AccountService.saveUsername(newUsername);
      AuthService.updateCachedProfile(
        name: newUsername,
        username: newUsername,
      );
      await _load();
      if (!mounted) return;
      _snack('Username saved and updated in sidebar!');
    } on AccountException catch (e) {
      if (mounted) _snack(e.message, error: true);
    } catch (e) {
      if (mounted) _snack('Could not save username: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future< void > _saveEmailOnly() async {
    if (_saving) return;
    final err = _validateEmail(_emailCtrl.text);
    if (err != null) {
      _snack(err, error: true);
      return;
    }
    if (!_emailChanged) {
      _snack('Email address is already up to date.');
      return;
    }
    if (_currentPasswordCtrl.text.isEmpty) {
      _snack(
        'Please enter your Current Password in Section 2 first to verify changing your email.',
        error: true,
      );
      return;
    }
    await _save();
  }

  Widget _personalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _avatarSection(),
        const SizedBox(height: 18),
        TextFormField(
          controller: _usernameCtrl,
          decoration: _decoration(
            label: 'Username',
            suffix: IconButton(
              icon: const Icon(
                Icons.save_rounded,
                color: Color(0xFF0288D1),
              ),
              tooltip: 'Save Username',
              onPressed: _saving ? null : _saveUsernameOnly,
            ),
          ),
          textInputAction: TextInputAction.done,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validateUsername,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          decoration: _decoration(
            label: 'Registered Email Address',
            suffix: IconButton(
              icon: const Icon(
                Icons.save_rounded,
                color: Color(0xFF0288D1),
              ),
              tooltip: 'Save Email Address',
              onPressed: _saving ? null : _saveEmailOnly,
            ),
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validateEmail,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _securitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Change your password directly inside FiBER using a 6-digit OTP sent to your registered Gmail address. Once updated, a confirmation email notification will be sent to your inbox.',
          style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 14),

        // ── Step 1 & Step 2: Request OTP & Verify 6-Digit OTP Inside the App ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _otpVerified
                ? Colors.green.shade50
                : const Color(0xFFF0F8FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _otpVerified
                  ? Colors.green.shade400
                  : Colors.lightBlue.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _otpVerified
                            ? Icons.verified_user_rounded
                            : Icons.lock_clock_rounded,
                        color: _otpVerified
                            ? Colors.green.shade700
                            : const Color(0xFF0277BD),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _otpVerified
                              ? 'Step 1 & 2 Complete: Gmail OTP Verified'
                              : 'Step 1 & 2: Request & Verify Gmail OTP (5-Min Expiry)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _otpVerified
                                ? Colors.green.shade800
                                : const Color(0xFF0B3C5D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isEmailVerified
                          ? Colors.green.shade100
                          : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isEmailVerified ? '● Email Verified' : '● Unverified',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isEmailVerified
                            ? Colors.green.shade900
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _otpSent && !_otpVerified
                    ? (_otpSecondsLeft > 0
                        ? 'Enter the 6-digit OTP sent to ${_profile?.email ?? _emailCtrl.text.trim()}. Expires in ${(_otpSecondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_otpSecondsLeft % 60).toString().padLeft(2, '0')}'
                        : 'Your OTP has expired. Tap "Resend OTP" to receive a new code in your Gmail.')
                    : _otpVerified
                        ? 'Your identity is verified! Proceed to Step 3 below to set and confirm your new password.'
                        : 'Request a 6-digit One-Time Password (OTP) sent to your registered Gmail (${_profile?.email ?? _emailCtrl.text.trim()}) to verify your account and unlock password changes.',
                style: TextStyle(
                  fontSize: 12,
                  color: (_otpSent && !_otpVerified && _otpSecondsLeft == 0)
                      ? Colors.red.shade700
                      : Colors.black54,
                ),
              ),
              if (_otpStatusMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _otpStatusIsError
                        ? Colors.red.shade50
                        : Colors.lightBlue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _otpStatusIsError
                          ? Colors.red.shade200
                          : Colors.lightBlue.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _otpStatusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _otpStatusIsError
                              ? Colors.red.shade800
                              : const Color(0xFF0B3C5D),
                        ),
                      ),
                      if (_fallbackOtpHint != null &&
                          _fallbackOtpHint!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SelectableText(
                          'Verification OTP Code: $_fallbackOtpHint',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0277BD),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              if (!_otpVerified)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      child: TextField(
                        controller: _otpCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '6-digit OTP',
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          (_otpSent && _otpSecondsLeft > 0 && !_verifyingOtp)
                              ? _verifyPasswordChangeOtp
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _verifyingOtp
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Verify OTP'),
                    ),
                    OutlinedButton.icon(
                      onPressed: (_resendCooldownSeconds > 0 || _sendingOtp)
                          ? null
                          : _sendPasswordChangeOtp,
                      icon: _sendingOtp
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 15),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(
                        _sendingOtp
                            ? 'Sending...'
                            : !_otpSent
                                ? 'Send OTP to Gmail'
                                : (_resendCooldownSeconds > 0
                                    ? 'Resend (${_resendCooldownSeconds}s)'
                                    : 'Resend OTP'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Step 3: Set & Confirm New Password Inside the App ──
        const Text(
          'Step 3: Set New Password',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
            color: Color(0xFF0B3C5D),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _currentPasswordCtrl,
          obscureText: _obscureCurrent,
          autofillHints: const [AutofillHints.password],
          decoration: _decoration(
            label: 'Current Password (Optional if OTP Verified)',
            hint: 'Enter current password if changing email',
            suffix: IconButton(
              icon: Icon(
                _obscureCurrent ? Icons.visibility_off : Icons.visibility,
              ),
              tooltip: _obscureCurrent ? 'Show password' : 'Hide password',
              onPressed: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
          ),
          validator: _validateCurrentPassword,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _newPasswordCtrl,
          obscureText: _obscureNew,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: _decoration(
            label: 'New Password',
            hint: '8–20 chars, uppercase, lowercase, number',
            suffix: IconButton(
              icon: Icon(
                _obscureNew ? Icons.visibility_off : Icons.visibility,
              ),
              tooltip: _obscureNew ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validateNewPassword,
          onChanged: (_) => setState(() {}),
        ),
        if (_newPasswordCtrl.text.isNotEmpty) _buildDynamicPasswordChecklist(),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmNewPasswordCtrl,
          obscureText: _obscureConfirmNew,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          decoration: _decoration(
            label: 'Confirm New Password',
            hint: 'Re-enter your new password',
            suffix: IconButton(
              icon: Icon(
                _obscureConfirmNew ? Icons.visibility_off : Icons.visibility,
              ),
              tooltip: _obscureConfirmNew ? 'Show password' : 'Hide password',
              onPressed: () =>
                  setState(() => _obscureConfirmNew = !_obscureConfirmNew),
            ),
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: _validateConfirmNewPassword,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // ── Step 4: Save New Password & Dispatch Confirmation Email ──
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.lock_reset_rounded),
            label: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Update Password & Send Confirmation Email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0277BD),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _accountActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Sign out of your FiBER session on this device. Your progress, study time, flashcards, and assessment history remain safely stored in the cloud.',
          style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _confirmLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text(
            'Log Out of Account',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading && _profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError ?? 'Could not load your account.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                  });
                  _load();
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Personal Information
                _sectionCard(
                  title: '1. Personal Information',
                  child: _personalInfoSection(),
                ),
                const SizedBox(height: 16),

                // 2. Account and Security
                _sectionCard(
                  title: '2. Account and Security',
                  child: _securitySection(),
                ),
                const SizedBox(height: 16),

                // 3. Account Actions
                _sectionCard(
                  title: '3. Account Actions',
                  child: _accountActionsSection(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile & Account Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _buildBody(),
    );
  }
}
