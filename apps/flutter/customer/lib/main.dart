// Wheelio Customer app. One Flutter codebase: web first, then iOS, then Android.
// Ported from apps/ios/Customer. See docs/FLUTTER.md.

import 'package:flutter/material.dart';
import 'package:wheelio_ui/wheelio_ui.dart';
import 'package:wheelio_firebase/wheelio_firebase.dart';

import 'data/store.dart';
import 'screens/auth_pay.dart';
import 'screens/booking.dart';
import 'screens/gallery.dart';
import 'screens/home.dart';
import 'screens/live.dart';
import 'screens/notifications.dart';
import 'screens/problem.dart';
import 'screens/start.dart';
import 'screens/support.dart';
import 'screens/firebase_live.dart';

Future<void> main() => launchWheelio(captain: false, demo: const CustomerApp());

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key});
  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> with WidgetsBindingObserver {
  final store = AppStore(live: WheelioRuntime.backend);
  final router = AppRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.refreshSystemPermission();
    store.live?.listenPush('customer',(id){if(mounted){store.set(()=>store.currentOrderId=id);router.push(R(N.live,id:id));}});
    // On a laptop there's no phone to call from: say so instead of dialling.
    Support.onCallUnavailable = (n) => store.set(() => store.toast = 'Calls work on your phone: ${Fmt.phone(n.replaceFirst('+91', ''))}');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) store.refreshSystemPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    store: store,
    router: router,
    child: MaterialApp(
      title: '${Brand.name} – ${Brand.tagline}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: wFont,
        colorScheme: ColorScheme.fromSeed(seedColor: WColor.primary, primary: WColor.primary),
        scaffoldBackgroundColor: WColor.white,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        textSelectionTheme: const TextSelectionThemeData(cursorColor: WColor.primary, selectionColor: WColor.primaryTint),
      ),
      // The app keeps its phone layout on every screen size (docs/FLUTTER.md).
      builder: (context, child) => PhoneFrame(
        child: PaymentEnvironmentLabel(child: DemoLabel(child: child!)),
      ),
      home: const _Root(),
    ),
  );
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    if (store.isLive && !store.backendReady) {
      return WScreen(
        children: [
          const WTitleBlock('Loading Wheelio…'),
          if (store.backendMessage != null) WText(store.backendMessage!, WType.body) else const Center(child: CircularProgressIndicator()),
          if (store.backendMessage != null) ...[
            const Gap(20),WButton('Retry',onTap:() {store.live!.refreshCatalog().catchError((Object e) {store.set(()=>store.backendMessage=backendError(e));});}),
          ],
        ],
      );
    }
    return Material(
      color: WColor.white,
      child: Stack(
        children: [
          WNavStack<R>(router: router, root: store.isLoggedIn || store.hasSeenWelcome ? const MainTabs() : const WelcomeScreen(), builder: _destination),
          if (router.showSplash) Positioned.fill(child: SplashScreen(onDone: () => router.setSplash(false))),
          if (!store.isLive) const _GalleryTab(),
          const Positioned.fill(child: LiveNotificationBanner()),
        ],
      ),
    );
  }
}

/// Small "Screens" tab on the left edge in demo mode that opens the screen gallery.
class _GalleryTab extends StatelessWidget {
  const _GalleryTab();
  @override
  Widget build(BuildContext context) {
    final router = context.router;
    return Positioned(
      left: 0,
      top: MediaQuery.sizeOf(context).height * 0.42,
      child: Pressable(
        label: 'Screens gallery',
        onTap: () {
          router.setSplash(false);
          if (!router.isAt(N.gallery)) router.go(N.gallery);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: WColor.inverse.withValues(alpha: 0.72),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
          child: Text(
            'Screens',
            style: wStyle(WType.small, weight: semibold, size: 11, color: WColor.white),
          ),
        ),
      ),
    );
  }
}

Widget _destination(R r) {
  if (WheelioRuntime.backend != null) {
    if ({N.booked, N.live, N.photoCompare, N.rate, N.reportProblem, N.problemPhotos, N.disputeStatus, N.refund, N.bookingDetail, N.refundUPI}.contains(r.n)) {
      return FirebaseOrderScreen(orderId: r.id);
    }
    if ({N.notifications,N.notificationSettings,N.notifyAsk}.contains(r.n)) return Builder(builder:(context)=>WScreen(header:WAppBar(onLeading:context.router.pop),children:[FirebaseInbox(captain:false,onOpen:(id){context.store.set(()=>context.store.currentOrderId=id);context.router.push(R(N.live,id:id));})]));
    if ({N.whatsApp, N.notifyAsk, N.help, N.helpCaptain, N.helpEmergency, N.changePhone, N.notificationSettings, N.notifications}.contains(r.n)) {
      return const FirebaseAccountHelp();
    }
  }
  return switch (r.n) {
    N.welcome => const WelcomeScreen(),
    N.vehicleType => VehicleTypeScreen(large: r.large),
    N.washType => const WashTypeScreen(),
    N.vehicleNumber => const VehicleNumberScreen(),
    N.photos => const PhotosScreen(),
    N.camera => CameraScreen(angle: r.angle!, forceDenied: r.denied),
    N.location => LocationScreen(forceOff: r.off),
    N.addressSearch => const AddressSearchScreen(),
    N.manualAddress => const ManualAddressScreen(),
    N.floorSlot => const FloorSlotScreen(),
    N.entryNotes => const EntryNotesScreen(),
    N.timeSlot => const TimeSlotScreen(),
    N.review => const ReviewScreen(),
    N.login => LoginScreen(showError: r.error),
    N.otp => OtpScreen(start: r.otp),
    N.name => const NameScreen(),
    N.paying => PayingScreen(initial: r.pay),
    N.booked => const ViewingOrder(child: BookedScreen()),
    N.whatsApp => const WhatsAppScreen(),
    N.notifyAsk => const NotifyAskScreen(),
    N.live => const LiveOrderScreen(),
    N.photoCompare => const PhotoCompareScreen(),
    N.rate => const RateScreen(),
    N.reportProblem => const ReportProblemScreen(),
    N.problemPhotos => ProblemPhotosScreen(kind: r.kind!),
    N.disputeStatus => const DisputeStatusScreen(),
    N.refund => const RefundScreen(),
    N.bookingDetail => BookingDetailScreen(orderId: r.id!),
    N.repeatBooking => RepeatScreen(id: r.id!),
    N.help => const HelpScreen(),
    N.helpCaptain => HelpCaptainScreen(topic: r.topic!),
    N.helpEmergency => const EmergencyHelpScreen(),
    N.changePhone => const ChangePhoneScreen(),
    N.notifications => const NotificationsScreen(),
    N.refundUPI => RefundUPIScreen(orderId: r.id),
    N.notificationSettings => const NotificationSettingsScreen(),
    N.offline => const OfflineScreen(),
    N.serverError => const ServerErrorScreen(),
    N.sessionExpired => const SessionExpiredScreen(),
    N.gallery => const GalleryScreen(),
  };
}
