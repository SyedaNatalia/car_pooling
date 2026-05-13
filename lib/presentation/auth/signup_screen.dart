import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
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
      await AuthService().signUp(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        company: _selectedCompany,
        department: _selectedDepartment,
        role: _selectedRole,
      );
      // Router's redirect will automatically navigate to /home
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(e.toString()));
      }
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
      return 'An account already exists with this email. Please login or use a different email.';
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
            hintText: 'example@gmail.com',
            prefixIcon:
                Icon(Icons.email_outlined, color: AppTheme.textDark),
          ),
          // validator: (v) {
          //   if (v == null || v.isEmpty) return 'Email is required';
          //   if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
          //   final allowed = ['ffc.com.pk', 'olive.com', 'sone.com', 'fojifoods.com'];
          //   final lower = v.trim().toLowerCase();
          //   if (!allowed.any((d) => lower.endsWith('@\$d'))) {
          //     return 'Only company emails allowed\n(e.g. yourname@ffc.com.pk)';
          //   }
          //   return null;
          // },
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
          validator: (v) =>
              v == null || v.isEmpty ? 'Phone number is required' : null,
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