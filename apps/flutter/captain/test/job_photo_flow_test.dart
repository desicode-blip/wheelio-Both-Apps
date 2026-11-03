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
 @override bool get customerAllowsPhotoAi=>customerPermission;
 @override void queueEvidence({required bool after,required int side,required Uint8List bytes}){captures++;shots['${after?'after':'before'}_$side']=bytes;(after?afterDone:beforeDone).add(side);}
 @override Future<List<dynamic>> liveCheckPhotos({bool aiAllowed=false}){sentDecision=aiAllowed;reviews++;return review.future;}
 @override Future<void> liveProgress(String action,{bool acknowledgePhotoIssues=false}){finishes++;return finish.future;}
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
 for(final allowed in [false,true]){
   testWidgets('Captain forwards only the explicit AI choice $allowed',(tester)async{
     final store=PhotoFixture()..afterDone={0,1,2,3}..customerPermission=true,router=WRouterC();
     await show(tester,store,router,const JobPhotosScreen(after:true));
     await tester.tap(find.text('Check photos'));await tester.pump();await tester.pump(const Duration(milliseconds:300));
     expect(store.reviews,0);
     expect(find.text('Allow Google AI photo check?'),findsOneWidget);
     await tester.tap(find.text(allowed?'Allow AI check':'Continue without AI'));await tester.pump();
     expect(store.reviews,1);expect(store.sentDecision,allowed);
     store.review.complete([]);store.finish.complete();await tester.pumpAndSettle();
     expect(router.last?.n,N.uploading);
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
 testWidgets('Check photos responds on first tap and waits for actual finish before leaving',(tester)async{
   final store=PhotoFixture()..afterDone={0,1,2,3},router=WRouterC();
   await show(tester,store,router,const JobPhotosScreen(after:true));
   await tester.tap(find.text('Check photos'));await tester.pump();
   expect(store.reviews,1);expect(tester.widget<WButton>(find.byType(WButton)).loading,true);
   expect(store.sentDecision,false);expect(find.text('Allow Google AI photo check?'),findsNothing);
   await tester.tap(find.byType(WButton),warnIfMissed:false);expect(store.reviews,1);
   store.review.complete([]);await tester.pump();expect(store.finishes,1);expect(router.path,isEmpty);
   store.finish.complete();await tester.pump();expect(router.last?.n,N.uploading);
   await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
}
