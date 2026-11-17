import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  final bool initialIsSignUp;

  const LoginScreen({super.key, this.initialIsSignUp = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _backupGmailCtrl = TextEditingController();
  final TextEditingController _backupOtpCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  late bool _isSignUp;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _backupGmailOtpSent = false;
  bool _backupGmailVerified = false;
  String _verifiedBackupGmail = '';

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    _passwordCtrl.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _passwordCtrl.removeListener(_onPasswordChanged);
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _backupGmailCtrl.dispose();
    _backupOtpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // Live password requirement checks for Sign Up
  String get _pwd => _passwordCtrl.text;
  bool get _hasValidLength => _pwd.length >= 8 && _pwd.length <= 20;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_pwd);
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_pwd);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_pwd);
  bool get _isPasswordStrong =>
      _hasValidLength && _hasUppercase && _hasLowercase && _hasNumber;

  void _toggleMode(bool signUpMode) {
    if (_isSignUp == signUpMode) return;
    setState(() {
      _isSignUp = signUpMode;
      _formKey.currentState?.reset();
    });
  }

  void _showRegistrationHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registration Help'),
        content: const SingleChildScrollView(
          child: Text(
            'Sign up using your CvSU email address or log in if you already have an account. For teachers, the admin or department chairperson will provide an account to access the Teacher Dashboard for managing learning materials and monitoring student progress.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _sendBackupGmailVerificationCode() {
    final gmail = _backupGmailCtrl.text.trim().toLowerCase();
    if (gmail.isEmpty || !gmail.endsWith('@gmail.com')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid @gmail.com address for your backup account.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final otpCode = DataService.generateEmailOtp(
      email: gmail,
      purpose: 'backup_gmail',
    );
    setState(() {
      _backupGmailOtpSent = true;
      _backupGmailVerified = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        backgroundColor: const Color(0xFF00695C),
        behavior: SnackBarBehavior.floating,
        content: Text(
          '📧 Gmail Verification Sent to $gmail!\nYour 6-digit verification code is: $otpCode (Expires in 5 mins)',
        ),
      ),
    );
  }

  void _confirmBackupGmailOtp() {
    final gmail = _backupGmailCtrl.text.trim().toLowerCase();
    final err = DataService.verifyEmailOtp(
      email: gmail,
      purpose: 'backup_gmail',
      enteredCode: _backupOtpCtrl.text,
    );
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
      );
      return;
    }
    setState(() {
      _backupGmailVerified = true;
      _verifiedBackupGmail = gmail;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Backup Gmail ($gmail) verified and linked!'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future< void > _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    if (_isSignUp) {
      final user = await AuthService.signUp(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        _usernameCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user != null) {
        Navigator.pushReplacementNamed(context, '/student');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AuthService.lastErrorMessage ??
                  'Sign up failed. Email may already be in use.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if this is a newly approved Teacher account awaiting first-time password setup
    final pendingSetup = await AuthService.checkPendingTeacherSetup(
      _emailCtrl.text.trim(),
    );
    if (pendingSetup != null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showFirstTimeTeacherPasswordSetupModal(pendingSetup);
      return;
    }

    // Existing Login Flow (retains access for all previously registered users)
    final user = await AuthService.login(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.lastErrorMessage ?? 'Invalid email, password, or role.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (user.role == UserRole.admin) {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (user.role == UserRole.teacher) {
      Navigator.pushReplacementNamed(context, '/teacher');
    } else {
      Navigator.pushReplacementNamed(context, '/student');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF041C32),
              Color(0xFF0B3C5D),
              Color(0xFF064663),
              Color(0xFF0277BD),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.14,
                child: Image.asset(
                  'lib/assets/images/Minimalist Blue Fish Pattern.png',
                  fit: BoxFit.cover,
                  color: Colors.cyanAccent,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // ── Back button ─────────────────────────────────
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.lightBlueAccent,
                        ),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(context, '/');
                          }
                        },
                        tooltip: 'Back',
                      ),
                    ),
                  ),

                  // ── Form ────────────────────────────────────────
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: _buildGlassCard(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFF0B3C5D).withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_rounded,
                          size: 13, color: Colors.cyanAccent),
                      SizedBox(width: 4),
                      Text(
                        'Secure CvSU Portal',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSignUp)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _showRegistrationHelp,
                    tooltip: 'Registration help',
                    icon: const Icon(
                      Icons.help_outline_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.35)),
              ),
              child: Image.asset(
                'lib/assets/Logo/fiber_logo.png',
                height: 52,
                width: 52,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.set_meal_rounded,
                  size: 44,
                  color: Colors.cyanAccent,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isSignUp ? 'Create Student Account' : 'Welcome Back!',
              style: GoogleFonts.playfairDisplay(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _isSignUp
                  ? 'Join your CvSU-Naic classmates to review'
                  : 'Fisheries Technologist Licensure Reviewer',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            // ── Modern Animated Segmented Pill Control ──
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF031C32),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleMode(false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: !_isSignUp
                              ? const LinearGradient(
                                  colors: [Color(0xFF00BCD4), Color(0xFF0288D1)],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'Sign In',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !_isSignUp ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _toggleMode(true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: _isSignUp
                              ? const LinearGradient(
                                  colors: [Color(0xFF00BCD4), Color(0xFF0288D1)],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'Register',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isSignUp ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isSignUp) ...[
              _buildTextField(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _usernameCtrl,
                label: 'Username',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 12),
            ],
            _buildTextField(
              controller: _emailCtrl,
              label: 'Email Address',
              icon: Icons.alternate_email_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _passwordCtrl,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              hint: _isSignUp ? '8–20 chars, uppercase, lowercase, number' : null,
              isPassword: true,
              obscureValue: _obscurePassword,
              onToggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),

            // ── Section 8.1: Forgot Password? Button Below Password Field on Sign-In Page ──
            if (!_isSignUp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _openForgotPasswordScreen,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(
                    Icons.lock_reset_rounded,
                    size: 16,
                    color: Colors.cyanAccent,
                  ),
                  label: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),

            if (_isSignUp && _pwd.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildPasswordChecklist(),
            ],
            if (_isSignUp) ...[
              const SizedBox(height: 12),
              _buildTextField(
                controller: _confirmPasswordCtrl,
                label: 'Confirm Password',
                icon: Icons.lock_reset_rounded,
                isPassword: true,
                obscureValue: _obscureConfirmPassword,
                onToggleObscure: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
            ],

            SizedBox(height: _isSignUp ? 22 : 12),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.cyanAccent)
                : _buildPrimaryButton(),
            const SizedBox(height: 14),
            _buildBottomLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordChecklist() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF031C32).withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password Requirements (Case-Sensitive):',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _requirementRow('8–20 Characters', _hasValidLength)),
              const SizedBox(width: 8),
              Expanded(child: _requirementRow('Uppercase (A–Z)', _hasUppercase)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _requirementRow('Lowercase (a–z)', _hasLowercase)),
              const SizedBox(width: 8),
              Expanded(child: _requirementRow('Number (0–9)', _hasNumber)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requirementRow(String text, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: met
            ? Colors.greenAccent.withOpacity(0.12)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: met ? Colors.greenAccent.withOpacity(0.5) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 13,
            color: met ? Colors.greenAccent : Colors.white38,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: TextStyle(
                  color: met ? Colors.greenAccent : Colors.white60,
                  fontSize: 11,
                  fontWeight: met ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    bool isPassword = false,
    bool obscureValue = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? obscureValue : false,
      style: const TextStyle(color: Colors.white, fontSize: 14.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13.5),
        floatingLabelStyle: const TextStyle(
          color: Colors.cyanAccent,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: const Color(0xFF031C32).withOpacity(0.6),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.cyanAccent, size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureValue
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white70,
                  size: 20,
                ),
                tooltip: obscureValue ? 'Show password' : 'Hide password',
                onPressed: onToggleObscure,
              )
            : null,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Please enter $label';
        if (label.toLowerCase().contains('email')) {
          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
          if (!emailRegex.hasMatch(v.trim())) {
            return 'Please enter a valid email address (e.g., name@cvsu.edu.ph)';
          }
        }
        if (_isSignUp && label == 'Password') {
          if (!_hasValidLength) {
            return 'Password must be 8 to 20 characters long';
          }
          if (!_hasUppercase || !_hasLowercase) {
            return 'Include both uppercase (A-Z) and lowercase (a-z) letters';
          }
          if (!_hasNumber) {
            return 'Include at least one number (0-9)';
          }
        }
        if (_isSignUp && label == 'Confirm Password' && v != _passwordCtrl.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildPrimaryButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BCD4), Color(0xFF0288D1)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withOpacity(0.4),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        onPressed: _submit,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSignUp ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              _isSignUp ? 'Create Student Account' : 'Sign In',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 15.5,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future< void > _openForgotPasswordScreen() async {
    final recoveredEmail = await Navigator.push< String >(
      context,
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _emailCtrl.text.trim(),
        ),
      ),
    );
    if (!mounted) return;
    if (recoveredEmail != null && recoveredEmail.trim().isNotEmpty) {
      setState(() {
        _isSignUp = false;
        _emailCtrl.text = recoveredEmail.trim();
        _passwordCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Password Changed Successfully! Your password has been updated. You can now sign in using your new password.',
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showFirstTimeTeacherPasswordSetupModal(
    Map< String, dynamic > teacherData,
  ) {
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;
    bool isSaving = false;
    String? errorMsg;

    final teacherName = (teacherData['name'] ?? 'Faculty Member').toString();
    final teacherEmail = (teacherData['email'] ?? '').toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final pwd = newPwdCtrl.text;
          final validLen = pwd.length >= 8 && pwd.length <= 20;
          final hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
          final hasLower = RegExp(r'[a-z]').hasMatch(pwd);
          final hasNum = RegExp(r'[0-9]').hasMatch(pwd);

          Widget checkItem(String label, bool ok) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    size: 15,
                    color: ok ? Colors.green.shade700 : Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: ok ? FontWeight.w600 : FontWeight.normal,
                        color: ok ? Colors.green.shade800 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0B3C5D), Color(0xFF0288D1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.cyanAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Up Faculty Password',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your Teacher Account Has Been Approved!',
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.lightBlue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, $teacherName!',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B3C5D),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$teacherEmail • Fisheries Faculty',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Create your permanent password below to activate your Teacher Portal:',
                      style: TextStyle(fontSize: 12.5, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPwdCtrl,
                      obscureText: obscure1,
                      onChanged: (_) => setModalState(() => errorMsg = null),
                      decoration: InputDecoration(
                        labelText: 'Create Password',
                        filled: true,
                        fillColor: const Color(0xFFF8FBFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure1 ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () =>
                              setModalState(() => obscure1 = !obscure1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          checkItem('8 to 20 characters long', validLen),
                          checkItem('At least 1 uppercase letter (A–Z)', hasUpper),
                          checkItem('At least 1 lowercase letter (a–z)', hasLower),
                          checkItem('At least 1 number (0–9)', hasNum),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmPwdCtrl,
                      obscureText: obscure2,
                      onChanged: (_) => setModalState(() => errorMsg = null),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        filled: true,
                        fillColor: const Color(0xFFF8FBFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscure2 ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () =>
                              setModalState(() => obscure2 = !obscure2),
                        ),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Activate & Enter Portal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0277BD),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!validLen || !hasUpper || !hasLower || !hasNum) {
                          setModalState(
                            () => errorMsg =
                                'Please meet all password requirements above.',
                          );
                          return;
                        }
                        if (newPwdCtrl.text != confirmPwdCtrl.text) {
                          setModalState(
                            () => errorMsg = 'Passwords do not match.',
                          );
                          return;
                        }
                        setModalState(() {
                          isSaving = true;
                          errorMsg = null;
                        });
                        final user =
                            await AuthService.completeFirstTimeTeacherSetup(
                          email: teacherEmail,
                          newPassword: newPwdCtrl.text,
                        );
                        if (!mounted) return;
                        if (user != null) {
                          Navigator.pop(ctx);
                          Navigator.pushReplacementNamed(context, '/teacher');
                        } else {
                          setModalState(() {
                            isSaving = false;
                            errorMsg = AuthService.lastErrorMessage ??
                                'Could not complete password setup.';
                          });
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTeacherRequestDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedTitle = 'Prof.';
    const titles = ['Prof.', 'Inst.', 'Dr.', 'Assoc. Prof.'];
    const fbleSubjects = [
      'Aquaculture',
      'Capture Fisheries',
      'Post-Harvest Fisheries',
      'Aquatic Resources & Ecology',
    ];
    final Set< String > selectedSubjects = {'Aquaculture'};
    bool showSubjectList = false;
    String? errorMsg;
    bool isSubmitting = false;

    InputDecoration darkInputDecoration({
      required String label,
      String? hint,
      IconData? icon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
        floatingLabelStyle: const TextStyle(
          color: Colors.cyanAccent,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: const Color(0xFF031C32).withOpacity(0.65),
        prefixIcon: icon != null
            ? Icon(icon, color: Colors.cyanAccent, size: 19)
            : null,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.cyanAccent, width: 1.8),
        ),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF082D49), Color(0xFF0B3C5D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.cyanAccent.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header with Fixed Top-Right X Close Button ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.cyanAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Faculty Account Request',
                                style: GoogleFonts.playfairDisplay(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Dept. of Fisheries & Aquatic Sciences',
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: isSubmitting ? null : () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Combined Title Dropdown + Full Name Row ──
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF031C32).withOpacity(0.65),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton< String >(
                              value: selectedTitle,
                              dropdownColor: const Color(0xFF082D49),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.cyanAccent,
                                size: 18,
                              ),
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                              items: titles
                                  .map(
                                    (t) => DropdownMenuItem< String >(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedTitle = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: darkInputDecoration(
                              label: 'Full Name',
                              hint: 'Juan Dela Cruz',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Institutional Email ──
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: darkInputDecoration(
                        label: 'CvSU / Institutional Email',
                        hint: 'name@cvsu.edu.ph',
                        icon: Icons.alternate_email_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Minimalist Expandable Multi-Select Subject Picker ──
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setModalState(
                        () => showSubjectList = !showSubjectList,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF031C32).withOpacity(0.65),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: showSubjectList
                                ? Colors.cyanAccent
                                : Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.cyanAccent,
                              size: 19,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FBLE Subjects Handled',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedSubjects.join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${selectedSubjects.length} Selected',
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              showSubjectList
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: Colors.cyanAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showSubjectList)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF031C32).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: fbleSubjects.map((subj) {
                            final isChosen = selectedSubjects.contains(subj);
                            return CheckboxListTile(
                              value: isChosen,
                              dense: true,
                              activeColor: const Color(0xFF00BCD4),
                              checkColor: Colors.white,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                subj,
                                style: TextStyle(
                                  color: isChosen
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: isChosen
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedSubjects.add(subj);
                                  } else if (selectedSubjects.length > 1) {
                                    selectedSubjects.remove(subj);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),

                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          errorMsg!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // ── Glowing Submit Button ──
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF0288D1)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                size: 17,
                                color: Colors.white,
                              ),
                        label: const Text(
                          'Submit Faculty Request',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final rawName = nameCtrl.text.trim();
                                final email =
                                    emailCtrl.text.trim().toLowerCase();
                                if (rawName.isEmpty || email.isEmpty) {
                                  setModalState(
                                    () => errorMsg =
                                        'Please enter your full name and email address.',
                                  );
                                  return;
                                }
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(email)) {
                                  setModalState(
                                    () => errorMsg =
                                        'Please enter a valid email address.',
                                  );
                                  return;
                                }
                                final formattedName = rawName
                                        .toLowerCase()
                                        .startsWith(selectedTitle.toLowerCase())
                                    ? rawName
                                    : '$selectedTitle $rawName';
                                final autoUsername = email.split('@').first;
                                final subjectsSummary =
                                    'DFAS • ${selectedSubjects.join(", ")}';

                                setModalState(() {
                                  isSubmitting = true;
                                  errorMsg = null;
                                });
                                try {
                                  await DataService.submitTeacherAccountRequest(
                                    name: formattedName,
                                    username: autoUsername,
                                    email: email,
                                    department: subjectsSummary,
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '✅ Faculty request submitted! Once approved by the Admin, enter your email here to set up your password.',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } catch (e) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    errorMsg = e
                                        .toString()
                                        .replaceFirst('Exception: ', '');
                                  });
                                }
                              },
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

  Widget _buildBottomLink() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isSignUp ? 'Already registered?' : 'Need an account?',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            TextButton(
              onPressed: () => _toggleMode(!_isSignUp),
              child: Text(
                _isSignUp ? 'Sign in' : 'Register now',
                style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _showTeacherRequestDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.35)),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_rounded,
                    size: 16,
                    color: Colors.cyanAccent,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'CvSU Faculty Member? Request Account',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Section 8.1: Dedicated In-App Password Recovery Screen (Email OTP)
// ══════════════════════════════════════════════════════════════════
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State< ForgotPasswordScreen > createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State< ForgotPasswordScreen > {
  late final TextEditingController _emailCtrl;
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _newPwdCtrl = TextEditingController();
  final TextEditingController _confirmPwdCtrl = TextEditingController();

  bool _otpSent = false;
  bool _otpVerified = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _updatingPassword = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  int _otpSecondsLeft = 0; // 300s (5 minutes)
  int _resendCooldownSeconds = 0; // 60s
  Timer? _timer;

  String? _statusMessage;
  bool _statusIsError = false;
  String? _fallbackOtpHint;
  String? _matchedUserId;
  String? _matchedUserName;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  bool get _validLength =>
      _newPwdCtrl.text.length >= 8 && _newPwdCtrl.text.length <= 20;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_newPwdCtrl.text);
  bool get _hasLower => RegExp(r'[a-z]').hasMatch(_newPwdCtrl.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newPwdCtrl.text);
  bool get _passwordValid =>
      _validLength && _hasUpper && _hasLower && _hasNumber;

  Future< void > _sendRecoveryOtp() async {
    final cleanEmail = _emailCtrl.text.trim().toLowerCase();
    if (cleanEmail.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      setState(() {
        _statusMessage = 'Please enter a valid registered email address.';
        _statusIsError = true;
      });
      return;
    }
    if (_sendingOtp || _resendCooldownSeconds > 0) return;

    setState(() {
      _sendingOtp = true;
      _statusMessage = null;
      _statusIsError = false;
      _fallbackOtpHint = null;
    });

    try {
      final userDoc = await AuthService.findUserByEmail(cleanEmail);
      if (!mounted) return;
      if (userDoc == null) {
        setState(() {
          _sendingOtp = false;
          _statusMessage =
              'No FiBER account found with email $cleanEmail. Please check your email address.';
          _statusIsError = true;
        });
        return;
      }

      _matchedUserId = (userDoc['id'] ?? '').toString();
      _matchedUserName =
          (userDoc['name'] ?? userDoc['username'] ?? '').toString();

      final result = await DataService.sendEmailOtp(
        email: cleanEmail,
        purpose: 'forgot_password',
        recipientName: _matchedUserName,
        uid: _matchedUserId,
      );
      if (!mounted) return;

      final deliveredViaHttp = result['deliveredViaHttp'] == true;
      final generatedCode = (result['code'] ?? '').toString();

      _timer?.cancel();
      setState(() {
        _sendingOtp = false;
        _otpSent = true;
        _otpVerified = false;
        _otpCtrl.clear();
        _otpSecondsLeft = 300;
        _resendCooldownSeconds = 60;
        _statusIsError = false;
        if (deliveredViaHttp) {
          _statusMessage =
              '📧 6-digit recovery OTP sent to $cleanEmail! Check your Gmail Inbox (and Spam/Promotions).';
          _fallbackOtpHint = null;
        } else {
          _statusMessage =
              'Email relay notice: Use your generated 6-digit recovery OTP below:';
          _fallbackOtpHint = generatedCode;
        }
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          if (_otpSecondsLeft > 0) _otpSecondsLeft--;
          if (_resendCooldownSeconds > 0) _resendCooldownSeconds--;
          if (_otpSecondsLeft == 0 && !_otpVerified) {
            _statusMessage =
                'Your OTP has expired (5-minute limit). Tap "Resend OTP" to request a new code.';
            _statusIsError = true;
            _fallbackOtpHint = null;
          }
          if (_otpSecondsLeft == 0 && _resendCooldownSeconds == 0) {
            t.cancel();
          }
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingOtp = false;
        _statusMessage = 'Failed to send OTP: $e';
        _statusIsError = true;
      });
    }
  }

  Future< void > _verifyRecoveryOtp() async {
    if (_verifyingOtp) return;
    final cleanEmail = _emailCtrl.text.trim().toLowerCase();
    setState(() => _verifyingOtp = true);

    final err = await DataService.verifyEmailOtpAndMarkVerified(
      email: cleanEmail,
      purpose: 'forgot_password',
      enteredCode: _otpCtrl.text,
      uid: _matchedUserId,
    );
    if (!mounted) return;
    setState(() => _verifyingOtp = false);

    if (err != null) {
      setState(() {
        _statusMessage = err;
        _statusIsError = true;
      });
      return;
    }

    _timer?.cancel();
    setState(() {
      _otpVerified = true;
      _fallbackOtpHint = null;
      _statusIsError = false;
      _statusMessage =
          '✅ OTP Verified! Enter and confirm your new password below.';
    });
  }

  Future< void > _completePasswordRecovery() async {
    if (_updatingPassword) return;
    if (!_otpVerified) {
      setState(() {
        _statusMessage = 'Please verify your 6-digit OTP first.';
        _statusIsError = true;
      });
      return;
    }
    if (!_passwordValid) {
      setState(() {
        _statusMessage =
            'Please satisfy all password requirements (8–20 chars, uppercase, lowercase, and number).';
        _statusIsError = true;
      });
      return;
    }
    if (_newPwdCtrl.text != _confirmPwdCtrl.text) {
      setState(() {
        _statusMessage = 'New password and confirmation do not match.';
        _statusIsError = true;
      });
      return;
    }

    final cleanEmail = _emailCtrl.text.trim().toLowerCase();
    setState(() {
      _updatingPassword = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    final ok = await AuthService.completeInAppOtpPasswordReset(
      email: cleanEmail,
      newPassword: _newPwdCtrl.text,
    );
    if (!mounted) return;
    setState(() => _updatingPassword = false);

    if (ok) {
      await showDialog< void >(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade700,
                size: 26,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Password Changed Successfully!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF0B3C5D),
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Password Changed Successfully! Your password has been updated. You can now sign in using your new password.',
            style: TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Continue to Sign In',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, cleanEmail);
    } else {
      setState(() {
        _statusMessage =
            AuthService.lastErrorMessage ?? 'Failed to update password.';
        _statusIsError = true;
      });
    }
  }

  Widget _pwdReqRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: met ? Colors.greenAccent : Colors.white54,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: met ? Colors.greenAccent : Colors.white70,
                fontWeight: met ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF041C32),
              Color(0xFF0B3C5D),
              Color(0xFF064663),
              Color(0xFF0277BD),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.lightBlueAccent,
                    ),
                    tooltip: 'Back to Sign In',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B3C5D).withOpacity(0.88),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent.withOpacity(0.14),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.cyanAccent.withOpacity(0.4),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.lock_reset_rounded,
                                  size: 36,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'In-App Password Recovery',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Recover your FiBER account directly inside the app using a 6-digit OTP sent to your registered Gmail.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Step 1: Registered Email Address
                            TextField(
                              controller: _emailCtrl,
                              enabled: !_otpVerified,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Registered Email Address',
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                prefixIcon: const Icon(
                                  Icons.alternate_email_rounded,
                                  color: Colors.cyanAccent,
                                ),
                                filled: true,
                                fillColor:
                                    const Color(0xFF031C32).withOpacity(0.65),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (!_otpVerified) ...[
                              ElevatedButton.icon(
                                onPressed:
                                    (_sendingOtp || _resendCooldownSeconds > 0)
                                        ? null
                                        : _sendRecoveryOtp,
                                icon: _sendingOtp
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 17),
                                label: Text(
                                  _sendingOtp
                                      ? 'Sending OTP...'
                                      : !_otpSent
                                          ? 'Step 1: Send 6-Digit OTP to Email'
                                          : (_resendCooldownSeconds > 0
                                              ? 'Resend OTP (${_resendCooldownSeconds}s)'
                                              : 'Resend OTP'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BCD4),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],

                            if (_otpSent && !_otpVerified) ...[
                              const SizedBox(height: 14),
                              Text(
                                _otpSecondsLeft > 0
                                    ? 'Step 2: Enter 6-Digit OTP (Expires in ${(_otpSecondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_otpSecondsLeft % 60).toString().padLeft(2, '0')})'
                                    : 'OTP Expired — Please tap Resend OTP above.',
                                style: TextStyle(
                                  color: _otpSecondsLeft > 0
                                      ? Colors.cyanAccent
                                      : Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _otpCtrl,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        letterSpacing: 3,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        hintText: '6-digit OTP',
                                        hintStyle: const TextStyle(
                                          color: Colors.white38,
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFF031C32)
                                            .withOpacity(0.65),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: (_otpSecondsLeft > 0 &&
                                            !_verifyingOtp)
                                        ? _verifyRecoveryOtp
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade600,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
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
                                        : const Text(
                                            'Verify OTP',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ],

                            if (_statusMessage != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _statusIsError
                                      ? Colors.redAccent.withOpacity(0.18)
                                      : Colors.greenAccent.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _statusIsError
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _statusMessage!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_fallbackOtpHint != null &&
                                        _fallbackOtpHint!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      SelectableText(
                                        'Verification OTP Code: $_fallbackOtpHint',
                                        style: const TextStyle(
                                          color: Colors.cyanAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],

                            if (_otpVerified) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Step 3: Create & Confirm New Password',
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _newPwdCtrl,
                                obscureText: _obscureNew,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'New Password',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: Colors.cyanAccent,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureNew
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureNew = !_obscureNew,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF031C32)
                                      .withOpacity(0.65),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF031C32)
                                      .withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  children: [
                                    _pwdReqRow(
                                      '8 to 20 characters long',
                                      _validLength,
                                    ),
                                    _pwdReqRow(
                                      'At least 1 uppercase letter (A–Z)',
                                      _hasUpper,
                                    ),
                                    _pwdReqRow(
                                      'At least 1 lowercase letter (a–z)',
                                      _hasLower,
                                    ),
                                    _pwdReqRow(
                                      'At least 1 number (0–9)',
                                      _hasNumber,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _confirmPwdCtrl,
                                obscureText: _obscureConfirm,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Confirm New Password',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.lock_reset_rounded,
                                    color: Colors.cyanAccent,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF031C32)
                                      .withOpacity(0.65),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _updatingPassword
                                    ? null
                                    : _completePasswordRecovery,
                                icon: _updatingPassword
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_circle_outline_rounded,
                                      ),
                                label: const Text(
                                  'Reset Password & Return to Sign In',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BCD4),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}