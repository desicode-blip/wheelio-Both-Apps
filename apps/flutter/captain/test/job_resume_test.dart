import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/main.dart';
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/data/job_resume.dart';
import 'package:washkrew_captain/screens/wash.dart';

class Stamp{Stamp(this.date);final DateTime date;DateTime toDate()=>date;}
class ResumeFixture extends CaptainStore{
  ResumeFixture(){
    liveUid='captain';queue=[];liveEarnings=[];liveOffers=[];
    signedUp=true;registered=true;exploring=true;online=false;
    liveCaptain={'paymentMode':'live'};name='Test';
  }
  @override bool get isLive=>true;
  @override void refreshSystemPermission(){}
  @override void markRead(String id){}
}
Map<String,dynamic> order({String status='washing',int after=4})=>{
  'id':'job','captainId':'captain','status':status,'paymentMode':'live',
  'day':DateTime.now().toIso8601String().substring(0,10),
  'slotStart':Stamp(DateTime.now().subtract(const Duration(minutes:30))),
  'slotEnd':Stamp(DateTime.now().add(const Duration(hours:1))),
  'arrivedAt':Stamp(DateTime.now()),'identityStatus':'verified',
  'vehicleName':'Hatchback','vehicleKind':'hatchback','captainPayPaise':10000,
  'evidence':{for(var i=0;i<4;i++)'before_$i':<String,dynamic>{},for(var i=0;i<after;i++)'after_$i':<String,dynamic>{}},
};
Future<void> phone(WidgetTester tester)async{
  tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
}
Future<void> settle(WidgetTester tester)async{
  await tester.pump();await tester.pump(const Duration(milliseconds:400));await tester.pump();
}
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(()async{
    final loader=FontLoader('packages/washkrew_ui/Roboto');
    for(final weight in ['Regular','Medium','SemiBold','Bold']){loader.addFont(rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-$weight.ttf'));}
    await loader.load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test('server phases never restart a washing/submitted job at selfie',(){
    expect(captainJobPhase(null),isNull);
    expect(captainJobPhase({'status':'pendingPayment'}),isNull);
    expect(captainJobPhase({'status':'onTheWay'}),CaptainJobPhase.arrival);
    expect(captainJobPhase({'status':'onTheWay','arrivedAt':1}),CaptainJobPhase.identity);
    expect(captainJobPhase({'status':'onTheWay','arrivedAt':1,'identityStatus':'verified'}),CaptainJobPhase.beforePhotos);
    expect(captainJobPhase({'status':'onTheWay','arrivedAt':1,'customerMedia':{'note_audio':{}},'identityStatus':'verified'}),CaptainJobPhase.ownerNote);
    expect(captainJobPhase(order(after:0)),CaptainJobPhase.washing);
    expect(captainJobPhase(order(after:1)),CaptainJobPhase.afterPhotos);
    expect(captainJobPhase(order()),CaptainJobPhase.afterPhotos);
    expect(captainJobPhase(order(status:'photosReady')),CaptainJobPhase.submitted);
    expect(captainJobPhase(order(status:'cancelled')),CaptainJobPhase.cancelled);
  });
  test('job and notification entry restore confirmed photo counts and ignore another account snapshot',(){
    final store=ResumeFixture()..liveLoaded=true,router=WRouterC();
    store.receiveLiveOrders('another',[order()]);expect(store.liveOrders,isEmpty);
    store.receiveLiveOrders('captain',[order(after:2)]);
    expect(store.resumeWork(router),true);expect(router.last?.n,N.afterPhotos);
    expect(store.current.id,'job');expect(store.beforeDone,{0,1,2,3});expect(store.afterDone,{0,1});
    final notice=WNotif(id:'assigned',kind:WNotifKind.newJob,date:DateTime.now(),jobId:'job');
    expect(openWNotif(notice,store,router),isNull);expect(router.last?.n,N.afterPhotos);
    store.dispose();router.dispose();
  });
  testWidgets('cold reopen restores all uploaded After photos without asking for another selfie',(tester)async{
    await phone(tester);
    final saved=order();
    for(var opening=0;opening<2;opening++){
      final store=ResumeFixture()..liveLoaded=true;
      store.receiveLiveOrders('captain',[saved]);
      await tester.pumpWidget(CaptainApp(store:store));await settle(tester);
      expect(find.byType(JobPhotosScreen),findsOneWidget);
      expect(find.text('After photos'),findsOneWidget);expect(find.text('Send photos'),findsOneWidget);
      expect(find.text('Show your face'),findsNothing);expect(store.afterDone,{0,1,2,3});
      await tester.pumpWidget(const SizedBox());await tester.pump();
    }
  });
  for(final profileFirst in [true,false]){
    testWidgets('startup waits for profile and server orders, profileFirst=$profileFirst',(tester)async{
      await phone(tester);
      final store=ResumeFixture()..signedUp=profileFirst..liveLoaded=profileFirst;
      store.receiveLiveOrders('captain',[],fromCache:true);
      await tester.pumpWidget(CaptainApp(store:store));await settle(tester);
      expect(find.byType(JobPhotosScreen),findsNothing);
      store.receiveLiveOrders('captain',[order(after:1)]);
      if(!profileFirst){expect(find.byType(JobPhotosScreen),findsNothing);store.set((){store.signedUp=true;store.liveLoaded=true;});}
      await settle(tester);expect(find.text('After photos'),findsOneWidget);expect(store.afterDone,{0});
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('a stale selfie route redirects to After photos before opening any camera',(tester)async{
    await phone(tester);
    final store=ResumeFixture()..liveLoaded=true,router=WRouterC()..go(N.faceCheck);
    store.receiveLiveOrders('captain',[order()]);
    await tester.pumpWidget(CaptainScope(store:store,router:router,child:const MaterialApp(home:FaceCheckScreen())));await settle(tester);
    expect(router.last?.n,N.afterPhotos);
    await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
  });
}
