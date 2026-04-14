import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'RideTogether';
  static const String companyDomain = '@gmail.com';

  // ── Firestore Collections ─────────────────────────────────────────
  static const String usersCollection = 'users';
  static const String ridesCollection = 'rides';
  static const String bookingsCollection = 'bookings';
  static const String ratingsCollection = 'ratings';
  static const String chatsCollection = 'chats';
  static const String notificationsCollection = 'notifications';

  // ── Ride Status ───────────────────────────────────────────────────
  static const String rideUpcoming = 'upcoming';
  static const String rideActive = 'active';
  static const String rideCompleted = 'completed';
  static const String rideCancelled = 'cancelled';

  // ── Booking Status ────────────────────────────────────────────────
  static const String bookingPending = 'pending';
  static const String bookingAccepted = 'accepted';
  static const String bookingRejected = 'rejected';
  static const String bookingCompleted = 'completed';
  static const String bookingCancelled = 'cancelled';

  // ── User Roles ────────────────────────────────────────────────────
  static const String roleEmployee = 'employee';
  static const String roleApprentice = 'apprentice';
  static const String roleIntern = 'intern';
  static const String roleAdmin = 'admin';

  // ── Role Labels ────────────────────────────────────────────────────
  static const Map<String, String> roleLabels = {
    roleEmployee: 'Employee',
    roleApprentice: 'Apprentice',
    roleIntern: 'Intern',
    roleAdmin: 'Admin',
  };

  // ── Role List for Dropdown ─────────────────────────────────────────
  static const List<Map<String, String>> roles = [
    {'value': roleEmployee, 'label': 'Employee'},
    {'value': roleApprentice, 'label': 'Apprentice'},
    {'value': roleIntern, 'label': 'Intern'},
    {'value': roleAdmin, 'label': 'Admin'},
  ];

  // ── Companies ─────────────────────────────────────────────────────
  static const List<String> companies = [
    'FFC',
    'OLIVE',
    'Sone',
    'Foji Foods',
  ];

  // ── Departments ───────────────────────────────────────────────────
  static const List<String> departments = [
    'IoT',
    'Engineering',
    'Marketing',
    'Finance',
    'HR',
    'Operations',
    'Sales',
    'Design',
    'Legal',
    'Admin',
    'IT',
    'Other',
  ];

  // ── Shared Prefs Keys ─────────────────────────────────────────────
  static const String prefUserRole = 'user_role';
  static const String prefOnboarded = 'onboarded';
}