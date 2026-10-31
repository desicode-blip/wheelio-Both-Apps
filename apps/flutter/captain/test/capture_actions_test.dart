import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/onboarding.dart';
import 'package:washkrew_ui/washkrew_ui.dart';
import '../../packages/washkrew_ui/test/fake_camera.dart';

class ActionStore extends CaptainStore {
  @override
  bool get isLive => true;
  final upload = Completer<void>(),
      submission = Completer<void>(),
      payout = Completer<void>();
  int uploads = 0, submissions = 0, payoutCalls = 0;
  Uint8List? received;
  @override
  Future<void> liveUploadKyc(String kind, Uint8List bytes) async {
    uploads++;
    received = bytes;
    await upload.future;
    kycUploaded.add(kind);
    complete(KycStep.photo);
  }

  @override
  Future<void> liveSubmitApplication() async {
    submissions++;
    await submission.future;
  }

  @override
  Future<void> liveSavePayout({String? upi, String? accountNumber}) async {
    payoutCalls++;
    await payout.future;
  }
}

Future<void> show(
  WidgetTester tester,
  ActionStore store,
  WRouterC router,
  Widget screen,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    CaptainScope(
      store: store,
      router: router,
      child: MaterialApp(
        home: ListenableBuilder(
          listenable: router,
          builder: (context, _) => WNavStack<R>(
            router: router,
            root: screen,
            builder: (r) => r.n == N.steps
                ? const StepsScreen()
                : const Material(child: Text('Next authored route')),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> cleanup(
  WidgetTester tester,
  ActionStore store,
  WRouterC router,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  store.dispose();
  router.dispose();
}

Finder get shutter =>
    find.byWidgetPredicate((w) => w is Pressable && w.label == 'Take photo');
void main() {
  testWidgets(
    'selfie opens its front preview on entry; one shutter captures and waits for the real upload result',
    (tester) async {
      final store = ActionStore(), router = WRouterC(), rig = FakeCameraRig();
      await show(
        tester,
        store,
        router,
        SelfieScreen(cameraController: rig.controller),
      );
      expect(rig.controller.ready, true);
      expect(rig.natives.single.description, frontCamera);
      expect(find.byType(WCameraPreview), findsOneWidget);
      await tester.tap(shutter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(rig.natives.first.captures, 1);
      expect(store.uploads, 1);
      expect(store.steps[KycStep.photo], isNot(KycState.done));
      await tester.tap(shutter);
      await tester.pump();
      expect(store.uploads, 1);
      store.upload.complete();
      await tester.pumpAndSettle();
      expect(router.last?.n, N.steps);
      expect(store.steps[KycStep.photo], KycState.done);
      expect(store.signedUp, false);
      await cleanup(tester, store, router);
    },
  );
  testWidgets(
    'failed selfie upload stays incomplete and restores its in-screen camera for retry',
    (tester) async {
      final store = ActionStore(), router = WRouterC(), rig = FakeCameraRig();
      await show(
        tester,
        store,
        router,
        SelfieScreen(cameraController: rig.controller),
      );
      await tester.tap(shutter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      store.upload.completeError(StateError('Upload failed.'));
      await tester.pumpAndSettle();
      expect(router.path, isEmpty);
      expect(store.steps[KycStep.photo], isNot(KycState.done));
      expect(rig.controller.ready, true);
      expect(store.toast, contains('Upload failed'));
      await cleanup(tester, store, router);
    },
  );
  testWidgets(
    'application submission responds with loading and cannot be sent twice',
    (tester) async {
      final store = ActionStore()..kycUploaded = {'aadhaar', 'selfie'},
          router = WRouterC();
      await show(tester, store, router, const RulesScreen());
      await tester.tap(find.text('I agree'));
      await tester.pump();
      expect(store.submissions, 1);
      expect(router.path, isEmpty);
      expect(store.signedUp, false);
      final button = tester.widget<WButton>(find.byType(WButton).first);
      expect(button.loading, true);
      await tester.tap(find.byType(WButton).first);
      await tester.pump();
      expect(store.submissions, 1);
      store.submission.complete();
      await tester.pumpAndSettle();
      expect(router.last?.n, N.workSetup);
      expect(store.signedUp, false);
      await cleanup(tester, store, router);
    },
  );
  testWidgets(
    'payout save is single-flight and marks the step only after the save completes',
    (tester) async {
      final store = ActionStore()..upi = 'captain@bank', router = WRouterC();
      await show(tester, store, router, const BankScreen());
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(store.payoutCalls, 1);
      expect(store.steps[KycStep.bank], isNot(KycState.done));
      await tester.tap(find.byType(WButton).first);
      await tester.pump();
      expect(store.payoutCalls, 1);
      store.payout.complete();
      await tester.pumpAndSettle();
      expect(router.last?.n, N.steps);
      expect(store.steps[KycStep.bank], KycState.done);
      expect(store.signedUp, false);
      await cleanup(tester, store, router);
    },
  );
}
