class RideModel {
  final String id;
  final String driverId;
  final String driverName;
  final String? driverPhoto;
  final String? driverPhone;
  final double driverRating;
  final String? driverGender;
  final String carName;          
  final String carColor;         
  final String carPlate;
  final bool acAvailable;
  final LocationPoint startPoint;
  final LocationPoint endPoint;
  final List<LocationPoint> stops;
  final DateTime departureTime;
  final int totalSeats;
  final int availableSeats;
  final double pricePerSeat;   
  final String status;
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
    this.driverGender,
    this.carName = '',
    this.carColor = '',
    this.carPlate = '',
    this.acAvailable = false,
    required this.startPoint,
    required this.endPoint,
    this.stops = const [],
    required this.departureTime,
    required this.totalSeats,
    required this.availableSeats,
    this.pricePerSeat = 0,
    required this.status,
    this.notes,
    this.passengerIds = const [],
    required this.createdAt,
  });

  factory RideModel.fromMap(Map<String, dynamic> data, String id) {
    return RideModel(
      id: id,
      driverId:      data['driverId']      ?? '',
      driverName:    data['driverName']    ?? '',
      driverPhoto:   data['driverPhoto'],
      driverPhone:   data['driverPhone'],
      driverRating:  (data['driverRating'] ?? 0.0).toDouble(),
      driverGender:  data['driverGender'],
      carName:       data['carName']       ?? '',
      carColor:      data['carColor']      ?? '',
      carPlate:      data['carPlate']      ?? '',
      acAvailable:   data['acAvailable']   ?? false,
      startPoint:    LocationPoint.fromMap(data['startPoint'] ?? {}),
      endPoint:      LocationPoint.fromMap(data['endPoint']   ?? {}),
      stops: (data['stops'] as List<dynamic>? ?? [])
          .map((s) => LocationPoint.fromMap(s as Map<String, dynamic>))
          .toList(),
      departureTime: DateTime.parse(data['departureTime'] ?? DateTime.now().toIso8601String()),
      totalSeats:    data['totalSeats']     ?? 1,
      availableSeats:data['availableSeats'] ?? 1,
      pricePerSeat:  (data['pricePerSeat']  ?? 0.0).toDouble(),
      status:        data['status']         ?? 'upcoming',
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
    'driverGender':  driverGender,
    'carName':       carName,
    'carColor':      carColor,
    'carPlate':      carPlate,
    'acAvailable':   acAvailable,
    'startPoint':    startPoint.toMap(),
    'endPoint':      endPoint.toMap(),
    'stops':         stops.map((s) => s.toMap()).toList(),
    'departureTime': departureTime.toIso8601String(),
    'totalSeats':    totalSeats,
    'availableSeats':availableSeats,
    'pricePerSeat':  pricePerSeat,
    'status':        status,
    'notes':         notes,
    'passengerIds':  passengerIds,
    'createdAt':     createdAt.toIso8601String(),
  };

  RideModel copyWith({
    String? status,
    int? availableSeats,
    int? totalSeats,
    List<String>? passengerIds,
    double? pricePerSeat,
    String? carName,
    String? carColor,
    String? carPlate,
    bool? acAvailable,
    String? notes,
    String? driverGender,
  }) {
    return RideModel(
      id:             id,
      driverId:       driverId,
      driverName:     driverName,
      driverPhoto:    driverPhoto,
      driverPhone:    driverPhone,
      driverRating:   driverRating,
      driverGender:   driverGender   ?? this.driverGender,
      carName:        carName        ?? this.carName,
      carColor:       carColor       ?? this.carColor,
      carPlate:       carPlate       ?? this.carPlate,
      acAvailable:    acAvailable    ?? this.acAvailable,
      startPoint:     startPoint,
      endPoint:       endPoint,
      stops:          stops,
      departureTime:  departureTime,
      totalSeats:     totalSeats     ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      pricePerSeat:   pricePerSeat   ?? this.pricePerSeat,
      status:         status         ?? this.status,
      notes:          notes          ?? this.notes,
      passengerIds:   passengerIds   ?? this.passengerIds,
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
