class RideModel {
  final String id;
  final String driverId;
  final String driverName;
  final String? driverPhoto;
  final String? driverPhone;      
  final double driverRating;
  final LocationPoint startPoint;
  final LocationPoint endPoint;
  final List<LocationPoint> stops;
  final DateTime departureTime;
  final int totalSeats;
  final int availableSeats;
  final String status;
  final String rideType;          
  final String? notes;
  final List<String> passengerIds;
  final DateTime createdAt;

  RideModel({
    required this.id,
    required this.driverId,
    required this.driverName,
    this.driverPhoto,
    this.driverPhone,
    required this.driverRating,
    required this.startPoint,
    required this.endPoint,
    this.stops = const [],
    required this.departureTime,
    required this.totalSeats,
    required this.availableSeats,
    required this.status,
    this.rideType = 'economy',
    this.notes,
    this.passengerIds = const [],
    required this.createdAt,
  });

  factory RideModel.fromMap(Map<String, dynamic> data, String id) {
    return RideModel(
      id: id,
      driverId:     data['driverId']     ?? '',
      driverName:   data['driverName']   ?? '',
      driverPhoto:  data['driverPhoto'],
      driverPhone:  data['driverPhone'],
      driverRating: (data['driverRating'] ?? 0.0).toDouble(),
      startPoint:   LocationPoint.fromMap(data['startPoint'] ?? {}),
      endPoint:     LocationPoint.fromMap(data['endPoint']   ?? {}),
      stops: (data['stops'] as List<dynamic>? ?? [])
          .map((s) => LocationPoint.fromMap(s as Map<String, dynamic>))
          .toList(),
      departureTime: DateTime.parse(data['departureTime'] ?? DateTime.now().toIso8601String()),
      totalSeats:    data['totalSeats']    ?? 4,
      availableSeats:data['availableSeats']?? 4,
      status:        data['status']        ?? 'upcoming',
      rideType:      data['rideType']      ?? 'economy',
      notes:         data['notes'],
      passengerIds:  List<String>.from(data['passengerIds'] ?? []),
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'driverId':      driverId,
    'driverName':    driverName,
    'driverPhoto':   driverPhoto,
    'driverPhone':   driverPhone,
    'driverRating':  driverRating,
    'startPoint':    startPoint.toMap(),
    'endPoint':      endPoint.toMap(),
    'stops':         stops.map((s) => s.toMap()).toList(),
    'departureTime': departureTime.toIso8601String(),
    'totalSeats':    totalSeats,
    'availableSeats':availableSeats,
    'status':        status,
    'rideType':      rideType,
    'notes':         notes,
    'passengerIds':  passengerIds,
    'createdAt':     createdAt.toIso8601String(),
  };

  RideModel copyWith({
    String? status,
    int? availableSeats,
    List<String>? passengerIds,
  }) {
    return RideModel(
      id:             id,
      driverId:       driverId,
      driverName:     driverName,
      driverPhoto:    driverPhoto,
      driverPhone:    driverPhone,
      driverRating:   driverRating,
      startPoint:     startPoint,
      endPoint:       endPoint,
      stops:          stops,
      departureTime:  departureTime,
      totalSeats:     totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      status:         status ?? this.status,
      rideType:       rideType,
      notes:          notes,
      passengerIds:   passengerIds ?? this.passengerIds,
      createdAt:      createdAt,
    );
  }
}

class LocationPoint {
  final String address;
  final double lat;
  final double lng;

  LocationPoint({
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory LocationPoint.fromMap(Map<String, dynamic> map) => LocationPoint(
    address: map['address'] ?? '',
    lat: (map['lat'] ?? 0.0).toDouble(),
    lng: (map['lng'] ?? 0.0).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'address': address,
    'lat': lat,
    'lng': lng,
  };
}
