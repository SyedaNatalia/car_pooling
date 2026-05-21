// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/app_providers.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');

      if (msg.startsWith('email_not_verified:')) {
        final email = msg.replaceFirst('email_not_verified:', '');
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EmailVerificationWaitScreen(email: email)));
        return;
      }

      setState(() => _errorMessage = _friendlyError(msg));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    final msg = raw.replaceAll('Exception: ', '');
    if (msg.contains('Network error') ||
        msg.contains('network-request-failed') ||
        msg.contains('SocketException')) {
      return 'No internet connection. Please check your connection.';
    }
    if (msg.contains('timeout') || msg.contains('TimeoutException')) {
      return 'Connection timed out. Please try again.';
    }
    if (msg.contains('No account found')) {
      return 'No account found with this email. Please sign up first.';
    }
    if (msg.contains('Incorrect password') ||
        msg.contains('invalid-credential') ||
        msg.contains('Invalid email or password')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('disabled')) {
      return 'Your account has been disabled. Please contact support.';
    }
    if (msg.contains('Too many') || msg.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later.';
    }
    return msg.isNotEmpty ? msg : 'Sign in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: Column(
        children: [
          // ── Branded gradient header ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 28,
              bottom: 32,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A0A5E), Color(0xFF270d7d), Color(0xFF3B1FA8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.xxl),
                bottomRight: Radius.circular(AppRadius.xxl),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: AppShadows.elevated,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: Image.asset('assets/images/logo.jpeg',
                        fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'FairFare Carpool',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3),
                ),
              ],
            ),
          ),

          // ── Form card ──────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, bottomInset + 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome back',
                            style: AppTextStyles.h2),
                        const SizedBox(height: AppSpacing.lg),

                        // ── Error banner ────────────────────────────
                        if (_errorMessage != null) ...[
                          _ErrorBanner(message: _errorMessage!),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // ── Email ────────────────────────────────────
                        _FieldLabel('Email'),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'Enter Your Email',
                            prefixIcon: Icon(Icons.email_outlined,
                                color: AppTheme.textMedium, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Email is required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // ── Password ─────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _FieldLabel('Password'),
                            TextButton(
                              onPressed: () =>
                                  context.push('/auth/forgot-password'),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap),
                              child: const Text('Forgot password?',
                                  style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppTheme.textMedium, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppTheme.textMedium,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Password is required';
                            if (v.length < 8)
                              return 'At least 8 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ── Sign in button ────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppTheme.primary.withValues(alpha: 0.55),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                               : const Text('Sign In',
    style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700)),
                          ),
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // ── Sign up link ──────────────────────────────
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("Don't have an account? ",
                                  style: AppTextStyles.body),
                              GestureDetector(
                                onTap: () => context.go('/auth/signup'),
                                child: const Text('Sign Up',
                                    style: TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyBold.copyWith(color: AppTheme.textDark),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppTheme.error, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
