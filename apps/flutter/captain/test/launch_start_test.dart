// 13 Nov (Aman): logged out → Language, then the welcome slides, every launch; logged in →
// Home; a logged-in account with no name must add it before anything else.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/main.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/welcome.dart';

class LaunchStore extends CaptainStore {
  LaunchStore({required bool loggedIn, String profileName = 'Raju'}) {
    sessionKnown = true;
    if (loggedIn) {
      liveUid = 'captain';liveLoaded = true;liveOrdersLoaded = true;queue = [];liveEarnings = [];liveOffers = [];
      registered = true;exploring = true;signedUp = false;liveCaptain = {'paymentMode': 'live'};name = profileName;
    }
  }
  @override bool get isLive => true;
  @override void refreshSystemPermission() {}
}

Future<void> open(WidgetTester tester, CaptainStore store) async {
  tester.view.physicalSize = const Size(390, 844);tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(CaptainApp(store: store));
  for (var i = 0; i < 4; i++) {await tester.pump(const Duration(milliseconds: 300));}
}

void main() {
  testWidgets('logged out: Language first, even if this session browsed as a guest', (tester) async {
    final store = LaunchStore(loggedIn: false)..exploring = true;
    await open(tester, store);
    expect(find.byType(LanguageScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('logged in: Home, no Language or slides', (tester) async {
    await open(tester, LaunchStore(loggedIn: true));
    expect(find.byType(LanguageScreen), findsNothing);
    expect(find.byType(WelcomeScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('logged in without a name: Add your name, no back', (tester) async {
    await open(tester, LaunchStore(loggedIn: true, profileName: ''));
    expect(find.text('Add your name'), findsOneWidget);
    expect(find.text('Your name is missing. Add it to continue.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
