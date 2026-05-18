import 'ride_model.dart';

class BookingModel {
  final String id;
  final String rideId;
  final String passengerId;
  final String passengerName;
  final String? passengerPhoto;
  final String? passengerGender;
  final LocationPoint pickupPoint;
  final int seatsNeeded;       
  final double offeredPrice;   
  final String status;
  final String? passengerNotes;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  BookingModel({
    required this.id,
    required this.rideId,
    required this.passengerId,
    required this.passengerName,
    this.passengerPhoto,
    this.passengerGender,
    required this.pickupPoint,
    this.seatsNeeded = 1,
    this.offeredPrice = 0,
    required this.status,
    this.passengerNotes,
    required this.createdAt,
    this.acceptedAt,
  });

  factory BookingModel.fromMap(Map<String, dynamic> data, String id) {
    return BookingModel(
      id: id,
      rideId:          data['rideId']          ?? '',
      passengerId:     data['passengerId']      ?? '',
      passengerName:   data['passengerName']    ?? '',
      passengerPhoto:  data['passengerPhoto'],
      passengerGender: data['passengerGender'],
      pickupPoint:     LocationPoint.fromMap(data['pickupPoint'] ?? {}),
      seatsNeeded:     data['seatsNeeded']      ?? 1,
      offeredPrice:    (data['offeredPrice']    ?? 0.0).toDouble(),
      status:          data['status']           ?? 'pending',
      passengerNotes:  data['passengerNotes'],
      createdAt:       data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      acceptedAt:      data['acceptedAt'] != null
          ? DateTime.parse(data['acceptedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'rideId':          rideId,
    'passengerId':     passengerId,
    'passengerName':   passengerName,
    'passengerPhoto':  passengerPhoto,
    'passengerGender': passengerGender,
    'pickupPoint':     pickupPoint.toMap(),
    'seatsNeeded':     seatsNeeded,
    'offeredPrice':    offeredPrice,
    'status':          status,
    'passengerNotes':  passengerNotes,
    'createdAt':       createdAt.toIso8601String(),
    'acceptedAt':      acceptedAt?.toIso8601String(),
  };
}