class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String department;
  final String role;
  final String? photoUrl;
  final CarDetails? carDetails;
  final double rating;
  final int totalRides;
  final DateTime createdAt;
  final bool isActive;
  final String? gender; 

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.company,
    required this.department,
    required this.role,
    this.photoUrl,
    this.carDetails,
    this.rating = 0.0,
    this.totalRides = 0,
    required this.createdAt,
    this.isActive = true,
    this.gender,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      company: data['company'] ?? '',
      department: data['department'] ?? '',
      role: data['role'] ?? 'employee',
      photoUrl: data['photoUrl'],
      carDetails: data['carDetails'] != null
          ? CarDetails.fromMap(data['carDetails'])
          : null,
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalRides: data['totalRides'] ?? 0,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
      isActive: data['isActive'] ?? true,
      gender: data['gender'],
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'phone': phone,
    'company': company,
    'department': department,
    'role': role,
    'photoUrl': photoUrl,
    'carDetails': carDetails?.toMap(),
    'rating': rating,
    'totalRides': totalRides,
    'createdAt': createdAt.toIso8601String(),
    'isActive': isActive,
    'gender': gender,
  };
}

class CarDetails {
  final String make;
  final String model;
  final String color;
  final String plateNumber;
  final int year;
  final bool hasAC;

  CarDetails({
    required this.make,
    required this.model,
    required this.color,
    required this.plateNumber,
    required this.year,
    this.hasAC = false,
  });

  factory CarDetails.fromMap(Map<String, dynamic> map) => CarDetails(
    make: map['make'] ?? '',
    model: map['model'] ?? '',
    color: map['color'] ?? '',
    plateNumber: map['plateNumber'] ?? '',
    year: map['year'] ?? 2020,
    hasAC: map['hasAC'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'make': make,
    'model': model,
    'color': color,
    'plateNumber': plateNumber,
    'year': year,
    'hasAC': hasAC,
  };
}