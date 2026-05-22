import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../core/constants/app_constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get firebaseUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String company,
    required String department,
    required String role,
  }) async {
    // Store profile data so finaliseProfile() can use it after verification
    _pendingProfile = _PendingProfile(
      name: name,
      email: email,
      phone: phone,
      company: company,
      department: department,
      role: role,
    );

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user!.updateDisplayName(name.trim());
      await credential.user!.sendEmailVerification();
      // Keep signed in — EmailVerificationWaitScreen needs currentUser
      return email.trim();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return await _handleExistingEmail(email: email, password: password);
      }
      throw Exception(_handleAuthError(e));
    }
  }

  // Handles the case where Firebase says email-already-in-use during signup
  Future<String> _handleExistingEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in to check verification status
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.reload();
      final verified = _auth.currentUser?.emailVerified ?? false;

      if (verified) {
        // Real verified account — tell user to login instead
        await _auth.signOut();
        throw Exception('already_verified');
      } else {
        // Unverified account — resend email, keep signed in for polling
        await cred.user!.sendEmailVerification();
        return email.trim();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        // Different password = email belongs to someone else
        throw Exception('email_taken');
      }
      throw Exception(_handleAuthError(e));
    }
  }

  Future<UserModel> finaliseProfile() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user.');
    await user.reload();
    if (!(_auth.currentUser?.emailVerified ?? false)) {
      throw Exception('Email not yet verified.');
    }

    // Check if Firestore doc already exists (safe to call multiple times)
    final existing = await getUserProfile(user.uid);
    if (existing != null) return existing; // ✅ already saved, just return it

    final profile = _pendingProfile;
    final name = profile?.name.trim() ?? user.displayName?.trim() ?? '';
    final email = profile?.email.trim() ?? user.email?.trim() ?? '';
    final phone = profile?.phone.trim() ?? '';
    final company = profile?.company ?? AppConstants.companies.first;
    final department = profile?.department ?? AppConstants.departments.first;
    final role = profile?.role ?? AppConstants.roleEmployee;

    final newUser = UserModel(
      uid: user.uid,
      name: name,
      email: email,
      phone: phone,
      company: company,
      department: department,
      role: role,
      rating: 0.0,
      totalRides: 0,
      createdAt: DateTime.now(),
      isActive: true,
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(newUser.toMap(), SetOptions(merge: true));

    _pendingProfile = null;
    return newUser;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;

      // Fresh reload from Firebase — don't trust cached token
      await user.reload();
      final fresh = _auth.currentUser!;

      if (!fresh.emailVerified) {
        // Stay signed in so the wait screen can poll and resend
        throw Exception('email_not_verified:${email.trim()}');
      }

      // Try to get existing Firestore profile
      UserModel? userProfile = await getUserProfile(fresh.uid);

      if (userProfile == null) {
        userProfile = await finaliseProfile();
      }

      if (!userProfile.isActive) {
        await _auth.signOut();
        throw Exception(
            'Your account has been disabled. Please contact support.');
      }

      return userProfile;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(
          'Session expired. Please go back and sign up again.');
    }
    await user.reload();
    if (_auth.currentUser?.emailVerified ?? false) {
      throw Exception('already_verified');
    }
    await user.sendEmailVerification();
  }

  // ── Forgot Password ───────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    _pendingProfile = null;
    await _auth.signOut();
  }

  // ── Get User Profile ──────────────────────────────────────────────────────
  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Future<UserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await getUserProfile(user.uid);
  }

  Stream<UserModel?> streamUserProfile(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    });
  }

  // ── Update Profile ────────────────────────────────────────────────────────
  Future<void> updateProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update(data);
    if (data.containsKey('name')) {
      await _auth.currentUser?.updateDisplayName(data['name']);
    }
  }

  Future<void> updateCarDetails({
    required String uid,
    required CarDetails carDetails,
  }) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({'carDetails': carDetails.toMap()});
  }

  // ── Pending profile store ─────────────────────────────────────────────────
  // Static so the data survives across AuthService() instantiations
  // (signUp() and finaliseProfile() are called on different instances).
  static _PendingProfile? _pendingProfile;

  // ── Error Handler ─────────────────────────────────────────────────────────
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}

// ── Pending Profile ───────────────────────────────────────────────────────────
// Holds signup form data in memory between signUp() and finaliseProfile().
class _PendingProfile {
  final String name;
  final String email;
  final String phone;
  final String company;
  final String department;
  final String role;

  _PendingProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.company,
    required this.department,
    required this.role,
  });
}