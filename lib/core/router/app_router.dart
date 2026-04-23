import 'package:car_pooling/presentation/profile/about_screen.dart';
import 'package:car_pooling/presentation/profile/help_screen.dart';
import 'package:car_pooling/presentation/profile/my_booking_screen.dart';
import 'package:car_pooling/presentation/profile/my_rides_screen.dart';
import 'package:car_pooling/presentation/profile/notifications_screen.dart';
import 'package:car_pooling/presentation/profile/ride_history_screen.dart';
import 'package:flutter/material.dart';
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
import '../../presentation/chat/chat_screen.dart';
import '../../presentation/admin/admin_screen.dart';
import '../../presentation/profile/rating_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Listen to auth state for redirect
  final authNotifier = ValueNotifier<bool>(false);

  ref.listen(firebaseAuthStateProvider, (_, next) {
    authNotifier.value = !authNotifier.value; // trigger refresh
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(firebaseAuthStateProvider);
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation == '/splash';

      // Not logged in + not on auth page → go to login
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';

      // Logged in + on auth page → go home
      if (isLoggedIn && isAuthRoute && state.matchedLocation != '/splash') {
        return '/home';
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
          return RideResultsScreen(date: extra['date'] as DateTime);
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

      // Admin
      GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      GoRoute(path: '/ride-history',   builder: (_, __) => const RideHistoryScreen()),
GoRoute(path: '/my-bookings',    builder: (_, __) => const MyBookingsScreen()),
GoRoute(path: '/my-rides',       builder: (_, __) => const MyRidesScreen()),
GoRoute(path: '/notifications',  builder: (_, __) => const NotificationsScreen()),
GoRoute(path: '/help',           builder: (_, __) => const HelpScreen()),
GoRoute(path: '/about',          builder: (_, __) => const AboutScreen()),
GoRoute(
  path: '/rate/:rideId/:ratedUserId',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>?;
    return RatingScreen(
      rideId: state.pathParameters['rideId']!,
      ratedUserId: state.pathParameters['ratedUserId']!,
      ratedUserName: extra?['name'] as String? ?? 'User',
      ratedUserPhoto: extra?['photo'] as String?,
    );
  },
),
    ],
  );
});