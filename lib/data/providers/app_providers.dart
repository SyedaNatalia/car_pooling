import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/ride_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../../core/constants/app_constants.dart';

// ─── Service Providers ────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final rideServiceProvider = Provider<RideService>((ref) => RideService());

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

// ─── Router Refresh ───────────────────────────────────────────────────────────

/// Increment this counter to force GoRouter to re-evaluate redirect guards.
/// Used after email verification because authStateChanges does not fire when
/// emailVerified flips — only on sign-in / sign-out events.
final routerRefreshProvider = StateProvider<int>((ref) => 0);

// ─── Auth State ───────────────────────────────────────────────────────────────

/// Firebase auth stream — null means logged out.
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Current UserModel from Firestore (realtime stream).
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(firebaseAuthStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authServiceProvider).streamUserProfile(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ─── Active Booking — single source of truth ─────────────────────────────────

/// Real-time stream of the current user's active (pending/accepted) booking.
/// Returns null when the user has no active booking.
final activeBookingProvider = StreamProvider.autoDispose<BookingModel?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(rideServiceProvider).streamActiveBooking(user.uid);
});

/// Real-time stream of the ride linked to the user's active booking.
/// Returns null when there is no active booking OR when the linked ride is
/// cancelled, expired, or completed — so stale bookings never surface a
/// dead ride on the home screen.
///
/// Also hides the banner client-side when the departure time is in the past
/// so it disappears as soon as the next Firestore snapshot arrives (which is
/// triggered by the periodic timer in HomeScreen calling autoExpireRides()).
final activeBookedRideProvider = StreamProvider.autoDispose<RideModel?>((ref) {
  final booking = ref.watch(activeBookingProvider).valueOrNull;
  if (booking == null) return Stream.value(null);
  return ref.watch(rideServiceProvider).streamRide(booking.rideId).map((ride) {
    if (ride == null) return null;
    const deadStatuses = {
      AppConstants.rideCancelled,
      AppConstants.rideExpired,
      AppConstants.rideCompleted,
    };
    if (deadStatuses.contains(ride.status)) return null;
    // Client-side guard: hide banner if the upcoming ride's departure time
    // has already passed (autoExpireRides will write the Firestore update
    // within the next minute, but this hides it immediately on re-evaluation).
    if (ride.status == AppConstants.rideUpcoming &&
        ride.departureTime.isBefore(DateTime.now())) {
      return null;
    }
    return ride;
  });
});

// ─── Role Restrictions — single source of truth ──────────────────────────────

/// True when the current user (as driver) has an upcoming or active offered ride.
/// Derived reactively from driverRidesProvider — no extra Firestore reads.
final hasActiveRideProvider = Provider.autoDispose<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;
  final rides = ref.watch(driverRidesProvider(user.uid)).valueOrNull ?? [];
  return rides.any(
    (r) =>
        r.status == AppConstants.rideUpcoming ||
        r.status == AppConstants.rideActive,
  );
});

/// True when the current user (as passenger) has an active booking AND the
/// linked ride is still upcoming/active. Derives from activeBookedRideProvider
/// so a cancelled or expired ride immediately releases the "Offer Ride" block.
final hasActiveBookingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(activeBookedRideProvider).valueOrNull != null;
});

// ─── Notification badge count — single stream shared across widgets ───────────

/// Unread notification count for the current user.  Sharing one StreamProvider
/// prevents HomeScreen header and the bottom-nav badge from each opening their
/// own Firestore listener for the same query.
final unreadNotifCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value(0);
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: user.uid)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);
});



/// Driver's rides stream — autoDispose prevents memory leaks for unused family args.
final driverRidesProvider =
    StreamProvider.autoDispose.family<List<RideModel>, String>((ref, driverId) {
  return ref.watch(rideServiceProvider).getDriverRides(driverId);
});

/// Passenger's accepted rides stream.
final passengerRidesProvider =
    StreamProvider.autoDispose.family<List<RideModel>, String>((ref, passengerId) {
  return ref.watch(rideServiceProvider).getPassengerRides(passengerId);
});

/// Single ride realtime stream.
final rideStreamProvider =
    StreamProvider.autoDispose.family<RideModel?, String>((ref, rideId) {
  return ref.watch(rideServiceProvider).streamRide(rideId);
});

/// Search results — triggered by date. Cached per date, auto-disposed when screen leaves.
final searchRidesProvider =
    FutureProvider.autoDispose.family<List<RideModel>, DateTime>((ref, date) {
  return ref.read(rideServiceProvider).searchRides(date: date);
});

// ─── Booking Providers ────────────────────────────────────────────────────────

/// All bookings for a ride (driver view — to manage requests).
final rideBookingsProvider =
    StreamProvider.autoDispose.family<List<BookingModel>, String>((ref, rideId) {
  return ref.watch(rideServiceProvider).getRideBookings(rideId);
});

/// All bookings made by a passenger.
final passengerBookingsProvider =
    StreamProvider.autoDispose.family<List<BookingModel>, String>((ref, passengerId) {
  return ref.watch(rideServiceProvider).getPassengerBookings(passengerId);
});

// ─── Chat Provider ────────────────────────────────────────────────────────────

final chatMessagesProvider =
    StreamProvider.autoDispose.family<List<dynamic>, String>((ref, rideId) {
  return ref.watch(chatServiceProvider).streamMessages(rideId);
});

// ─── State Notifiers ─────────────────────────────────────────────────────────

/// Handles ride creation. Errors are rethrown so the UI can display them.
class CreateRideNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> createRide(RideModel ride) async {
    state = const AsyncLoading();
    try {
      final id = await ref.read(rideServiceProvider).createRide(ride);
      state = const AsyncData(null);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final createRideProvider =
    AsyncNotifierProvider<CreateRideNotifier, void>(CreateRideNotifier.new);

/// Handles booking creation and status updates. Errors are rethrown so the UI
/// can display them via a snackbar or inline message.
class BookingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> createBooking(BookingModel booking) async {
    state = const AsyncLoading();
    try {
      final id = await ref.read(rideServiceProvider).createBooking(booking);
      state = const AsyncData(null);
      return id;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateStatus(String bookingId, String status) async {
    state = const AsyncLoading();
    try {
      await ref.read(rideServiceProvider).updateBookingStatus(bookingId, status);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final bookingNotifierProvider =
    AsyncNotifierProvider<BookingNotifier, void>(BookingNotifier.new);

/// Handles profile and car detail updates.
class ProfileNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    state = const AsyncLoading();
    try {
      await ref.read(authServiceProvider).updateProfile(uid: uid, data: data);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateCarDetails(String uid, CarDetails carDetails) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(authServiceProvider)
          .updateCarDetails(uid: uid, carDetails: carDetails);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, void>(ProfileNotifier.new);