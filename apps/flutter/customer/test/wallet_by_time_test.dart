import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/screens/booking.dart';
import 'package:washkrew_customer/screens/common.dart';
import 'package:washkrew_customer/screens/live.dart';
import 'package:washkrew_customer/screens/problem.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

const timingPolicy = <String,dynamic>{'kind':'walletByTime','creditMinutes':5,'cutoffMinutes':120,'lateCreditBps':5000,'serviceFailure':'wallet'};
class TimingStore extends AppStore {
  @override
  bool get isLive => true;
  TimingStore({this.phase='fullCredit'}) {
    liveConfig={'cancellationPolicy':timingPolicy};
    final o=sampleOrder(OrderStatus.onTheWay);
    o.paymentStatus='captured';o.liveCancelPolicy=timingPolicy;
  }
  String phase;
  bool crossOnConfirm=false;
  String? confirmed;
  int cancelCalls=0;
  int get returned => phase=='fullCredit'?14900:phase=='partialCredit'?7450:0;
  @override
  Future<Map<String,dynamic>?> cancellationQuote(String id) async => {'orderId':id,'currency':'INR','kind':'credit','phase':phase,'cashRefundPaise':0,'walletCreditPaise':returned,'feePaise':14900-returned,'freeWashesRestored':0,'confirmation':phase,'creditCutoffAt':DateTime.parse('2026-11-01T10:00:00+05:30').millisecondsSinceEpoch,'fullCreditDeadlineAt':DateTime.parse('2026-11-01T07:05:00+05:30').millisecondsSinceEpoch};
  @override
  Future<void> cancel(String id,{String? confirmation}) async {
    cancelCalls++;
    if(crossOnConfirm){crossOnConfirm=false;phase='noCredit';throw StateError('Cancellation terms have changed. Review the amounts and confirm again.');}
    confirmed=confirmation;currentOrder!.status=OrderStatus.cancelled;changed();
  }
}
final captureKey=GlobalKey();
Future<void> capture(WidgetTester tester,String name) async {
  const target=String.fromEnvironment('WALLET_CAPTURE_DIR');
  if(target.isEmpty)return;
  // Explicit local widget fixtures only; this never connects to Firebase.
  await tester.runAsync(() async {
    final boundary=captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image=await boundary.toImage(pixelRatio:1);
    final data=await image.toByteData(format:ui.ImageByteFormat.png);
    Directory(target).createSync(recursive:true);File('$target/$name.png').writeAsBytesSync(data!.buffer.asUint8List());image.dispose();
  });
}
Future<void> phone(WidgetTester tester,AppStore store,AppRouter router,Widget child) async {
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(RepaintBoundary(key:captureKey,child:AppScope(store:store,router:router,child:MaterialApp(debugShowCheckedModeBanner:false,home:child))));await tester.pumpAndSettle();
}
Future<void> cleanup(WidgetTester tester,AppStore store,AppRouter router) async {await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(()async{
    final loader=FontLoader('packages/washkrew_ui/Roboto');for(final n in ['Regular','Medium','SemiBold','Bold']){loader.addFont(rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-$n.ttf'));}await loader.load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('CupertinoIcons')..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'))).load();
  });
  test('new terms and outcome copy never promise a cash refund for wallet cancellation',(){
    final store=TimingStore(),o=store.currentOrder!;
    expect(o.cancellationTerms,contains('100% wallet credit'));expect(o.cancellationTerms,contains('0% inside 2 hours'));expect(o.cancellationTerms,contains('No bank refund'));
    for(final phase in ['fullCredit','partialCredit','noCredit']){
      store.phase=phase;o.cancellationOutcome={'kind':'credit','phase':phase,'creditPaise':store.returned,'feePaise':14900-store.returned,'restoreReserved':false};
      expect(o.cancellationSummary,contains('No bank refund'));expect(o.returnedWalletCredit,store.returned/100);
    }store.dispose();
  });
  testWidgets('existing Review card discloses grace, two-hour cutoff and wallet reuse on the authored phone width',(tester)async{
    final s=TimingStore()..draftFull(),r=AppRouter();s.customer=Customer(id:'fixture',phone:'')..credit=74.5;
    await phone(tester,s,r,const ReviewScreen());
    expect(find.text(cancellationPolicyText(timingPolicy)),findsOneWidget);expect(find.text('Choose Pay by wallet below, or top up your balance.'),findsOneWidget);expect(s.draft.pricePaise,14900);expect(tester.takeException(),isNull);
    await tester.ensureVisible(find.text(cancellationPolicyText(timingPolicy)));await tester.pumpAndSettle();await capture(tester,'review');
    await cleanup(tester,s,r);
  });
  for(final phase in ['fullCredit','partialCredit','noCredit']){
    testWidgets('existing cancel sheet renders $phase using the server amount',(tester)async{
      final s=TimingStore(phase:phase),r=AppRouter();
      await phone(tester,s,r,Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()=>openCancelSheet(context,s.currentOrder!),child:const Text('Open')))));
      await tester.tap(find.text('Open'));await tester.pumpAndSettle();
      expect(find.textContaining('No bank refund'),findsOneWidget);
      expect(find.textContaining(phase=='noCredit'?'No wallet credit is returned':'${Fmt.rupees(s.returned/100)} goes to your wallet'),findsOneWidget);
      expect(find.text('Cancel booking'),findsOneWidget);expect(tester.takeException(),isNull);
      await capture(tester,'cancel-$phase');
      await cleanup(tester,s,r);
    });
  }
  testWidgets('crossing the two-hour cutoff refreshes amounts and requires another confirmation',(tester)async{
    final s=TimingStore(phase:'partialCredit')..crossOnConfirm=true,r=AppRouter();
    await phone(tester,s,r,Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()=>openCancelSheet(context,s.currentOrder!),child:const Text('Open')))));
    await tester.tap(find.text('Open'));await tester.pumpAndSettle();await tester.tap(find.text('Cancel booking'));await tester.pumpAndSettle();
    expect(s.cancelCalls,1);expect(s.confirmed,isNull);expect(find.textContaining('No wallet credit is returned'),findsOneWidget);
    await tester.ensureVisible(find.text('Cancel booking'));await tester.tap(find.text('Cancel booking'));await tester.pumpAndSettle();
    expect(s.confirmed,'noCredit');expect(s.cancelCalls,2);await cleanup(tester,s,r);
  });
  testWidgets('zero-credit cancellation uses the existing result without a bank-refund action',(tester)async{
    final s=TimingStore(),r=AppRouter(),o=s.currentOrder!;o.status=OrderStatus.cancelled;o.cancellationOutcome={'kind':'credit','phase':'noCredit','creditPaise':0,'feePaise':14900,'restoreReserved':false};
    await phone(tester,s,r,const LiveOrderScreen());expect(find.textContaining('No wallet credit is returned'),findsOneWidget);expect(find.text('Book again'),findsOneWidget);expect(find.text('Track refund'),findsNothing);expect(tester.takeException(),isNull);await capture(tester,'cancelled-zero');await cleanup(tester,s,r);
  });
  testWidgets('service failure displays actual full wallet credit without asking for a UPI refund',(tester)async{
    final s=TimingStore(),r=AppRouter(),o=s.currentOrder!;o.status=OrderStatus.noCaptain;o.cancellationOutcome={'kind':'credit','phase':'serviceFailure','creditPaise':14900,'feePaise':0,'restoreReserved':false};
    await phone(tester,s,r,const LiveOrderScreen());expect(find.text('Wallet credit'),findsOneWidget);expect(find.text('₹149'),findsOneWidget);expect(find.text('See refund'),findsNothing);expect(find.text('Go home'),findsOneWidget);expect(tester.takeException(),isNull);await capture(tester,'service-failure');await cleanup(tester,s,r);
  });
  testWidgets('a human-upheld report shows wallet credit and does not invent a bonus free wash',(tester)async{
    final s=TimingStore(),r=AppRouter(),o=s.currentOrder!;o.status=OrderStatus.disputeUpheld;o.cancellationOutcome={'kind':'credit','phase':'serviceFailure','creditPaise':14900,'feePaise':0,'restoreReserved':false};o.dispute=Dispute(ref:'FIXTURE',kind:ProblemKind.notClean,createdAt:DateTime.now(),note:'Fixture',outcome:DisputeOutcome.upheld,decisionNote:'Human-reviewed fixture',creditsAwarded:0);
    await phone(tester,s,r,const DisputeStatusScreen());expect(find.text('Wallet credit'),findsOneWidget);expect(find.text('Book again'),findsOneWidget);expect(find.text('Book free wash'),findsNothing);expect(tester.takeException(),isNull);await capture(tester,'dispute-upheld');await cleanup(tester,s,r);
  });
}
