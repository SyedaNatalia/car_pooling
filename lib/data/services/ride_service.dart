import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';
import '../../core/constants/app_constants.dart';

class RideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference get _rides =>
      _firestore.collection(AppConstants.ridesCollection);
  CollectionReference get _bookings =>
      _firestore.collection(AppConstants.bookingsCollection);
  CollectionReference get _ratings =>
      _firestore.collection(AppConstants.ratingsCollection);
  CollectionReference get _notifications =>
      _firestore.collection(AppConstants.notificationsCollection);

  // ── FIX 1: Duplicate ride prevention ────────────────────────────
  // Check karta hai k driver ka koi upcoming/active ride already exist karta hai
  Future<bool> hasActiveRide(String driverId) async {
    final snap = await _rides
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          AppConstants.rideUpcoming,
          AppConstants.rideActive,
        ])
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── FIX 2: createRide with duplicate guard ───────────────────────
  Future<String> createRide(RideModel ride) async {
    // Publish karne se pehle check karo k already ek active ride hai
    final alreadyActive = await hasActiveRide(ride.driverId);
    if (alreadyActive) {
      throw Exception(
        'You have already published a ride. Please complete or cancel it before offering a new one.',
      );
    }
    final docRef = await _rides.add(ride.toMap());
    return docRef.id;
  }

  // ── FIX 3: searchRides — deduplicate + expire past rides ─────────
  Future<List<RideModel>> searchRides({
    required DateTime date,
    String? excludeDriverId,
  }) async {
    final driverToExclude = excludeDriverId ?? _currentUid;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay   = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await _rides
        .where('status', isEqualTo: AppConstants.rideUpcoming)
        .where('departureTime',
            isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('departureTime',
            isLessThanOrEqualTo: endOfDay.toIso8601String())
        .orderBy('departureTime')
        .get();

    final now = DateTime.now();

    // Unique IDs track karo taake duplicates na aayein
    final seen = <String>{};

    return snapshot.docs
        .map((d) => RideModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .where((r) {
          if (seen.contains(r.id)) return false; // duplicate skip
          seen.add(r.id);
          return r.availableSeats > 0 &&
              r.driverId != driverToExclude &&
              r.departureTime.isAfter(now); // FIX: expired rides hide
        })
        .toList();
  }

  Future<RideModel?> getRideById(String rideId) async {
    final doc = await _rides.doc(rideId).get();
    if (!doc.exists) return null;
    return RideModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Stream<RideModel?> streamRide(String rideId) {
    return _rides.doc(rideId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RideModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  Stream<List<RideModel>> getDriverRides(String driverId) {
    return _rides.where('driverId', isEqualTo: driverId).snapshots().map((snap) {
      final seen  = <String>{};
      final list  = snap.docs
          .map((d) => RideModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .where((r) => seen.add(r.id)) // deduplicate
          .toList();
      list.sort((a, b) => b.departureTime.compareTo(a.departureTime));
      return list;
    });
  }

  Stream<List<RideModel>> getPassengerRides(String passengerId) {
    return _rides
        .where('passengerIds', arrayContains: passengerId)
        .snapshots()
        .map((snap) {
      final seen = <String>{};
      final list = snap.docs
          .map((d) => RideModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .where((r) => seen.add(r.id)) // deduplicate
          .toList();
      list.sort((a, b) => b.departureTime.compareTo(a.departureTime));
      return list;
    });
  }

  Future<void> updateRideStatus(String rideId, String status) async {
    await _rides.doc(rideId).update({'status': status});
    final rideDoc = await _rides.doc(rideId).get();
    if (!rideDoc.exists) return;
    final ride = RideModel.fromMap(rideDoc.data() as Map<String, dynamic>, rideId);

    String title = '', body = '', type = 'ride_status';
    if (status == AppConstants.rideActive) {
      title = 'Ride Started 🚗'; body = 'Your ride with ${ride.driverName} has started!'; type = 'ride_started';
    } else if (status == AppConstants.rideCompleted) {
      title = 'Ride Completed ✅'; body = 'Ride complete. Please rate your experience.'; type = 'ride_completed';
    } else if (status == AppConstants.rideCancelled) {
      title = 'Ride Cancelled ❌'; body = 'Your ride with ${ride.driverName} was cancelled.'; type = 'ride_cancelled';
    }
    if (title.isNotEmpty) {
      for (final uid in ride.passengerIds) {
        // FIX: driver ko apni ride ka notification na bhejo
        if (uid != ride.driverId) {
          await _saveNotif(userId: uid, title: title, body: body, type: type, rideId: rideId);
        }
      }
    }
  }

  Future<void> cancelRide(String rideId) async {
    final batch = _firestore.batch();
    batch.update(_rides.doc(rideId), {'status': AppConstants.rideCancelled});
    final snap = await _bookings
        .where('rideId', isEqualTo: rideId)
        .where('status', whereIn: [AppConstants.bookingPending, AppConstants.bookingAccepted])
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'status': AppConstants.bookingCancelled});
    }
    await batch.commit();

    final rideDoc = await _rides.doc(rideId).get();
    if (rideDoc.exists) {
      final ride = RideModel.fromMap(rideDoc.data() as Map<String, dynamic>, rideId);
      for (final uid in ride.passengerIds) {
        // FIX: driver ko apni hi ride cancel ka notification na aye
        if (uid != ride.driverId) {
          await _saveNotif(userId: uid, title: 'Ride Cancelled ❌',
              body: 'Ride with ${ride.driverName} cancelled.', type: 'ride_cancelled', rideId: rideId);
        }
      }
    }
  }

  Future<String> createBooking(BookingModel booking) async {
    final existing = await _bookings
        .where('rideId', isEqualTo: booking.rideId)
        .where('passengerId', isEqualTo: booking.passengerId)
        .where('status', whereIn: [AppConstants.bookingPending, AppConstants.bookingAccepted])
        .get();
    if (existing.docs.isNotEmpty) throw Exception('You have already booked this ride.');

    final docRef = await _bookings.add(booking.toMap());

    // FIX: Driver ko notify karo — lekin sirf tab jab passenger != driver
    final rideDoc = await _rides.doc(booking.rideId).get();
    if (rideDoc.exists) {
      final ride = RideModel.fromMap(rideDoc.data() as Map<String, dynamic>, booking.rideId);
      // Agar passenger aur driver same nahi hain tabhi notification bheji jayegi
      if (ride.driverId != booking.passengerId) {
        await _saveNotif(
          userId: ride.driverId,
          title: 'New Booking Request 🙋',
          body: '${booking.passengerName} wants to join your ride.',
          type: 'booking_request',
          rideId: booking.rideId,
        );
      }
    }
    return docRef.id;
  }

  Stream<List<BookingModel>> getRideBookings(String rideId) {
    return _bookings.where('rideId', isEqualTo: rideId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => BookingModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  Stream<List<BookingModel>> getPassengerBookings(String passengerId) {
    return _bookings.where('passengerId', isEqualTo: passengerId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => BookingModel.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> updateBookingStatus(String bookingId, String status) async {
    final bookingDoc = await _bookings.doc(bookingId).get();
    if (!bookingDoc.exists) throw Exception('Booking not found');
    final booking = BookingModel.fromMap(bookingDoc.data() as Map<String, dynamic>, bookingDoc.id);

    final batch = _firestore.batch();
    batch.update(_bookings.doc(bookingId), {'status': status});

    if (status == AppConstants.bookingAccepted) {
      batch.update(_rides.doc(booking.rideId), {
        'availableSeats': FieldValue.increment(-1),
        'passengerIds': FieldValue.arrayUnion([booking.passengerId]),
      });
    } else if (status == AppConstants.bookingRejected || status == AppConstants.bookingCancelled) {
      if (booking.status == AppConstants.bookingAccepted) {
        batch.update(_rides.doc(booking.rideId), {
          'availableSeats': FieldValue.increment(1),
          'passengerIds': FieldValue.arrayRemove([booking.passengerId]),
        });
      }
    }
    await batch.commit();

    String title = '', body = '', type = 'booking_update';
    if (status == AppConstants.bookingAccepted) {
      title = 'Booking Accepted ✅'; body = 'Your booking was accepted! Get ready.'; type = 'booking_accepted';
    } else if (status == AppConstants.bookingRejected) {
      title = 'Booking Not Accepted'; body = 'Your request was not accepted by the driver.'; type = 'booking_rejected';
    }
    if (title.isNotEmpty) {
      await _saveNotif(userId: booking.passengerId, title: title, body: body,
          type: type, rideId: booking.rideId);
    }
  }

  Future<void> notifyMessage({
    required String rideId,
    required String senderId,
    required String senderName,
    required String message,
  }) async {
    final rideDoc = await _rides.doc(rideId).get();
    if (!rideDoc.exists) return;
    final ride = RideModel.fromMap(rideDoc.data() as Map<String, dynamic>, rideId);

    final participants = <String>{ride.driverId, ...ride.passengerIds};
    participants.remove(senderId);

    final truncated = message.length > 60 ? '${message.substring(0, 60)}...' : message;
    for (final uid in participants) {
      await _saveNotif(
        userId: uid,
        title: '$senderName 💬',
        body: truncated,
        type: 'new_message',
        rideId: rideId,
      );
    }
  }

  Future<void> _saveNotif({
    required String userId, required String title,
    required String body, required String type, String? rideId,
  }) async {
    try {
      await _notifications.add({
        'userId':    userId,
        'title':     title,
        'body':      body,
        'type':      type,
        'rideId':    rideId,
        'isRead':    false,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> submitRating({
    required String rideId, required String raterId,
    required String ratedId, required double rating, String? comment,
  }) async {
    final existing = await _ratings
        .where('rideId', isEqualTo: rideId).where('raterId', isEqualTo: raterId)
        .where('ratedId', isEqualTo: ratedId).get();
    if (existing.docs.isNotEmpty) throw Exception('Already rated.');

    final batch = _firestore.batch();
    batch.set(_ratings.doc(), {
      'rideId': rideId, 'raterId': raterId, 'ratedId': ratedId,
      'rating': rating, 'comment': comment, 'createdAt': DateTime.now().toIso8601String(),
    });

    final userDoc = await _firestore.collection(AppConstants.usersCollection).doc(ratedId).get();
    if (userDoc.exists) {
      final d = userDoc.data()!;
      final cur   = (d['rating'] ?? 0.0).toDouble();
      final total = (d['totalRides'] ?? 0) as int;
      final nt    = total + 1;
      final nr    = ((cur * total) + rating) / nt;
      batch.update(_firestore.collection(AppConstants.usersCollection).doc(ratedId),
          {'rating': double.parse(nr.toStringAsFixed(1)), 'totalRides': nt});
    }
    await batch.commit();
  }

  Future<bool> hasRated({
    required String rideId, required String raterId, required String ratedId,
  }) async {
    final snap = await _ratings.where('rideId', isEqualTo: rideId)
        .where('raterId', isEqualTo: raterId).where('ratedId', isEqualTo: ratedId).get();
    return snap.docs.isNotEmpty;
  }

  Future<List<RideModel>> getAllRides() async {
    final snap = await _rides.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => RideModel.fromMap(d.data() as Map<String, dynamic>, d.id)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snap = await _firestore.collection(AppConstants.usersCollection).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  }

  Future<void> toggleUserStatus(String uid, bool isActive) async {
    await _firestore.collection(AppConstants.usersCollection).doc(uid).update({'isActive': isActive});
  }
}