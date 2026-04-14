// lib/data/providers/app_providers.dart
// Riverpod providers — services, auth state, rides, bookings

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/ride_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';

// ─── Service Providers ────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final rideServiceProvider = Provider<RideService>((ref) => RideService());

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

// ─── Auth State ───────────────────────────────────────────────────────────────

/// Firebase auth stream — null means logged out
final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Current UserModel from Firestore (realtime)
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(firebaseAuthStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.read(authServiceProvider).streamUserProfile(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ─── Ride Providers ───────────────────────────────────────────────────────────

/// Driver's rides stream
final driverRidesProvider =
    StreamProvider.family<List<RideModel>, String>((ref, driverId) {
  return ref.read(rideServiceProvider).getDriverRides(driverId);
});

/// Passenger's rides stream
final passengerRidesProvider =
    StreamProvider.family<List<RideModel>, String>((ref, passengerId) {
  return ref.read(rideServiceProvider).getPassengerRides(passengerId);
});

/// Single ride stream (realtime)
final rideStreamProvider =
    StreamProvider.family<RideModel?, String>((ref, rideId) {
  return ref.read(rideServiceProvider).streamRide(rideId);
});

/// Search rides result — triggered manually
final searchRidesProvider =
    FutureProvider.family<List<RideModel>, DateTime>((ref, date) async {
  return ref.read(rideServiceProvider).searchRides(date: date);
});

// ─── Booking Providers ────────────────────────────────────────────────────────

/// Ride's bookings stream (for driver to manage requests)
final rideBookingsProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, rideId) {
  return ref.read(rideServiceProvider).getRideBookings(rideId);
});

/// Passenger's own bookings
final passengerBookingsProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, passengerId) {
  return ref.read(rideServiceProvider).getPassengerBookings(passengerId);
});

// ─── Chat Provider ────────────────────────────────────────────────────────────

final chatMessagesProvider =
    StreamProvider.family<List<dynamic>, String>((ref, rideId) {
  return ref.read(chatServiceProvider).streamMessages(rideId);
});

// ─── State Notifiers ─────────────────────────────────────────────────────────

/// Create ride notifier
class CreateRideNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> createRide(RideModel ride) async {
    state = const AsyncLoading();
    return await AsyncValue.guard(() async {
      final id = await ref.read(rideServiceProvider).createRide(ride);
      state = const AsyncData(null);
      return id;
    }).then((value) => value.value ?? '');
  }
}

final createRideProvider =
    AsyncNotifierProvider<CreateRideNotifier, void>(CreateRideNotifier.new);

/// Booking notifier
class BookingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String> createBooking(BookingModel booking) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(rideServiceProvider).createBooking(booking));
    state = result.hasError ? AsyncError(result.error!, StackTrace.empty) : const AsyncData(null);
    return result.value ?? '';
  }

  Future<void> updateStatus(String bookingId, String status) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(rideServiceProvider).updateBookingStatus(bookingId, status));
    state = result.hasError
        ? AsyncError(result.error!, StackTrace.empty)
        : const AsyncData(null);
  }
}

final bookingNotifierProvider =
    AsyncNotifierProvider<BookingNotifier, void>(BookingNotifier.new);

/// Profile update notifier
class ProfileNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(authServiceProvider).updateProfile(uid: uid, data: data));
    state = result.hasError
        ? AsyncError(result.error!, StackTrace.empty)
        : const AsyncData(null);
  }

  Future<void> updateCarDetails(String uid, CarDetails carDetails) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref
        .read(authServiceProvider)
        .updateCarDetails(uid: uid, carDetails: carDetails));
    state = result.hasError
        ? AsyncError(result.error!, StackTrace.empty)
        : const AsyncData(null);
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, void>(ProfileNotifier.new);