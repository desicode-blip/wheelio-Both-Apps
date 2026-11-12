// WashKrew Captain app. One Flutter codebase: web first, then iOS, then Android.
// Ported from apps/ios/Captain. See docs/FLUTTER.md.

import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

import 'data/store.dart';
import 'features/monthly_jobs.dart';
import 'features/preview_features.dart';
import 'screens/account.dart';
import 'screens/gallery.dart';
import 'screens/help.dart';
import 'screens/service_area.dart';
import 'screens/home.dart';
import 'screens/money.dart';
import 'screens/onboarding.dart';
import 'screens/wash.dart';
import 'screens/welcome.dart';

Future<void> main() => launchWashKrew(captain: true, demo: const CaptainApp());

class CaptainApp extends StatefulWidget {
  const CaptainApp({super.key,this.store});
  final CaptainStore? store;
  @override
  State<CaptainApp> createState() => _CaptainAppState();
}

class _CaptainAppState extends State<CaptainApp> with WidgetsBindingObserver {
  late final store = widget.store??CaptainStore(live: WashKrewRuntime.backend);
  final router = WRouterC();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.onJobCancelled=(id,reason){if(mounted)router.replace([R(reason=='slotExpired'?N.noShowCancelled:N.ownerCancelled)]);};
    store.onOffersChanged=(){
      if(!mounted||!Device.appIsActive||!store.online||store.liveOffers.isEmpty)return;
      WidgetsBinding.instance.addPostFrameCallback((_){
        if(mounted&&store.liveOffers.isNotEmpty){
          // v2 (13 Nov): a monthly recurring job rings on its own gold screen.
          final monthly=store.monthlyOffers.where((o)=>!store.declinedMonthly.contains(o.id)).firstOrNull;
          final alert=monthly!=null?const R(N.monthlyAlert):store.oneTimeOffers.isNotEmpty?const R(N.jobAlert):null;
          if(alert==null||router.isAt(N.monthlyAlert))return;
          if(monthly!=null)store.openMonthlyId=monthly.id;
          if(router.isAt(N.jobMissed)){router.swapTop(alert);}
          else if(router.path.isEmpty){router.push(alert);}
        }
      });
    };
    store.refreshSystemPermission();
    if(widget.store==null&&store.isLive)WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted)requestStartupPermissions(); });
    store.live?.listenPush('captain',(id){
      if(!mounted)return;
      final notice=store.notifications.where((n)=>n.jobId==id).firstOrNull;
      if(notice!=null){final info=openWNotif(notice,store,router);if(info!=null)store.set(()=>store.toast=info);}
      else{router.home();router.tab=1;}
    });
    // On a laptop there's no phone to call from: say so instead of dialling.
    Support.onUnavailable=(message)=>store.set(()=>store.toast=message);
    Support.onCallUnavailable = (n) => store.set(
      () => store.toast = store.t(
        'Calls work on your phone: ${Fmt.phone(n.replaceFirst('+91', ''))}',
        'कॉल फ़ोन से होती है: ${Fmt.phone(n.replaceFirst('+91', ''))}',
        'కాల్స్ ఫోన్‌లో పని చేస్తాయి: ${Fmt.phone(n.replaceFirst('+91', ''))}',
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    store.foreground(s==AppLifecycleState.resumed);
    if (s == AppLifecycleState.resumed) {
      store.refreshSystemPermission();
      store.live?.registerPush('captain').catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CaptainScope(
    store: store,
    router: router,
    child: MaterialApp(
      title: Brand.captainApp,
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
        child: DemoLabel(child: child!),
      ),
      home: const _Root(),
    ),
  );
}

class _Root extends StatefulWidget {
  const _Root();
  @override State<_Root> createState()=>_RootState();
}
class _RootState extends State<_Root>{
  String? restoredAccount;
  int? observedReset;
  bool resetting=false;

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    observedReset ??= store.accountResetRevision;
    if(observedReset != store.accountResetRevision){
      observedReset=store.accountResetRevision;restoredAccount=null;resetting=true;
      WidgetsBinding.instance.addPostFrameCallback((_){if(mounted){router.home();setState(()=>resetting=false);}});
    }
    if(resetting)return const Material(color:WColor.white,child:LanguageScreen());
    if(store.liveUid.isEmpty)restoredAccount=null;
    if(store.isLive&&store.liveUid.isNotEmpty&&store.liveLoaded&&store.liveOrdersLoaded&&store.signedUp&&restoredAccount!=store.liveUid){
      restoredAccount=store.liveUid;
      final account=store.liveUid;
      WidgetsBinding.instance.addPostFrameCallback((_){
        if(mounted&&store.liveUid==account&&router.path.isEmpty)store.resumeWork(router);
      });
    }
    return Material(
      color: WColor.white,
      child: Stack(
        children: [
          WNavStack<R>(router: router, root: store.signedUp || store.exploring ? const CaptainTabs() : const LanguageScreen(), builder: _destination),
          if (!store.isLive) const _GalleryTab(),
          const Positioned.fill(child: WLiveBanner()),
        ],
      ),
    );
  }
}

/// Small "Screens" tab on the left edge (demo only). While stepping through the gallery
/// it also shows the screen ID with ‹ › to move to the previous or next screen.
class _GalleryTab extends StatelessWidget {
  const _GalleryTab();

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    final top = MediaQuery.sizeOf(context).height * 0.42;
    final i = router.tour;
    const shape = BorderRadius.horizontal(right: Radius.circular(12));
    final bg = WColor.inverse.withValues(alpha: 0.72);
    Widget tourButton(String label, int j) => Pressable(
      label: label == '‹' ? 'Previous screen' : 'Next screen',
      onTap: () {
        if (j < 0 || j >= galleryAll.length) return;
        router.setTour(j, router.tourLang);
        openGalleryEntry(galleryAll[j], store, router);
      },
      child: SizedBox(
        width: 26,
        height: 30,
        child: Center(
          child: Text(
            label,
            style: wStyle(WType.body, weight: bold, size: 18, color: WColor.white),
          ),
        ),
      ),
    );
    return Positioned(
      left: 0,
      top: top,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pressable(
            label: 'Screens gallery',
            onTap: () {
              if (!router.isAt(N.gallery)) router.go(N.gallery);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: bg, borderRadius: shape),
              child: Text(
                'Screens',
                style: wStyle(WType.small, weight: semibold, size: 11, color: WColor.white),
              ),
            ),
          ),
          if (i != null && !router.isAt(N.gallery))
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: bg, borderRadius: shape),
              child: Column(
                children: [
                  Text(
                    galleryAll[i].id,
                    style: wStyle(WType.small, weight: semibold, size: 11, color: WColor.white),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: [tourButton('‹', i - 1), tourButton('›', i + 1)]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Widget _destination(R r) => Builder(builder:(context){
  if(!context.store.trainingEnabled && [N.training,N.video,N.quiz,N.quizResult,N.refresher].contains(r.n))return context.store.signedUp ? const MeTab() : const StepsScreen();
  return switch (r.n) {
  N.welcome => const WelcomeScreen(),
  N.referrals => const CaptainReferralsScreen(),
  N.referralScenarios => const CaptainReferralScenariosScreen(),
  N.referralAdmin => const ReferralAdminPreview(),
  N.payGuide => const PayGuidePreview(),
  N.offerTermsPreview => const OfferTermsPreview(),
  N.recurringAssignment => const RecurringAssignmentPreview(),
  N.monthlyAlert => const MonthlyJobAlertScreen(),
  N.openJobs => OpenJobsScreen(monthly: r.flag),
  N.recovery => CaptainRecoveryScreen(cancel: r.flag),
  N.recoveryScenarios => const CaptainRecoveryScenariosScreen(),
  N.recoveryOwnerPreview => const RecoveryOwnerPreview(),
  N.recoveryEarnings => const RecoveryEarningsPreview(),
  N.signUp => SignUpScreen(login: r.flag, verified: r.index == 1),
  N.otp => WOtpScreen(login: r.flag),
  N.steps => StepsScreen(problem: r.flag),
  N.aadhaar => AadhaarScreen(unclear: r.flag),
  N.selfie => const SelfieScreen(),
  N.bank => const BankScreen(),
  N.training => const TrainingScreen(),
  N.video => VideoScreen(index: r.index),
  N.quiz => const QuizScreen(),
  N.quizResult => QuizResultScreen(passed: r.flag),
  N.rules => const RulesScreen(),
  N.workSetup => context.store.captainAreaEnabled?const ServiceAreaScreen(setup:true):const WorkAreaScreen(setup: true),
  N.jobAlert => JobAlertScreen(batched: r.flag),
  N.jobMissed => const JobMissedScreen(),
  N.goToVehicle => const GoToVehicleScreen(),
  N.gateProblem => const GateProblemScreen(),
  N.cantFind => const CantFindScreen(),
  N.ownerCancelled => const OwnerCancelledScreen(),
  N.faceCheck => const FaceCheckScreen(),
  N.beforePhotos => const JobPhotosScreen(),
  N.camera => JobCameraScreen(after: r.flag, side: r.index),
  N.photoDark => PhotoDarkScreen(side:r.index,after:r.flag),
  N.washing => const WashingScreen(),
  N.afterPhotos => const JobPhotosScreen(after: true),
  N.aiCheck => const AiCheckScreen(),
  N.uploading => const UploadingScreen(),
  N.jobDone => JobDoneScreen(late: r.flag),
  N.payoutDetail => const PayoutDetailScreen(),
  N.payoutHeld => const PayoutHeldScreen(),
  N.level => const LevelScreen(),
  N.probationExtended => const ProbationScreen(),
  N.refresher => const RefresherScreen(),
  N.blocked => const BlockedScreen(),
  N.help => const WHelpScreen(),
  N.notifications => const WNotificationsScreen(),
  N.notifyFirst => const NotifyFirstScreen(),
  N.notificationSettings => const WNotificationSettingsScreen(),
  N.changePhone => const WChangePhoneScreen(),
  N.editUPI => const WEditUPIScreen(),
  N.noShowCancelled => const WNoShowCancelledScreen(),
  N.workArea => context.store.captainAreaEnabled?const ServiceAreaScreen():const WorkAreaScreen(),
  N.ownerNote => const OwnerNoteScreen(),
  N.helpFlow => HelpFlowScreen(topic: r.topic!),
  N.gallery => const WGalleryScreen(),
};});
