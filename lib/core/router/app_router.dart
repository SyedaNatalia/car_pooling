import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
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
    ],
  );
});