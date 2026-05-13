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

  // ── Duplicate ride prevention ────────────────────────────
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

  // ── Rider active booking check ───────────────────────────────
  Future<bool> hasActivePendingBooking(String passengerId) async {
    final snap = await _bookings
        .where('passengerId', isEqualTo: passengerId)
        .where('status', whereIn: [
          AppConstants.bookingPending,
          AppConstants.bookingAccepted,
        ])
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── createRide with duplicate guard ───────────────────────
  Future<String> createRide(RideModel ride) async {
    final alreadyActive = await hasActiveRide(ride.driverId);
    if (alreadyActive) {
      throw Exception(
        'You have already published a ride. Please complete or cancel it before offering a new one.',
      );
    }
    final docRef = await _rides.add(ride.toMap());
    return docRef.id;
  }

  Future<List<RideModel>> searchRidesByStatus({
    required String status,
    required DateTime date,
    String? excludeDriverId,
    String? fromCity,
    String? toCity,
    double? maxPrice,
    int? seatsNeeded,
  }) async {
    final driverToExclude = excludeDriverId ?? _currentUid;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay   = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final now        = DateTime.now();

    final snap = await _rides
        .where('status', isEqualTo: status)
        .get();

    return snap.docs
        .map((d) => RideModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .where((r) {
          if (r.availableSeats <= 0)         return false;
          if (r.driverId == driverToExclude) return false;
          if (r.departureTime.isBefore(startOfDay) ||
              r.departureTime.isAfter(endOfDay)) {
            return false;
          }
          if (status == 'upcoming' && !r.departureTime.isAfter(now)) return false;
          if (maxPrice != null && maxPrice > 0 && r.pricePerSeat > maxPrice) return false;
          if (seatsNeeded != null && seatsNeeded > 0 &&
              r.availableSeats < seatsNeeded) {
            return false;
          }

          final hasFrom = fromCity != null && fromCity.trim().isNotEmpty;
          final hasTo   = toCity   != null && toCity.trim().isNotEmpty;
          if (!hasFrom && !hasTo) return true;

          bool fromOk = true, toOk = true;
          if (hasFrom) {
            final q = fromCity!.toLowerCase().trim();
            fromOk  = r.startPoint.address.toLowerCase().contains(q) ||
                      r.stops.any((s) => s.address.toLowerCase().contains(q));
          }
          if (hasTo) {
            final q = toCity!.toLowerCase().trim();
            toOk    = r.endPoint.address.toLowerCase().contains(q) ||
                      r.stops.any((s) => s.address.toLowerCase().contains(q));
          }
          if (hasFrom && hasTo) return fromOk && toOk;
          if (hasFrom) return fromOk;
          if (hasTo)   return toOk;
          return true;
        })
        .toList();
  }

  Future<List<RideModel>> searchRides({
    required DateTime date,
    String? excludeDriverId,
    String? fromCity,
    String? toCity,
    double? maxPrice,
    int? seatsNeeded,
  }) async {
    final driverToExclude = excludeDriverId ?? _currentUid;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay   = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final now        = DateTime.now();

    final snapUpcoming = await _rides
        .where('status', isEqualTo: AppConstants.rideUpcoming)
        .get();
    final snapActive = await _rides
        .where('status', isEqualTo: AppConstants.rideActive)
        .get();

    final allDocs = [...snapUpcoming.docs, ...snapActive.docs];
    final seen    = <String>{};

    final results = allDocs
        .map((d) => RideModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .where((r) {
          // Deduplicate
          if (!seen.add(r.id)) return false;

          // Must have seats
          if (r.availableSeats <= 0) return false;

          // Exclude own rides
          if (r.driverId == driverToExclude) return false;

          // Date filter — departure must fall on selected day
          if (r.departureTime.isBefore(startOfDay) ||
              r.departureTime.isAfter(endOfDay)) {
            return false;
          }

          // Upcoming rides must still be in the future
          if (r.status == AppConstants.rideUpcoming &&
              !r.departureTime.isAfter(now)) {
            return false;
          }

          // Price filter
          if (maxPrice != null && maxPrice > 0 && r.pricePerSeat > maxPrice) {
            return false;
          }

          // Seats filter
          if (seatsNeeded != null &&
              seatsNeeded > 0 &&
              r.availableSeats < seatsNeeded) {
            return false;
          }

          // ── Route matching ─────────────────────────────────────────
          final hasFromFilter = fromCity != null && fromCity.trim().isNotEmpty;
          final hasToFilter   = toCity   != null && toCity.trim().isNotEmpty;

          if (!hasFromFilter && !hasToFilter) return true;

          bool fromOk = true;
          bool toOk   = true;

          if (hasFromFilter) {
            final query      = fromCity!.toLowerCase().trim();
            final rStart     = r.startPoint.address.toLowerCase();
            final startMatch = rStart.contains(query);
            final stopMatch  = r.stops.any(
              (s) => s.address.toLowerCase().contains(query),
            );
            fromOk = startMatch || stopMatch;
          }

          if (hasToFilter) {
            final query     = toCity!.toLowerCase().trim();
            final rEnd      = r.endPoint.address.toLowerCase();
            final endMatch  = rEnd.contains(query);
            final stopMatch = r.stops.any(
              (s) => s.address.toLowerCase().contains(query),
            );
            toOk = endMatch || stopMatch;
          }

          if (hasFromFilter && hasToFilter) return fromOk && toOk;
          if (hasFromFilter) return fromOk;
          if (hasToFilter)   return toOk;
          return true;
        })
        .toList();

    results.sort((a, b) => a.departureTime.compareTo(b.departureTime));
    return results;
  }

  Stream<List<RideModel>> streamSearchRides({
    required DateTime date,
    String? excludeDriverId,
    String? fromCity,
    String? toCity,
    double? maxPrice,
    int? seatsNeeded,
  }) {
    final driverToExclude = excludeDriverId ?? _currentUid;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay   = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _rides
        .where('status', whereIn: [
          AppConstants.rideUpcoming,
          AppConstants.rideActive,
        ])
        .snapshots()
        .map((snap) {
          final now  = DateTime.now();
          final seen = <String>{};

          final filtered = snap.docs
              .map((d) => RideModel.fromMap(d.data() as Map<String, dynamic>, d.id))
              .where((r) {
                if (!seen.add(r.id))               return false;
                if (r.availableSeats <= 0)          return false;
                if (r.driverId == driverToExclude)  return false;
                if (r.departureTime.isBefore(startOfDay) ||
                    r.departureTime.isAfter(endOfDay)) {
                  return false;
                }
                if (r.status == AppConstants.rideUpcoming &&
                    !r.departureTime.isAfter(now)) {
                  return false;
                }
                if (maxPrice != null && maxPrice > 0 &&
                    r.pricePerSeat > maxPrice) {
                  return false;
                }
                if (seatsNeeded != null && seatsNeeded > 0 &&
                    r.availableSeats < seatsNeeded) {
                  return false;
                }

                final hasFrom = fromCity != null && fromCity.trim().isNotEmpty;
                final hasTo   = toCity   != null && toCity.trim().isNotEmpty;
                if (!hasFrom && !hasTo) return true;

                bool fromOk = true, toOk = true;
                if (hasFrom) {
                  final q = fromCity!.toLowerCase().trim();
                  fromOk  = r.startPoint.address.toLowerCase().contains(q) ||
                            r.stops.any((s) => s.address.toLowerCase().contains(q));
                }
                if (hasTo) {
                  final q = toCity!.toLowerCase().trim();
                  toOk    = r.endPoint.address.toLowerCase().contains(q) ||
                            r.stops.any((s) => s.address.toLowerCase().contains(q));
                }
                if (hasFrom && hasTo) return fromOk && toOk;
                if (hasFrom) return fromOk;
                if (hasTo)   return toOk;
                return true;
              })
              .toList();

          filtered.sort((a, b) => a.departureTime.compareTo(b.departureTime));
          return filtered;
        });
  }

  // ── Passenger booking cancel ───────────────────────────────
  Future<void> cancelBooking(String bookingId) async {
    final bookingDoc = await _bookings.doc(bookingId).get();
    if (!bookingDoc.exists) throw Exception('Booking not found');
    final booking = BookingModel.fromMap(
        bookingDoc.data() as Map<String, dynamic>, bookingDoc.id);

    if (booking.status == AppConstants.bookingCancelled) return;

    await _bookings.doc(bookingId).update({'status': AppConstants.bookingCancelled});

    _cancelBookingBackground(booking);
  }

  void _cancelBookingBackground(BookingModel booking) {
    Future(() async {
      if (booking.status == AppConstants.bookingAccepted) {
        try {
          await _rides.doc(booking.rideId).update({
            'availableSeats': FieldValue.increment(booking.seatsNeeded),
            'passengerIds': FieldValue.arrayRemove([booking.passengerId]),
          });
        } catch (_) {
        }
      }

      try {
        final rideDoc = await _rides.doc(booking.rideId).get();
        if (rideDoc.exists) {
          final ride = RideModel.fromMap(
              rideDoc.data() as Map<String, dynamic>, booking.rideId);
          await _saveNotif(
            userId: ride.driverId,
            title: 'Booking Cancelled ❌',
            body: '${booking.passengerName} has cancelled their booking for your ride.',
            type: 'booking_cancelled',
            rideId: booking.rideId,
          );
          await _saveNotif(
            userId: booking.passengerId,
            title: 'Booking Cancelled',
            body: "Your booking for ${ride.driverName}'s ride has been cancelled.",
            type: 'booking_cancelled_self',
            rideId: booking.rideId,
          );
        }
      } catch (_) {}
    });
  }

  Future<void> autoExpireRides() async {
    try {
      final now = DateTime.now();

      final snapUpcoming = await _rides
          .where('status', isEqualTo: AppConstants.rideUpcoming)
          .get();
      final snapActive = await _rides
          .where('status', isEqualTo: AppConstants.rideActive)
          .get();

      final expiredUpcoming = snapUpcoming.docs.where((doc) {
        final ride = RideModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        return ride.departureTime.isBefore(now);
      }).toList();

      final expiredActive = snapActive.docs.where((doc) {
        final ride = RideModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        return ride.departureTime.add(const Duration(hours: 2)).isBefore(now);
      }).toList();

      final allExpiredDocs = [...expiredUpcoming, ...expiredActive];
      if (allExpiredDocs.isEmpty) return;

      final rideBatch = _firestore.batch();
      for (final doc in allExpiredDocs) {
        rideBatch.update(_rides.doc(doc.id), {'status': AppConstants.rideExpired});
      }
      await rideBatch.commit();

      for (final doc in allExpiredDocs) {
        final ride = RideModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        try {
          final bSnap = await _bookings
              .where('rideId', isEqualTo: doc.id)
              .where('status', whereIn: [
                AppConstants.bookingPending,
                AppConstants.bookingAccepted,
              ])
              .get();

          if (bSnap.docs.isNotEmpty) {
            final bBatch = _firestore.batch();
            for (final b in bSnap.docs) {
              bBatch.update(b.reference, {'status': AppConstants.bookingExpired});
            }
            await bBatch.commit();
          }

          // Passenger notifications
          for (final pid in ride.passengerIds) {
            if (pid != ride.driverId) {
              await _saveNotif(
                userId: pid,
                title: 'Ride Expired',
                body: 'Your booking for the ride with ${ride.driverName} has expired as the ride was not completed in time.',
                type: 'ride_expired',
                rideId: doc.id,
              );
            }
          }
          // Driver notification
          await _saveNotif(
            userId: ride.driverId,
            title: 'Ride Expired',
            body: 'Your ride has been automatically marked as expired as the departure time has passed.',
            type: 'ride_expired',
            rideId: doc.id,
          );
        } catch (_) {}
      }
    } catch (_) {}
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
      title = 'Ride Started 🚗'; body = 'Your ride with ${ride.driverName} has started! Have a safe trip.'; type = 'ride_started';
    } else if (status == AppConstants.rideCompleted) {
      title = 'Ride Completed ✅'; body = 'Your ride is complete. Please rate your experience.'; type = 'ride_completed';
    } else if (status == AppConstants.rideCancelled) {
      title = 'Ride Cancelled ❌'; body = 'Your ride with ${ride.driverName} has been cancelled by the driver.'; type = 'ride_cancelled';
    }
    if (title.isNotEmpty) {
      for (final uid in ride.passengerIds) {
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
        if (uid != ride.driverId) {
          await _saveNotif(
            userId: uid,
            title: 'Ride Cancelled ❌',
            body: 'The driver ${ride.driverName} has cancelled the ride. Your booking has been cancelled automatically.',
            type: 'ride_cancelled',
            rideId: rideId,
          );
        }
      }
      await _saveNotif(
        userId: ride.driverId,
        title: 'Ride Cancelled',
        body: 'Your ride has been cancelled successfully. All passengers have been notified.',
        type: 'ride_cancelled_self',
        rideId: rideId,
      );
    }
  }

  Future<String> createBooking(BookingModel booking) async {
    final existing = await _bookings
        .where('rideId', isEqualTo: booking.rideId)
        .where('passengerId', isEqualTo: booking.passengerId)
        .where('status', whereIn: [AppConstants.bookingPending, AppConstants.bookingAccepted])
        .get();
    if (existing.docs.isNotEmpty) throw Exception('You have already booked this ride.');

    final globalActive = await _bookings
        .where('passengerId', isEqualTo: booking.passengerId)
        .where('status', whereIn: [AppConstants.bookingPending, AppConstants.bookingAccepted])
        .get();
    if (globalActive.docs.isNotEmpty) {
      throw Exception(
        'You already have an active booking. Please complete or cancel it before joining a new ride.',
      );
    }

    final docRef = await _bookings.add(booking.toMap());

    final rideDoc = await _rides.doc(booking.rideId).get();
    if (rideDoc.exists) {
      final ride = RideModel.fromMap(rideDoc.data() as Map<String, dynamic>, booking.rideId);
      if (ride.driverId != booking.passengerId) {
        await _saveNotif(
          userId: ride.driverId,
          title: 'New Booking Request 🙋',
          body: '${booking.passengerName} has requested to join your ride.',
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
        'availableSeats': FieldValue.increment(-booking.seatsNeeded),
        'passengerIds': FieldValue.arrayUnion([booking.passengerId]),
      });
    } else if (status == AppConstants.bookingRejected || status == AppConstants.bookingCancelled) {

      if (booking.status == AppConstants.bookingAccepted) {
        batch.update(_rides.doc(booking.rideId), {
          'availableSeats': FieldValue.increment(booking.seatsNeeded),
          'passengerIds': FieldValue.arrayRemove([booking.passengerId]),
        });
      }
    }
    await batch.commit();

    String title = '', body = '', type = 'booking_update';
    if (status == AppConstants.bookingAccepted) {
      title = 'Booking Accepted ✅'; body = 'Your booking has been accepted! Get ready for your ride.'; type = 'booking_accepted';
    } else if (status == AppConstants.bookingRejected) {
      title = 'Booking Not Accepted'; body = 'The driver has declined your booking request.'; type = 'booking_rejected';
    }
    if (title.isNotEmpty) {
      await _saveNotif(userId: booking.passengerId, title: title, body: body,
          type: type, rideId: booking.rideId);
    }

    if (status == AppConstants.bookingAccepted) {
      String passengerPhone = '';
      try {
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(booking.passengerId)
            .get();
        passengerPhone = userDoc.data()?['phone'] as String? ?? '';
      } catch (_) {}

      final rideDoc2 = await _rides.doc(booking.rideId).get();
      if (rideDoc2.exists) {
        final ride2 = RideModel.fromMap(rideDoc2.data() as Map<String, dynamic>, booking.rideId);
        await _saveNotif(
          userId: ride2.driverId,
          title: 'Ride Confirmed ✅',
          body: '${booking.passengerName} is confirmed for your ride.',
          type: 'booking_accepted_driver',
          rideId: booking.rideId,
          extraData: passengerPhone.isNotEmpty ? {'passengerPhone': passengerPhone} : null,
        );
      }
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
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final data = {
        'userId':    userId,
        'title':     title,
        'body':      body,
        'type':      type,
        'rideId':    rideId,
        'isRead':    false,
        'createdAt': DateTime.now().toIso8601String(),
      };
      if (extraData != null) data.addAll(extraData);
      await _notifications.add(data);
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
      final cur          = (d['rating'] ?? 0.0).toDouble();
      final totalRatings = (d['totalRatings'] ?? 0) as int;
      final newTotal     = totalRatings + 1;
      final newRating    = ((cur * totalRatings) + rating) / newTotal;
      batch.update(_firestore.collection(AppConstants.usersCollection).doc(ratedId), {
        'rating': double.parse(newRating.toStringAsFixed(1)),
        'totalRatings': newTotal,
        // NOTE: totalRides is NOT touched here
      });
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