class AppConstants {
  static const String appName = 'RideTogether';
  static const String companyDomain = '@gmail.com';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String ridesCollection = 'rides';
  static const String bookingsCollection = 'bookings';
  static const String ratingsCollection = 'ratings';
  static const String chatsCollection = 'chats';
  static const String notificationsCollection = 'notifications';

  // Ride Status
  static const String rideUpcoming = 'upcoming';
  static const String rideActive = 'active';
  static const String rideCompleted = 'completed';
  static const String rideCancelled = 'cancelled';

  // Booking Status
  static const String bookingPending = 'pending';
  static const String bookingAccepted = 'accepted';
  static const String bookingRejected = 'rejected';
  static const String bookingCompleted = 'completed';
  static const String bookingCancelled = 'cancelled';

  // User Roles
  static const String roleDriver = 'driver';
  static const String rolePassenger = 'passenger';
  static const String roleBoth = 'both';
  static const String roleAdmin = 'admin';

  // Shared Prefs Keys
  static const String prefUserRole = 'user_role';
  static const String prefOnboarded = 'onboarded';
}
