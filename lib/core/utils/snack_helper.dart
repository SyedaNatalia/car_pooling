import 'package:flutter/material.dart';

const Color _snackBg      = Color(0xFF1B2A5E);
const Color _snackSuccess = Color(0xFF22C55E);
const Color _snackError   = Color(0xFFEF4444);

String friendlyError(dynamic e) {
  String raw = e.toString();

  // Strip all known prefixes repeatedly
  bool changed = true;
  while (changed) {
    changed = false;
    final prefixes = [
      'Exception: ',
      'FirebaseException: ',
      'FirebaseAuthException: ',
      'PlatformException: ',
    ];
    for (final p in prefixes) {
      if (raw.startsWith(p)) {
        raw = raw.substring(p.length).trim();
        changed = true;
      }
    }
  }

  // Strip [firebase_auth/code] or [cloud_firestore/code] style brackets
  raw = raw.replaceAll(RegExp(r'^\[[\w/_-]+\]\s*'), '');

  // Strip trailing stack trace / extra info after a newline
  if (raw.contains('\n')) raw = raw.split('\n').first.trim();

  const map = <String, String>{
    'permission-denied':        'You don\'t have permission for this action.',
    'network-request-failed':   'No internet connection. Please try again.',
    'unavailable':              'Service unavailable. Please try again later.',
    'not-found':                'Record not found.',
    'already-exists':           'This record already exists.',
    'unauthenticated':          'Please log in again.',
    'email-already-in-use':     'This email is already registered.',
    'user-not-found':           'No account found with this email.',
    'wrong-password':           'Incorrect password. Please try again.',
    'invalid-credential':       'Incorrect email or password. Please try again.',
    'weak-password':            'Password is too weak. Use at least 6 characters.',
    'invalid-email':            'Please enter a valid email address.',
    'too-many-requests':        'Too many attempts. Please wait and try again.',
    'requires-recent-login':    'Please log in again to complete this action.',
    'Cancel window has closed': 'Booking can only be cancelled within 5 minutes.',
    'Booking not found':        'Booking not found.',
    'User not found':           'User account not found. Please log in again.',
    'User profile not found':   'User profile not found. Please log in again.',
    'Already rated':            'You have already rated this ride.',
    'You have already booked':  'You have already booked this ride.',
    'INVALID_LOGIN_CREDENTIALS':'Incorrect email or password. Please try again.',
    'channel-error':            'Something went wrong. Please try again.',
  };

  for (final entry in map.entries) {
    if (raw.toLowerCase().contains(entry.key.toLowerCase())) return entry.value;
  }

  // Last resort — if it still looks like a technical string, show generic
  final looksTechnical = raw.contains('/') || raw.contains('(') ||
      raw.contains('Exception') || raw.contains('Error') ||
      raw.length > 120;
  if (looksTechnical) return 'Something went wrong. Please try again.';

  return raw.isNotEmpty ? raw : 'Something went wrong. Please try again.';
}

void showErrorSnack(BuildContext context, dynamic e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              friendlyError(e),
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: _snackBg,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _snackError, width: 1.5),
      ),
      duration: const Duration(seconds: 4),
    ),
  );
}

void showSuccessSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: _snackBg,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _snackSuccess, width: 1.5),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}