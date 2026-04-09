// lib/data/services/auth_service.dart
// Pure frontend mock — Firebase nahi hai

import '../models/user_model.dart';

// Dummy logged-in user
final _mockUser = UserModel(
  uid: 'user_001',
  name: 'Sara Ahmed',
  email: 'sara@company.com',
  phone: '0300-1234567',
  department: 'Engineering',
  role: 'both',
  rating: 4.7,
  totalRides: 23,
  createdAt: DateTime(2024, 1, 15),
  carDetails: CarDetails(
    make: 'Toyota',
    model: 'Corolla',
    color: 'White',
    plateNumber: 'LHR-1234',
    year: 2021,
  ),
);

class AuthService {
  // Mock current user — hamesha logged in dikhao
  UserModel? get currentUser => _mockUser;

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800)); // fake delay
    return _mockUser;
  }

  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String department,
    required String role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _mockUser;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<UserModel?> getCurrentUserProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockUser;
  }

  Future<void> updateProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> updateCarDetails({
    required String uid,
    required CarDetails carDetails,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}