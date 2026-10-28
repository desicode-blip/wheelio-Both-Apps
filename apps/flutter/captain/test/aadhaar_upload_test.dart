import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/onboarding.dart';

class UploadOnlyStore extends CaptainStore {
  @override
  bool get isLive => true;
}

void main() {
  for (final language in Lang.values) {
    testWidgets('Aadhaar uses phone upload and no DigiLocker in ${language.name}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = UploadOnlyStore()..lang = language;
      final router = WRouterC();
      await tester.pumpWidget(CaptainScope(store: store, router: router, child: const MaterialApp(home: AadhaarScreen())));
      expect(find.textContaining('DigiLocker'), findsNothing);
      expect(find.text('Skip this step (testing)'), findsNothing);
      expect(store.steps[KycStep.aadhaar], isNot(KycState.done));
      final upload = store.t('Upload Aadhaar photo', 'आधार की फ़ोटो अपलोड करें', 'ఆధార్ ఫోటో అప్‌లోడ్ చేయండి');
      expect(find.text(upload), findsOneWidget);
      await tester.tap(find.text(upload));
      await tester.pumpAndSettle();
      expect(find.text(store.t('Take photo', 'फ़ोटो लें', 'ఫోటో తీయండి')), findsOneWidget);
      expect(find.text(store.t('Choose from gallery', 'गैलरी से चुनें', 'గ్యాలరీ నుండి ఎంచుకోండి')), findsOneWidget);
      await tester.tap(find.text(store.t('Cancel', 'रद्द करें', 'రద్దు చేయండి')));
      await tester.pumpAndSettle();
      expect(store.steps[KycStep.aadhaar], isNot(KycState.done));
      expect(store.signedUp, isFalse);
      expect(store.online, isFalse);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      router.dispose();
    });
  }
}
