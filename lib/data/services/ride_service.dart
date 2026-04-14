import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../../core/constants/app_constants.dart';

class RideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _rides =>
      _firestore.collection(AppConstants.ridesCollection);

  CollectionReference get _bookings =>
      _firestore.collection(AppConstants.bookingsCollection);

  CollectionReference get _ratings =>
      _firestore.collection(AppConstants.ratingsCollection);

  // ─── Create Ride ──────────────────────────────────────────────────
  Future<String> createRide(RideModel ride) async {
    final docRef = await _rides.add(ride.toMap());
    return docRef.id;
  }

  Future<List<RideModel>> searchRides({required DateTime date}) async {
    final startOfDay =
        DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay =
        DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _rides
        .where('status', isEqualTo: AppConstants.rideUpcoming)
        .where('departureTime',
            isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('departureTime',
            isLessThanOrEqualTo: endOfDay.toIso8601String())
        .orderBy('departureTime')
        .get();

    final rides = snapshot.docs
        .map((doc) => RideModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .toList();

    // availableSeats filter in-memory (Firestore restriction ki wajah se)
    return rides.where((r) => r.availableSeats > 0).toList();
  }

  // ─── Get Ride by ID ───────────────────────────────────────────────
  Future<RideModel?> getRideById(String rideId) async {
    final doc = await _rides.doc(rideId).get();
    if (!doc.exists) return null;
    return RideModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  // ─── Stream single ride (realtime) ───────────────────────────────
  Stream<RideModel?> streamRide(String rideId) {
    return _rides.doc(rideId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RideModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  // ─── Driver's Rides ───────────────────────────────────────────────
  // Required index: driverId ASC → departureTime DESC
  Stream<List<RideModel>> getDriverRides(String driverId) {
    return _rides
        .where('driverId', isEqualTo: driverId)
        .orderBy('departureTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RideModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList());
  }

  // ─── Passenger's Rides ────────────────────────────────────────────
  // Required index: passengerIds ASC → departureTime DESC
  Stream<List<RideModel>> getPassengerRides(String passengerId) {
    return _rides
        .where('passengerIds', arrayContains: passengerId)
        .orderBy('departureTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => RideModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList());
  }

  // ─── Update Ride Status ───────────────────────────────────────────
  Future<void> updateRideStatus(String rideId, String status) async {
    await _rides.doc(rideId).update({'status': status});
  }

  // ─── Cancel Ride ──────────────────────────────────────────────────
  Future<void> cancelRide(String rideId) async {
    final batch = _firestore.batch();
    batch.update(_rides.doc(rideId), {'status': AppConstants.rideCancelled});

    final bookingsSnap = await _bookings
        .where('rideId', isEqualTo: rideId)
        .where('status', whereIn: [
          AppConstants.bookingPending,
          AppConstants.bookingAccepted,
        ])
        .get();

    for (final doc in bookingsSnap.docs) {
      batch.update(doc.reference, {'status': AppConstants.bookingCancelled});
    }

    await batch.commit();
  }

  // ─── Create Booking ───────────────────────────────────────────────
  Future<String> createBooking(BookingModel booking) async {
    final existing = await _bookings
        .where('rideId', isEqualTo: booking.rideId)
        .where('passengerId', isEqualTo: booking.passengerId)
        .where('status', whereIn: [
          AppConstants.bookingPending,
          AppConstants.bookingAccepted,
        ])
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('You have already booked this ride.');
    }

    final docRef = await _bookings.add(booking.toMap());
    return docRef.id;
  }

  // ─── Get Ride's Bookings ──────────────────────────────────────────
  // FIX: orderBy hata diya — simple single-field query
  // composite index ki zaroorat nahi
  // Sorting client-side ho rahi hai
  Stream<List<BookingModel>> getRideBookings(String rideId) {
    return _bookings
        .where('rideId', isEqualTo: rideId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => BookingModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
      // Client-side sort by createdAt
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  // ─── Get Passenger's Bookings ─────────────────────────────────────
  // FIX: same — orderBy hata ke client-side sort
  Stream<List<BookingModel>> getPassengerBookings(String passengerId) {
    return _bookings
        .where('passengerId', isEqualTo: passengerId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => BookingModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
      // Client-side sort: newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ─── Accept / Reject Booking ──────────────────────────────────────
  Future<void> updateBookingStatus(String bookingId, String status) async {
    final bookingDoc = await _bookings.doc(bookingId).get();
    if (!bookingDoc.exists) throw Exception('Booking not found');

    final booking = BookingModel.fromMap(
      bookingDoc.data() as Map<String, dynamic>,
      bookingDoc.id,
    );

    final batch = _firestore.batch();
    batch.update(_bookings.doc(bookingId), {'status': status});

    if (status == AppConstants.bookingAccepted) {
      batch.update(_rides.doc(booking.rideId), {
        'availableSeats': FieldValue.increment(-1),
        'passengerIds': FieldValue.arrayUnion([booking.passengerId]),
      });
    } else if (status == AppConstants.bookingRejected ||
        status == AppConstants.bookingCancelled) {
      if (booking.status == AppConstants.bookingAccepted) {
        batch.update(_rides.doc(booking.rideId), {
          'availableSeats': FieldValue.increment(1),
          'passengerIds': FieldValue.arrayRemove([booking.passengerId]),
        });
      }
    }

    await batch.commit();
  }

  // ─── Submit Rating ────────────────────────────────────────────────
  Future<void> submitRating({
    required String rideId,
    required String raterId,
    required String ratedId,
    required double rating,
    String? comment,
  }) async {
    final existing = await _ratings
        .where('rideId', isEqualTo: rideId)
        .where('raterId', isEqualTo: raterId)
        .where('ratedId', isEqualTo: ratedId)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('You have already rated this user for this ride.');
    }

    final batch = _firestore.batch();
    final ratingRef = _ratings.doc();
    batch.set(ratingRef, {
      'rideId': rideId,
      'raterId': raterId,
      'ratedId': ratedId,
      'rating': rating,
      'comment': comment,
      'createdAt': DateTime.now().toIso8601String(),
    });

    final userDoc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(ratedId)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data()!;
      final currentRating = (userData['rating'] ?? 0.0).toDouble();
      final totalRides = (userData['totalRides'] ?? 0) as int;
      final newTotalRides = totalRides + 1;
      final newRating =
          ((currentRating * totalRides) + rating) / newTotalRides;

      batch.update(
        _firestore.collection(AppConstants.usersCollection).doc(ratedId),
        {
          'rating': double.parse(newRating.toStringAsFixed(1)),
          'totalRides': newTotalRides,
        },
      );
    }

    await batch.commit();
  }

  // ─── Admin: Get All Rides ─────────────────────────────────────────
  Future<List<RideModel>> getAllRides() async {
    final snapshot =
        await _rides.orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => RideModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ))
        .toList();
  }

  // ─── Admin: Get All Users ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .toList();
  }

  // ─── Admin: Toggle User Active Status ────────────────────────────
  Future<void> toggleUserStatus(String uid, bool isActive) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'isActive': isActive});
  }
}