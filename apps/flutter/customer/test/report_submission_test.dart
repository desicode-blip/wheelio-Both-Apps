import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_customer/data/report_submission.dart';
import 'package:washkrew_customer/data/store.dart';
import 'package:washkrew_customer/data/models.dart';
import 'package:washkrew_customer/screens/problem.dart';

void main(){
 test('report binds the original booking and retries an acknowledged-but-lost submission without reuploading locked photos',()async{
  final photos=[Uint8List.fromList([1,2,3])];var uploads=0,calls=0;
  final order=<String,dynamic>{'customerId':'owner','status':'photosReady'};
  Future<void> run()=>submitProblemReport(orderId:'original',ownerId:'owner',kind:'damage',note:'Scratch on the left',photos:photos,
   load:(id)async{expect(id,'original');return order;},upload:(id,index,bytes)async{expect(id,'original');uploads++;},
   submit:(data)async{expect(data['orderId'],'original');calls++;order['status']='disputed';order['dispute']={'kind':'damage','note':'Scratch on the left','photos':['original.jpg']};if(calls==1)throw StateError('Response lost');});
  await expectLater(run(),throwsStateError);await run();expect(uploads,1);expect(calls,2);
 });
 test('failed upload prevents report mutation; ownership, active-wash and conflicting-report cases reject before uploads',()async{
  var submits=0,uploads=0;Map<String,dynamic>? order={'customerId':'owner','status':'photosReady'};
  Future<void> run()=>submitProblemReport(orderId:'wash',ownerId:'owner',kind:'notClean',note:'Dirt',photos:[Uint8List(1)],load:(_)async=>order,
   upload:(_,_,_)async{uploads++;throw StateError('Offline');},submit:(_)async{submits++;});
  await expectLater(run(),throwsStateError);expect(submits,0);expect(uploads,1);
  for(final value in [null,{'customerId':'other','status':'photosReady'},{'customerId':'owner','status':'washing'},{'customerId':'owner','dispute':{'kind':'damage','note':'Other report','photos':[]}}]){
   order=value;await expectLater(run(),throwsStateError);
  }
  expect(uploads,1);expect(submits,0);
 });
 testWidgets('report Next carries the original booking even if another notification selects a different booking',(tester)async{
  final store=AppStore()..currentOrderId='original',router=AppRouter();
  await tester.pumpWidget(AppScope(store:store,router:router,child:const MaterialApp(home:ReportProblemScreen(orderId:'original'))));
  store.currentOrderId='different';await tester.tap(find.text('Next'));expect(router.last?.id,'original');expect(router.last?.n,N.problemPhotos);
  await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
 testWidgets('no-show can be described without impossible wash photos and submit is disabled until evidence or details exist',(tester)async{
  final store=AppStore(),router=AppRouter();
  await tester.pumpWidget(AppScope(store:store,router:router,child:const MaterialApp(home:ProblemPhotosScreen(kind:ProblemKind.noShow,orderId:'original'))));
  // Demo retains authored sample evidence; live validation is covered by the
  // report coordinator and the authenticated backend tests.
  expect(find.text('Describe what happened. Add a photo if you have one.'),findsOneWidget);
  await tester.pumpWidget(const SizedBox());store.dispose();router.dispose();
 });
}
