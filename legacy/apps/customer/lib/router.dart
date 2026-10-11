import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'config/app_config.dart';
import 'data/models.dart';
import 'features/auth.dart';
import 'features/booking.dart';
import 'features/dev_gallery.dart';
import 'features/home.dart';
import 'features/live_order.dart';
import 'features/payment.dart';
import 'features/problems.dart';
import 'features/start.dart';
import 'features/system.dart';
import 'routes.dart';

GoRouter buildRouter() {
  GoRoute route(String path, Widget Function(Map<String, String> q) build) =>
      GoRoute(path: path, builder: (context, state) => build(state.uri.queryParameters));

  PhotoAngle angleFrom(String? name) =>
      PhotoAngle.values.firstWhere((a) => a.name == name, orElse: () => PhotoAngle.front);

  return GoRouter(
    initialLocation: R.splash,
    routes: [
      route(R.splash, (q) => SplashScreen(autoContinue: q['state'] != 'static')),
      route(R.welcome, (_) => const WelcomeScreen()),
      // Booking
      route(R.vehicleType, (q) => q['state'] == 'large'
          ? const _LargeText(child: VehicleTypeScreen()) // C52
          : const VehicleTypeScreen()),
      route(R.vehicleNumber, (q) => VehicleNumberScreen(showError: q['state'] == 'error')),
      route(R.photos, (_) => const PhotosScreen()),
      route(R.camera, (q) => CameraScreen(angle: angleFrom(q['angle']), forceDenied: q['state'] == 'denied')),
      route(R.location, (q) => LocationScreen(forceOff: q['state'] == 'off')),
      route(R.addressSearch, (_) => const AddressSearchScreen()),
      route(R.floorSlot, (_) => const FloorSlotScreen()),
      route(R.entryNotes, (_) => const EntryNotesScreen()),
      route(R.timeSlot, (_) => const TimeSlotScreen()),
      route(R.review, (_) => const ReviewScreen()),
      // Login
      route(R.login, (q) => LoginScreen(showError: q['state'] == 'error')),
      route(R.otp, (q) => OtpScreen(
            initial: switch (q['state']) {
              'wrong' => OtpView.wrong,
              'expired' => OtpView.expired,
              _ => OtpView.entering,
            },
          )),
      route(R.name, (_) => const NameScreen()),
      route(R.sessionExpired, (_) => const SessionExpiredScreen()),
      // Payment
      route(R.payMethod, (_) => const PayMethodScreen()),
      route(R.paying, (q) => PayingScreen(
            initial: switch (q['state']) {
              'failed' => PayView.failed,
              'pending' => PayView.pending,
              _ => PayView.processing,
            },
          )),
      route(R.booked, (_) => const BookedScreen()),
      route(R.whatsApp, (_) => const WhatsAppReferenceScreen()),
      route(R.notifyAsk, (_) => const NotifyAskScreen()),
      // Live order
      route(R.searching, (_) => const SearchingScreen()),
      route(R.noWasher, (_) => const NoWasherScreen()),
      route(R.onTheWay, (_) => const OnTheWayScreen()),
      route(R.washing, (_) => const WashingScreen()),
      route(R.checkPhotos, (_) => const CheckPhotosScreen()),
      route(R.photoCompare, (q) => PhotoCompareScreen(angle: angleFrom(q['angle']))),
      route(R.rate, (_) => const RateScreen()),
      route(R.autoApproved, (_) => const AutoApprovedScreen()),
      route(R.cancel, (_) => const CancelScreen()),
      route(R.cancelled, (_) => const CancelledScreen()),
      // Problems
      route(R.reportProblem, (_) => const ReportProblemScreen()),
      route(R.problemPhotos, (_) => const ProblemPhotosScreen()),
      route(R.disputeSent, (_) => const DisputeSentScreen()),
      route(R.disputeDecision, (_) => const DisputeDecisionScreen()),
      route(R.refund, (_) => const RefundStatusScreen()),
      // Home and account
      route(R.home, (q) => HomeScreen(forceLoading: q['state'] == 'loading')),
      route(R.bookings, (q) => BookingsScreen(initialTab: q['tab'] == 'past' ? 1 : 0)),
      route(R.bookingDetail, (_) => const BookingDetailScreen()),
      route(R.repeat, (_) => const RepeatScreen()),
      route(R.vehicles, (_) => const VehiclesScreen()),
      route(R.profile, (q) => q['state'] == 'delete' ? const ProfileWithDeleteDialog() : const ProfileScreen()),
      route(R.help, (_) => const HelpScreen()),
      // System states
      route(R.offline, (_) => const OfflineScreen()),
      route(R.error, (_) => const ErrorScreen()),
      if (AppConfig.useMock) route(R.gallery, (_) => const DevGalleryScreen()),
    ],
    errorBuilder: (context, state) => const ErrorScreen(),
  );
}

/// C52: the same screen at 200% text size.
class _LargeText extends StatelessWidget {
  const _LargeText({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child,
      );
}
