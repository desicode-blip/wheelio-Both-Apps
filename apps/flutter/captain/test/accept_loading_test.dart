import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/home.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

class ClaimFixture extends CaptainStore {
  final pending = Completer<void>();
  int claims = 0, rejections = 0;
  @override bool get isLive => true;
  @override Future<void> liveClaim(String orderId) { claims++; return pending.future; }
  @override Future<void> liveReject(String orderId) async { rejections++; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('packages/washkrew_ui/Roboto')
      ..addFont(rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-Regular.ttf'));
    await loader.load();
  });
  testWidgets('one Accept tap shows progress, blocks duplicates/reject, then returns Home', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ClaimFixture()..signedUp=true..online=true;
    final router = WRouterC()..push(const R(N.jobAlert));
    store.liveOffers=[Job(id:'offer',plate:'QA',type:'Hatchback',isBike:false,pay:100,tower:'Area',floor:'Open',slot:'Parking',window:'6–8',time:'6:00')];
    store.offerExpiry['offer']=DateTime.now().add(const Duration(seconds:60));
    store.offerOutcomes['offer']='pending';
    await tester.pumpWidget(CaptainScope(store:store,router:router,child:const MaterialApp(home:JobAlertScreen())));
    await tester.pump();
    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(store.claims,1);
    final button=tester.widget<WButton>(find.byWidgetPredicate((w)=>w is WButton&&w.loading));
    expect(button.enabled,false);
    await tester.tap(find.text('Reject'),warnIfMissed:false);
    await tester.pump();
    expect(store.rejections,0);
    expect(store.claims,1);
    store.pending.complete();
    await tester.pump();
    expect(router.path,isEmpty);
    await tester.pumpWidget(const SizedBox());
    store.dispose();router.dispose();
  });
}
