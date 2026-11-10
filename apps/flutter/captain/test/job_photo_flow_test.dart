import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:washkrew_captain/data/store.dart';
import 'package:washkrew_captain/screens/wash.dart';
import 'package:washkrew_ui/washkrew_ui.dart';

class PhotoFixture extends CaptainStore {
 @override bool get isLive=>true;
 final review=Completer<List<dynamic>>(),finish=Completer<void>();
 int captures=0,reviews=0,finishes=0;
 bool customerPermission=false;
 bool? sentDecision;
 bool? skipped;
 @override bool get customerAllowsPhotoAi=>customerPermission;
 @override void queueEvidence({required bool after,required int side,required Uint8List bytes}){captures++;shots['${after?'after':'before'}_$side']=bytes;(after?afterDone:beforeDone).add(side);}
 @override Future<List<dynamic>> liveCheckPhotos({bool aiAllowed=false}){sentDecision=aiAllowed;reviews++;return review.future;}
 @override Future<void> liveProgress(String action,{bool acknowledgePhotoIssues=false,bool skipPhotoAi=false}){skipped=skipPhotoAi;finishes++;return finish.future;}
}
class CaptureFixture extends WCameraController {
 int captures=0,stops=0;
 @override Future<void> start({bool front=false})async{ready=true;notifyListeners();}
 @override Future<Uint8List?> capture()async{
   captures++;
   final frame=image.Image(width:640,height:480);
   for(var y=0;y<480;y++){for(var x=0;x<640;x++){frame.setPixelRgb(x,y,x%256,y%256,(x+y)%256);}}
   return Uint8List.fromList(image.encodeJpg(frame));
 }
 @override Future<void> stop()async{stops++;ready=false;}
}
Future<void> show(WidgetTester tester,PhotoFixture store,WRouterC router,Widget child)async{
 tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
 addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
 tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
 await tester.pumpWidget(CaptainScope(store:store,router:router,child:MaterialApp(home:child)));
 await tester.pump();await tester.pump();
}
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUpAll(()async{
   final loader=FontLoader('packages/washkrew_ui/Roboto')..addFont(rootBundle.load('packages/washkrew_ui/lib/fonts/Roboto-Regular.ttf'));await loader.load();
 });
 for(final checkAi in [false,true]){
   testWidgets('Captain chooses AI or direct send without a permission popup: $checkAi',(tester)async{
     final store=PhotoFixture()..afterDone={0,1,2,3}..customerPermission=true,router=WRouterC();
     await show(tester,store,router,const JobPhotosScreen(after:true));
     await tester.tap(find.text(checkAi?'Check with AI':'Send without AI'));await tester.pump();
     expect(find.text('Allow Google AI photo check?'),findsNothing);
     expect(store.reviews,checkAi?1:0);
     if(checkAi){expect(store.sentDecision,true);store.review.complete([]);await tester.pump();}
     expect(store.finishes,1);expect(store.skipped,!checkAi);
     store.finish.complete();await tester.pumpAndSettle();expect(router.last?.n,N.uploading);
     await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
   });
 }
 testWidgets('shutter advances the side without stopping/reopening camera or waiting for upload',(tester)async{
   final store=PhotoFixture(),router=WRouterC(),camera=CaptureFixture();
   await show(tester,store,router,JobCameraScreen(after:false,side:0,cameraController:camera));
   await tester.tap(find.byWidgetPredicate((w)=>w is Pressable&&w.label=='Take photo'));await tester.pump();
   await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:300)));
   await tester.pump();
   expect(store.captures,1);expect(store.beforeDone,{0});expect(find.text('Back'),findsOneWidget);expect(camera.stops,0);
   await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
 testWidgets('Customer OFF sends on the first tap without an AI call or repeated finish',(tester)async{
   final store=PhotoFixture()..afterDone={0,1,2,3},router=WRouterC();
   await show(tester,store,router,const JobPhotosScreen(after:true));
   expect(find.text('Check with AI'),findsNothing);expect(find.text('Send without AI'),findsNothing);
   await tester.tap(find.text('Send photos'));await tester.pump();
   expect(store.reviews,0);expect(store.finishes,1);expect(store.skipped,true);
   await tester.tap(find.byType(WButton),warnIfMissed:false);expect(store.finishes,1);
   store.finish.complete();await tester.pump();expect(router.last?.n,N.uploading);
   await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
 for(final after in [false,true]){for(var side=0;side<4;side++){
  testWidgets('viewfinder shows the wash phase and angle for ${after?'after':'before'} side $side',(tester)async{
   final store=PhotoFixture(),router=WRouterC(),camera=CaptureFixture();
   await show(tester,store,router,JobCameraScreen(after:after,side:side,cameraController:camera));
   final sideLabel=['Front','Back','Left','Right'][side];
   expect(find.text('${after?'After wash':'Before wash'} · $sideLabel · ${side+1}/4'),findsOneWidget);
   expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
  });
 }

 }
}
