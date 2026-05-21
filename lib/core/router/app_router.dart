import 'package:car_pooling/presentation/profile/about_screen.dart';
import 'package:car_pooling/presentation/profile/help_screen.dart';
import 'package:car_pooling/presentation/profile/my_booking_screen.dart';
import 'package:car_pooling/presentation/profile/my_rides_screen.dart';
import 'package:car_pooling/presentation/profile/notifications_screen.dart';
import 'package:car_pooling/presentation/profile/ride_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/app_providers.dart';
import '../../presentation/auth/splash_screen.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/signup_screen.dart';
import '../../presentation/auth/forgot_password_screen.dart';
import '../../presentation/home/main_shell.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/rides/find_ride_screen.dart';
import '../../presentation/rides/ride_results_screen.dart';
import '../../presentation/rides/ride_detail_screen.dart';
import '../../presentation/rides/offer_ride_screen.dart';
import '../../presentation/rides/manage_requests_screen.dart';
import '../../presentation/rides/active_ride_screen.dart';
import '../../presentation/booking/booking_confirm_screen.dart';
import '../../presentation/profile/profile_screen.dart';
import '../../presentation/profile/edit_profile_screen.dart';
import '../../presentation/profile/edit_car_details_screen.dart';
import '../../presentation/chat/chat_screen.dart';
import '../../presentation/admin/admin_screen.dart';
import '../../presentation/profile/rating_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Single ValueNotifier that drives GoRouter's refreshListenable.
  // We toggle it whenever either the Firebase auth state changes OR the
  // manual routerRefreshProvider counter increments (e.g. after email
  // verification — authStateChanges does not fire when emailVerified flips).
  final refreshNotifier = ValueNotifier<bool>(false);

  void toggle() => refreshNotifier.value = !refreshNotifier.value;

  ref.listen(firebaseAuthStateProvider, (_, __) => toggle());
  ref.listen(routerRefreshProvider, (_, __) => toggle());

  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) async {
      final authState = ref.read(firebaseAuthStateProvider);

      // Still loading — stay on splash, don't redirect yet
      if (authState.isLoading) {
        if (state.matchedLocation != '/splash') return '/splash';
        return null;
      }

      final firebaseUser = authState.valueOrNull;

      if (firebaseUser != null) {
        try { await firebaseUser.reload(); } catch (_) {}
      }
      final freshUser = FirebaseAuth.instance.currentUser;
      final isLoggedIn = freshUser != null && freshUser.emailVerified;

      final loc = state.matchedLocation;
      final isAuthRoute = loc.startsWith('/auth');
      final isSplash = loc == '/splash';

      // On splash — redirect based on login state
      if (isSplash) {
        return isLoggedIn ? '/home' : '/auth/login';
      }

      // Not logged in + not on auth page → go to login
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';

      // Logged in + on auth page → go home
      if (isLoggedIn && isAuthRoute) return '/home';

      // Admin route — only role==admin can access /admin
      if (loc == '/admin') {
        try {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) return '/auth/login';
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final role = doc.data()?['role'] as String? ?? '';
          if (role != 'admin') return '/home';
        } catch (_) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),

      // Auth routes
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // Main shell with bottom nav
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/find-ride', builder: (_, __) => const FindRideScreen()),
          GoRoute(path: '/offer-ride', builder: (_, __) => const OfferRideScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // Ride routes
      GoRoute(
        path: '/ride-results',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return RideResultsScreen(
            date: extra['date'] as DateTime,
            fromCity: extra['fromCity'] as String?,
            toCity: extra['toCity'] as String?,
            pickupLat: (extra['pickupLocation'] as dynamic)?.latitude as double?,
            pickupLng: (extra['pickupLocation'] as dynamic)?.longitude as double?,
            dropoffLat: (extra['dropoffLocation'] as dynamic)?.latitude as double?,
            dropoffLng: (extra['dropoffLocation'] as dynamic)?.longitude as double?,
          );
        },
      ),
      GoRoute(
        path: '/ride/:id',
        builder: (context, state) =>
            RideDetailScreen(rideId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/ride/:id/book',
        builder: (context, state) =>
            BookingConfirmScreen(rideId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/ride/:id/requests',
        builder: (context, state) =>
            ManageRequestsScreen(rideId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/ride/:id/active',
        builder: (context, state) =>
            ActiveRideScreen(rideId: state.pathParameters['id']!),
      ),

      // Chat
      GoRoute(
        path: '/chat/:rideId',
        builder: (context, state) =>
            ChatScreen(rideId: state.pathParameters['rideId']!),
      ),

      // Profile edit
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => const EditProfileScreen(),
      ),

      // Car details edit
      GoRoute(
        path: '/edit-car-details',
        builder: (_, __) => const EditCarDetailsScreen(),
      ),

      // Admin
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(path: '/ride-history',   builder: (_, __) => const RideHistoryScreen()),
GoRoute(path: '/my-bookings',    builder: (_, __) => const MyBookingsScreen()),
GoRoute(path: '/my-rides',       builder: (_, __) => const MyRidesScreen()),
GoRoute(path: '/notifications',  builder: (_, __) => const NotificationsScreen()),
GoRoute(path: '/help',           builder: (_, __) => const HelpScreen()),
GoRoute(path: '/about',          builder: (_, __) => const AboutScreen()),
// GoRoute(
//   path: '/rate/:rideId/:ratedUserId',
//   builder: (context, state) {
//     final extra = state.extra as Map<String, dynamic>?;
//     return RatingScreen(
//       rideId: state.pathParameters['rideId']!,
//       ratedUserId: state.pathParameters['ratedUserId']!,
//       ratedUserName: extra?['name'] as String? ?? 'User',
//       ratedUserPhoto: extra?['photo'] as String?,
//     );
//   },
// ),
GoRoute(
  path: '/rate/:rideId/:ratedUserId',
  builder: (context, state) => const SizedBox.shrink(),
),
    ],
  );
});