import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'FairFare Carpool';
  static const String companyDomain = '@olivetech.com.pk';

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
  static const String rideExpired   = 'expired';

  // ── Booking Status ────────────────────────────────────────────────
  static const String bookingPending = 'pending';
  static const String bookingAccepted = 'accepted';
  static const String bookingRejected = 'rejected';
  static const String bookingCompleted = 'completed';
  static const String bookingCancelled = 'cancelled';
  static const String bookingExpired = 'expired';

  // ── User Roles ────────────────────────────────────────────────────
  static const String roleEmployee = 'employee';
  static const String roleApprentice = 'apprentice';
  static const String roleIntern = 'intern';
  static const String roleAdmin = 'admin';
  static const String roleHeadSmartSolutions = 'head_smart_solutions';
  static const String roleHeadRenewableEnergy = 'head_renewable_energy';
  static const String roleHeadBusinessDev = 'head_business_development';

  // ── Role Labels ────────────────────────────────────────────────────
  static const Map<String, String> roleLabels = {
    roleEmployee:            'Employee',
    roleApprentice:          'Apprentice',
    roleIntern:              'Intern',
    roleAdmin:               'Admin',
    roleHeadSmartSolutions:  'Head of Smart Solutions',
    roleHeadRenewableEnergy: 'Head of Renewable Energy',
    roleHeadBusinessDev:     'Head of Business Development',
  };

  // ── Role List for Dropdown ─────────────────────────────────────────
  static const List<Map<String, String>> roles = [
    {'value': roleEmployee,            'label': 'Employee'},
    {'value': roleApprentice,          'label': 'Apprentice'},
    {'value': roleIntern,              'label': 'Intern'},
    {'value': roleHeadSmartSolutions,  'label': 'Head of Smart Solutions'},
    {'value': roleHeadRenewableEnergy, 'label': 'Head of Renewable Energy'},
    {'value': roleHeadBusinessDev,     'label': 'Head of Business Development'},
    {'value': roleAdmin,               'label': 'Admin'},
  ];

  // ── Companies ─────────────────────────────────────────────────────
  static const List<String> companies = [
    'OliveTech',
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
    'Renewable Energy',
    'Business Development',
    'Other',
  ];

  // ── Shared Prefs Keys ─────────────────────────────────────────────
  static const String prefUserRole = 'user_role';
  static const String prefOnboarded = 'onboarded';
}