import 'ride_model.dart';

class BookingModel {
  final String id;
  final String rideId;
  final String passengerId;
  final String passengerName;
  final String? passengerPhoto;
  final LocationPoint pickupPoint;
  final int seatsNeeded;       
  final double offeredPrice;   
  final String status;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.rideId,
    required this.passengerId,
    required this.passengerName,
    this.passengerPhoto,
    required this.pickupPoint,
    this.seatsNeeded = 1,
    this.offeredPrice = 0,
    required this.status,
    required this.createdAt,
  });

  factory BookingModel.fromMap(Map<String, dynamic> data, String id) {
    return BookingModel(
      id: id,
      rideId:        data['rideId']        ?? '',
      passengerId:   data['passengerId']   ?? '',
      passengerName: data['passengerName'] ?? '',
      passengerPhoto:data['passengerPhoto'],
      pickupPoint:   LocationPoint.fromMap(data['pickupPoint'] ?? {}),
      seatsNeeded:   data['seatsNeeded']   ?? 1,
      offeredPrice:  (data['offeredPrice'] ?? 0.0).toDouble(),
      status:        data['status']        ?? 'pending',
      createdAt:     data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'rideId':        rideId,
    'passengerId':   passengerId,
    'passengerName': passengerName,
    'passengerPhoto':passengerPhoto,
    'pickupPoint':   pickupPoint.toMap(),
    'seatsNeeded':   seatsNeeded,
    'offeredPrice':  offeredPrice,
    'status':        status,
    'createdAt':     createdAt.toIso8601String(),
  };
}