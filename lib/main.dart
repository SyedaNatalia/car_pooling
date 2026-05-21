import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/connectivity_wrapper.dart';
import 'core/router/app_router.dart';
import 'data/services/ride_service.dart';
import 'firebase_options.dart';

/// Catches unhandled errors from all Riverpod providers and logs them.
/// Replace the debugPrint with FirebaseCrashlytics.instance.recordError
/// once Crashlytics is added to the project.
class _AppProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    debugPrint('[Riverpod] Provider ${provider.name ?? provider.runtimeType} '
        'failed: $error');
  }
}

// Background message handler (top-level function required by FCM)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence so the app stays usable on
  // flaky networks and caches recently viewed rides/bookings locally.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notification permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Save FCM token to Firestore — only for verified users who have a profile
  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    final user = FirebaseAuth.instance.currentUser;
    // ✅ Only update if email is verified (unverified users have no Firestore doc)
    if (user != null && user.emailVerified) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});
    }
  });

  // Expire stale rides whenever a user logs in so the home screen and
  // Find Ride screen never show past-departure rides on fresh session start.
  // This covers the logout → re-login scenario where HomeScreen's timer
  // hasn't fired yet.
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      RideService().autoExpireRides();
    }
  });

  await dotenv.load(fileName: ".env");

  runApp(
    ProviderScope(
      observers: [_AppProviderObserver()],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'FairFare Carpool',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => ConnectivityWrapper(child: child ?? const SizedBox()),
    );
  }
}