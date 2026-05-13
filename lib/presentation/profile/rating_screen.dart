import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/ride_service.dart';
import '../../data/models/ride_model.dart';

class RatingScreen extends StatefulWidget {
  final String rideId;
  final String ratedUserId;
  final String ratedUserName;
  final String? ratedUserPhoto;

  const RatingScreen({
    super.key,
    required this.rideId,
    required this.ratedUserId,
    required this.ratedUserName,
    this.ratedUserPhoto,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _alreadyRated = false;
  bool _checking = true;

  final _rideService = RideService();

  @override
  void initState() {
    super.initState();
    _checkAlreadyRated();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkAlreadyRated() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final rated = await _rideService.hasRated(
      rideId:  widget.rideId,
      raterId: myUid,
      ratedId: widget.ratedUserId,
    );
    if (mounted) setState(() { _alreadyRated = rated; _checking = false; });
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a star rating'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _rideService.submitRating(
        rideId:  widget.rideId,
        raterId: myUid,
        ratedId: widget.ratedUserId,
        rating:  _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted! Thank you.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Rate Your Ride'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _alreadyRated
              ? _AlreadyRatedView(onDone: () => context.go('/home'))
              : Column(
                  children: [
                    const SizedBox(height: 16),

                    // User avatar
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryLight,
                      backgroundImage: widget.ratedUserPhoto != null
                          ? NetworkImage(widget.ratedUserPhoto!)
                          : null,
                      child: widget.ratedUserPhoto == null
                          ? Text(
                              widget.ratedUserName.isNotEmpty
                                  ? widget.ratedUserName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 36, color: AppTheme.primary,
                                  fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'How was your ride with',
                      style: TextStyle(
                          fontSize: 14, color: AppTheme.textMedium),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.ratedUserName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 32),

                    // Stars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final starVal = i + 1.0;
                        return GestureDetector(
                          onTap: () => setState(() => _rating = starVal),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              _rating >= starVal
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 48,
                              color: _rating >= starVal
                                  ? const Color(0xFFF59E0B)
                                  : AppTheme.border,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ratingLabel(_rating),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _rating > 0
                            ? const Color(0xFFF59E0B)
                            : AppTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Comment
                    TextField(
                      controller: _commentController,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: 'Leave a comment (optional)',
                        hintStyle: const TextStyle(color: AppTheme.textLight),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primary),
                        ),
                        filled: true,
                        fillColor: AppTheme.bgWhite,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Submit Rating',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Skip',
                          style: TextStyle(color: AppTheme.textMedium)),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _ratingLabel(double r) {
    if (r == 0) return 'Tap to rate';
    if (r <= 1) return 'Poor';
    if (r <= 2) return 'Fair';
    if (r <= 3) return 'Good';
    if (r <= 4) return 'Great';
    return 'Excellent';
  }
}

class _AlreadyRatedView extends StatelessWidget {
  final VoidCallback onDone;
  const _AlreadyRatedView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: AppTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.check_circle, color: AppTheme.success, size: 44),
        ),
        const SizedBox(height: 20),
        const Text('Already Rated',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: AppTheme.textDark)),
        const SizedBox(height: 8),
        const Text('You have already submitted a rating for this ride.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMedium, height: 1.5)),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size(160, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Go Home', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}