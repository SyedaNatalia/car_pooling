import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/providers/app_providers.dart';
import '../../data/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedCompany = AppConstants.companies.first;
  String _selectedDepartment = AppConstants.departments.first;
  String _selectedRole = AppConstants.roles.first['value']!;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // signUp() now returns the email and keeps user signed-in for polling
      final email = await AuthService().signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        company: _selectedCompany,
        department: _selectedDepartment,
        role: _selectedRole,
      );
      // DO NOT sign out — EmailVerificationWaitScreen needs currentUser
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailVerificationWaitScreen(email: email),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');

      if (msg == 'already_verified') {
        setState(() => _errorMessage =
            'This email is already registered and verified.\nPlease login instead.');
        return;
      }
      if (msg == 'email_taken') {
        setState(() => _errorMessage =
            'An account already exists with this email.\nPlease login or use a different email.');
        return;
      }

      setState(() => _errorMessage = _friendlyError(msg));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // User-friendly error messages
  String _friendlyError(String raw) {
    final msg = raw.replaceAll('Exception: ', '');
    if (msg.contains('Network error') ||
        msg.contains('network-request-failed') ||
        msg.contains('SocketException')) {
      return 'No internet connection. Please check your Wi-Fi or mobile data and try again.';
    }
    if (msg.contains('timeout') || msg.contains('TimeoutException')) {
      return 'Connection timed out. Your internet may be slow — please try again.';
    }
    if (msg.contains('already exists') || msg.contains('email-already-in-use')) {
      return 'An account already exists with this email.\nPlease login instead, or use a different email.';
    }
    if (msg.contains('weak-password') || msg.contains('at least 6') || msg.contains('at least 8')) {
      return 'Password must be at least 8 characters long.';
    }
    if (msg.contains('invalid-email') || msg.contains('Invalid email')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('Too many') || msg.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later.';
    }
    return msg.isNotEmpty ? msg : 'Could not create account. Please try again.';
  }

  // ── Personal Info ─────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Full Name'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Enter your full name',
            prefixIcon: Icon(Icons.person_outline, color: AppTheme.textDark),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: 16),
        _fieldLabel('Company Email'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'yourname@olivetech.com.pk',
            prefixIcon:
                Icon(Icons.email_outlined, color: AppTheme.textDark),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Email is required';
            if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
            final lower = v.trim().toLowerCase();
            // ✅ @gmail.com allowed temporarily for testing
            final isAllowed = lower.endsWith(AppConstants.companyDomain) ||
                lower.endsWith('@gmail.com');
            if (!isAllowed) {
              return 'Only company email allowed\n(e.g. yourname${AppConstants.companyDomain})';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _fieldLabel('Phone Number'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: '03XX-XXXXXXX',
            prefixIcon:
                Icon(Icons.phone_outlined, color: AppTheme.textDark),
          ),
        validator: (v) {
              if (v == null || v.isEmpty) return 'Phone number is required';
              // Accept 03XXXXXXXXX (11 digits) or +92XXXXXXXXXX (13 chars)
              final digits = v.replaceAll(RegExp(r'[\s\-]'), '');
              final valid = RegExp(r'^(03\d{9}|(\+92)\d{10})$').hasMatch(digits);
              if (!valid) return 'Enter a valid Pakistani number\n(e.g. 03XX-XXXXXXX or +92XXXXXXXXXX)';
              return null;
            },
        ),
      ],
    );
  }

  // ── Company, Department & Role ────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company Dropdown
        _fieldLabel('Company'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCompany,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.domain_outlined, color: AppTheme.textDark),
            hintText: 'Select Company',
          ),
          items: AppConstants.companies
              .map((company) => DropdownMenuItem(
                    value: company,
                    child: Text(company),
                  ))
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedCompany = newValue;
              });
            }
          },
        ),
        const SizedBox(height: 16),

        // Department Dropdown
        _fieldLabel('Department'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDepartment,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.business_outlined, color: AppTheme.textDark),
            hintText: 'Select Department',
          ),
          items: AppConstants.departments
              .map((department) => DropdownMenuItem(
                    value: department,
                    child: Text(department),
                  ))
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedDepartment = newValue;
              });
            }
          },
        ),
        const SizedBox(height: 16),

        // Role Dropdown
        _fieldLabel('Role'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedRole,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person_outline, color: AppTheme.textDark),
            hintText: 'Select Role',
          ),
          items: AppConstants.roles
              .map((role) => DropdownMenuItem(
                    value: role['value'],
                    child: Text(role['label']!),
                  ))
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() {
                _selectedRole = newValue;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'Enter Your Password',
            prefixIcon:
                const Icon(Icons.lock_outline, color: AppTheme.textDark),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.textDark,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
            if (v.length < 8) return 'Password must be at least 8 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),
        _fieldLabel('Confirm Password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Re-enter password',
            prefixIcon:
                const Icon(Icons.lock_outline, color: AppTheme.textDark),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.textDark,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Please confirm password';
            if (v != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppTheme.textDark,
        ),
      );

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return 'Personal Info';
      case 1:
        return 'Company Details';
      default:
        return 'Set Password';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.bgLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.go('/auth/login');
            }
          },
        ),
        title: Text(
          _stepTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Step indicator ────────────────────────────────
                Row(
                  children: List.generate(3, (index) {
                    final isCompleted = index < _currentStep;
                    final isActive = index == _currentStep;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                        height: 4,
                        decoration: BoxDecoration(
                          color: isCompleted || isActive
                              ? AppTheme.primary
                              : AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 12),
                Text(
                  'Step ${_currentStep + 1} of 3',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    key: ValueKey(_currentStep),
                    children: [
                      if (_currentStep == 0) _buildStep1(),
                      if (_currentStep == 1) _buildStep2(),
                      if (_currentStep == 2) _buildStep3(),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_currentStep < 2) {
                              if (_formKey.currentState!.validate()) {
                                setState(() => _currentStep++);
                              }
                            } else {
                              _signUp();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _currentStep < 2 ? 'Continue' : 'Create Account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                if (_currentStep == 0)
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(color: AppTheme.textMedium),
                        ),
                        TextButton(
                          onPressed: () => context.go('/auth/login'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmailVerificationWaitScreen extends ConsumerStatefulWidget {
  final String email;
  const EmailVerificationWaitScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationWaitScreen> createState() =>
      _EmailVerificationWaitScreenState();
}

class _EmailVerificationWaitScreenState
    extends ConsumerState<EmailVerificationWaitScreen> with WidgetsBindingObserver {
  final _authService = AuthService();

  Timer? _pollTimer;
  bool _isVerifying = false;
  bool _isSending = false;
  bool _justSent = false;
  Timer? _cooldownTimer;
  String? _infoMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ watch app foreground/background
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ clean up observer
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ✅ Called automatically when user comes back to app from email client
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isVerifying) {
      _checkOnce();
    }
  }

  // Single immediate check — used on app resume
  Future<void> _checkOnce() async {
    try {
      final verified = await _authService.checkEmailVerified();
      if (verified && mounted) {
        _pollTimer?.cancel();
        await _onVerified();
      }
    } catch (_) {}
  }

  // ── Polling (every 4s as backup) ──────────────────────────────────────────
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_isVerifying) return;
      await _checkOnce();
    });
  }

  Future<void> _onVerified() async {
    if (!mounted || _isVerifying) return;
    setState(() => _isVerifying = true);
    _pollTimer?.cancel();

    try {
      await _authService.finaliseProfile();

      // Trigger GoRouter redirect re-evaluation. authStateChanges does not
      // fire when emailVerified flips, so we increment this counter manually.
      ref.read(routerRefreshProvider.notifier).state++;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified! Welcome aboard 🎉'),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _infoMessage = 'Account setup failed. Please try logging in.';
        _isError = true;
      });
    }
  }

  // ── Resend ─────────────────────────────────────────────────────────────────
  Future<void> _resend() async {
    if (_isSending || _justSent) return;
    setState(() {
      _isSending = true;
      _infoMessage = null;
      _isError = false;
    });
    try {
      await _authService.resendVerificationEmail();
      if (!mounted) return;
      setState(() {
        _justSent = true;
        _isSending = false;
        _infoMessage = 'Verification email sent! Check your inbox & spam folder.';
        _isError = false;
      });
      // 60s cooldown before allowing another resend
      _cooldownTimer = Timer(const Duration(seconds: 60), () {
        if (mounted) setState(() { _justSent = false; _infoMessage = null; });
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg == 'already_verified') {
        // Race condition: they verified while tapping resend
        _pollTimer?.cancel();
        await _onVerified();
        return;
      }
      setState(() {
        _isSending = false;
        _infoMessage = msg.contains('Session expired')
            ? 'Session expired. Please go back and sign up again.'
            : 'Could not send email. Please check your connection and try again.';
        _isError = true;
      });
    }
  }

  // ── Back to Login ──────────────────────────────────────────────────────────
  Future<void> _backToLogin() async {
    _pollTimer?.cancel();
    await _authService.signOut();
    if (mounted) context.go('/auth/login');
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // Icon
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    size: 48, color: AppTheme.primary),
              ),

              const SizedBox(height: 28),

              const Text(
                'Verify your email',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDark),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              const Text(
                'We sent a verification link to',
                style: TextStyle(fontSize: 14, color: AppTheme.textMedium),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              const Text(
                'Open your email and click the verification link. This page will update automatically once you\'ve verified.',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textMedium, height: 1.6),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Color(0xFFF59E0B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        // ✅ @gmail.com allowed temporarily for testing
                        'No email? Check your spam folder. Make sure you used a valid ${AppConstants.companyDomain} or @gmail.com address.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Status indicator
              if (_isVerifying)
                const Column(
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 10),
                    Text('Setting up your account…',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textMedium)),
                  ],
                )
              else
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    ),
                    SizedBox(width: 10),
                    Text('Checking verification status…',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textLight)),
                  ],
                ),

              const SizedBox(height: 24),

              // Resend button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_isSending || _justSent || _isVerifying)
                      ? null
                      : _resend,
                  icon: _isSending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary))
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(_justSent
                      ? 'Email sent — check inbox'
                      : 'Resend verification email'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.primary),
                    foregroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              if (_infoMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _infoMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _isError ? AppTheme.error : AppTheme.success,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 12),

              // Back to login
              TextButton(
                onPressed: _isVerifying ? null : _backToLogin,
                child: const Text(
                  'Back to Login',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMedium,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}