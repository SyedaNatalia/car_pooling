// import 'package:flutter/material.dart';
// import '../theme/app_theme.dart';

// String friendlyError(dynamic e) {
//   final raw = e.toString()
//       .replaceAll('Exception: ', '')
//       .replaceAll('FirebaseException: ', '')
//       .replaceAll('[cloud_firestore/', '')
//       .replaceAll('[firebase_auth/', '')
//       .replaceAll(RegExp(r'\] .*'), '');

//   const map = {
//     'permission-denied':        'You don\'t have permission for this action.',
//     'network-request-failed':   'No internet connection. Please try again.',
//     'unavailable':              'Service unavailable. Please try again later.',
//     'not-found':                'Record not found.',
//     'already-exists':           'This already exists.',
//     'unauthenticated':          'Please log in again.',
//     'Cancel window has closed': 'Booking can only be cancelled within 5 minutes of acceptance.',
//     'Booking not found':        'Booking not found.',
//   };

//   for (final entry in map.entries) {
//     if (raw.contains(entry.key)) return entry.value;
//   }
//   return raw.isNotEmpty ? raw : 'Something went wrong. Please try again.';
// }

// void showErrorSnack(BuildContext context, dynamic e) {
//   if (!context.mounted) return;
//   ScaffoldMessenger.of(context).removeCurrentSnackBar();
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(
//       content: Row(children: [
//         const Icon(Icons.error_outline, color: Colors.white, size: 18),
//         const SizedBox(width: 10),
//         Expanded(child: Text(friendlyError(e),
//             style: const TextStyle(fontSize: 13))),
//       ]),
//       backgroundColor: AppTheme.error,
//       behavior: SnackBarBehavior.floating,
//       margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       duration: const Duration(seconds: 4),
//     ),
//   );
// }

// void showSuccessSnack(BuildContext context, String message) {
//   if (!context.mounted) return;
//   ScaffoldMessenger.of(context).removeCurrentSnackBar();
//   ScaffoldMessenger.of(context).showSnackBar(
//     SnackBar(
//       content: Row(children: [
//         const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
//         const SizedBox(width: 10),
//         Expanded(child: Text(message,
//             style: const TextStyle(fontSize: 13))),
//       ]),
//       backgroundColor: AppTheme.success,
//       behavior: SnackBarBehavior.floating,
//       margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       duration: const Duration(seconds: 3),
//     ),
//   );
// }
import 'package:flutter/material.dart';

// ── Light navy-blue used as snackbar background ──────────────
const Color _snackBg     = Color(0xFF1B2A5E); // light navy blue
const Color _snackBorder = Color(0xFFEF4444); // red border outline

String friendlyError(dynamic e) {
  // Strip all known exception/error prefixes so raw "Exception: xyz" never shows
  String raw = e.toString();

  // Remove common Flutter / Firebase / Dart prefixes (repeat until clean)
  final prefixes = [
    'Exception: ',
    'FirebaseException: ',
    'FirebaseAuthException: ',
    '[firebase_auth/email-already-in-use] ',
    '[firebase_auth/',
    '[cloud_firestore/',
  ];

  bool changed = true;
  while (changed) {
    changed = false;
    for (final p in prefixes) {
      if (raw.startsWith(p)) {
        raw = raw.substring(p.length).trim();
        changed = true;
      }
    }
  }

  // Remove trailing "] code" fragments left by Firebase error codes
  raw = raw.replaceAll(RegExp(r'^\[[\w/-]+\]\s*'), '');

  // Friendly message map — keyed on fragments that may appear in the raw string
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
    'weak-password':            'Password is too weak. Use at least 6 characters.',
    'invalid-email':            'Please enter a valid email address.',
    'too-many-requests':        'Too many attempts. Please wait a moment and try again.',
    'requires-recent-login':    'Please log in again to complete this action.',
    'Cancel window has closed': 'Booking can only be cancelled within 5 minutes of acceptance.',
    'Booking not found':        'Booking not found.',
    'User not found':           'User account not found. Please log in again.',
    'User profile not found':   'User profile not found. Please log in again.',
    'Already rated':            'You have already rated this ride.',
    'You have already booked':  'You have already booked this ride.',
  };

  for (final entry in map.entries) {
    if (raw.contains(entry.key)) return entry.value;
  }

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
        side: const BorderSide(color: _snackBorder, width: 1.5),
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
        side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}