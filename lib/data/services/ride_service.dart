// lib/data/services/ride_service.dart
// Pure frontend mock — Firestore nahi hai

import '../models/ride_model.dart';
import '../models/booking_model.dart';

// Mock rides data
final _mockRides = [
  RideModel(
    id: 'ride_001',
    driverId: 'user_002',
    driverName: 'Ali Hassan',
    driverRating: 4.8,
    startPoint: LocationPoint(address: 'DHA Phase 5, Lahore', lat: 31.4816, lng: 74.3985),
    endPoint: LocationPoint(address: 'Office, Gulberg III, Lahore', lat: 31.5204, lng: 74.3587),
    departureTime: DateTime.now().add(const Duration(hours: 2)),
    totalSeats: 4,
    availableSeats: 2,
    status: 'upcoming',
    notes: 'Will pick from main gate',
    passengerIds: ['user_003'],
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  RideModel(
    id: 'ride_002',
    driverId: 'user_004',
    driverName: 'Ayesha Khan',
    driverRating: 4.5,
    startPoint: LocationPoint(address: 'Johar Town, Lahore', lat: 31.4697, lng: 74.2728),
    endPoint: LocationPoint(address: 'Office, Gulberg III, Lahore', lat: 31.5204, lng: 74.3587),
    departureTime: DateTime.now().add(const Duration(hours: 3, minutes: 30)),
    totalSeats: 3,
    availableSeats: 1,
    status: 'upcoming',
    passengerIds: ['user_005', 'user_006'],
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  RideModel(
    id: 'ride_003',
    driverId: 'user_001',
    driverName: 'Sara Ahmed',
    driverRating: 4.7,
    startPoint: LocationPoint(address: 'Model Town, Lahore', lat: 31.4833, lng: 74.3291),
    endPoint: LocationPoint(address: 'Office, Gulberg III, Lahore', lat: 31.5204, lng: 74.3587),
    departureTime: DateTime.now().add(const Duration(days: 1, hours: 8)),
    totalSeats: 4,
    availableSeats: 3,
    status: 'upcoming',
    passengerIds: [],
    createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
  ),
  RideModel(
    id: 'ride_004',
    driverId: 'user_002',
    driverName: 'Ali Hassan',
    driverRating: 4.8,
    startPoint: LocationPoint(address: 'Bahria Town, Lahore', lat: 31.3660, lng: 74.2138),
    endPoint: LocationPoint(address: 'Office, Gulberg III, Lahore', lat: 31.5204, lng: 74.3587),
    departureTime: DateTime.now().subtract(const Duration(hours: 5)),
    totalSeats: 4,
    availableSeats: 0,
    status: 'completed',
    passengerIds: ['user_001', 'user_003', 'user_005'],
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

class RideService {
  Future<String> createRide(RideModel ride) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return 'ride_new_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<List<RideModel>> searchRides({required DateTime date}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockRides
        .where((r) =>
            r.status == 'upcoming' &&
            r.departureTime.isAfter(DateTime.now()) &&
            r.availableSeats > 0)
        .toList();
  }

  Future<RideModel?> getRideById(String rideId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _mockRides.firstWhere((r) => r.id == rideId);
    } catch (_) {
      return null;
    }
  }

  // Driver ke rides
  Stream<List<RideModel>> getDriverRides(String driverId) async* {
    await Future.delayed(const Duration(milliseconds: 400));
    yield _mockRides.where((r) => r.driverId == driverId).toList();
  }

  // Passenger ke rides
  Stream<List<RideModel>> getPassengerRides(String passengerId) async* {
    await Future.delayed(const Duration(milliseconds: 400));
    yield _mockRides
        .where((r) => r.passengerIds.contains(passengerId))
        .toList();
  }

  Future<void> updateRideStatus(String rideId, String status) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> cancelRide(String rideId) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Booking
  Future<String> createBooking(BookingModel booking) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return 'booking_${DateTime.now().millisecondsSinceEpoch}';
  }

  Stream<List<BookingModel>> getRideBookings(String rideId) async* {
    await Future.delayed(const Duration(milliseconds: 400));
    yield []; // Empty for now
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> submitRating({
    required String rideId,
    required String raterId,
    required String ratedId,
    required double rating,
    String? comment,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Admin
  Future<List<RideModel>> getAllRides() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockRides;
  }
}