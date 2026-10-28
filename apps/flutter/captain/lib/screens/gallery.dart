// Screens gallery (demo only): opens every captain screen W00–W57 with sample data.
// Ported from apps/ios/Captain/Screens/WGalleryScreen.swift.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

import '../data/store.dart';

class GalleryEntry {
  const GalleryEntry(this.id, this.title, {this.prep, this.routes = const [], this.tab, this.stage = 3});
  final String id;
  final String title;
  final void Function(CaptainStore s)? prep;
  final List<R> routes;
  final int? tab;

  /// 0 new (language), 1 guest exploring, 2 signed up (no KYC), 3 ready for jobs.
  final int stage;
}

typedef _E = GalleryEntry;

final gallerySections = <(String, List<GalleryEntry>)>[
  ('06 · Welcome, sign-up, KYC', [
    const _E('W01', 'Choose language', stage: 0),
    const _E('W00', 'Welcome: earnings and benefits', routes: [R(N.welcome)], stage: 0),
    const _E('W00g', 'Home as a guest (exploring)', tab: 0, stage: 1),
    const _E('W00m', 'Me as a guest', tab: 3, stage: 1),
    const _E('W00j', 'Jobs as a guest (example day)', tab: 1, stage: 1),
    const _E('W02', 'Sign up: name and number', routes: [R(N.signUp)], stage: 1),
    const _E('W02l', 'Log in: number only', routes: [R(N.signUp, flag: true)], stage: 1),
    const _E('W03', 'Enter the code', routes: [R(N.otp)], stage: 1),
    const _E('W03h', 'Home after sign-up (KYC card)', tab: 0, stage: 2),
    _E('W16', 'Accept a job → quick KYC', prep: (s) => s..steps = {}..kycFromJob = true, routes: const [R(N.steps)], stage: 2),
    const _E('W16a', 'Job rings for a new captain (accept → KYC)', routes: [R(N.jobAlert)], stage: 2),
    _E('W04', 'KYC steps (process overview)', prep: (s) => s.steps = {}, routes: const [R(N.steps)], stage: 2),
    const _E('W05', 'Verify Aadhaar', routes: [R(N.aadhaar)], stage: 2),
    const _E('W05b', 'Aadhaar photo not clear', routes: [R(N.aadhaar, flag: true)], stage: 2),
    const _E('W06', 'Your photo (selfie)', routes: [R(N.selfie)], stage: 2),
    const _E('W07', 'Get paid (UPI or bank)', routes: [R(N.bank)], stage: 2),
    _E('W08', 'Training videos', prep: (s) => s.videosWatched = 1, routes: const [R(N.training)], stage: 2),
    const _E('W09', 'Video player', routes: [R(N.video, index: 1)], stage: 2),
    const _E('W10', 'Quiz', routes: [R(N.quiz)], stage: 2),
    const _E('W11', 'Quiz passed', routes: [R(N.quizResult, flag: true)], stage: 2),
    const _E('W11b', 'Quiz failed', routes: [R(N.quizResult)], stage: 2),
    const _E('W12', 'Rules', routes: [R(N.rules)], stage: 2),
    const _E('W12w', 'Work profile (first time): jobs, then times', routes: [R(N.workSetup)], stage: 2),
    _E('W14r', 'Home: profile under review (pop-up)', prep: (s) => s..startReview()..reviewNoticePending = true, tab: 0, stage: 2),
    const _E('W15', '1 thing to fix (selfie mismatch)', routes: [R(N.steps, flag: true)], stage: 2),
  ]),
  ('07 · Home and jobs', [
    _E('W20', 'Home – offline', prep: (s) => s..online = false..jobsToday = 0..jobLimit = 2, tab: 0),
    _E('W21', 'Home – online (a job rings in 4 s)', prep: (s) => s.online = true, tab: 0),
    _E('W50', 'Home – low battery, no internet', prep: (s) => s..online = true..lowSignal = true, tab: 0),
    const _E('W22', 'New job alert', routes: [R(N.jobAlert)]),
    _E('W22m', kIsWeb ? 'Many jobs: 3 ring, stacked (See next job)' : 'Many jobs: 3 ring, stacked (swipe left to skip)', routes: const [R(N.jobAlert)]),
    _E('W22s', 'Single job (no others ring)', prep: (s) => s.extraOffers = 0, routes: const [R(N.jobAlert)]),
    const _E('W57', 'Where I work (societies, distance, place)', routes: [R(N.workArea)]),
    _E('W22o', 'Job alert – only My Home Avatar', prep: (s) => s..workMode = WorkMode.societies..chosenSocieties = {'My Home Avatar'}, routes: const [R(N.jobAlert)]),
    const _E('W22b', 'New job alert – batched', routes: [R(N.jobAlert, flag: true)]),
    _E('W22h', 'New job alert – Hindi', prep: (s) => s.lang = Lang.hi, routes: const [R(N.jobAlert)]),
    _E('W22t', 'New job alert – Telugu', prep: (s) => s.lang = Lang.te, routes: const [R(N.jobAlert)]),
    const _E('W23', 'Job went to someone else', routes: [R(N.jobMissed)]),
    _E('W24', 'Daily limit reached', prep: (s) => s..online = true..jobsToday = 4..jobLimit = 4..earnedToday = 464, tab: 0),
    const _E('W25', 'Today’s jobs', tab: 1),
    const _E('W26', 'Go to vehicle', routes: [R(N.goToVehicle)]),
    const _E('W27', 'Can’t get in (gate pass)', routes: [R(N.goToVehicle), R(N.gateProblem)]),
    const _E('W28', 'Can’t find vehicle', routes: [R(N.goToVehicle), R(N.cantFind)]),
    const _E('W26o', 'Owner’s note (plays first, must listen)', routes: [R(N.goToVehicle), R(N.ownerNote)]),
    const _E('W29', 'Owner cancelled', routes: [R(N.ownerCancelled)]),
    _E('W26n', 'Didn’t show up: late → slot over → cancelled (≈20 s)', prep: (s) => s.noShowDemo = true, routes: const [R(N.goToVehicle)]),
    _E('W55', 'Job cancelled: didn’t reach in time', prep: (s) => s..noShowCancelled = true..noShowPlate = 'TS 09 EA 4521', routes: const [R(N.noShowCancelled)]),
  ]),
  ('08 · Wash and photos', [
    const _E('W30', 'Quick face check', routes: [R(N.goToVehicle), R(N.faceCheck)]),
    _E('W31', 'Before photos', prep: (s) => s..beforeDone = {0, 1}..ownerNoteHeard = true, routes: const [R(N.goToVehicle), R(N.beforePhotos)]),
    const _E('W32', 'Camera – guided side', routes: [R(N.goToVehicle), R(N.beforePhotos), R(N.camera, index: 2)]),
    const _E('W33', 'Photo too dark', routes: [R(N.goToVehicle), R(N.beforePhotos), R(N.photoDark,index:2)]),
    _E('W34', 'Washing – timer', prep: (s) => s.ownerNoteHeard = true, routes: const [R(N.goToVehicle), R(N.washing)]),
    _E('W34b', 'Washing – late', prep: (s) => s.lateWash = true, routes: const [R(N.goToVehicle), R(N.washing)]),
    _E('W35', 'After photos', prep: (s) => s.afterDone = {0, 1, 2}, routes: const [R(N.goToVehicle), R(N.afterPhotos)]),
    _E('W36', 'AI photo check', prep: (s) => s.afterDone = {0, 1, 2, 3}, routes: const [R(N.goToVehicle), R(N.afterPhotos), R(N.aiCheck)]),
    _E('W37', 'Sending photos (weak signal)', prep: (s) => s.lowSignal = true, routes: const [R(N.uploading)]),
    const _E('W38', 'Shine done', routes: [R(N.jobDone)]),
    const _E('W38b', 'Done, late', routes: [R(N.jobDone, flag: true)]),
  ]),
  ('09 · Money, level, account', [
    const _E('W40', 'Money', tab: 2),
    const _E('W41', 'Payout detail', routes: [R(N.payoutDetail)]),
    const _E('W42', 'Money held', routes: [R(N.payoutHeld)]),
    const _E('W43', 'My level', routes: [R(N.level)]),
    const _E('W44', 'Probation extended', routes: [R(N.probationExtended)]),
    const _E('W45', 'Refresher video lock', routes: [R(N.refresher)]),
    const _E('W46', 'Account blocked, appeal', routes: [R(N.blocked)]),
    const _E('W47', 'Me (profile)', tab: 3),
    const _E('W48', 'Help: pick a problem', routes: [R(N.help)]),
    const _E('W48a', 'Help · money (check → owner → team)', routes: [R(N.help), R(N.helpFlow, topic: HelpTopic.money)]),
    const _E('W48b', 'Help · problem at a job', routes: [R(N.help), R(N.helpFlow, topic: HelpTopic.job)]),
    const _E('W48c', 'Help · rating or photo check', routes: [R(N.help), R(N.helpFlow, topic: HelpTopic.rating)]),
    const _E('W48d', 'Help · app not working (skips owner)', routes: [R(N.help), R(N.helpFlow, topic: HelpTopic.app)]),
    _E('W51', 'Notifications', prep: (s) => s.seedNotifications(), routes: const [R(N.notifications)]),
    _E('W51e', 'Notifications – empty', prep: (s) => s.notifications = [], routes: const [R(N.notifications)]),
    _E('W51o', 'Notifications – alerts off', prep: (s) => s..seedNotifications()..notificationsOn = false, routes: const [R(N.notifications)]),
    const _E('W52', 'Notification settings', routes: [R(N.notificationSettings)]),
    const _E('W53', 'Change phone number', routes: [R(N.changePhone)]),
    const _E('W54', 'Change payout UPI', routes: [R(N.editUPI)]),
    _E('W56', 'Live banner: new job (in-app)', prep: (s) => s..seedNotifications()..online = true..notify(WNotifKind.newJob, job: s.current), tab: 0),
  ]),
];

final galleryAll = [for (final s in gallerySections) ...s.$2];

/// Opens one gallery entry: resets the demo, sets the sign-up stage, then shows the screen.
void openGalleryEntry(GalleryEntry e, CaptainStore store, WRouterC router) {
  final lang = router.tourLang ?? store.lang;
  store.resetDemo();
  store.lang = lang;
  store.signedUp = e.stage >= 3;
  store.registered = e.stage >= 2;
  store.exploring = e.stage >= 1;
  store.nudgeShown = true;
  if (e.stage >= 2 && store.notifications.isEmpty) store.seedNotifications();
  e.prep?.call(store);
  store.changed();
  if (e.tab != null) {
    router.home();
    router.tab = e.tab!;
    return;
  }
  router.replace(e.routes);
}

class WGalleryScreen extends StatelessWidget {
  const WGalleryScreen({super.key});

  void _open(BuildContext context, GalleryEntry e) {
    final store = context.store, router = context.router;
    router.setTour(galleryAll.indexWhere((x) => x.id == e.id), store.lang);
    openGalleryEntry(e, store, router);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store, router = context.router;
    Widget toggle(String title, bool on, void Function(bool) set) =>
        WToggleRow(padding: const EdgeInsets.symmetric(vertical: 6), on: on, onChanged: (v) => store.set(() => set(v)), child: WText(title, WType.body, size: 15, color: WColor.heading));
    return WScreen(
      gutter: WSpace.gutterCaptain,
      header: WAppBar(title: 'Screens', subtitle: 'Demo mode · sample data', trailing: null, onLeading: router.pop),
      children: [
        const Padding(padding: EdgeInsets.only(top: 10, bottom: 6), child: WText('Language', WType.label)),
        WSegmented(options: const ['English', 'हिन्दी', 'తెలుగు'], selection: Lang.values.indexOf(store.lang), onChanged: (i) => store.set(() => store.lang = Lang.values[i])),
        const SizedBox(height: 10),
        toggle('Dark photo on left side (W33)', store.darkPhoto, (v) => store.darkPhoto = v),
        toggle('AI flags the left mirror (W36)', store.aiFlag, (v) => store.aiFlag = v),
        toggle('Wash runs late (W34b)', store.lateWash, (v) => store.lateWash = v),
        toggle('Weak signal (W37, W50)', store.lowSignal, (v) => store.lowSignal = v),
        toggle('Batched job alert (W22b)', store.batchedAlert, (v) => store.batchedAlert = v),
        const SizedBox(height: 10),
        WButton('Reset demo', kind: ButtonKind.tonal, onTap: store.resetDemo),
        const SizedBox(height: 10),
        WButton('Step through all screens', kind: ButtonKind.tonal, onTap: () {
          router.setTour(0, store.lang);
          openGalleryEntry(galleryAll[0], store, router);
        }),
        for (final s in gallerySections) ...[
          Padding(padding: const EdgeInsets.only(top: 20, bottom: 4), child: WText(s.$1, WType.section, weight: semibold)),
          for (final e in s.$2.where((e)=>store.trainingEnabled||!e.routes.any((r)=>[N.training,N.video,N.quiz,N.quizResult,N.refresher].contains(r.n)))) ...[
            Pressable(
              feedback: false,
              onTap: () => _open(context, e),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  SizedBox(width: 48, child: WText(e.id, WType.label, color: WColor.primaryStrong)),
                  const SizedBox(width: 12),
                  Expanded(child: WText(e.title, WType.rowTitle)),
                  const WIconView(WIcon.chevron, size: 12, color: WColor.secondary),
                ]),
              ),
            ),
            const WDivider(),
          ],
        ],
      ],
    );
  }
}
